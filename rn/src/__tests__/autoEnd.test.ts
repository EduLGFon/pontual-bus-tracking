import { autoEndReason, walkingPromptDue, tripMaxMs } from "../domain/trip/autoEnd";

describe("autoEnd", () => {
  test("gps off fires", () => {
    expect(autoEndReason({ startedAtMs: 0, gpsOffSinceMs: 1, permissionRevoked: false, walkingPromptAtMs: null }, 10 * 60 * 1000)).toBe("gpsOff");
  });
  test("permission revoked fires", () => {
    expect(autoEndReason({ startedAtMs: 0, gpsOffSinceMs: null, permissionRevoked: true, walkingPromptAtMs: null }, 1000)).toBe("permissionRevoked");
  });
  test("walking prompt due", () => {
    expect(walkingPromptDue({ slowSinceMs: 0, promptAtMs: null, nowMs: 15 * 60 * 1000 })).toBe(true);
  });
  test("max duration constant", () => {
    expect(tripMaxMs).toBe(4 * 3600 * 1000);
  });
});
