import { decideMode, wantedMode, intervalSForMode } from "../domain/trip/samplingPolicy";

const base = { role: "L", speedMps: 10, offline: false, stillS: 0, paused: false };

describe("samplingPolicy", () => {
  test("upgrade to leaderMoving applies immediately", () => {
    expect(decideMode({ current: "waiting", input: base, nowMs: 1000, lastChangeMs: 999 })).toBe("leaderMoving");
  });
  test("hysteresis blocks downgrade", () => {
    expect(decideMode({ current: "leaderMoving", input: { ...base, role: "F" }, nowMs: 1000, lastChangeMs: 990 })).toBe("leaderMoving");
  });
  test("intervals and paused", () => {
    expect(intervalSForMode("leaderMoving")).toBe(5);
    expect(wantedMode({ ...base, paused: true })).toBe("paused");
  });
});
