// In-process consumer for the learning subsystem. Subscribes to engine
// events, maintains per-trip working state in memory, and accumulates
// de-identified aggregates that are flushed to PostgreSQL periodically.
// See docs/data-learning.md sections 3-5.
import { decodePolyline, distM, encodePolyline } from "../domain/geo.ts";
import {
  recordLearningDirectionAssigned,
  recordLearningFlush,
  recordLearningFlushFailed,
  recordLearningRouteBelowMinTrips,
  recordLearningRouteChainTooSmall,
  recordLearningRouteNoFlapSuppressed,
  recordLearningRouteOversized,
  recordLearningRoutePublished,
  recordLearningRouteRetired,
  recordLearningRouteTooShort,
  recordLearningTripGapDropped,
  recordLearningTripIneligible,
  recordLearningTripNoCellTransition,
  recordLearningTripsContributed,
  recordLearningTripTooFewSamples,
  recordLearningTripTooShort,
} from "../observability/metrics.ts";
import { medianDeviationM, simplify, smooth } from "./routeLearner.ts";
import {
  addTrip,
  assignOrdinals,
  buildChain,
  type CorridorAcc,
  coverageScore,
  DEFAULT_MAX_GAP_M,
  newCorridorAcc,
  type Pt,
} from "./corridor.ts";
import type { EngineEvent } from "../domain/types.ts";
import type { Sql } from "../db/client.ts";
import type {
  DwellAcc,
  LearningConfig,
  SegmentAcc,
  StopCluster,
  TripWork,
} from "./types.ts";

export interface ConsumerDeps {
  sql: Sql;
  config: () => LearningConfig;
  now: () => number;
  /** Privacy gate selected by env; see DECISIONS.md#D98. */
  privacyMode: () => "all" | "route_stops";
  // consent version lookup for a device is done by caller; consumer
  // receives it via handleTripStart's consentVersion.
}

function dayKey(ms: number, tzOffsetHours = -3): string {
  // America/Sao_Paulo is UTC-3 (no DST since 2019).
  const d = new Date(ms + tzOffsetHours * 3600 * 1000);
  return d.toISOString().slice(0, 10);
}

function dayOfWeek(ms: number, tzOffsetHours = -3): number {
  const d = new Date(ms + tzOffsetHours * 3600 * 1000);
  return d.getUTCDay();
}

function hourBucket(ms: number, tzOffsetHours = -3): number {
  const d = new Date(ms + tzOffsetHours * 3600 * 1000);
  return d.getUTCHours() * 4 + Math.floor(d.getUTCMinutes() / 15);
}

export class LearningConsumer {
  private works = new Map<string, TripWork>();
  private routeAccs = new Map<string, CorridorAcc>();
  private stopClusters = new Map<string, StopCluster>();
  private dwellAccs = new Map<string, DwellAcc>();
  private segmentAccs = new Map<string, SegmentAcc>();
  private watermarkTrips = new Map<string, number>();
  private terminusStopIds = new Set<string>();
  private config: LearningConfig;

  constructor(private deps: ConsumerDeps) {
    this.config = deps.config();
  }

  reloadConfig(): void {
    this.config = this.deps.config();
  }

  /** Seed direction slots from persisted learned_routes (F3). */
  async loadLearnedRoutes(): Promise<void> {
    try {
      const rows = await this.deps.sql`
        select line_id, direction, polyline from learned_routes
        where status = 'active'
        order by line_id asc, direction asc, version desc
      `;
      for (
        const r of rows as unknown as Array<{
          line_id: number;
          direction: number;
          polyline: string;
        }>
      ) {
        const k = this.key(r.line_id, r.direction);
        if (this.routeAccs.has(k)) continue;
        let origin: Pt | null = null;
        try {
          origin = decodePolyline(r.polyline, 5)[0] ?? null;
        } catch {
          origin = null;
        }
        if (!origin) continue;
        this.routeAccs.set(
          k,
          newCorridorAcc(
            r.line_id,
            r.direction,
            origin,
            this.config.corridorCellM,
          ),
        );
      }
    } catch {
      // DB down.
    }
  }

  /** Seed in-memory stop clusters from persisted learned_stops (F2). */
  async loadLearnedStops(): Promise<void> {
    try {
      const rows = await this.deps.sql`
        select id, line_id, direction, ordinal, lat, lng, radius_m, sample_passes
        from learned_stops
        where active = true
      `;
      for (
        const r of rows as unknown as Array<{
          id: string;
          line_id: number;
          direction: number;
          ordinal: number;
          lat: number;
          lng: number;
          radius_m: number;
          sample_passes: number;
        }>
      ) {
        if (this.stopClusters.has(r.id)) continue;
        const c: StopCluster = {
          id: r.id,
          lineId: r.line_id,
          direction: r.direction,
          ordinal: r.ordinal,
          centroidLat: r.lat,
          centroidLng: r.lng,
          radiusM: r.radius_m,
          passCount: r.sample_passes,
          distinctDays: new Set(["seed", "seed2", "seed3"]),
          reservoir: [],
        };
        this.stopClusters.set(r.id, c);
      }
    } catch {
      // DB down: skip seeding.
    }
  }

  isEnabled(): boolean {
    return this.config.enabled;
  }

  configSnapshot(): LearningConfig {
    return this.config;
  }

  private key(lineId: number, direction: number): string {
    return `${lineId}:${direction}`;
  }

  handle(
    event: EngineEvent,
    opts: { consentVersion: number; eligible: boolean },
  ): void {
    if (!this.config.enabled) return;
    switch (event.kind) {
      case "tripStarted":
        this.onTripStarted(event, opts);
        break;
      case "fixAccepted":
        this.onFixAccepted(event);
        break;
      case "tripEnded":
        this.onTripEnded(event);
        break;
      default:
        break;
    }
  }

  private onTripStarted(
    e: Extract<EngineEvent, { kind: "tripStarted" }>,
    opts: { consentVersion: number; eligible: boolean },
  ): void {
    if (opts.consentVersion < this.config.minConsentVersion) {
      recordLearningTripIneligible();
      return;
    }
    if (!opts.eligible) {
      recordLearningTripIneligible();
      return;
    }
    const work: TripWork = {
      tripKey: e.tripKey,
      lineId: e.lineId,
      direction: null,
      consentVersion: opts.consentVersion,
      eligible: true,
      startedAtMs: e.startedAtMs,
      endedAtMs: null,
      samples: [{ t: e.startedAtMs, lat: e.lat, lng: e.lng, speed: 0 }],
      dwells: [],
      totalDistanceM: 0,
    };
    this.works.set(e.tripKey, work);
  }

  private onFixAccepted(
    e: Extract<EngineEvent, { kind: "fixAccepted" }>,
  ): void {
    const work = this.works.get(e.tripKey);
    if (!work) return;
    const last = work.samples[work.samples.length - 1];
    const dt = e.atMs - last.t;
    const dd = distM(last.lat, last.lng, e.lat, e.lng);
    if (
      dd < this.config.minSampleSpacingM &&
      dt < this.config.minSampleSpacingS * 1000
    ) {
      // downsample: replace last sample with newer one
      work.samples[work.samples.length - 1] = {
        t: e.atMs,
        lat: e.lat,
        lng: e.lng,
        speed: e.speedMps,
      };
      return;
    }
    if (work.samples.length >= this.config.maxSamplesPerTrip) {
      // uniform downsample by dropping every other
      work.samples = work.samples.filter((_, i) => i % 2 === 0);
    }
    work.samples.push({ t: e.atMs, lat: e.lat, lng: e.lng, speed: e.speedMps });
    work.totalDistanceM += dd;

    // dwell detection: if speed below threshold, extend or start dwell
    if (e.speedMps < this.config.stopSpeedMps) {
      const lastDwell = work.dwells[work.dwells.length - 1];
      if (
        lastDwell &&
        e.atMs - lastDwell.endMs < this.config.minDwellS * 1000 + 5000
      ) {
        lastDwell.endMs = e.atMs;
        // update centroid running (simple: keep first; recompute at flush)
      } else {
        work.dwells.push({
          lat: e.lat,
          lng: e.lng,
          startMs: e.atMs,
          endMs: e.atMs,
        });
      }
    }
  }

  private onTripEnded(e: Extract<EngineEvent, { kind: "tripEnded" }>): void {
    const work = this.works.get(e.tripKey);
    if (!work) return;
    work.endedAtMs = this.deps.now();
    this.finalizeTrip(work);
    this.works.delete(e.tripKey);
  }

  private finalizeTrip(work: TripWork): void {
    if (work.samples.length < 3) {
      recordLearningTripTooFewSamples();
      return;
    }
    const cfg = this.config;
    // trim ends
    const start = work.startedAtMs + cfg.trimEndsS * 1000;
    const end = (work.endedAtMs ?? work.samples[work.samples.length - 1].t) -
      cfg.trimEndsS * 1000;
    const kept = work.samples.filter((s) => s.t >= start && s.t <= end);
    if (kept.length < 3) {
      recordLearningTripTooFewSamples();
      return;
    }

    // total distance
    let total = 0;
    for (let i = 1; i < kept.length; i++) {
      total += distM(
        kept[i - 1].lat,
        kept[i - 1].lng,
        kept[i].lat,
        kept[i].lng,
      );
    }
    if (total < cfg.minTripRouteM) {
      recordLearningTripTooShort();
      return;
    }

    const keptPoints: Pt[] = kept.map((s) => ({ lat: s.lat, lng: s.lng }));
    // Count dropped long gaps (segments longer than the corridor max gap).
    let gapDropped = false;
    for (let i = 1; i < keptPoints.length; i++) {
      if (
        distM(
          keptPoints[i - 1].lat,
          keptPoints[i - 1].lng,
          keptPoints[i].lat,
          keptPoints[i].lng,
        ) > DEFAULT_MAX_GAP_M
      ) {
        gapDropped = true;
      }
    }
    if (gapDropped) recordLearningTripGapDropped();
    const direction = this.assignDirection(work.lineId, keptPoints);
    work.direction = direction;
    recordLearningDirectionAssigned();

    // Absolute-space corridor accumulation per (line, direction). Progress
    // bins cannot place partial trips in a shared frame. See D98.
    const accKey = this.key(work.lineId, direction);
    let acc = this.routeAccs.get(accKey);
    if (!acc) {
      acc = newCorridorAcc(
        work.lineId,
        direction,
        keptPoints[0],
        cfg.corridorCellM,
      );
      this.routeAccs.set(accKey, acc);
    }
    const beforeTrips = acc.tripCount;
    addTrip(acc, keptPoints);
    if (acc.tripCount > beforeTrips) {
      this.watermarkTrips.set(
        accKey,
        (this.watermarkTrips.get(accKey) ?? 0) + 1,
      );
    } else {
      recordLearningTripNoCellTransition();
    }

    // dwell detection finalization
    const trimStart = start;
    const trimEnd = end;
    for (const d of work.dwells) {
      if (d.endMs - d.startMs < cfg.minDwellS * 1000) continue;
      if (d.startMs < trimStart || d.endMs > trimEnd) continue;
      const durS = (d.endMs - d.startMs) / 1000;
      const hb = hourBucket(d.startMs);
      const dow = dayOfWeek(d.startMs);
      const day = dayKey(d.startMs);
      // cluster assignment deferred to flush-time; store as a pseudo-stop
      // keyed by rounded coords for now.
      // find existing cluster within radius
      let cluster: StopCluster | undefined;
      for (const c of this.stopClusters.values()) {
        if (c.lineId !== work.lineId || c.direction !== direction) continue;
        if (
          distM(c.centroidLat, c.centroidLng, d.lat, d.lng) <=
            cfg.stopClusterRadiusM
        ) {
          cluster = c;
          break;
        }
      }
      if (!cluster) {
        const id = crypto.randomUUID();
        cluster = {
          id,
          lineId: work.lineId,
          direction,
          ordinal: 0,
          centroidLat: d.lat,
          centroidLng: d.lng,
          radiusM: cfg.stopClusterRadiusM,
          passCount: 0,
          distinctDays: new Set(),
          reservoir: [],
        };
        this.stopClusters.set(id, cluster);
      }
      // update centroid running
      cluster.reservoir.push({ lat: d.lat, lng: d.lng, day });
      cluster.passCount += 1;
      cluster.distinctDays.add(day);
      // recompute centroid as median of reservoir (capped)
      if (cluster.reservoir.length > 64) {
        cluster.reservoir = cluster.reservoir.slice(-64);
      }
      const lats = cluster.reservoir.map((p) => p.lat);
      const lngs = cluster.reservoir.map((p) => p.lng);
      cluster.centroidLat = median(lats);
      cluster.centroidLng = median(lngs);

      // dwell stats
      const dwellKey = `${cluster.id}:${hb}:${dow}`;
      let da = this.dwellAccs.get(dwellKey);
      if (!da) {
        da = {
          stopId: cluster.id,
          hourBucket: hb,
          dayOfWeek: dow,
          count: 0,
          sumS: 0,
          minS: durS,
          maxS: durS,
          reservoir: [],
        };
        this.dwellAccs.set(dwellKey, da);
      }
      da.count += 1;
      da.sumS += durS;
      da.minS = Math.min(da.minS, durS);
      da.maxS = Math.max(da.maxS, durS);
      if (da.reservoir.length < 64) da.reservoir.push(durS);
      else {
        // reservoir sampling
        const j = Math.floor(Math.random() * (da.count));
        if (j < 64) da.reservoir[j] = durS;
      }

      // segment stats will be computed in a second pass using stop sequence;
      // store dwell centroids for now.
    }

    // segment stats: pair consecutive dwells that map to stops. Track
    // dwell boundaries so travel time = next.start - prev.end (F4).
    interface DwellHit {
      cluster: StopCluster;
      startMs: number;
      endMs: number;
    }
    const hits: DwellHit[] = [];
    for (const d of work.dwells) {
      if (d.endMs - d.startMs < cfg.minDwellS * 1000) continue;
      if (d.startMs < trimStart || d.endMs > trimEnd) continue;
      let cl: StopCluster | undefined;
      for (const c of this.stopClusters.values()) {
        if (c.lineId !== work.lineId || c.direction !== direction) continue;
        if (
          distM(c.centroidLat, c.centroidLng, d.lat, d.lng) <=
            cfg.stopClusterRadiusM
        ) {
          cl = c;
          break;
        }
      }
      if (cl) hits.push({ cluster: cl, startMs: d.startMs, endMs: d.endMs });
    }
    // dedupe consecutive same cluster, merging dwell boundaries
    const ordered: DwellHit[] = [];
    for (const h of hits) {
      const last = ordered[ordered.length - 1];
      if (last && last.cluster.id === h.cluster.id) {
        last.endMs = Math.max(last.endMs, h.endMs);
      } else {
        ordered.push({
          cluster: h.cluster,
          startMs: h.startMs,
          endMs: h.endMs,
        });
      }
    }
    // terminus suppression: drop first and last stop's dwell stats (F4).
    // Segment stats still use them for connectivity, but dwell stats for
    // termini are suppressed by skipping upsertDwell for first/last cluster
    // ids of this trip. We mark them via a set checked in flush.
    const terminusIds = new Set<string>();
    if (ordered.length >= 1) terminusIds.add(ordered[0].cluster.id);
    if (ordered.length >= 2) {
      terminusIds.add(ordered[ordered.length - 1].cluster.id);
    }
    for (const id of terminusIds) this.terminusStopIds.add(id);
    for (let i = 0; i + 1 < ordered.length; i++) {
      const from = ordered[i];
      const to = ordered[i + 1];
      const travelS = Math.max(0, (to.startMs - from.endMs) / 1000);
      const dist = distM(
        from.cluster.centroidLat,
        from.cluster.centroidLng,
        to.cluster.centroidLat,
        to.cluster.centroidLng,
      );
      const segKey =
        `${work.lineId}:${direction}:${from.cluster.id}:${to.cluster.id}`;
      const hb = hourBucket(work.startedAtMs);
      const dow = dayOfWeek(work.startedAtMs);
      const key = `${segKey}:${hb}:${dow}`;
      let sa = this.segmentAccs.get(key);
      if (!sa) {
        sa = {
          lineId: work.lineId,
          direction,
          fromStop: from.cluster.id,
          toStop: to.cluster.id,
          hourBucket: hb,
          dayOfWeek: dow,
          count: 0,
          sumS: 0,
          minS: travelS,
          maxS: travelS,
          distanceM: dist,
          reservoir: [],
        };
        this.segmentAccs.set(key, sa);
      }
      sa.count += 1;
      sa.sumS += travelS;
      sa.minS = Math.min(sa.minS, travelS);
      sa.maxS = Math.max(sa.maxS, travelS);
      if (sa.reservoir.length < 64) sa.reservoir.push(travelS);
      else {
        const j = Math.floor(Math.random() * sa.count);
        if (j < 64) sa.reservoir[j] = travelS;
      }
      sa.distanceM = dist;
    }
  }

  /**
   * Assign a direction from existing corridors for this line. No accumulator
   * means direction 0; exactly one means that accumulator's direction, so a
   * restart that seeded only one slot keeps new trips on it instead of
   * splitting the corridor into direction 0. With two, the corridor covered
   * by the trip wins, falling back to bearing only when both cover nothing.
   */
  private assignDirection(lineId: number, pts: Pt[]): number {
    const accs = [...this.routeAccs.values()]
      .filter((a) => a.lineId === lineId)
      .sort((a, b) => a.direction - b.direction);
    if (accs.length === 0) return 0;
    if (accs.length === 1) return accs[0].direction;
    const [a, b] = accs;
    const sa = coverageScore(a, pts);
    const sb = coverageScore(b, pts);
    if (sa !== sb) return sa > sb ? a.direction : b.direction;
    if (sa !== 0) return 0;
    const tripBearing = bearingRad(pts[0], pts[pts.length - 1]);
    const ba = this.accBearing(a);
    const bb = this.accBearing(b);
    if (ba === null || bb === null) return 0;
    return angleDiff(tripBearing, ba) <= angleDiff(tripBearing, bb)
      ? a.direction
      : b.direction;
  }

  private accBearing(acc: CorridorAcc): number | null {
    const chain = buildChain(acc, {
      cellM: this.config.corridorCellM,
      minEdgeWeight: 1,
      minCells: 2,
    });
    if (!chain || chain.length < 2) return null;
    return bearingRad(chain[0], chain[chain.length - 1]);
  }

  /**
   * Effective privacy thresholds. "all" is the learning phase: one pass is
   * enough. "route_stops" keeps the configured k-anonymity gates.
   */
  private gates(): {
    minStopPasses: number;
    stopMinDistinctDays: number;
    kMin: number;
  } {
    if (this.deps.privacyMode() === "all") {
      return { minStopPasses: 1, stopMinDistinctDays: 1, kMin: 1 };
    }
    return {
      minStopPasses: this.config.minStopPasses,
      stopMinDistinctDays: this.config.stopMinDistinctDays,
      kMin: this.config.kMin,
    };
  }

  // ---- Flush ----

  async flush(): Promise<void> {
    if (!this.config.enabled) return;
    recordLearningFlush();
    try {
      let contributed = 0;
      for (const n of this.watermarkTrips.values()) contributed += n;
      recordLearningTripsContributed(contributed);
      // Persist learned route polylines from the absolute corridor. Skip when
      // no new trips since the last publish (T1): prevents one stale trip from
      // generating a new version every flush cycle.
      for (const acc of this.routeAccs.values()) {
        // Snapshot before the first await: a trip that finalizes during the
        // awaits below belongs to the next flush, so the snapshot (never the
        // live count) is compared and published on every path.
        const tripCount = acc.tripCount;
        if (tripCount < this.config.minRouteTrips) {
          recordLearningRouteBelowMinTrips();
          continue;
        }
        if (tripCount <= acc.lastPublishedTripCount) continue;
        const chain = buildChain(acc, {
          cellM: this.config.corridorCellM,
          minEdgeWeight: 1,
          minCells: this.config.corridorMinCells,
        });
        if (!chain) {
          recordLearningRouteChainTooSmall();
          acc.lastPublishedTripCount = tripCount;
          continue;
        }
        const smoothed = smooth(chain);
        let pts = simplify(smoothed, 5);
        if (pts.length > 400) pts = simplify(smoothed, 10);
        // Geometric length gate (minRouteLengthM): a chain can satisfy the cell
        // minimum yet be a short stub. Reject publication until the simplified
        // polyline spans the configured minimum; the trip watermark still
        // advances so this chain is not re-evaluated every flush.
        let lengthM = 0;
        for (let i = 1; i < pts.length; i++) {
          lengthM += distM(
            pts[i - 1].lat,
            pts[i - 1].lng,
            pts[i].lat,
            pts[i].lng,
          );
        }
        if (lengthM < this.config.minRouteLengthM) {
          recordLearningRouteTooShort();
          acc.lastPublishedTripCount = tripCount;
          continue;
        }
        const poly = encodePolyline(pts, 5);
        if (poly.length > 8192) {
          recordLearningRouteOversized();
          acc.lastPublishedTripCount = tripCount;
          continue; // reject publication
        }
        await this.upsertRoute(acc, poly, pts.length, pts);
        await this.updateStopOrdinals(acc.lineId, acc.direction, pts);
        acc.lastPublishedTripCount = tripCount;
      }

      // Persist watermarks
      for (const [k, n] of this.watermarkTrips) {
        const [lineId, direction] = k.split(":").map(Number);
        await this.upsertWatermark(lineId, direction, n);
      }
      this.watermarkTrips.clear();

      // Determine which stop clusters qualify for promotion. Only promoted
      // stops get a learned_stops row, so dwell/segment stats (which FK to
      // learned_stops) must be gated on the same set. Upsert stops FIRST so
      // the foreign keys resolve.
      const gates = this.gates();
      const qualifyingStopIds = new Set<string>();
      for (const c of this.stopClusters.values()) {
        if (c.passCount < gates.minStopPasses) continue;
        if (c.distinctDays.size < gates.stopMinDistinctDays) continue;
        qualifyingStopIds.add(c.id);
      }
      for (const c of this.stopClusters.values()) {
        if (!qualifyingStopIds.has(c.id)) continue;
        await this.upsertStop(c, c.ordinal);
      }

      // Persist dwell stats (only for promoted stops)
      for (const acc of this.dwellAccs.values()) {
        const p50 = percentile(acc.reservoir, 0.5) ||
          acc.sumS / Math.max(1, acc.count);
        const p90 = percentile(acc.reservoir, 0.9) || acc.maxS;
        if (acc.count < gates.kMin) continue;
        if (!qualifyingStopIds.has(acc.stopId)) continue;
        if (this.terminusStopIds.has(acc.stopId)) continue;
        await this.upsertDwell(acc, p50, p90);
      }
      this.dwellAccs.clear();

      // Persist segment stats (only when both endpoints are promoted stops)
      for (const acc of this.segmentAccs.values()) {
        if (acc.count < gates.kMin) continue;
        if (
          !qualifyingStopIds.has(acc.fromStop) ||
          !qualifyingStopIds.has(acc.toStop)
        ) {
          continue;
        }
        const p50 = percentile(
          acc.reservoir.length
            ? acc.reservoir
            : [acc.sumS / Math.max(1, acc.count)],
          0.5,
        );
        const p90 = percentile(
          acc.reservoir.length ? acc.reservoir : [acc.maxS],
          0.9,
        );
        await this.upsertSegment(acc, p50, p90);
      }
      this.segmentAccs.clear();

      this.terminusStopIds.clear();
      // Keep stop clusters in memory across flushes so their ids stay stable
      // and centroids accumulate (F2). Bounded by the in-memory cluster set;
      // decay/pruning is handled by the retention job (F6).
    } catch (e) {
      recordLearningFlushFailed();
      throw e;
    }
  }

  private async upsertRoute(
    acc: { lineId: number; direction: number; tripCount: number },
    polyline: string,
    pointCount: number,
    points: Array<{ lat: number; lng: number }>,
  ): Promise<void> {
    // No-flap gate: if an active route exists and the new polyline deviates
    // less than 15 m on median, keep the old version (docs 5.1).
    const activeRows = await this.deps.sql`
      select polyline from learned_routes
      where line_id = ${acc.lineId} and direction = ${acc.direction}
        and status = 'active'
      order by version desc
      limit 1
    `;
    const active = (activeRows as unknown as Array<{ polyline: string }>)[0];
    if (active) {
      let activePts: Array<{ lat: number; lng: number }> = [];
      try {
        activePts = decodePolyline(active.polyline, 5);
      } catch {
        activePts = [];
      }
      if (activePts.length >= 2) {
        const dev = medianDeviationM(points, activePts);
        if (dev < 15) {
          recordLearningRouteNoFlapSuppressed();
          return; // no flap
        }
      }
    }
    const rows = await this.deps.sql`
      select coalesce(max(version), 0) as v
      from learned_routes
      where line_id = ${acc.lineId} and direction = ${acc.direction}
    `;
    const version =
      Number((rows as unknown as Array<{ v: number }>)[0]?.v ?? 0) + 1;
    // Retire any prior active version so only one active row per
    // (line, direction) survives (T1). Retained 30 days per docs.
    const retired = await this.deps.sql`
      update learned_routes
      set status = 'retired', retired_at = now()
      where line_id = ${acc.lineId} and direction = ${acc.direction}
        and status = 'active'
      returning id
    `;
    recordLearningRouteRetired((retired as unknown[]).length);
    const dev = active
      ? medianDeviationM(
        points,
        (() => {
          try {
            return decodePolyline(active.polyline, 5);
          } catch {
            return [];
          }
        })(),
      )
      : null;
    await this.deps.sql`
      insert into learned_routes (line_id, direction, version, status, polyline, point_count, sample_trips, median_deviation_m, computed_at)
      values (${acc.lineId}, ${acc.direction}, ${version}, 'active', ${polyline}, ${pointCount}, ${acc.tripCount}, ${dev}, now())
    `;
    recordLearningRoutePublished();
  }

  /**
   * Project this direction's stop centroids onto the published chain and
   * persist the resulting ordinals. Runs after every publish so stops that
   * predate a chain are corrected on the next one.
   */
  private async updateStopOrdinals(
    lineId: number,
    direction: number,
    chain: Pt[],
  ): Promise<void> {
    const clusters = [...this.stopClusters.values()].filter(
      (c) => c.lineId === lineId && c.direction === direction,
    );
    if (clusters.length === 0) return;
    const ordinals = assignOrdinals(
      clusters.map((c) => ({ lat: c.centroidLat, lng: c.centroidLng })),
      chain,
    );
    for (let i = 0; i < clusters.length; i++) {
      clusters[i].ordinal = ordinals[i];
      await this.deps.sql`
        update learned_stops set ordinal = ${ordinals[i]}
        where id = ${clusters[i].id}
      `;
    }
  }

  private async upsertWatermark(
    lineId: number,
    direction: number,
    trips: number,
  ): Promise<void> {
    await this.deps.sql`
      insert into learning_watermarks (line_id, direction, trips_since_route_recompute, trips_since_stop_recompute, last_flush_at)
      values (${lineId}, ${direction}, ${trips}, ${trips}, now())
      on conflict (line_id, direction) do update set
        trips_since_route_recompute = learning_watermarks.trips_since_route_recompute + ${trips},
        trips_since_stop_recompute = learning_watermarks.trips_since_stop_recompute + ${trips},
        last_flush_at = now()
    `;
  }

  private async upsertDwell(
    acc: DwellAcc,
    p50: number,
    p90: number,
  ): Promise<void> {
    await this.deps.sql`
      insert into stop_dwell_stats (stop_id, hour_bucket, day_of_week, sample_count, dwell_p50_s, dwell_p90_s, updated_at)
      values (${acc.stopId}, ${acc.hourBucket}, ${acc.dayOfWeek}, ${acc.count}, ${p50}, ${p90}, now())
      on conflict (stop_id, hour_bucket, day_of_week) do update set
        sample_count = stop_dwell_stats.sample_count + ${acc.count},
        dwell_p50_s = ${p50},
        dwell_p90_s = ${p90},
        updated_at = now()
    `;
  }

  private async upsertSegment(
    acc: SegmentAcc,
    p50: number,
    p90: number,
  ): Promise<void> {
    await this.deps.sql`
      insert into segment_stats (line_id, direction, from_stop, to_stop, hour_bucket, day_of_week, sample_count, travel_p50_s, travel_p90_s, distance_m, updated_at)
      values (${acc.lineId}, ${acc.direction}, ${acc.fromStop}, ${acc.toStop}, ${acc.hourBucket}, ${acc.dayOfWeek}, ${acc.count}, ${p50}, ${p90}, ${acc.distanceM}, now())
      on conflict (line_id, direction, from_stop, to_stop, hour_bucket, day_of_week) do update set
        sample_count = segment_stats.sample_count + ${acc.count},
        travel_p50_s = ${p50},
        travel_p90_s = ${p90},
        distance_m = ${acc.distanceM},
        updated_at = now()
    `;
  }

  private async upsertStop(c: StopCluster, ordinal: number): Promise<void> {
    // insert if not exists by proximity? For v1 just insert new row.
    await this.deps.sql`
      insert into learned_stops (id, line_id, direction, ordinal, lat, lng, radius_m, sample_passes, first_seen_at, last_seen_at, active)
      values (${c.id}, ${c.lineId}, ${c.direction}, ${ordinal}, ${c.centroidLat}, ${c.centroidLng}, ${c.radiusM}, ${c.passCount}, now(), now(), true)
      on conflict (id) do update set
        lat = ${c.centroidLat},
        lng = ${c.centroidLng},
        ordinal = ${ordinal},
        sample_passes = learned_stops.sample_passes + ${c.passCount},
        last_seen_at = now(),
        active = true
    `;
  }

  // ---- Read helpers used by routes ----

  /**
   * Active route for a line; more sample trips wins, then newer version,
   * then lower direction so equal-trip directions resolve deterministically.
   */
  async learnedRouteForLine(
    lineId: number,
  ): Promise<
    | {
      dir: number;
      polyline: string;
      version: number;
      trips: number;
      computedAt: string;
    }
    | null
  > {
    const rows = await this.deps.sql`
      select direction, version, polyline, sample_trips, computed_at
      from learned_routes
      where line_id = ${lineId} and status = 'active'
      order by sample_trips desc, version desc, direction asc
      limit 1
    `;
    const r = (rows as unknown as Array<
      {
        direction: number;
        version: number;
        polyline: string;
        sample_trips: number;
        computed_at: string;
      }
    >)[0];
    if (!r) return null;
    return {
      dir: r.direction,
      polyline: r.polyline,
      version: r.version,
      trips: r.sample_trips,
      computedAt: r.computed_at,
    };
  }

  async learnedStopsForLine(
    lineId: number,
    dir: number,
  ): Promise<
    Array<
      {
        id: string;
        ordinal: number;
        lat: number;
        lng: number;
        radiusM: number;
        passes: number;
        active: boolean;
      }
    >
  > {
    const rows = await this.deps.sql`
      select id, ordinal, lat, lng, radius_m, sample_passes, active
      from learned_stops
      where line_id = ${lineId} and direction = ${dir} and active = true
      order by ordinal asc
    `;
    return (rows as unknown as Array<
      {
        id: string;
        ordinal: number;
        lat: number;
        lng: number;
        radius_m: number;
        sample_passes: number;
        active: boolean;
      }
    >).map((r) => ({
      id: r.id,
      ordinal: r.ordinal,
      lat: r.lat,
      lng: r.lng,
      radiusM: r.radius_m,
      passes: r.sample_passes,
      active: r.active,
    }));
  }

  async allLearnedRoutes(): Promise<
    Array<{
      lineId: number;
      direction: number;
      version: number;
      polyline: string;
      trips: number;
      computedAt: string;
    }>
  > {
    if (!this.config.enabled) return [];
    const rows = await this.deps.sql`
      select line_id, direction, version, polyline, sample_trips, computed_at
      from learned_routes
      where status = 'active'
      order by line_id asc, direction asc, version desc
    `;
    const seen = new Set<string>();
    const out: Array<{
      lineId: number;
      direction: number;
      version: number;
      polyline: string;
      trips: number;
      computedAt: string;
    }> = [];
    for (
      const r of rows as unknown as Array<{
        line_id: number;
        direction: number;
        version: number;
        polyline: string;
        sample_trips: number;
        computed_at: string;
      }>
    ) {
      const key = `${r.line_id}:${r.direction}`;
      if (seen.has(key)) continue;
      seen.add(key);
      out.push({
        lineId: r.line_id,
        direction: r.direction,
        version: r.version,
        polyline: r.polyline,
        trips: r.sample_trips,
        computedAt: r.computed_at,
      });
    }
    return out;
  }

  async allLearnedStops(): Promise<
    Array<{
      lineId: number;
      direction: number;
      stops: Array<{
        id: string;
        ordinal: number;
        lat: number;
        lng: number;
        radiusM: number;
        passes: number;
      }>;
    }>
  > {
    if (!this.config.enabled) return [];
    const rows = await this.deps.sql`
      select line_id, direction, id, ordinal, lat, lng, radius_m, sample_passes
      from learned_stops
      where active = true
      order by line_id asc, direction asc, ordinal asc
    `;
    const groups = new Map<
      string,
      {
        lineId: number;
        direction: number;
        stops: Array<{
          id: string;
          ordinal: number;
          lat: number;
          lng: number;
          radiusM: number;
          passes: number;
        }>;
      }
    >();
    for (
      const r of rows as unknown as Array<{
        line_id: number;
        direction: number;
        id: string;
        ordinal: number;
        lat: number;
        lng: number;
        radius_m: number;
        sample_passes: number;
      }>
    ) {
      const key = `${r.line_id}:${r.direction}`;
      let g = groups.get(key);
      if (!g) {
        g = { lineId: r.line_id, direction: r.direction, stops: [] };
        groups.set(key, g);
      }
      g.stops.push({
        id: r.id,
        ordinal: r.ordinal,
        lat: r.lat,
        lng: r.lng,
        radiusM: r.radius_m,
        passes: r.sample_passes,
      });
    }
    return [...groups.values()];
  }

  async segmentStats(
    lineId: number,
    direction: number,
    fromStop: string,
    toStop: string,
    hourBucket: number,
    dayOfWeek: number,
  ): Promise<
    { p50: number; p90: number; count: number; distanceM: number } | null
  > {
    // try exact bucket
    let rows = await this.deps.sql`
      select sample_count, travel_p50_s, travel_p90_s, distance_m
      from segment_stats
      where line_id = ${lineId} and direction = ${direction}
        and from_stop = ${fromStop} and to_stop = ${toStop}
        and hour_bucket = ${hourBucket} and day_of_week = ${dayOfWeek}
      limit 1
    `;
    let r = (rows as unknown as Array<
      {
        sample_count: number;
        travel_p50_s: number;
        travel_p90_s: number;
        distance_m: number;
      }
    >)[0];
    if (!r) {
      // fallback: any dow, same hour
      rows = await this.deps.sql`
        select sample_count, travel_p50_s, travel_p90_s, distance_m
        from segment_stats
        where line_id = ${lineId} and direction = ${direction}
          and from_stop = ${fromStop} and to_stop = ${toStop}
          and hour_bucket = ${hourBucket}
        order by sample_count desc
        limit 1
      `;
      r = (rows as unknown as Array<
        {
          sample_count: number;
          travel_p50_s: number;
          travel_p90_s: number;
          distance_m: number;
        }
      >)[0];
    }
    if (!r || r.sample_count < this.gates().kMin) return null;
    return {
      p50: r.travel_p50_s,
      p90: r.travel_p90_s,
      count: r.sample_count,
      distanceM: r.distance_m,
    };
  }

  async dwellStats(
    stopId: string,
    hourBucket: number,
    dayOfWeek: number,
  ): Promise<{ p50: number; p90: number; count: number } | null> {
    let rows = await this.deps.sql`
      select sample_count, dwell_p50_s, dwell_p90_s
      from stop_dwell_stats
      where stop_id = ${stopId} and hour_bucket = ${hourBucket} and day_of_week = ${dayOfWeek}
      limit 1
    `;
    let r = (rows as unknown as Array<
      { sample_count: number; dwell_p50_s: number; dwell_p90_s: number }
    >)[0];
    if (!r) {
      rows = await this.deps.sql`
        select sample_count, dwell_p50_s, dwell_p90_s
        from stop_dwell_stats
        where stop_id = ${stopId} and hour_bucket = ${hourBucket}
        order by sample_count desc
        limit 1
      `;
      r = (rows as unknown as Array<
        { sample_count: number; dwell_p50_s: number; dwell_p90_s: number }
      >)[0];
    }
    if (!r || r.sample_count < this.gates().kMin) return null;
    return { p50: r.dwell_p50_s, p90: r.dwell_p90_s, count: r.sample_count };
  }
}

function bearingRad(a: Pt, b: Pt): number {
  const cosLat = Math.cos((((a.lat + b.lat) / 2) * Math.PI) / 180);
  const dx = (b.lng - a.lng) * cosLat;
  const dy = b.lat - a.lat;
  return Math.atan2(dx, dy);
}

function angleDiff(a: number, b: number): number {
  let diff = b - a;
  if (diff > Math.PI) diff -= 2 * Math.PI;
  else if (diff < -Math.PI) diff += 2 * Math.PI;
  return Math.abs(diff);
}

function median(xs: number[]): number {
  if (xs.length === 0) return 0;
  const s = [...xs].sort((a, b) => a - b);
  const m = Math.floor(s.length / 2);
  return s.length % 2 === 0 ? (s[m - 1] + s[m]) / 2 : s[m];
}

function percentile(xs: number[], p: number): number {
  if (xs.length === 0) return 0;
  const s = [...xs].sort((a, b) => a - b);
  const idx = Math.min(s.length - 1, Math.max(0, Math.ceil(p * s.length) - 1));
  return s[idx];
}
