// Static data validator and builder. The repo is the source of truth:
// humans edit data/lines/*.json, this tool validates and builds the
// deployed bundle. See PLAN.md section 7.
// Run: deno task data-validate | data-build (from tools/).

const ROOT = new URL("../../", import.meta.url);
const LINES_DIR = new URL("data/lines/", ROOT);
const SCHEMA_URL = new URL("data/schema/line.schema.json", ROOT);
const STOPS_URL = new URL("data/stops.json", ROOT);
const STOPS_SCHEMA_URL = new URL("data/schema/stops.schema.json", ROOT);
const BUILD_DIR = new URL("build/", ROOT);
const SIZE_BUDGET = 100 * 1024;
const STOPS_BUDGET = 32 * 1024;

export interface LineFile {
  path: string;
  data: Record<string, unknown>;
  bytes: number;
}

export async function readLineFiles(): Promise<LineFile[]> {
  const schema = JSON.parse(await Deno.readTextFile(SCHEMA_URL));
  const out: LineFile[] = [];
  for await (const entry of Deno.readDir(LINES_DIR)) {
    if (!entry.isFile || !entry.name.endsWith(".json")) continue;
    const url = new URL(entry.name, LINES_DIR);
    const text = await Deno.readTextFile(url);
    const bytes = new TextEncoder().encode(text).length;
    let data: unknown;
    try {
      data = JSON.parse(text);
    } catch {
      throw new Error(`${entry.name}: invalid JSON`);
    }
    checkStructure(entry.name, schema, data);
    out.push({
      path: entry.name,
      data: data as Record<string, unknown>,
      bytes,
    });
  }
  return out;
}

/** Structural check driven by the JSON Schema file (subset interpreter). */
export function checkStructure(
  name: string,
  schema: Schema,
  data: unknown,
): void {
  const fail = (why: string): never => {
    throw new Error(`${name}: ${why}`);
  };
  if (typeof data !== "object" || data === null || Array.isArray(data)) {
    fail("root must be an object");
  }
  const obj = data as Record<string, unknown>;
  for (const key of schema.required ?? []) {
    if (!(key in obj)) fail(`missing required key ${key}`);
  }
  if (schema.additionalProperties === false) {
    for (const key of Object.keys(obj)) {
      if (!(key in (schema.properties ?? {}))) fail(`unknown key ${key}`);
    }
  }
  for (const [key, prop] of Object.entries(schema.properties ?? {})) {
    if (!(key in obj)) continue;
    checkValue(`${key}`, prop, obj[key], fail);
  }
}

interface Schema {
  required?: string[];
  additionalProperties?: boolean;
  properties?: Record<string, Prop>;
}

interface Prop {
  type?: string | string[];
  const?: unknown;
  enum?: unknown[];
  pattern?: string;
  minimum?: number;
  maximum?: number;
  minLength?: number;
  maxLength?: number;
  minItems?: number;
  items?: Prop | { type: string };
}

function checkValue(
  path: string,
  prop: Prop,
  value: unknown,
  fail: (why: string) => never,
): void {
  if (prop.const !== undefined && value !== prop.const) {
    fail(`${path} must be ${JSON.stringify(prop.const)}`);
  }
  if (prop.enum && !prop.enum.includes(value)) {
    fail(`${path} has a bad enum value`);
  }
  const types = Array.isArray(prop.type)
    ? prop.type
    : prop.type
    ? [prop.type]
    : [];
  if (types.length > 0) {
    const ok = types.some((t) =>
      jsType(value) === t || (t === "integer" && isInt(value))
    );
    if (!ok) fail(`${path} has a bad type`);
  }
  if (typeof value === "string") {
    if (prop.minLength !== undefined && value.length < prop.minLength) {
      fail(`${path} is too short`);
    }
    if (prop.maxLength !== undefined && value.length > prop.maxLength) {
      fail(`${path} is too long`);
    }
    if (prop.pattern && !new RegExp(prop.pattern).test(value)) {
      fail(`${path} does not match ${prop.pattern}`);
    }
  }
  if (typeof value === "number") {
    if (prop.minimum !== undefined && value < prop.minimum) {
      fail(`${path} is too small`);
    }
    if (prop.maximum !== undefined && value > prop.maximum) {
      fail(`${path} is too large`);
    }
  }
  if (
    Array.isArray(value) && prop.minItems !== undefined &&
    value.length < prop.minItems
  ) {
    fail(`${path} needs more items`);
  }
}

function jsType(value: unknown): string {
  if (value === null) return "null";
  if (Array.isArray(value)) return "array";
  return typeof value;
}

function isInt(value: unknown): boolean {
  return typeof value === "number" && Number.isInteger(value);
}

/** Semantic checks: uniqueness, sorted times, size budget. */
export function checkSemantics(files: LineFile[]): void {
  const ids = new Set<unknown>();
  const codes = new Set<unknown>();
  const shorts = new Set<unknown>();
  let total = 0;
  for (const f of files) {
    total += f.bytes;
    const d = f.data;
    for (
      const [key, set] of [["id", ids], ["code", codes], [
        "short",
        shorts,
      ]] as const
    ) {
      if (set.has(d[key])) {
        throw new Error(`${f.path}: duplicate ${key} ${String(d[key])}`);
      }
      set.add(d[key]);
    }
    for (const s of (d["schedules"] as Record<string, unknown>[])) {
      const keys = Object.keys(s).sort();
      if (JSON.stringify(keys) !== '["day_type","origin","times"]') {
        throw new Error(`${f.path}: bad schedule keys ${keys.join(",")}`);
      }
      if (
        !["weekday", "saturday", "sunday_holiday"].includes(
          s["day_type"] as string,
        )
      ) {
        throw new Error(`${f.path}: bad day_type ${String(s["day_type"])}`);
      }
      const times = s["times"] as string[];
      for (const t of times) {
        if (!/^([01][0-9]|2[0-3]):[0-5][0-9]$/.test(t)) {
          throw new Error(`${f.path}: bad time ${t}`);
        }
      }
      const sorted = [...times].sort();
      if (times.some((t, i) => t !== sorted[i])) {
        throw new Error(`${f.path}: unsorted times for ${String(s["origin"])}`);
      }
      if (new Set(times).size !== times.length) {
        throw new Error(
          `${f.path}: duplicate times for ${String(s["origin"])}`,
        );
      }
    }
  }
  if (total > SIZE_BUDGET) {
    throw new Error(`lines exceed size budget: ${total} > ${SIZE_BUDGET}`);
  }
}

export interface StopPoint {
  id: string;
  name: string | null;
  lat: number;
  lng: number;
  src: string;
}

/** Read and validate the city bus stops. Absence means none mapped yet. */
export async function readStopsFile(): Promise<StopPoint[]> {
  let text: string;
  try {
    text = await Deno.readTextFile(STOPS_URL);
  } catch {
    return [];
  }
  let data: unknown;
  try {
    data = JSON.parse(text);
  } catch {
    throw new Error("stops.json: invalid JSON");
  }
  if (!Array.isArray(data)) {
    throw new Error("stops.json: root must be an array");
  }
  const schema = JSON.parse(await Deno.readTextFile(STOPS_SCHEMA_URL));
  const out: StopPoint[] = [];
  for (const [i, item] of data.entries()) {
    checkStructure(`stops.json[${i}]`, schema, item);
    out.push(item as StopPoint);
  }
  checkStopsSemantics(out);
  return out;
}

/** Semantic checks: unique sorted ids, served-area bbox, size budget. */
export function checkStopsSemantics(stops: StopPoint[]): void {
  const ids = new Set<string>();
  let total = 0;
  let prev = "";
  for (const s of stops) {
    if (ids.has(s.id)) throw new Error(`stops.json: duplicate id ${s.id}`);
    ids.add(s.id);
    if (s.id < prev) throw new Error("stops.json: ids must be sorted");
    prev = s.id;
    if (s.lat < -19.05 || s.lat > -18.40 || s.lng < -40.25 || s.lng > -39.55) {
      throw new Error(`stops.json: ${s.id} outside the served area`);
    }
    total += JSON.stringify(s).length;
  }
  if (total > STOPS_BUDGET) {
    throw new Error(`stops exceed size budget: ${total} > ${STOPS_BUDGET}`);
  }
}

async function sha12(text: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(text),
  );
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0"))
    .join("").slice(0, 12);
}

/** Build the deployed bundle into build/. Returns the manifest. */
export async function buildBundle(
  files: LineFile[],
  stops: StopPoint[] = [],
): Promise<Record<string, unknown>> {
  const { encodePolyline, parseGeoJson } = await import("../route/main.ts");
  const lines = files.map((f) => f.data).sort((a, b) =>
    Number(a["id"]) - Number(b["id"])
  );
  const codes = new Set(lines.map((l) => String(l["code"])));
  const linesText = JSON.stringify(lines);
  const linesHash = await sha12(linesText);
  const linesName = `lines.${linesHash}.json`;

  await Deno.mkdir(BUILD_DIR, { recursive: true });
  await Deno.mkdir(new URL("routes/", BUILD_DIR), { recursive: true });
  await Deno.writeTextFile(new URL(linesName, BUILD_DIR), linesText);

  const routes: Record<string, string> = {};
  const routesDir = new URL("../routes/", LINES_DIR);
  for await (const entry of Deno.readDir(routesDir)) {
    if (!entry.isFile || !entry.name.endsWith(".geojson")) continue;
    const code = entry.name.replace(/\.geojson$/, "");
    if (!codes.has(code)) {
      throw new Error(`route ${entry.name} matches no line`);
    }
    const points = parseGeoJson(
      await Deno.readTextFile(new URL(entry.name, routesDir)),
    );
    if (points.length > 1000) {
      throw new Error(
        `route ${code} has ${points.length} points, simplify first`,
      );
    }
    const poly = encodePolyline(points, 5);
    if (new TextEncoder().encode(poly).length > 8 * 1024) {
      throw new Error(`route ${code} polyline exceeds 8 KB`);
    }
    const hash = await sha12(poly);
    const name = `${code}.${hash}.json`;
    await Deno.writeTextFile(
      new URL(`routes/${name}`, BUILD_DIR),
      JSON.stringify({ code, polyline: poly }),
    );
    routes[code] = `routes/${name}`;
  }

  let stopsName: string | null = null;
  if (stops.length > 0) {
    const stopsText = JSON.stringify(stops);
    stopsName = `stops.${await sha12(stopsText)}.json`;
    await Deno.writeTextFile(new URL(stopsName, BUILD_DIR), stopsText);
  }

  const manifest = {
    data_version: linesHash,
    lines: linesName,
    routes,
    stops: stopsName,
    generated_at: new Date().toISOString(),
  };
  await Deno.writeTextFile(
    new URL("manifest.json", BUILD_DIR),
    JSON.stringify(manifest, null, 2),
  );

  const config = {
    min_app_version: "0.1.0",
    maintenance: false,
    message_pt: "",
    consent_version: 1,
    tile_url: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
  };
  await Deno.writeTextFile(
    new URL("config.json", BUILD_DIR),
    JSON.stringify(config, null, 2),
  );

  // Pages headers. API origin comes from the environment; production values
  // land with INFRA-05. See PLAN.md 12.5.
  const api = Deno.env.get("API_ORIGIN") ?? "https://api.localhost";
  const ws = api.replace(/^http/, "ws");
  const headers = `/*
  Content-Security-Policy: default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob: https://tile.openstreetmap.org; connect-src 'self' ${api} ${ws} https://tile.openstreetmap.org; worker-src 'self' blob:; manifest-src 'self'; object-src 'none'; base-uri 'self'; form-action 'none'; frame-ancestors 'none'
  Strict-Transport-Security: max-age=31536000; includeSubDomains
  X-Content-Type-Options: nosniff
  Referrer-Policy: no-referrer
  Permissions-Policy: geolocation=(self), camera=(), microphone=(), payment=(), usb=()
  Cross-Origin-Opener-Policy: same-origin
/data/*
  Cache-Control: public, max-age=31536000, immutable
/data/manifest.json
  Cache-Control: no-cache
/data/config.json
  Cache-Control: no-cache
`;
  await Deno.writeTextFile(new URL("_headers", BUILD_DIR), headers);
  return manifest;
}

if (import.meta.main) {
  const cmd = Deno.args[0];
  const files = await readLineFiles();
  checkSemantics(files);
  const stops = await readStopsFile();
  if (cmd === "validate") {
    console.log(`valid: ${files.length} line files, ${stops.length} stops`);
  } else if (cmd === "build") {
    const manifest = await buildBundle(files, stops);
    console.log(`built: ${JSON.stringify(manifest)}`);
  } else {
    console.error("usage: main.ts validate|build");
    Deno.exit(2);
  }
}
