// Sampling policy. Mirrors app/lib/domain/trip/sampling_policy.dart.
export type SamplingMode =
  | "waiting"
  | "leaderMoving"
  | "leaderStill"
  | "follower"
  | "offlineSaver"
  | "paused";

export const streamHysteresisMs = 30000;

export function intervalSForMode(mode: SamplingMode): number {
  switch (mode) {
    case "leaderMoving":
    case "waiting":
      return 5;
    case "leaderStill":
      return 15;
    case "follower":
    case "offlineSaver":
    case "paused":
      return 45;
  }
}

export interface TripModeInput {
  role: string;
  speedMps: number;
  offline: boolean;
  stillS: number;
  paused: boolean;
}

export function wantedMode(input: TripModeInput): SamplingMode {
  if (input.paused) return "paused";
  if (input.offline) return "offlineSaver";
  switch (input.role) {
    case "L":
      if (input.stillS >= 60) return "leaderStill";
      return "leaderMoving";
    case "F":
      return "follower";
    default:
      return "waiting";
  }
}

export function decideMode(opts: {
  current: SamplingMode;
  input: TripModeInput;
  nowMs: number;
  lastChangeMs: number;
}): SamplingMode {
  const wanted = wantedMode(opts.input);
  if (wanted === opts.current) return opts.current;
  if (intervalSForMode(wanted) < intervalSForMode(opts.current)) return wanted;
  if (wanted === "leaderMoving" && opts.current !== "leaderMoving") return wanted;
  if (opts.nowMs - opts.lastChangeMs < streamHysteresisMs) return opts.current;
  return wanted;
}
