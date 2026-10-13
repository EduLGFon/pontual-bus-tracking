// Route shape bbox and early-reject behavior. Pure tests, no DB.
import { assert, assertEquals } from "@std/assert";
import {
  distToPolylineM,
  distToShapeM,
  routeShape,
} from "../src/domain/geo.ts";

const LINE = routeShape([
  { lat: -18.7, lng: -39.55 },
  { lat: -18.71, lng: -39.54 },
  { lat: -18.72, lng: -39.53 },
]);

Deno.test("routeShape wraps points with the bounding box", () => {
  assertEquals(LINE.pts.length, 3);
  assertEquals(LINE.minLat, -18.72);
  assertEquals(LINE.maxLat, -18.7);
  assertEquals(LINE.minLng, -39.55);
  assertEquals(LINE.maxLng, -39.53);
});

Deno.test("distToShapeM matches the exact scan near the route", () => {
  const lat = -18.705;
  const lng = -39.545;
  assertEquals(
    distToShapeM(lat, lng, LINE, 300),
    distToPolylineM(lat, lng, LINE.pts),
  );
});

Deno.test("distToShapeM rejects far fixes above the max", () => {
  // ~100 km away: the segment scan must be skipped, and the answer must
  // still compare above the max like the exact distance would.
  const far = distToShapeM(-19.5, -40.5, LINE, 300);
  assert(far > 300);
  assert(distToPolylineM(-19.5, -40.5, LINE.pts) > 300);
});

Deno.test("distToShapeM answers Infinity for an empty shape", () => {
  assertEquals(distToShapeM(-18.7, -39.55, routeShape([]), 300), Infinity);
});
