import { decideMode, wantedMode, intervalSForMode } from "../domain/trip/samplingPolicy";

function assert(cond: boolean, msg: string) {
  if (!cond) throw new Error(msg);
}

const base = { role: "L", speedMps: 10, offline: false, stillS: 0, paused: false };

// upgrade applies immediately
assert(
  decideMode({ current: "waiting", input: base, nowMs: 1000, lastChangeMs: 999 }) === "leaderMoving",
  "upgrade to leaderMoving",
);
// hysteresis blocks downgrade
assert(
  decideMode({ current: "leaderMoving", input: { ...base, role: "F" }, nowMs: 1000, lastChangeMs: 990 }) === "leaderMoving",
  "hysteresis blocks downgrade",
);
assert(intervalSForMode("leaderMoving") === 5, "interval");
assert(wantedMode({ ...base, paused: true }) === "paused", "wanted paused");
