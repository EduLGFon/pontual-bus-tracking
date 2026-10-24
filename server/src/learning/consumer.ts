// In-process consumer for the learning subsystem. Subscribes to engine
// events, maintains per-trip working state in memory, and accumulates
// de-identified aggregates that are flushed to PostgreSQL periodically.
// See docs/data-learning.md sections 3-5.
import { distM } from "../domain/geo.ts";
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
  private routeAccs = new Map<string, {
    lineId: number;
    direction: number;
    bins: Map<number, { lats: number[]; lngs: number[] }>;
    tripCount: number;
  }>();
  private stopClusters = new Map<string, StopCluster>();
  private dwellAccs = new Map<string, DwellAcc>();
  private segmentAccs = new Map<string, SegmentAcc>();
  private watermarkTrips = new Map<string, number>();
  private config: LearningConfig;

  constructor(private deps: ConsumerDeps) {
    this.config = deps.config();
  }

  reloadConfig(): void {
    this.config = this.deps.config();
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

  handle(event: EngineEvent, consentVersion: number): void {
    if (!this.config.enabled) return;
    switch (event.kind) {
      case "tripStarted":
        this.onTripStarted(event, consentVersion);
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
    consentVersion: number,
  ): void {
    if (consentVersion < this.config.minConsentVersion) return;
    const work: TripWork = {
      tripKey: e.tripKey,
      lineId: e.lineId,
      direction: null,
      consentVersion,
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
    if (work.samples.length < 3) return;
    const cfg = this.config;
    // trim ends
    const start = work.startedAtMs + cfg.trimEndsS * 1000;
    const end = (work.endedAtMs ?? work.samples[work.samples.length - 1].t) -
      cfg.trimEndsS * 1000;
    const kept = work.samples.filter((s) => s.t >= start && s.t <= end);
    if (kept.length < 3) return;

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
    if (total < cfg.minRouteLengthM) return;

    // direction assignment deferred: assign 0 for now if no existing; else
    // compare vector to existing directions for this line.
    const first = kept[0];
    const last = kept[kept.length - 1];
    const vLat = last.lat - first.lat;
    const vLng = last.lng - first.lng;
    const dirs = new Set<number>();
    for (const acc of this.routeAccs.values()) {
      if (acc.lineId === work.lineId) dirs.add(acc.direction);
    }
    let direction = 0;
    if (dirs.size > 0) {
      // find nearest direction by comparing to a stored mean vector; we
      // store mean in a parallel map? For simplicity, reuse first acc's vector.
      // Fallback: if second direction exists, check angle.
      if (dirs.has(1)) {
        // compute mean vector for dir 0 and 1 from first acc bin endpoints
        // Simplified: assign 1 if vector differs > 60 deg from dir0 mean.
        // We approximate by checking the first acc's first/last bin centroid.
        const a0 = this.routeAccs.get(this.key(work.lineId, 0));
        const a1 = this.routeAccs.get(this.key(work.lineId, 1));
        const mean0 = a0 ? this.accMeanVector(a0) : null;
        const mean1 = a1 ? this.accMeanVector(a1) : null;
        const ang0 = mean0
          ? this.angleBetween(vLat, vLng, mean0.lat, mean0.lng)
          : 0;
        const ang1 = mean1
          ? this.angleBetween(vLat, vLng, mean1.lat, mean1.lng)
          : 180;
        if (ang1 < ang0 && ang1 < 60) direction = 1;
        else if (ang0 < 60) direction = 0;
        else if (dirs.size < 2) direction = 1;
        else return; // discard
      }
    }
    work.direction = direction;

    // route accumulation: bin by progress
    const accKey = this.key(work.lineId, direction);
    let acc = this.routeAccs.get(accKey);
    if (!acc) {
      acc = { lineId: work.lineId, direction, bins: new Map(), tripCount: 0 };
      this.routeAccs.set(accKey, acc);
    }
    const bins = new Map<number, { lats: number[]; lngs: number[] }>();
    let cum = 0;
    let prev = kept[0];
    for (let i = 1; i < kept.length; i++) {
      cum += distM(prev.lat, prev.lng, kept[i].lat, kept[i].lng);
      const progress = total === 0 ? 0 : cum / total;
      const bi = Math.min(
        cfg.routeBins - 1,
        Math.max(0, Math.floor(progress * cfg.routeBins)),
      );
      if (!bins.has(bi)) bins.set(bi, { lats: [], lngs: [] });
      const b = bins.get(bi)!;
      b.lats.push(kept[i].lat);
      b.lngs.push(kept[i].lng);
      prev = kept[i];
    }
    for (const [bi, b] of bins) {
      if (!acc.bins.has(bi)) acc.bins.set(bi, { lats: [], lngs: [] });
      const ab = acc.bins.get(bi)!;
      // store per-trip median instead of raw points to bound memory
      const medLat = median(b.lats);
      const medLng = median(b.lngs);
      ab.lats.push(medLat);
      ab.lngs.push(medLng);
    }
    acc.tripCount += 1;

    // watermark
    const wk = accKey;
    this.watermarkTrips.set(wk, (this.watermarkTrips.get(wk) ?? 0) + 1);

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

    // segment stats: pair consecutive dwells that map to stops
    // We approximate by using the detected dwell clusters in order.
    const orderedStops: StopCluster[] = [];
    // map each dwell to its cluster by re-running nearest (already created)
    const dwellClusters: StopCluster[] = [];
    for (const d of work.dwells) {
      if (d.endMs - d.startMs < cfg.minDwellS * 1000) continue;
      if (d.startMs < trimStart || d.endMs > trimEnd) continue;
      // find cluster
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
      if (cl) dwellClusters.push(cl);
    }
    // dedupe consecutive same cluster
    for (const c of dwellClusters) {
      if (
        orderedStops.length === 0 ||
        orderedStops[orderedStops.length - 1].id !== c.id
      ) {
        orderedStops.push(c);
      }
    }
    for (let i = 0; i + 1 < orderedStops.length; i++) {
      const from = orderedStops[i];
      const to = orderedStops[i + 1];
      // travel time: from end of dwell i to start of dwell i+1
      // approximate using dwells array indices; use cluster pass timing not stored.
      // We don't have per-pair timing here easily; skip precise timing in v1
      // and rely on dwell durations only. Segment timing added when we track
      // dwell boundaries per stop, which requires richer state. For now,
      // record distance only with a placeholder count.
      const dist = distM(
        from.centroidLat,
        from.centroidLng,
        to.centroidLat,
        to.centroidLng,
      );
      const segKey = `${work.lineId}:${direction}:${from.id}:${to.id}`;
      const hb = hourBucket(work.startedAtMs);
      const dow = dayOfWeek(work.startedAtMs);
      const key = `${segKey}:${hb}:${dow}`;
      let sa = this.segmentAccs.get(key);
      if (!sa) {
        sa = {
          lineId: work.lineId,
          direction,
          fromStop: from.id,
          toStop: to.id,
          hourBucket: hb,
          dayOfWeek: dow,
          count: 0,
          sumS: 0,
          minS: 0,
          maxS: 0,
          distanceM: dist,
          reservoir: [],
        };
        this.segmentAccs.set(key, sa);
      }
      sa.count += 1;
      sa.distanceM = dist;
    }
  }

  private accMeanVector(
    acc: { bins: Map<number, { lats: number[]; lngs: number[] }> },
  ): { lat: number; lng: number } {
    // use first and last bin with data
    const keys = [...acc.bins.keys()].sort((a, b) => a - b);
    if (keys.length < 2) return { lat: 0, lng: 0 };
    const first = acc.bins.get(keys[0])!;
    const last = acc.bins.get(keys[keys.length - 1])!;
    const fLat = median(first.lats);
    const fLng = median(first.lngs);
    const lLat = median(last.lats);
    const lLng = median(last.lngs);
    return { lat: lLat - fLat, lng: lLng - fLng };
  }

  private angleBetween(
    aLat: number,
    aLng: number,
    bLat: number,
    bLng: number,
  ): number {
    const dot = aLat * bLat + aLng * bLng;
    const ma = Math.hypot(aLat, aLng);
    const mb = Math.hypot(bLat, bLng);
    if (ma === 0 || mb === 0) return 0;
    const cos = Math.max(-1, Math.min(1, dot / (ma * mb)));
    return (Math.acos(cos) * 180) / Math.PI;
  }

  // ---- Flush ----

  async flush(): Promise<void> {
    if (!this.config.enabled) return;
    // Route recompute gating: if watermark trips >= threshold, recompute.
    // For v1 we store accumulators as candidate rows via upsert of counts
    // only; full polyline recompute is triggered separately.
    // Persist watermarks
    for (const [k, n] of this.watermarkTrips) {
      const [lineId, direction] = k.split(":").map(Number);
      await this.upsertWatermark(lineId, direction, n);
    }
    this.watermarkTrips.clear();

    // Persist dwell stats
    for (const acc of this.dwellAccs.values()) {
      const p50 = percentile(acc.reservoir, 0.5) ||
        acc.sumS / Math.max(1, acc.count);
      const p90 = percentile(acc.reservoir, 0.9) || acc.maxS;
      if (acc.count < this.config.kMin) continue;
      await this.upsertDwell(acc, p50, p90);
    }
    this.dwellAccs.clear();

    // Persist segment stats
    for (const acc of this.segmentAccs.values()) {
      if (acc.count < this.config.kMin) continue;
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

    // Stop clusters: upsert learned_stops if passCount >= minStopPasses
    // and distinctDays >= stopMinDistinctDays
    for (const c of this.stopClusters.values()) {
      if (c.passCount < this.config.minStopPasses) continue;
      if (c.distinctDays.size < this.config.stopMinDistinctDays) continue;
      await this.upsertStop(c);
    }
    // keep clusters in memory for ordinal assignment? Clear to bound memory;
    // reload from DB on read. For v1 we clear.
    this.stopClusters.clear();
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

  private async upsertStop(c: StopCluster): Promise<void> {
    // insert if not exists by proximity? For v1 just insert new row.
    await this.deps.sql`
      insert into learned_stops (id, line_id, direction, ordinal, lat, lng, radius_m, sample_passes, first_seen_at, last_seen_at, active)
      values (${c.id}, ${c.lineId}, ${c.direction}, 0, ${c.centroidLat}, ${c.centroidLng}, ${c.radiusM}, ${c.passCount}, now(), now(), true)
      on conflict (id) do update set
        lat = ${c.centroidLat},
        lng = ${c.centroidLng},
        sample_passes = learned_stops.sample_passes + ${c.passCount},
        last_seen_at = now(),
        active = true
    `;
  }

  // ---- Read helpers used by routes ----

  async learnedRoute(
    lineId: number,
  ): Promise<
    | { polyline: string; version: number; trips: number; computedAt: string }
    | null
  > {
    const rows = await this.deps.sql`
      select version, polyline, sample_trips, computed_at
      from learned_routes
      where line_id = ${lineId} and status = 'active'
      order by version desc
      limit 1
    `;
    const r = (rows as unknown as Array<
      {
        version: number;
        polyline: string;
        sample_trips: number;
        computed_at: string;
      }
    >)[0];
    if (!r) return null;
    return {
      polyline: r.polyline,
      version: r.version,
      trips: r.sample_trips,
      computedAt: r.computed_at,
    };
  }

  async learnedStops(
    lineId: number,
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
      where line_id = ${lineId} and active = true
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
    if (!r || r.sample_count < this.config.kMin) return null;
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
    if (!r || r.sample_count < this.config.kMin) return null;
    return { p50: r.dwell_p50_s, p90: r.dwell_p90_s, count: r.sample_count };
  }
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
