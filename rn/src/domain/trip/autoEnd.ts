// Auto-end logic. Mirrors app/lib/domain/trip/auto_end.dart (simplified).
export function shouldAutoEnd(idleMs: number, maxIdleMs: number): boolean {
  return idleMs >= maxIdleMs;
}

// Sampling policy. Mirrors app/lib/domain/trip/sampling_policy.dart (simplified).
export function samplingIntervalMs(speedMps: number): number {
  if (speedMps < 1) return 15000;
  if (speedMps < 5) return 10000;
  return 5000;
}
