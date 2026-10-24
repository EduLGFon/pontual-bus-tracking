// Types for the de-identified learning subsystem.
// See docs/data-learning.md. Nothing here is persisted raw; all structs
// are either in-memory working state or aggregate rows.

export interface LearningConfig {
  enabled: boolean;
  minConsentVersion: number;
  minRouteTrips: number;
  minStopPasses: number;
  kMin: number;
  trimEndsS: number;
  flushIntervalS: number;
  cacheTtlS: number;
  routeBins: number;
  stopClusterRadiusM: number;
  stopSpeedMps: number;
  minDwellS: number;
  headwayHorizonS: number;
  defaultSpeedMps: number;
  defaultDwellS: number;
  minRouteLengthM: number;
  stopMinDistinctDays: number;
  maxSamplesPerTrip: number;
  minSampleSpacingM: number;
  minSampleSpacingS: number;
  maxMemoryBytes: number;
  recomputeEveryNTrips: number;
}

export const defaultLearningConfig = (): LearningConfig => ({
  enabled: false,
  minConsentVersion: 2,
  minRouteTrips: 20,
  minStopPasses: 4,
  kMin: 5,
  trimEndsS: 120,
  flushIntervalS: 300,
  cacheTtlS: 60,
  routeBins: 200,
  stopClusterRadiusM: 30,
  stopSpeedMps: 1.0,
  minDwellS: 10,
  headwayHorizonS: 1800,
  defaultSpeedMps: 6,
  defaultDwellS: 20,
  minRouteLengthM: 500,
  stopMinDistinctDays: 3,
  maxSamplesPerTrip: 200,
  minSampleSpacingM: 20,
  minSampleSpacingS: 10,
  maxMemoryBytes: 50 * 1024 * 1024,
  recomputeEveryNTrips: 5,
});

export interface TripSample {
  t: number;
  lat: number;
  lng: number;
  speed: number;
}

export interface TripWork {
  tripKey: string;
  lineId: number;
  direction: number | null;
  consentVersion: number;
  startedAtMs: number;
  endedAtMs: number | null;
  samples: TripSample[];
  dwells: Array<{ lat: number; lng: number; startMs: number; endMs: number }>;
  totalDistanceM: number;
}

export interface RouteBin {
  latSum: number;
  lngSum: number;
  n: number;
}

export interface RouteAcc {
  lineId: number;
  direction: number;
  bins: Map<number, { lats: number[]; lngs: number[] }>;
  tripCount: number;
}

export interface StopCluster {
  id: string;
  lineId: number;
  direction: number;
  centroidLat: number;
  centroidLng: number;
  radiusM: number;
  passCount: number;
  distinctDays: Set<string>;
  // reservoir of pass centroids for re-clustering
  reservoir: Array<{ lat: number; lng: number; day: string }>;
}

export interface DwellAcc {
  stopId: string;
  hourBucket: number;
  dayOfWeek: number;
  count: number;
  sumS: number;
  minS: number;
  maxS: number;
  reservoir: number[];
}

export interface SegmentAcc {
  lineId: number;
  direction: number;
  fromStop: string;
  toStop: string;
  hourBucket: number;
  dayOfWeek: number;
  count: number;
  sumS: number;
  minS: number;
  maxS: number;
  distanceM: number;
  reservoir: number[];
}

export interface LearnedRouteRow {
  id: string;
  lineId: number;
  direction: number;
  version: number;
  status: "candidate" | "active" | "retired";
  polyline: string;
  pointCount: number;
  sampleTrips: number;
  medianDeviationM: number | null;
  computedAt: string;
}

export interface LearnedStopRow {
  id: string;
  lineId: number;
  direction: number;
  ordinal: number;
  lat: number;
  lng: number;
  radiusM: number;
  samplePasses: number;
  active: boolean;
}

export interface SegmentStatRow {
  lineId: number;
  direction: number;
  fromStop: string;
  toStop: string;
  hourBucket: number;
  dayOfWeek: number;
  sampleCount: number;
  travelP50S: number;
  travelP90S: number;
  distanceM: number;
}

export interface DwellStatRow {
  stopId: string;
  hourBucket: number;
  dayOfWeek: number;
  sampleCount: number;
  dwellP50S: number;
  dwellP90S: number;
}
