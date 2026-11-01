// Auto-end policy. Mirrors app/lib/domain/trip/auto_end.dart.
export type AutoEndReason = "gpsOff" | "permissionRevoked" | "walkingTimeout" | "maxDuration";

export const gpsOffAfterMs = 5 * 60 * 1000;
export const walkingTimeoutMs = 5 * 60 * 1000;
export const walkingPromptAfterMs = 15 * 60 * 1000;
export const walkingSlowMaxMps = 0.5;
export const tripMaxMs = 4 * 3600 * 1000;

export interface AutoEndInput {
  startedAtMs: number;
  gpsOffSinceMs: number | null;
  permissionRevoked: boolean;
  walkingPromptAtMs: number | null;
}

export function autoEndReason(input: AutoEndInput, nowMs: number): AutoEndReason | null {
  if (input.permissionRevoked) return "permissionRevoked";
  const gpsOff = input.gpsOffSinceMs;
  if (gpsOff !== null && nowMs - gpsOff > gpsOffAfterMs) return "gpsOff";
  const prompt = input.walkingPromptAtMs;
  if (prompt !== null && nowMs - prompt > walkingTimeoutMs) return "walkingTimeout";
  if (nowMs - input.startedAtMs > tripMaxMs) return "maxDuration";
  return null;
}

export function walkingPromptDue(opts: {
  slowSinceMs: number | null;
  promptAtMs: number | null;
  nowMs: number;
}): boolean {
  if (opts.promptAtMs !== null) return false;
  if (opts.slowSinceMs === null) return false;
  return opts.nowMs - opts.slowSinceMs >= walkingPromptAfterMs;
}
