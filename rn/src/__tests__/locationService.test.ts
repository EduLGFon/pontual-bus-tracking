import {
  acceptFix,
  batteryBucket,
  dropReason,
  normalizeHeading,
  normalizeSpeed,
  round5,
} from "../features/trip/locationService";

describe("locationService filter", () => {
  test("accepts a good fix inside the area", () => {
    expect(
      acceptFix({ lat: -18.7, lng: -39.85, accuracyM: 10, isMocked: false, timestampMs: 1000 }, 2000),
    ).toBe(true);
  });
  test("drops mocked fixes", () => {
    expect(
      dropReason({ lat: -18.7, lng: -39.85, accuracyM: 10, isMocked: true, timestampMs: 1000 }, 2000),
    ).toBe("mocked");
  });
  test("drops stale fixes", () => {
    expect(
      dropReason({ lat: -18.7, lng: -39.85, accuracyM: 10, isMocked: false, timestampMs: 0 }, 30000),
    ).toBe("stale");
  });
  test("drops inaccurate fixes", () => {
    expect(
      dropReason({ lat: -18.7, lng: -39.85, accuracyM: 999, isMocked: false, timestampMs: 1000 }, 2000),
    ).toBe("accuracy");
  });
  test("drops out-of-area fixes", () => {
    expect(
      dropReason({ lat: 0, lng: 0, accuracyM: 10, isMocked: false, timestampMs: 1000 }, 2000),
    ).toBe("outside");
  });
  test("normalizes speed and heading", () => {
    expect(normalizeSpeed(-3)).toBe(0);
    expect(normalizeSpeed(1.234)).toBe(1.2);
    expect(normalizeHeading(90, 0.1)).toBeNull();
    expect(normalizeHeading(360, 5)).toBe(0);
    expect(normalizeHeading(90, 5)).toBe(90);
  });
  test("rounds and buckets", () => {
    expect(round5(1.123456789)).toBeCloseTo(1.12346, 5);
    expect(batteryBucket(83)).toBe(80);
  });
});
