// Route geometry: simplify traces and encode polylines.
// Input: GPX tracks or GeoJSON LineString (field rides, never committed raw
// unless the owner approves). Output: data/routes/<code>.geojson simplified
// LineString plus encoded polyline for the app bundle. See ARCHITECTURE.md 7.4.
// Precision 5, Douglas-Peucker tolerance about 5 m.

export interface Point {
  lat: number;
  lng: number;
}

/** Parse a GPX track file into points (trkpt lat/lon only). */
export function parseGpx(text: string): Point[] {
  const pts: Point[] = [];
  const re =
    /<trkpt[^>]*lat="([^"]+)"[^>]*lon="([^"]+)"|<trkpt[^>]*lon="([^"]+)"[^>]*lat="([^"]+)"/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(text)) !== null) {
    const lat = Number(m[1] ?? m[4]);
    const lng = Number(m[2] ?? m[3]);
    if (Number.isFinite(lat) && Number.isFinite(lng)) pts.push({ lat, lng });
  }
  return pts;
}

/** Parse a GeoJSON LineString file into points. */
export function parseGeoJson(text: string): Point[] {
  const doc = JSON.parse(text) as {
    type?: string;
    geometry?: { type?: string; coordinates?: unknown };
    coordinates?: unknown;
  };
  const geom = doc.type === "Feature"
    ? (doc as unknown as {
      geometry: { type: string; coordinates: number[][] };
    }).geometry
    : { type: doc.type, coordinates: doc.coordinates as number[][] };
  if (!geom || geom.type !== "LineString" || !Array.isArray(geom.coordinates)) {
    throw new Error("expected a GeoJSON LineString");
  }
  return geom.coordinates.map(([lng, lat]) => {
    if (typeof lat !== "number" || typeof lng !== "number") {
      throw new Error("bad coordinate");
    }
    return { lat, lng };
  });
}

function perpDistM(p: Point, a: Point, b: Point): number {
  const kx = 111320 * Math.cos(((a.lat + b.lat) / 2 * Math.PI) / 180);
  const px = (p.lng - a.lng) * kx;
  const py = (p.lat - a.lat) * 111320;
  const bx = (b.lng - a.lng) * kx;
  const by = (b.lat - a.lat) * 111320;
  const len2 = bx * bx + by * by;
  let t = len2 === 0 ? 0 : (px * bx + py * by) / len2;
  t = Math.max(0, Math.min(1, t));
  return Math.hypot(px - t * bx, py - t * by);
}

/** Douglas-Peucker simplification. Keeps endpoints. */
export function simplify(points: Point[], tolM: number): Point[] {
  if (points.length <= 2) return [...points];
  const keep = new Array<boolean>(points.length).fill(false);
  keep[0] = keep[points.length - 1] = true;
  const stack: [number, number][] = [[0, points.length - 1]];
  while (stack.length > 0) {
    const [first, last] = stack.pop()!;
    let best = -1;
    let bestD = 0;
    for (let i = first + 1; i < last; i++) {
      const d = perpDistM(points[i], points[first], points[last]);
      if (d > bestD) {
        bestD = d;
        best = i;
      }
    }
    if (bestD > tolM && best >= 0) {
      keep[best] = true;
      stack.push([first, best], [best, last]);
    }
  }
  return points.filter((_, i) => keep[i]);
}

/** Encode points as a Google polyline string at the given precision. */
export function encodePolyline(points: Point[], precision = 5): string {
  const factor = 10 ** precision;
  let lastLat = 0;
  let lastLng = 0;
  let out = "";
  for (const p of points) {
    const lat = Math.round(p.lat * factor);
    const lng = Math.round(p.lng * factor);
    out += encodeInt(lat - lastLat) + encodeInt(lng - lastLng);
    lastLat = lat;
    lastLng = lng;
  }
  return out;
}

function encodeInt(n: number): string {
  let v = n < 0 ? ~(n << 1) : n << 1;
  let out = "";
  while (v >= 32) {
    out += String.fromCharCode((32 | (v & 31)) + 63);
    v >>= 5;
  }
  return out + String.fromCharCode(v + 63);
}

/** Decode a polyline (tests and the server loader use this). */
export function decodePolyline(text: string, precision = 5): Point[] {
  const factor = 10 ** precision;
  const pts: Point[] = [];
  let lat = 0;
  let lng = 0;
  let i = 0;
  while (i < text.length) {
    let shift = 0;
    let delta = 0;
    let b: number;
    do {
      b = text.charCodeAt(i++) - 63;
      delta |= (b & 31) << shift;
      shift += 5;
    } while (b >= 32);
    lat += delta & 1 ? ~(delta >> 1) : delta >> 1;
    shift = 0;
    delta = 0;
    do {
      b = text.charCodeAt(i++) - 63;
      delta |= (b & 31) << shift;
      shift += 5;
    } while (b >= 32);
    lng += delta & 1 ? ~(delta >> 1) : delta >> 1;
    pts.push({ lat: lat / factor, lng: lng / factor });
  }
  return pts;
}

/** GeoJSON LineString text for the source of truth in data/routes/. */
export function toGeoJson(points: Point[]): string {
  return JSON.stringify({
    type: "LineString",
    coordinates: points.map((p) => [p.lng, p.lat]),
  });
}

if (import.meta.main) {
  const [input, code, outDir] = Deno.args;
  if (!input || !code || !outDir) {
    console.error(
      "usage: route_main.ts <trace.gpx|trace.geojson> <code> <data/routes dir>",
    );
    Deno.exit(2);
  }
  if (!/^[a-z0-9-]{2,40}$/.test(code)) {
    console.error("bad code");
    Deno.exit(2);
  }
  const text = await Deno.readTextFile(input);
  const raw = input.endsWith(".gpx") ? parseGpx(text) : parseGeoJson(text);
  if (raw.length < 2) {
    console.error("trace has fewer than 2 points");
    Deno.exit(1);
  }
  const simple = simplify(raw, 5);
  if (simple.length > 1000) {
    console.error(`simplified trace still has ${simple.length} points`);
    Deno.exit(1);
  }
  const poly = encodePolyline(simple, 5);
  if (new TextEncoder().encode(poly).length > 8 * 1024) {
    console.error("polyline exceeds 8 KB");
    Deno.exit(1);
  }
  await Deno.mkdir(outDir, { recursive: true });
  await Deno.writeTextFile(`${outDir}/${code}.geojson`, toGeoJson(simple));
  console.log(
    `code=${code} raw=${raw.length} kept=${simple.length} polyline=${poly.length}B`,
  );
}
