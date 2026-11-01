import { resolveSharingHealth } from "../domain/trip/sharingHealth";

describe("sharingHealth", () => {
  test("ended overall", () => {
    const ended = resolveSharingHealth({ ended: true, isStarting: false, offline: false, servicesOn: true, permissionGranted: true, imprecise: false, nowMs: 1000 });
    expect(ended.overall).toBe("ended");
  });
  test("offline issue", () => {
    const offline = resolveSharingHealth({ ended: false, isStarting: false, offline: true, servicesOn: true, permissionGranted: true, imprecise: false, nowMs: 1000, startedAtMs: 0, lastSuccessMs: 0 });
    expect(offline.issue).toBe("offline");
  });
});
