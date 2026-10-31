import { vehicleFromRow, vehicleAgeAt } from "../data/realtime/vehicleRepository";
import { canShareLine } from "../features/trip/shareFlow";
import { WebVisibilityTracker, webShouldPause } from "../platform/web/visibility";

describe("vehicleRepository rows", () => {
  test("parses 7-field rows", () => {
    const v = vehicleFromRow([7, -18.7, -39.85, 90, 36, 2, 12]);
    expect(v).not.toBeNull();
    expect(v!.id).toBe(7);
    expect(v!.heading).toBe(90);
    expect(v!.paceKmh).toBeNull();
  });
  test("parses 8-field rows with pace", () => {
    const v = vehicleFromRow([7, -18.7, -39.85, null, 36, 2, 12, 30.5]);
    expect(v!.paceKmh).toBe(30.5);
  });
  test("rejects short rows", () => {
    expect(vehicleFromRow([1, 2])).toBeNull();
  });
  test("age advances monotonically", () => {
    expect(vehicleAgeAt({ id: 1, lat: 0, lng: 0, heading: null, kmh: 0, members: 1, ageS: 5, paceKmh: null, receivedAtMs: 1000 }, 4000)).toBe(8);
  });
});

describe("shareFlow", () => {
  test("only pilot and active lines can share", () => {
    expect(canShareLine({ pilot: true, is_active: true } as never)).toBe(true);
    expect(canShareLine({ pilot: false, is_active: true } as never)).toBe(false);
    expect(canShareLine({ pilot: true, is_active: false } as never)).toBe(false);
  });
});

describe("web visibility", () => {
  test("pauses after 60s hidden", () => {
    expect(webShouldPause(59 * 1000)).toBe(false);
    expect(webShouldPause(60 * 1000)).toBe(true);
    const t = new WebVisibilityTracker();
    t.onHidden(0);
    t.check(61 * 1000);
    expect(t.paused).toBe(true);
    expect(t.hiddenFor(61 * 1000)).toBe(61 * 1000);
    t.onVisible();
    expect(t.paused).toBe(false);
  });
});
