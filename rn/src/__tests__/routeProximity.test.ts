import { minDistanceToPolylineM, linePassesNear } from "../core/geo/routeProximity";

function assert(cond: boolean, msg: string) {
  if (!cond) throw new Error(msg);
}

const d = minDistanceToPolylineM({ lat: 0, lng: 0 }, [{ lat: 0, lng: 0 }, { lat: 0, lng: 1 }]);
assert(Number.isFinite(d), "finite");
assert(
  linePassesNear({ place: { lat: 0, lng: 0 }, entry: { points: [{ lat: 0, lng: 0 }, { lat: 0, lng: 0.001 }], stops: [] }, routeRadiusM: 10000 }) === true,
  "passes",
);
