import { tripReduce, tripInProgress } from "../domain/trip/tripState";

function assert(cond: boolean, msg: string) {
  if (!cond) throw new Error(msg);
}

let s: any = { kind: "idle" };
s = tripReduce(s, "tapStart");
assert(s.kind === "consent", "consent");
s = tripReduce(s, "consentAccepted");
assert(s.kind === "permissions", "perms");
s = tripReduce(s, "permissionsGranted");
assert(s.kind === "starting", "starting");
s = tripReduce(s, "startConfirmed");
assert(s.kind === "active" && s.role === "waiting", "active");
assert(tripInProgress(s) === true, "in progress");
