// Aggregate counters only. No PII, no coordinates. See PLAN.md RNF18.

export interface MetricsSnapshot {
  startedAt: string;
  uptimeS: number;
  requestsTotal: number;
  healthChecksTotal: number;
  /** Successful WebSocket upgrades. */
  wsConnectsTotal: number;
  /** Upgrades refused for full caps (answered 503). */
  wsCapacityRefusedTotal: number;
  /** Total 429 answers across read and trip routes. */
  http429Total: number;
  /** Total 403 answers across read and trip routes. */
  http403Total: number;
  /** Pings dropped by the 4 s min-interval defense. Aggregate only. */
  pingsRateLimitedTotal: number;
  /** Passenger reports created and retracted. Aggregate only, no ids. */
  reportsCreatedTotal: number;
  reportsRetractedTotal: number;
  /** Learning subsystem aggregate counters (F5). No coordinates, no ids. */
  learningFlushesTotal: number;
  learningRoutesPublishedTotal: number;
  learningRoutesRetiredTotal: number;
  learningTripsContributedTotal: number;
  /** Drop-reason counters for the learning subsystem (aggregate only). */
  learningTripsIneligibleTotal: number;
  learningTripsTooFewSamplesTotal: number;
  learningTripsTooShortTotal: number;
  learningTripsGapDroppedTotal: number;
  learningTripsNoCellTransitionTotal: number;
  learningTripsDirectionAssignedTotal: number;
  learningRoutesBelowMinTripsTotal: number;
  learningRoutesChainTooSmallTotal: number;
  learningRoutesTooShortTotal: number;
  learningRoutesOversizedTotal: number;
  learningRoutesNoFlapSuppressedTotal: number;
  learningFlushesFailedTotal: number;
}

const startedAtMs = Date.now();
let requestsTotal = 0;
let healthChecksTotal = 0;
let wsConnectsTotal = 0;
let wsCapacityRefusedTotal = 0;
let http429Total = 0;
let http403Total = 0;
let pingsRateLimitedTotal = 0;
let reportsCreatedTotal = 0;
let reportsRetractedTotal = 0;
let learningFlushesTotal = 0;
let learningRoutesPublishedTotal = 0;
let learningRoutesRetiredTotal = 0;
let learningTripsContributedTotal = 0;
let learningTripsIneligibleTotal = 0;
let learningTripsTooFewSamplesTotal = 0;
let learningTripsTooShortTotal = 0;
let learningTripsGapDroppedTotal = 0;
let learningTripsNoCellTransitionTotal = 0;
let learningTripsDirectionAssignedTotal = 0;
let learningRoutesBelowMinTripsTotal = 0;
let learningRoutesChainTooSmallTotal = 0;
let learningRoutesTooShortTotal = 0;
let learningRoutesOversizedTotal = 0;
let learningRoutesNoFlapSuppressedTotal = 0;
let learningFlushesFailedTotal = 0;

export function recordRequest(): void {
  requestsTotal += 1;
}

export function recordHealthCheck(): void {
  healthChecksTotal += 1;
  requestsTotal += 1;
}

export function recordWsConnect(): void {
  wsConnectsTotal += 1;
}

export function recordWsCapacityRefused(): void {
  wsCapacityRefusedTotal += 1;
}

export function recordHttp429(): void {
  http429Total += 1;
}

export function recordHttp403(): void {
  http403Total += 1;
}

export function recordPingRateLimited(): void {
  pingsRateLimitedTotal += 1;
}

export function recordReportCreated(): void {
  reportsCreatedTotal += 1;
}

export function recordReportRetracted(): void {
  reportsRetractedTotal += 1;
}

export function recordLearningFlush(): void {
  learningFlushesTotal += 1;
}

export function recordLearningRoutePublished(): void {
  learningRoutesPublishedTotal += 1;
}

export function recordLearningRouteRetired(n = 1): void {
  learningRoutesRetiredTotal += n;
}

export function recordLearningTripsContributed(n: number): void {
  learningTripsContributedTotal += n;
}

export function recordLearningTripIneligible(): void {
  learningTripsIneligibleTotal += 1;
}

export function recordLearningTripTooFewSamples(): void {
  learningTripsTooFewSamplesTotal += 1;
}

export function recordLearningTripTooShort(): void {
  learningTripsTooShortTotal += 1;
}

export function recordLearningTripGapDropped(): void {
  learningTripsGapDroppedTotal += 1;
}

export function recordLearningTripNoCellTransition(): void {
  learningTripsNoCellTransitionTotal += 1;
}

export function recordLearningDirectionAssigned(): void {
  learningTripsDirectionAssignedTotal += 1;
}

export function recordLearningRouteBelowMinTrips(): void {
  learningRoutesBelowMinTripsTotal += 1;
}

export function recordLearningRouteChainTooSmall(): void {
  learningRoutesChainTooSmallTotal += 1;
}

export function recordLearningRouteTooShort(): void {
  learningRoutesTooShortTotal += 1;
}

export function recordLearningRouteOversized(): void {
  learningRoutesOversizedTotal += 1;
}

export function recordLearningRouteNoFlapSuppressed(): void {
  learningRoutesNoFlapSuppressedTotal += 1;
}

export function recordLearningFlushFailed(): void {
  learningFlushesFailedTotal += 1;
}

export function snapshot(): MetricsSnapshot {
  return {
    startedAt: new Date(startedAtMs).toISOString(),
    uptimeS: Math.floor((Date.now() - startedAtMs) / 1000),
    requestsTotal,
    healthChecksTotal,
    wsConnectsTotal,
    wsCapacityRefusedTotal,
    http429Total,
    http403Total,
    pingsRateLimitedTotal,
    reportsCreatedTotal,
    reportsRetractedTotal,
    learningFlushesTotal,
    learningRoutesPublishedTotal,
    learningRoutesRetiredTotal,
    learningTripsContributedTotal,
    learningTripsIneligibleTotal,
    learningTripsTooFewSamplesTotal,
    learningTripsTooShortTotal,
    learningTripsGapDroppedTotal,
    learningTripsNoCellTransitionTotal,
    learningTripsDirectionAssignedTotal,
    learningRoutesBelowMinTripsTotal,
    learningRoutesChainTooSmallTotal,
    learningRoutesTooShortTotal,
    learningRoutesOversizedTotal,
    learningRoutesNoFlapSuppressedTotal,
    learningFlushesFailedTotal,
  };
}
