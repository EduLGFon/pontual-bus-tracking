// Shared stateful fake Sql for learning tests. It mirrors the subset of
// accumulator SQL the consumer uses so route publication can rebuild a
// corridor from rows written by earlier trips. Any other query returns [].
import type { Sql } from "../src/db/client.ts";

interface RecordedQuery {
  text: string;
  values: unknown[];
}

interface FakeCell {
  line_id: number;
  direction: number;
  cell_key: string;
  lat: number;
  lng: number;
  trips: number;
}

interface FakeEdge {
  line_id: number;
  direction: number;
  from_cell: string;
  to_cell: string;
  trips: number;
}

interface FakeState {
  line_id: number;
  direction: number;
  sample_trips: number;
}

interface FakeRoute {
  id: string;
  line_id: number;
  direction: number;
  version: number;
  status: string;
  polyline: string;
  point_count: number;
  sample_trips: number;
  median_deviation_m: number | null;
  computed_at: string;
}

interface FakeDb {
  sql: Sql;
  queries: RecordedQuery[];
}

/**
 * Stateful tagged-template fake for the learning accumulators. It mirrors the
 * subset of SQL the consumer uses so a publish can rebuild a corridor from
 * rows written by earlier trips. Any other query returns no rows.
 */
export function fakeSql(): FakeDb {
  const queries: RecordedQuery[] = [];
  const cells = new Map<string, FakeCell>();
  const edges = new Map<string, FakeEdge>();
  const states = new Map<string, FakeState>();
  const routes: FakeRoute[] = [];
  let routeSeq = 0;

  const keyOf = (...parts: Array<string | number>) => parts.join(":");
  const jsonRows = <T>(values: unknown[]): T[] => {
    const raw = values.find((v) =>
      typeof v === "string" && v.trimStart().startsWith("[")
    );
    return raw === undefined ? [] : JSON.parse(raw as string) as T[];
  };
  const activeRoute = (lineId: number, direction: number) =>
    routes
      .filter((r) =>
        r.line_id === lineId && r.direction === direction &&
        r.status === "active"
      )
      .sort((a, b) => b.version - a.version)[0];

  const fn = ((strings: TemplateStringsArray, ...values: unknown[]) => {
    const text = strings.join("?");
    queries.push({ text, values });
    const t = text.toLowerCase();

    if (t.includes("insert into learning_route_cells")) {
      const lineId = values[0] as number;
      const direction = values[1] as number;
      for (
        const row of jsonRows<
          { cell_key: string; lat: number; lng: number }
        >(values)
      ) {
        const key = keyOf(lineId, direction, row.cell_key);
        const cur = cells.get(key);
        if (!cur) {
          cells.set(key, {
            line_id: lineId,
            direction,
            cell_key: row.cell_key,
            lat: row.lat,
            lng: row.lng,
            trips: 1,
          });
          continue;
        }
        cur.lat = (cur.lat * cur.trips + row.lat) / (cur.trips + 1);
        cur.lng = (cur.lng * cur.trips + row.lng) / (cur.trips + 1);
        cur.trips += 1;
      }
      return Promise.resolve([]);
    }

    if (t.includes("insert into learning_route_edges")) {
      const lineId = values[0] as number;
      const direction = values[1] as number;
      for (
        const row of jsonRows<
          { from_cell: string; to_cell: string }
        >(values)
      ) {
        const key = keyOf(lineId, direction, row.from_cell, row.to_cell);
        const cur = edges.get(key);
        if (cur) cur.trips += 1;
        else {
          edges.set(key, {
            line_id: lineId,
            direction,
            from_cell: row.from_cell,
            to_cell: row.to_cell,
            trips: 1,
          });
        }
      }
      return Promise.resolve([]);
    }

    if (t.includes("insert into learning_route_state")) {
      const lineId = values[0] as number;
      const direction = values[1] as number;
      const key = keyOf(lineId, direction);
      const cur = states.get(key);
      if (cur) cur.sample_trips += 1;
      else states.set(key, { line_id: lineId, direction, sample_trips: 1 });
      return Promise.resolve([]);
    }

    if (t.includes("insert into learned_routes")) {
      routeSeq += 1;
      routes.push({
        id: `fake-route-${routeSeq}`,
        line_id: values[0] as number,
        direction: values[1] as number,
        version: values[2] as number,
        status: "active",
        polyline: values[3] as string,
        point_count: values[4] as number,
        sample_trips: values[5] as number,
        median_deviation_m: values[6] as number | null,
        computed_at: "1970-01-01T00:00:00.000Z",
      });
      return Promise.resolve([]);
    }

    if (t.includes("update learned_routes set status = 'retired'")) {
      const lineId = values[0] as number;
      const direction = values[1] as number;
      const retired = routes.filter((r) =>
        r.line_id === lineId && r.direction === direction &&
        r.status === "active"
      );
      for (const r of retired) r.status = "retired";
      return Promise.resolve(retired.map((r) => ({ id: r.id })));
    }

    if (t.includes("update learned_routes set sample_trips")) {
      const sampleTrips = values[0] as number;
      if (t.includes("where id =")) {
        const route = routes.find((r) => r.id === values[1]);
        if (route) {
          route.sample_trips = sampleTrips;
          route.computed_at = "1970-01-01T00:00:00.000Z";
        }
      } else {
        const lineId = values[1] as number;
        const direction = values[2] as number;
        const route = activeRoute(lineId, direction);
        if (route) route.sample_trips = sampleTrips;
      }
      return Promise.resolve([]);
    }

    if (t.includes("update learning_route_state set last_publish_at")) {
      return Promise.resolve([]);
    }

    if (t.includes("coalesce(max(version)")) {
      const lineId = values[0] as number;
      const direction = values[1] as number;
      const versions = routes
        .filter((r) => r.line_id === lineId && r.direction === direction)
        .map((r) => r.version);
      return Promise.resolve([{
        v: versions.length === 0 ? 0 : Math.max(...versions),
      }]);
    }

    if (t.includes("left join learned_routes")) {
      const stale = [...states.values()].filter((s) => {
        if (s.sample_trips <= 0) return false;
        const active = activeRoute(s.line_id, s.direction);
        return !active || s.sample_trips > active.sample_trips;
      });
      return Promise.resolve(stale.map((s) => ({
        line_id: s.line_id,
        direction: s.direction,
      })));
    }

    if (t.includes("select cell_key, lat, lng, trips")) {
      const lineId = values[0] as number;
      const direction = values[1] as number;
      return Promise.resolve(
        [...cells.values()].filter((r) =>
          r.line_id === lineId && r.direction === direction
        ),
      );
    }

    if (t.includes("select from_cell, to_cell, trips")) {
      const lineId = values[0] as number;
      const direction = values[1] as number;
      return Promise.resolve(
        [...edges.values()].filter((r) =>
          r.line_id === lineId && r.direction === direction
        ).map((r) => ({
          from_cell: r.from_cell,
          to_cell: r.to_cell,
          trips: r.trips,
        })),
      );
    }

    if (t.includes("select sample_trips from learning_route_state")) {
      const lineId = values[0] as number;
      const direction = values[1] as number;
      const state = states.get(keyOf(lineId, direction));
      return Promise.resolve(
        state ? [{ sample_trips: state.sample_trips }] : [],
      );
    }

    if (t.includes("select line_id, direction, cell_key, lat, lng, trips")) {
      return Promise.resolve([...cells.values()]);
    }

    if (t.includes("select line_id, direction, from_cell, to_cell, trips")) {
      return Promise.resolve([...edges.values()]);
    }

    if (t.includes("select line_id, direction, sample_trips")) {
      return Promise.resolve([...states.values()]);
    }

    if (
      t.includes("select line_id, direction from learned_routes") &&
      t.includes("group by")
    ) {
      const seen = new Set<string>();
      const rows: Array<{ line_id: number; direction: number }> = [];
      for (const r of routes) {
        if (r.status !== "active") continue;
        const key = keyOf(r.line_id, r.direction);
        if (seen.has(key)) continue;
        seen.add(key);
        rows.push({ line_id: r.line_id, direction: r.direction });
      }
      return Promise.resolve(rows);
    }

    if (t.includes("select id, polyline from learned_routes")) {
      const lineId = values[0] as number;
      const direction = values[1] as number;
      const route = activeRoute(lineId, direction);
      return Promise.resolve(
        route ? [{ id: route.id, polyline: route.polyline }] : [],
      );
    }

    if (
      t.includes("select direction, version, polyline, sample_trips") &&
      t.includes("from learned_routes")
    ) {
      const lineId = values[0] as number;
      const rows = routes
        .filter((r) => r.line_id === lineId && r.status === "active")
        .sort((a, b) =>
          b.sample_trips - a.sample_trips || b.version - a.version ||
          a.direction - b.direction
        )
        .slice(0, 1)
        .map((r) => ({
          direction: r.direction,
          version: r.version,
          polyline: r.polyline,
          sample_trips: r.sample_trips,
          computed_at: r.computed_at,
        }));
      return Promise.resolve(rows);
    }

    if (
      t.includes("select line_id, direction, version, polyline") &&
      t.includes("from learned_routes")
    ) {
      return Promise.resolve(
        routes
          .filter((r) => r.status === "active")
          .sort((a, b) =>
            a.line_id - b.line_id || a.direction - b.direction ||
            b.version - a.version
          )
          .map((r) => ({
            line_id: r.line_id,
            direction: r.direction,
            version: r.version,
            polyline: r.polyline,
            sample_trips: r.sample_trips,
            computed_at: r.computed_at,
          })),
      );
    }

    return Promise.resolve([]);
  }) as unknown as Sql;
  return { sql: fn, queries };
}
