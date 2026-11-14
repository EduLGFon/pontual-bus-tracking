// Types for the de-identified learning subsystem.
// See docs/data-learning.md. Nothing here is persisted raw; all structs
// are either in-memory working state or aggregate rows.

export interface LearningConfig {
  enabled: boolean;
  minConsentVersion: number;
  trimEndsS: number;
  flushIntervalS: number;
  stopClusterRadiusM: number;
  stopSpeedMps: number;
  minDwellS: number;
  defaultSpeedMps: number;
  defaultDwellS: number;
  /** Absolute corridor grid size in metres. */
  corridorCellM: number;
  maxSamplesPerTrip: number;
  minSampleSpacingM: number;
  minSampleSpacingS: number;
}

export const defaultLearningConfig = (): LearningConfig => ({
  enabled: true,
  minConsentVersion: 2,
  trimEndsS: 120,
  flushIntervalS: 300,
  stopClusterRadiusM: 30,
  stopSpeedMps: 1.0,
  minDwellS: 5,
  defaultSpeedMps: 6,
  defaultDwellS: 20,
  corridorCellM: 50,
  maxSamplesPerTrip: 200,
  minSampleSpacingM: 20,
  minSampleSpacingS: 10,
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

export interface StopCluster {
  id: string;
  lineId: number;
  direction: number;
  /** Ordinal along the published corridor chain; 0 until a chain exists. */
  ordinal: number;
  centroidLat: number;
  centroidLng: number;
  radiusM: number;
  passCount: number;
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
