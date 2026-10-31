import { autoEndReason, walkingPromptDue, tripMaxMs } from "../domain/trip/autoEnd";

function assert(cond: boolean, msg: string) {
  if (!cond) throw new Error(msg);
}

assert(
  autoEndReason({ startedAtMs: 0, gpsOffSinceMs: 1, permissionRevoked: false, walkingPromptAtMs: null }, 10 * 60 * 1000) === "gpsOff",
  "gps off",
);
assert(
  autoEndReason({ startedAtMs: 0, gpsOffSinceMs: null, permissionRevoked: true, walkingPromptAtMs: null }, 1000) === "permissionRevoked",
  "perm",
);
assert(
  walkingPromptDue({ slowSinceMs: 0, promptAtMs: null, nowMs: 15 * 60 * 1000 }) === true,
  "walking due",
);
assert(tripMaxMs === 4 * 3600 * 1000, "max");
