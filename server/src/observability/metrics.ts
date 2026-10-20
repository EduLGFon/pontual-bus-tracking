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
  /** Passenger reports created and retracted. Aggregate only, no ids. */
  reportsCreatedTotal: number;
  reportsRetractedTotal: number;
}

const startedAtMs = Date.now();
let requestsTotal = 0;
let healthChecksTotal = 0;
let wsConnectsTotal = 0;
let wsCapacityRefusedTotal = 0;
let http429Total = 0;
let http403Total = 0;
let reportsCreatedTotal = 0;
let reportsRetractedTotal = 0;

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

export function recordReportCreated(): void {
  reportsCreatedTotal += 1;
}

export function recordReportRetracted(): void {
  reportsRetractedTotal += 1;
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
    reportsCreatedTotal,
    reportsRetractedTotal,
  };
}
