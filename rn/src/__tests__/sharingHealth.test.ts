import { resolveSharingHealth } from "../domain/trip/sharingHealth";

function assert(cond: boolean, msg: string) {
  if (!cond) throw new Error(msg);
}

const ended = resolveSharingHealth({
  ended: true, isStarting: false, offline: false, servicesOn: true,
  permissionGranted: true, imprecise: false, nowMs: 1000,
});
assert(ended.overall === "ended", "ended");

const offline = resolveSharingHealth({
  ended: false, isStarting: false, offline: true, servicesOn: true,
  permissionGranted: true, imprecise: false, nowMs: 1000, startedAtMs: 0, lastSuccessMs: 0,
});
assert(offline.issue === "offline", "offline issue");
