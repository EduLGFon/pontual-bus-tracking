// In-process consumer for the learning subsystem. Subscribes to engine
// events, maintains per-trip working state in memory, and accumulates
// de-identified aggregates that are flushed to PostgreSQL periodically.
// See docs/data-learning.md sections 3-5.
import { decodePolyline, distM, encodePolyline } from "../domain/geo.ts";
import {
  recordLearningDirectionAssigned,
  recordLearningFlush,
  recordLearningFlushFailed,
  recordLearningRouteChainTooSmall,
  recordLearningRouteNoFlapSuppressed,
  recordLearningRouteOversized,
  recordLearningRoutePublished,
  recordLearningRouteRetired,
  recordLearningTripGapDropped,
  recordLearningTripIneligible,
  recordLearningTripNoCellTransition,
  recordLearningTripsContributed,
  recordLearningTripTooFewSamples,
} from "../observability/metrics.ts";
import { Log } from "../observability/log.ts";
import { medianDeviationM, simplify, smooth } from "./routeLearner.ts";
import {
  addTrip,
  assignOrdinals,
  buildChain,
  type CorridorAcc,
  coverageScore,
  DEFAULT_MAX_GAP_M,
  GRID_ORIGIN,
  newCorridorAcc,
  type Pt,
} from "./corridor.ts";
import type { EngineEvent } from "../domain/types.ts";
import type { Sql, Tx } from "../db/client.ts";
import type {
  LearningConfig,
  StopCluster,
  TripSample,
  TripWork,
} from "./types.ts";

export interface ConsumerDeps {
  sql: Sql;
  config: () => LearningConfig;
  now: () => number;
  // consent version lookup for a device is done by caller; consumer
  // receives it via handleTripStart's consentVersion.
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
  private config: LearningConfig;
  // Serialized async work for finalized trips. Contributions and route
  // publications run off the request path but in trip-end order. The queue
  // is in memory only: if the process dies before a queued task runs, that
  // trip's contribution is lost. No raw trip data is persisted for replay.
  private queue: Promise<void> = Promise.resolve();

  constructor(private deps: ConsumerDeps) {
    this.config = deps.config();
  }

  reloadConfig(): void {
    this.config = this.deps.config();
  }

  /**
   * Reconstruct corridor accumulators from PostgreSQL. Cells, edges and
   * sample_trips are the source of truth; the in-memory copy only answers
   * direction assignment and coverage between trips. Active route rows seed
   * empty direction slots so an upgrade keeps the direction layout it had.
   */
  async loadLearnedRoutes(): Promise<void> {
    try {
      const accs = new Map<string, CorridorAcc>();
      const cellRows = await this.deps.sql`
        select line_id, direction, cell_key, lat, lng, trips
        from learning_route_cells
      `;
      for (
        const r of cellRows as unknown as Array<{
          line_id: number;
          direction: number;
          cell_key: string;
          lat: number;
          lng: number;
          trips: number;
        }>
      ) {
        const acc = this.accFor(accs, r.line_id, r.direction);
        acc.cells.set(r.cell_key, { lat: r.lat, lng: r.lng, n: r.trips });
      }
      const edgeRows = await this.deps.sql`
        select line_id, direction, from_cell, to_cell, trips
        from learning_route_edges
      `;
      for (
        const r of edgeRows as unknown as Array<{
          line_id: number;
          direction: number;
          from_cell: string;
          to_cell: string;
          trips: number;
        }>
      ) {
        const acc = this.accFor(accs, r.line_id, r.direction);
        acc.edges.set(`${r.from_cell}>${r.to_cell}`, r.trips);
      }
      const stateRows = await this.deps.sql`
        select line_id, direction, sample_trips from learning_route_state
      `;
      for (
        const r of stateRows as unknown as Array<{
          line_id: number;
          direction: number;
          sample_trips: number;
        }>
      ) {
        const acc = this.accFor(accs, r.line_id, r.direction);
        acc.tripCount = r.sample_trips;
      }
      const routeRows = await this.deps.sql`
        select line_id, direction from learned_routes
        where status = 'active'
        group by line_id, direction
      `;
      for (
        const r of routeRows as unknown as Array<{
          line_id: number;
          direction: number;
        }>
      ) {
        this.accFor(accs, r.line_id, r.direction);
      }
      this.routeAccs = accs;
    } catch {
      // DB down: no accumulators; direction stays 0 until the next restart.
    }
  }

  private accFor(
    accs: Map<string, CorridorAcc>,
    lineId: number,
    direction: number,
  ): CorridorAcc {
    const k = this.key(lineId, direction);
    let acc = accs.get(k);
    if (!acc) {
      acc = newCorridorAcc(
        lineId,
        direction,
        GRID_ORIGIN,
        this.config.corridorCellM,
      );
      accs.set(k, acc);
    }
    return acc;
  }

  /**
   * Seed the in-memory stop cache from persisted learned_stops (F2). The DB is
   * the source of truth: the cache only answers proximity matching between
   * trips, and reloading it returns the same ids, centroids and pass counts.
   */
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
    opts: { consentVersion: number },
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
    opts: { consentVersion: number },
  ): void {
    // Test and simulator trips opt out explicitly; live sharing still runs.
    if (e.synthetic === true) return;
    if (opts.consentVersion < this.config.minConsentVersion) {
      recordLearningTripIneligible();
      return;
    }
    const work: TripWork = {
      tripKey: e.tripKey,
      lineId: e.lineId,
      direction: null,
      consentVersion: opts.consentVersion,
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
    this.works.delete(e.tripKey);
    // Finalization does DB writes (cell/edge upserts, state, publish) and must
    // not block the HTTP response. Tasks run in trip-end order.
    this.enqueue(() => this.finalizeTrip(work));
  }

  private enqueue(task: () => Promise<void>): void {
    this.queue = this.queue.then(task).catch((e) => {
      Log.warn("learning contribution failed", {
        err: String(e).slice(0, 200),
      });
    });
  }

  /** Wait for queued contributions, including tasks they enqueue. */
  private async drainQueue(): Promise<void> {
    let current: Promise<void>;
    do {
      current = this.queue;
      await current;
    } while (current !== this.queue);
  }

  private async finalizeTrip(work: TripWork): Promise<void> {
    if (work.samples.length < 2) {
      recordLearningTripTooFewSamples();
      return;
    }
    const cfg = this.config;
    const kept = trimSamples(work.samples, cfg.trimEndsS);
    if (kept.length < 2) {
      recordLearningTripTooFewSamples();
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

    // Stops, dwell bins and travel bins are persisted before the corridor
    // contribution: publishRoute derives stop ordinals from the published
    // chain, so this trip's new stops must already exist in learned_stops.
    // Dwell and travel aggregates do not depend on a cell transition: a trip
    // with at least 2 kept fixes still contributes its stops and dwells.
    await this.contributeStops(work, kept, direction);

    // Temporary per-trip accumulator on the fixed grid. Dedup is structural
    // (Map keys), so each visited cell and each directed transition produces
    // exactly one row increment for this trip. Cell value is the trip's mean
    // fix in that cell, which keeps the weighted centroid aggregate-only.
    const tripAcc = newCorridorAcc(
      work.lineId,
      direction,
      GRID_ORIGIN,
      cfg.corridorCellM,
    );
    addTrip(tripAcc, keptPoints);
    if (tripAcc.tripCount > 0) {
      await this.contributeTrip(tripAcc);
      recordLearningTripsContributed(1);
    } else {
      recordLearningTripNoCellTransition();
    }
  }

  private async contributeStops(
    work: TripWork,
    kept: TripSample[],
    direction: number,
  ): Promise<void> {
    const aggregates = this.collectStopAggregates(work, kept, direction);
    if (!aggregates) return;
    await this.persistStopAggregates(aggregates);
  }

  /**
   * Turn this trip's surviving dwells into working stops, dwell bins and
   * travel bins. Consecutive dwells at the same stop collapse to one visit;
   * segments run between distinct consecutive stops and use the destination
   * arrival time for their time bucket, never the trip start.
   */
  private collectStopAggregates(
    work: TripWork,
    kept: TripSample[],
    direction: number,
  ): StopAggregates | null {
    const cfg = this.config;
    const trimStart = kept[0].t;
    const trimEnd = kept[kept.length - 1].t;
    const dwells = work.dwells.filter((d) =>
      d.endMs - d.startMs >= cfg.minDwellS * 1000 &&
      d.startMs >= trimStart && d.endMs <= trimEnd
    );
    if (dwells.length === 0) return null;

    const working = new Map<string, WorkingStop>();
    const hits: DwellHit[] = [];
    const dwellBins: DwellBin[] = [];
    for (const d of dwells) {
      const stop = this.workingStopFor(
        work.lineId,
        direction,
        d.lat,
        d.lng,
        working,
      );
      stop.added += 1;
      stop.sumLat += d.lat;
      stop.sumLng += d.lng;
      dwellBins.push({
        stopId: stop.cluster.id,
        hourBucket: hourBucket(d.startMs),
        dayOfWeek: dayOfWeek(d.startMs),
        binS: quantizeS((d.endMs - d.startMs) / 1000),
      });
      hits.push({ stop, startMs: d.startMs, endMs: d.endMs });
    }

    const ordered: DwellHit[] = [];
    for (const h of hits) {
      const last = ordered[ordered.length - 1];
      if (last && last.stop.cluster.id === h.stop.cluster.id) {
        last.endMs = Math.max(last.endMs, h.endMs);
      } else {
        ordered.push({ stop: h.stop, startMs: h.startMs, endMs: h.endMs });
      }
    }
    const travelBins: TravelBin[] = [];
    for (let i = 1; i < ordered.length; i++) {
      const from = ordered[i - 1];
      const to = ordered[i];
      if (from.stop.cluster.id === to.stop.cluster.id) continue;
      const travelS = Math.max(0, (to.startMs - from.endMs) / 1000);
      travelBins.push({
        lineId: work.lineId,
        direction,
        fromStop: from.stop.cluster.id,
        toStop: to.stop.cluster.id,
        hourBucket: hourBucket(to.startMs),
        dayOfWeek: dayOfWeek(to.startMs),
        binS: quantizeS(travelS),
      });
    }
    return { stops: [...working.values()], dwellBins, travelBins };
  }

  /**
   * Write one trip's stops, bins and recomputed stats in one transaction.
   * Stats read all persisted bins, so counts are cumulative and restart-safe.
   */
  private async persistStopAggregates(
    aggregates: StopAggregates,
  ): Promise<void> {
    const { stops, dwellBins, travelBins } = aggregates;
    const stopsById = new Map<string, WorkingStop>();
    for (const w of stops) stopsById.set(w.cluster.id, w);

    await this.deps.sql.begin(async (tx) => {
      for (const stop of stops) await this.persistStop(tx, stop);
      for (const b of dwellBins) {
        await tx`
          insert into learning_dwell_bins
            (stop_id, hour_bucket, day_of_week, bin_s, sample_count)
          values (${b.stopId}, ${b.hourBucket}, ${b.dayOfWeek}, ${b.binS}, 1)
          on conflict (stop_id, hour_bucket, day_of_week, bin_s) do update set
            sample_count = learning_dwell_bins.sample_count + 1
        `;
      }
      for (const b of travelBins) {
        await tx`
          insert into learning_travel_bins
            (line_id, direction, from_stop, to_stop, hour_bucket, day_of_week,
             bin_s, sample_count)
          values (${b.lineId}, ${b.direction}, ${b.fromStop}, ${b.toStop},
            ${b.hourBucket}, ${b.dayOfWeek}, ${b.binS}, 1)
          on conflict (
            line_id, direction, from_stop, to_stop, hour_bucket, day_of_week,
            bin_s
          ) do update set
            sample_count = learning_travel_bins.sample_count + 1
        `;
      }
      for (const k of uniqueDwellKeys(dwellBins)) {
        await this.recomputeDwellStat(tx, k);
      }
      for (const k of uniqueSegmentKeys(travelBins)) {
        const from = stopsById.get(k.fromStop);
        const to = stopsById.get(k.toStop);
        const distanceM = from && to
          ? distM(
            workingLat(from),
            workingLng(from),
            workingLat(to),
            workingLng(to),
          )
          : 0;
        await this.recomputeSegmentStat(tx, k, distanceM);
      }
    });

    // The DB is the source of truth. Apply the trip's changes to the cache
    // only after the transaction commits, so a rollback leaves no phantom
    // stop ids behind.
    for (const stop of stops) this.cacheStop(stop);
  }

  /**
   * Find a cache-backed stop within the cluster radius, or create a new
   * working stop for this trip. New stops are inserted by persistStop.
   */
  private workingStopFor(
    lineId: number,
    direction: number,
    lat: number,
    lng: number,
    working: Map<string, WorkingStop>,
  ): WorkingStop {
    const radiusM = this.config.stopClusterRadiusM;
    for (const w of working.values()) {
      if (w.cluster.lineId !== lineId || w.cluster.direction !== direction) {
        continue;
      }
      if (distM(workingLat(w), workingLng(w), lat, lng) <= radiusM) return w;
    }
    for (const c of this.stopClusters.values()) {
      if (c.lineId !== lineId || c.direction !== direction) continue;
      if (distM(c.centroidLat, c.centroidLng, lat, lng) > radiusM) continue;
      const w: WorkingStop = {
        cluster: c,
        added: 0,
        sumLat: 0,
        sumLng: 0,
        created: false,
      };
      working.set(c.id, w);
      return w;
    }
    const fresh: WorkingStop = {
      cluster: {
        id: crypto.randomUUID(),
        lineId,
        direction,
        ordinal: 0,
        centroidLat: 0,
        centroidLng: 0,
        radiusM,
        passCount: 0,
      },
      added: 0,
      sumLat: 0,
      sumLng: 0,
      created: true,
    };
    working.set(fresh.cluster.id, fresh);
    return fresh;
  }

  private async persistStop(tx: Tx, stop: WorkingStop): Promise<void> {
    const c = stop.cluster;
    if (stop.created) {
      await tx`
        insert into learned_stops
          (id, line_id, direction, ordinal, lat, lng, radius_m, sample_passes,
           first_seen_at, last_seen_at, active)
        values (${c.id}, ${c.lineId}, ${c.direction}, ${c.ordinal},
          ${workingLat(stop)}, ${workingLng(stop)}, ${c.radiusM},
          ${stop.added}, now(),
          now(), true)
      `;
      return;
    }
    // Weighted mean against the row's own pass count, so the centroid stays
    // cumulative even if the cache is stale.
    await tx`
      update learned_stops set
        lat = (lat * sample_passes + ${stop.sumLat})
          / (sample_passes + ${stop.added}),
        lng = (lng * sample_passes + ${stop.sumLng})
          / (sample_passes + ${stop.added}),
        sample_passes = sample_passes + ${stop.added},
        last_seen_at = now(),
        active = true
      where id = ${c.id}
    `;
  }

  private cacheStop(stop: WorkingStop): void {
    const c = stop.cluster;
    this.stopClusters.set(c.id, {
      id: c.id,
      lineId: c.lineId,
      direction: c.direction,
      ordinal: c.ordinal,
      centroidLat: workingLat(stop),
      centroidLng: workingLng(stop),
      radiusM: c.radiusM,
      passCount: c.passCount + stop.added,
    });
  }

  // ---- Corridor persistence ----

  /**
   * Persist one trip's deduplicated cells and edges, bump the direction's
   * sample_trips, then publish the route. Runs inside the serialized queue,
   * so contributions and publications for a line stay in trip-end order.
   */
  private async contributeTrip(trip: CorridorAcc): Promise<void> {
    const lineId = trip.lineId;
    const direction = trip.direction;
    await this.upsertCells(trip);
    await this.upsertEdges(trip);
    await this.deps.sql`
      insert into learning_route_state (line_id, direction, sample_trips)
      values (${lineId}, ${direction}, 1)
      on conflict (line_id, direction) do update set
        sample_trips = learning_route_state.sample_trips + 1
    `;
    this.updateMirror(trip);
    await this.publishRoute(lineId, direction);
  }

  /**
   * One parameterized statement per trip. jsonb_to_recordset keeps the rows
   * out of the SQL text; values are server-derived grid keys and centroids.
   * A cell row's `trips` counts contributing trips, not fixes.
   */
  private async upsertCells(trip: CorridorAcc): Promise<void> {
    if (trip.cells.size === 0) return;
    const rows = [...trip.cells].map(([cellKey, cell]) => ({
      cell_key: cellKey,
      lat: cell.lat,
      lng: cell.lng,
    }));
    await this.deps.sql`
      insert into learning_route_cells
        (line_id, direction, cell_key, lat, lng, trips,
         first_seen_at, last_seen_at)
      select ${trip.lineId}, ${trip.direction}, x.cell_key, x.lat, x.lng,
        1, now(), now()
      from jsonb_to_recordset(${JSON.stringify(rows)}::jsonb)
        as x(cell_key text, lat double precision, lng double precision)
      on conflict (line_id, direction, cell_key) do update set
        lat = (learning_route_cells.lat * learning_route_cells.trips
          + excluded.lat) / (learning_route_cells.trips + 1),
        lng = (learning_route_cells.lng * learning_route_cells.trips
          + excluded.lng) / (learning_route_cells.trips + 1),
        trips = learning_route_cells.trips + 1,
        last_seen_at = now()
    `;
  }

  private async upsertEdges(trip: CorridorAcc): Promise<void> {
    if (trip.edges.size === 0) return;
    const rows: Array<{ from_cell: string; to_cell: string }> = [];
    for (const key of trip.edges.keys()) {
      const sep = key.indexOf(">");
      if (sep <= 0 || sep === key.length - 1) continue;
      rows.push({
        from_cell: key.slice(0, sep),
        to_cell: key.slice(sep + 1),
      });
    }
    if (rows.length === 0) return;
    await this.deps.sql`
      insert into learning_route_edges
        (line_id, direction, from_cell, to_cell, trips,
         first_seen_at, last_seen_at)
      select ${trip.lineId}, ${trip.direction}, x.from_cell, x.to_cell,
        1, now(), now()
      from jsonb_to_recordset(${JSON.stringify(rows)}::jsonb)
        as x(from_cell text, to_cell text)
      on conflict (line_id, direction, from_cell, to_cell) do update set
        trips = learning_route_edges.trips + 1,
        last_seen_at = now()
    `;
  }

  /**
   * Keep the in-memory direction mirror aligned with the DB. The mirror only
   * answers direction assignment between trips; publication always rebuilds
   * from PostgreSQL.
   */
  private updateMirror(trip: CorridorAcc): void {
    const acc = this.accFor(this.routeAccs, trip.lineId, trip.direction);
    for (const [key, cell] of trip.cells) {
      const existing = acc.cells.get(key);
      if (!existing) {
        acc.cells.set(key, { lat: cell.lat, lng: cell.lng, n: 1 });
        continue;
      }
      const n = existing.n + 1;
      existing.lat += (cell.lat - existing.lat) / n;
      existing.lng += (cell.lng - existing.lng) / n;
      existing.n = n;
    }
    for (const key of trip.edges.keys()) {
      acc.edges.set(key, (acc.edges.get(key) ?? 0) + 1);
    }
    acc.tripCount += 1;
  }

  /**
   * Rebuild the corridor from PostgreSQL and publish after each contributing
   * trip. There is no trip-count, cell-count or minimum-length publication
   * gate: only geometry validity (2 points) and the polyline size cap apply.
   * Version churn is controlled geometrically: a route within 15 m median
   * deviation of the active one is updated in place.
   */
  private async publishRoute(
    lineId: number,
    direction: number,
  ): Promise<void> {
    const acc = await this.loadCorridorAcc(lineId, direction);
    const chain = buildChain(acc, {
      cellM: this.config.corridorCellM,
      minEdgeWeight: 1,
      minCells: 2,
    });
    const sampleTrips = acc.tripCount;
    if (!chain) {
      recordLearningRouteChainTooSmall();
      await this.updateActiveSampleTrips(lineId, direction, sampleTrips);
      await this.markPublishAttempt(lineId, direction);
      return;
    }
    const smoothed = smooth(chain);
    let pts = simplify(smoothed, 5);
    if (pts.length > 400) pts = simplify(smoothed, 10);
    if (pts.length < 2) {
      recordLearningRouteChainTooSmall();
      await this.updateActiveSampleTrips(lineId, direction, sampleTrips);
      await this.markPublishAttempt(lineId, direction);
      return;
    }
    const poly = encodePolyline(pts, 5);
    if (poly.length > 8192) {
      recordLearningRouteOversized();
      // Keep the active geometry; confidence still belongs to this direction.
      await this.updateActiveSampleTrips(lineId, direction, sampleTrips);
      await this.markPublishAttempt(lineId, direction);
      return;
    }
    await this.upsertRoute(
      lineId,
      direction,
      poly,
      pts.length,
      pts,
      sampleTrips,
    );
    await this.updateStopOrdinals(lineId, direction, pts);
    await this.markPublishAttempt(lineId, direction);
  }

  private async loadCorridorAcc(
    lineId: number,
    direction: number,
  ): Promise<CorridorAcc> {
    const acc = newCorridorAcc(
      lineId,
      direction,
      GRID_ORIGIN,
      this.config.corridorCellM,
    );
    const cellRows = await this.deps.sql`
      select cell_key, lat, lng, trips
      from learning_route_cells
      where line_id = ${lineId} and direction = ${direction}
    `;
    for (
      const r of cellRows as unknown as Array<{
        cell_key: string;
        lat: number;
        lng: number;
        trips: number;
      }>
    ) {
      acc.cells.set(r.cell_key, { lat: r.lat, lng: r.lng, n: r.trips });
    }
    const edgeRows = await this.deps.sql`
      select from_cell, to_cell, trips
      from learning_route_edges
      where line_id = ${lineId} and direction = ${direction}
    `;
    for (
      const r of edgeRows as unknown as Array<{
        from_cell: string;
        to_cell: string;
        trips: number;
      }>
    ) {
      acc.edges.set(`${r.from_cell}>${r.to_cell}`, r.trips);
    }
    const stateRows = await this.deps.sql`
      select sample_trips from learning_route_state
      where line_id = ${lineId} and direction = ${direction}
    `;
    acc.tripCount = Number(
      (stateRows as unknown as Array<{ sample_trips: number }>)[0]
        ?.sample_trips ?? 0,
    );
    return acc;
  }

  private async updateActiveSampleTrips(
    lineId: number,
    direction: number,
    sampleTrips: number,
  ): Promise<void> {
    if (sampleTrips <= 0) return;
    await this.deps.sql`
      update learned_routes set sample_trips = ${sampleTrips}
      where line_id = ${lineId} and direction = ${direction}
        and status = 'active'
    `;
  }

  private async markPublishAttempt(
    lineId: number,
    direction: number,
  ): Promise<void> {
    await this.deps.sql`
      update learning_route_state set last_publish_at = now()
      where line_id = ${lineId} and direction = ${direction}
    `;
  }

  /**
   * Safety net for the crash window between the sample_trips increment and
   * the async publication. The periodic flush republishes any direction whose
   * stored sample count is ahead of its active route. A trip queued but never
   * started is lost; only aggregate progress already in the DB is recovered.
   */
  private async publishStaleRoutes(): Promise<void> {
    const rows = await this.deps.sql`
      select s.line_id, s.direction
      from learning_route_state s
      left join learned_routes r
        on r.line_id = s.line_id and r.direction = s.direction
       and r.status = 'active'
      where s.sample_trips > 0
        and (r.id is null or s.sample_trips > r.sample_trips)
    `;
    for (
      const r of rows as unknown as Array<{
        line_id: number;
        direction: number;
      }>
    ) {
      await this.publishRoute(r.line_id, r.direction);
    }
  }

  /**
   * Assign a direction from DB-backed corridor accumulators for this line.
   * No accumulator means direction 0; exactly one means that accumulator's
   * direction, so a restart that reloaded only one slot keeps new trips on it
   * instead of splitting the corridor into direction 0. With two, the corridor
   * covered by the trip wins, falling back to bearing only when both cover
   * nothing.
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

  // ---- Flush ----

  async flush(): Promise<void> {
    if (!this.config.enabled) return;
    recordLearningFlush();
    try {
      // Finalized trips write cells, edges, state, stops, bins and stats off
      // the request path. Wait for them before republishing stale routes.
      await this.drainQueue();
      // Crash-window safety net; no-op when every direction is up to date.
      await this.publishStaleRoutes();
    } catch (e) {
      recordLearningFlushFailed();
      throw e;
    }
  }

  private async upsertRoute(
    lineId: number,
    direction: number,
    polyline: string,
    pointCount: number,
    points: Pt[],
    sampleTrips: number,
  ): Promise<void> {
    // Version churn control: an active route within 15 m median deviation is
    // kept, with its confidence and computed_at refreshed in place.
    const activeRows = await this.deps.sql`
      select id, polyline from learned_routes
      where line_id = ${lineId} and direction = ${direction}
        and status = 'active'
      order by version desc
      limit 1
    `;
    const active = (activeRows as unknown as Array<{
      id: string;
      polyline: string;
    }>)[0];
    let activePts: Pt[] = [];
    if (active) {
      try {
        activePts = decodePolyline(active.polyline, 5);
      } catch {
        activePts = [];
      }
    }
    const dev = activePts.length >= 2
      ? medianDeviationM(points, activePts)
      : null;
    if (active && dev !== null && dev < 15) {
      recordLearningRouteNoFlapSuppressed();
      await this.deps.sql`
        update learned_routes
        set sample_trips = ${sampleTrips}, computed_at = now()
        where id = ${active.id}
      `;
      return;
    }
    const rows = await this.deps.sql`
      select coalesce(max(version), 0) as v
      from learned_routes
      where line_id = ${lineId} and direction = ${direction}
    `;
    const version =
      Number((rows as unknown as Array<{ v: number }>)[0]?.v ?? 0) + 1;
    // Retire any prior active version so only one active row per
    // (line, direction) survives (T1). Retained 30 days per docs.
    const retired = await this.deps.sql`
      update learned_routes
      set status = 'retired', retired_at = now()
      where line_id = ${lineId} and direction = ${direction}
        and status = 'active'
      returning id
    `;
    recordLearningRouteRetired((retired as unknown[]).length);
    await this.deps.sql`
      insert into learned_routes (line_id, direction, version, status, polyline, point_count, sample_trips, median_deviation_m, computed_at)
      values (${lineId}, ${direction}, ${version}, 'active', ${polyline}, ${pointCount}, ${sampleTrips}, ${dev}, now())
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
    // Read from PostgreSQL, not the in-memory mirror: another process or a
    // direct admin fix can add a stop that this process has not cached yet.
    const rows = await this.deps.sql`
      select id, lat, lng from learned_stops
      where line_id = ${lineId} and direction = ${direction} and active = true
    `;
    const stops = rows as unknown as Array<{
      id: string;
      lat: number;
      lng: number;
    }>;
    if (stops.length === 0) return;
    const ordinals = assignOrdinals(
      stops.map((s) => ({ lat: s.lat, lng: s.lng })),
      chain,
    );
    for (let i = 0; i < stops.length; i++) {
      await this.deps.sql`
        update learned_stops set ordinal = ${ordinals[i]}
        where id = ${stops[i].id}
      `;
      const cached = this.stopClusters.get(stops[i].id);
      if (cached) cached.ordinal = ordinals[i];
    }
  }

  /**
   * Recompute a (stop, hour, day) dwell stat from all persisted bins. Counts
   * and percentiles are cumulative by construction; no per-batch reservoir.
   * Nearest-rank percentile over the bin histogram.
   */
  private async recomputeDwellStat(tx: Tx, key: DwellKey): Promise<void> {
    const rows = await tx`
      select bin_s, sample_count from learning_dwell_bins
      where stop_id = ${key.stopId} and hour_bucket = ${key.hourBucket}
        and day_of_week = ${key.dayOfWeek}
      order by bin_s asc
    ` as unknown as BinRow[];
    const total = sumCounts(rows);
    if (total === 0) return;
    await tx`
      insert into stop_dwell_stats
        (stop_id, hour_bucket, day_of_week, sample_count, dwell_p50_s,
         dwell_p90_s, updated_at)
      values (${key.stopId}, ${key.hourBucket}, ${key.dayOfWeek}, ${total},
        ${nearestRank(rows, 0.5)}, ${nearestRank(rows, 0.9)}, now())
      on conflict (stop_id, hour_bucket, day_of_week) do update set
        sample_count = excluded.sample_count,
        dwell_p50_s = excluded.dwell_p50_s,
        dwell_p90_s = excluded.dwell_p90_s,
        updated_at = now()
    `;
  }

  private async recomputeSegmentStat(
    tx: Tx,
    key: SegmentKey,
    distanceM: number,
  ): Promise<void> {
    const rows = await tx`
      select bin_s, sample_count from learning_travel_bins
      where line_id = ${key.lineId} and direction = ${key.direction}
        and from_stop = ${key.fromStop} and to_stop = ${key.toStop}
        and hour_bucket = ${key.hourBucket} and day_of_week = ${key.dayOfWeek}
      order by bin_s asc
    ` as unknown as BinRow[];
    const total = sumCounts(rows);
    if (total === 0) return;
    await tx`
      insert into segment_stats
        (line_id, direction, from_stop, to_stop, hour_bucket, day_of_week,
         sample_count, travel_p50_s, travel_p90_s, distance_m, updated_at)
      values (${key.lineId}, ${key.direction}, ${key.fromStop}, ${key.toStop},
        ${key.hourBucket}, ${key.dayOfWeek}, ${total},
        ${nearestRank(rows, 0.5)}, ${nearestRank(rows, 0.9)},
        ${distanceM}, now())
      on conflict (
        line_id, direction, from_stop, to_stop, hour_bucket, day_of_week
      ) do update set
        sample_count = excluded.sample_count,
        travel_p50_s = excluded.travel_p50_s,
        travel_p90_s = excluded.travel_p90_s,
        distance_m = excluded.distance_m,
        updated_at = now()
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
    // Every stored aggregate with at least one sample is served.
    if (!r || r.sample_count < 1) return null;
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
    // Every stored aggregate with at least one sample is served.
    if (!r || r.sample_count < 1) return null;
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

interface WorkingStop {
  cluster: StopCluster;
  /** Passes contributed by this trip; the base count lives on cluster. */
  added: number;
  sumLat: number;
  sumLng: number;
  created: boolean;
}

interface DwellHit {
  stop: WorkingStop;
  startMs: number;
  endMs: number;
}

interface DwellBin {
  stopId: string;
  hourBucket: number;
  dayOfWeek: number;
  binS: number;
}

interface TravelBin {
  lineId: number;
  direction: number;
  fromStop: string;
  toStop: string;
  hourBucket: number;
  dayOfWeek: number;
  binS: number;
}

interface StopAggregates {
  stops: WorkingStop[];
  dwellBins: DwellBin[];
  travelBins: TravelBin[];
}

interface DwellKey {
  stopId: string;
  hourBucket: number;
  dayOfWeek: number;
}

interface SegmentKey {
  lineId: number;
  direction: number;
  fromStop: string;
  toStop: string;
  hourBucket: number;
  dayOfWeek: number;
}

interface BinRow {
  bin_s: number;
  sample_count: number;
}

/** Weighted centroid of a working stop, combining base passes and this trip. */
function workingLat(stop: WorkingStop): number {
  const n = stop.cluster.passCount + stop.added;
  if (n === 0) return stop.cluster.centroidLat;
  return (stop.cluster.centroidLat * stop.cluster.passCount + stop.sumLat) / n;
}

function workingLng(stop: WorkingStop): number {
  const n = stop.cluster.passCount + stop.added;
  if (n === 0) return stop.cluster.centroidLng;
  return (stop.cluster.centroidLng * stop.cluster.passCount + stop.sumLng) / n;
}

/**
 * Privacy trim. Normal trips drop trimEndsS from each end. A trip shorter
 * than 2*trimEndsS drops at most 10% per end, never the whole trip: a short
 * trip still contributes its stops and dwells. Falls back to all samples if
 * the proportional trim would leave fewer than 2.
 */
function trimSamples(
  samples: TripSample[],
  trimEndsS: number,
): TripSample[] {
  if (samples.length < 2) return samples;
  const first = samples[0].t;
  const last = samples[samples.length - 1].t;
  const durationMs = Math.max(0, last - first);
  const normalTrimMs = trimEndsS * 1000;
  const trimMs = durationMs < 2 * normalTrimMs
    ? Math.min(normalTrimMs, Math.floor(durationMs * 0.1))
    : normalTrimMs;
  const kept = samples.filter((s) =>
    s.t >= first + trimMs && s.t <= last - trimMs
  );
  return kept.length >= 2 ? kept : samples;
}

/** Quantize a duration into 5 s bins clamped to [5, 3600]. */
function quantizeS(durationS: number): number {
  const rounded = Math.round(durationS / 5) * 5;
  return Math.min(3600, Math.max(5, rounded));
}

function uniqueDwellKeys(bins: DwellBin[]): DwellKey[] {
  const keys = new Map<string, DwellKey>();
  for (const b of bins) {
    keys.set(`${b.stopId}:${b.hourBucket}:${b.dayOfWeek}`, {
      stopId: b.stopId,
      hourBucket: b.hourBucket,
      dayOfWeek: b.dayOfWeek,
    });
  }
  return [...keys.values()];
}

function uniqueSegmentKeys(bins: TravelBin[]): SegmentKey[] {
  const keys = new Map<string, SegmentKey>();
  for (const b of bins) {
    keys.set(
      `${b.fromStop}:${b.toStop}:${b.hourBucket}:${b.dayOfWeek}`,
      {
        lineId: b.lineId,
        direction: b.direction,
        fromStop: b.fromStop,
        toStop: b.toStop,
        hourBucket: b.hourBucket,
        dayOfWeek: b.dayOfWeek,
      },
    );
  }
  return [...keys.values()];
}

function sumCounts(bins: BinRow[]): number {
  let total = 0;
  for (const b of bins) total += b.sample_count;
  return total;
}

/**
 * Nearest-rank percentile over ordered histogram bins: the first bin whose
 * cumulative count reaches ceil(p * total).
 */
function nearestRank(bins: BinRow[], p: number): number {
  const total = sumCounts(bins);
  if (total === 0) return 0;
  const rank = Math.max(1, Math.ceil(p * total));
  let cumulative = 0;
  for (const b of bins) {
    cumulative += b.sample_count;
    if (cumulative >= rank) return b.bin_s;
  }
  return bins[bins.length - 1].bin_s;
}
