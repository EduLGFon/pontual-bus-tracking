import { minDistanceToPolylineM, linePassesNear } from "../core/geo/routeProximity";

describe("routeProximity", () => {
  test("finite distance", () => {
    const d = minDistanceToPolylineM({ lat: 0, lng: 0 }, [{ lat: 0, lng: 0 }, { lat: 0, lng: 1 }]);
    expect(Number.isFinite(d)).toBe(true);
  });
  test("line passes near", () => {
    expect(linePassesNear({ place: { lat: 0, lng: 0 }, entry: { points: [{ lat: 0, lng: 0 }, { lat: 0, lng: 0.001 }], stops: [] }, routeRadiusM: 10000 })).toBe(true);
  });
});
