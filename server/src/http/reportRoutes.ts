// Passenger report write endpoint. One route, two operations: report and
// retract. No report ids, no votes, no coordinates. Reads ride on the line
// snapshot; this route only changes in-memory state.
// PRIVACY: no area id, kind, or device id is logged.
// See DECISIONS.md#D82/D83 and PLAN.md 6.5.
import { Hono } from "@hono/hono";
import type { Sql } from "../db/client.ts";
import { guardState } from "../db/guard.ts";
import type { RuntimeConfig } from "../config/runtime.ts";
import type { LineResolver } from "../data/lines.ts";
import { isAreaInServedBBox, isValidAreaId } from "../domain/areas.ts";
import {
  applyReport,
  reportRows,
  retractReport,
  targetMismatch,
} from "../domain/reports.ts";
import {
  recordHttp403,
  recordHttp429,
  recordReportCreated,
  recordReportRetracted,
} from "../observability/metrics.ts";
import { authMiddleware } from "../security/auth.ts";
import { RateLimiter } from "../security/rateLimit.ts";
import type { Store } from "../state/store.ts";
import { readJsonBody } from "./body.ts";
import { parseJson, ReportBody } from "./schemas.ts";

const BODY_CAP = 1024;

type Vars = {
  Variables: { requestId: string; deviceId: string; clientIp: string };
};

export interface ReportDeps {
  sql: Sql;
  store: Store;
  lines: LineResolver;
  runtime: () => Promise<RuntimeConfig>;
  onLineChanged: (lineId: number) => void;
}

export function buildReportRoutes(deps: ReportDeps): Hono<Vars> {
  const app = new Hono<Vars>();
  const auth = authMiddleware(deps.sql);
  // Generous but finite; reports are tiny and rare per device.
  const perDevice = new RateLimiter(12, 60 * 1000);
  const perIp = new RateLimiter(60, 60 * 1000);

  app.post("/v1/reports", auth, async (c) => {
    const nowMs = Date.now();
    const rt = await deps.runtime();
    if (!rt.serviceEnabled || !rt.reports.enabled) {
      c.header("Retry-After", "30");
      return c.json({ e: "maint" }, 503);
    }
    const deviceId = c.get("deviceId");
    const ip = c.get("clientIp");
    if (!perDevice.hit(deviceId, nowMs) || !perIp.hit(ip, nowMs)) {
      c.header("Retry-After", "60");
      recordHttp429();
      return c.json({ e: "rate" }, 429);
    }
    const state = await guardState(deps.sql, deviceId);
    if (state.blocked) {
      recordHttp403();
      return c.json({ e: "blocked" }, 403);
    }
    const body = await readJsonBody(c, BODY_CAP);
    if (body.kind !== "json") {
      return c.json(
        { e: body.kind === "media" ? "media" : "bad_request" },
        body.kind === "media" ? 415 : 400,
      );
    }
    const parsed = parseJson(ReportBody, body.value);
    if (parsed === null) return c.json({ e: "bad_request" }, 400);
    const line = deps.lines(parsed.line);
    if (!line || !line.isActive) return c.json({ e: "line" }, 404);
    const areaId = parsed.area ?? null;
    if (areaId !== null) {
      if (!isValidAreaId(areaId) || !isAreaInServedBBox(areaId)) {
        return c.json({ e: "bad_request" }, 400);
      }
    }
    if (targetMismatch(parsed.kind, areaId)) {
      return c.json({ e: "bad_request" }, 400);
    }
    if (parsed.op === "report") {
      const out = applyReport(
        deps.store,
        line.id,
        parsed.kind,
        areaId,
        deviceId,
        nowMs,
        rt.reports,
      );
      if (!out.ok) {
        if (out.code === "disabled") {
          c.header("Retry-After", "30");
          return c.json({ e: "maint" }, 503);
        }
        c.header("Retry-After", "60");
        recordHttp429();
        return c.json({ e: "quota" }, 429);
      }
      if (out.changed) deps.onLineChanged(line.id);
      if (out.created) recordReportCreated();
      return c.json(
        {
          t: Math.floor(nowMs / 1000),
          r: reportRows(deps.store, line.id, nowMs),
        },
        out.created ? 201 : 200,
      );
    }
    const out = retractReport(
      deps.store,
      line.id,
      parsed.kind,
      areaId,
      deviceId,
    );
    if (out.changed) deps.onLineChanged(line.id);
    if (out.changed) recordReportRetracted();
    return c.json({
      t: Math.floor(nowMs / 1000),
      r: reportRows(deps.store, line.id, nowMs),
    });
  });

  return app;
}
