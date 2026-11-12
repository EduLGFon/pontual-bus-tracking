// Driver simulator: buses, riders, abuse scenarios, latency report.
// Uses real HTTP and WebSocket against the local or staging server.
// Abuse scenarios run against localhost only. See PLAN.md T13.
// Usage: deno task sim -- --base http://127.0.0.1:8080 --line 7 ...

interface Args {
  base: string;
  line: number;
  buses: number;
  riders: number;
  durationS: number;
  pingS: number;
  seed: number;
  abuse: boolean;
}

function parseArgs(raw: string[]): Args {
  const get = (name: string, def: string): string => {
    const i = raw.indexOf(`--${name}`);
    return i >= 0 && i + 1 < raw.length ? raw[i + 1] : def;
  };
  return {
    base: get("base", "http://127.0.0.1:8080"),
    line: Number(get("line", "7")),
    buses: Number(get("buses", "1")),
    riders: Number(get("riders", "2")),
    durationS: Number(get("duration", "90")),
    pingS: Number(get("ping", "0")),
    seed: Number(get("seed", "1")),
    abuse: raw.includes("--abuse"),
  };
}

interface Rider {
  token: string;
  role: string;
  pings: number;
  bus: number;
}

async function post(
  base: string,
  path: string,
  token: string | null,
  body: unknown,
): Promise<{ status: number; json: unknown }> {
  const headers: Record<string, string> = {
    "content-type": "application/json",
  };
  if (token) headers["authorization"] = `Bearer ${token}`;
  const res = await fetch(base + path, {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });
  let json: unknown = null;
  try {
    json = await res.json();
  } catch {
    json = null;
  }
  return { status: res.status, json };
}

async function main(): Promise<void> {
  const args = parseArgs(Deno.args);
  const isLocal = args.base.includes("127.0.0.1") ||
    args.base.includes("localhost");
  if (args.abuse && !isLocal) {
    console.error("abuse scenarios run against localhost only");
    Deno.exit(2);
  }
  const baseLat = -18.72;
  const baseLng = -39.85;

  // Viewer: subscribe to the line and record snapshots.
  let wsMsgs = 0;
  let wsSnapshots = 0;
  let lastVehicleAgeS = -1;
  const latencies: number[] = [];
  let lastPingAt = 0;
  const ws = new WebSocket(args.base.replace("http", "ws") + "/v1/stream");
  await new Promise<void>((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error("ws open timeout")), 10000);
    ws.onopen = () => {
      clearTimeout(timer);
      resolve();
    };
    ws.onerror = () => {
      clearTimeout(timer);
      reject(new Error("ws open failed"));
    };
  });
  ws.send(JSON.stringify({ op: "sub", line: args.line }));
  ws.onmessage = (ev) => {
    wsMsgs += 1;
    try {
      const msg = JSON.parse(String(ev.data)) as { v?: unknown[]; t?: number };
      if (Array.isArray(msg.v)) {
        wsSnapshots += 1;
        const ages = msg.v.map((row) => (row as number[])[6]).filter((a) =>
          typeof a === "number"
        );
        if (ages.length > 0) lastVehicleAgeS = Math.min(...ages);
        if (lastPingAt > 0) latencies.push(Date.now() - lastPingAt);
      }
    } catch {
      // Heartbeats and bye are ignored.
    }
  };

  // Riders: register, consent, start, then ping in a loop.
  const riders: Rider[] = [];
  for (let b = 0; b < args.buses; b++) {
    for (let r = 0; r < args.riders; r++) {
      const reg = await post(args.base, "/v1/devices", null, {});
      const token = (reg.json as { token?: string }).token;
      if (!token) throw new Error(`register failed: ${reg.status}`);
      await post(args.base, "/v1/consents", token, { version: 2 });
      riders.push({ token, role: "W", pings: 0, bus: b });
    }
  }

  const errors: string[] = [];
  const roleChanges: string[] = [];
  let handovers = 0;
  let resumes = 0;
  const deadline = Date.now() + args.durationS * 1000;
  const lats = riders.map(() => baseLat);
  const lngs = riders.map((_, i) =>
    baseLng + Math.floor(i / Math.max(1, args.riders)) * 0.004
  );
  const seqs = riders.map(() => 0);
  let seq = 0;
  // Buses bounce inside the city bbox so an 8-hour soak never drifts
  // out of bounds (out-of-bbox fixes strike toward an abuse end, which
  // is correct engine behavior, not soak load). Edges stay inside the
  // server bbox (lng -40.25 to -39.55) with margin.
  const dirs = riders.map(() => 1);
  const eastEdge = baseLng + 0.24;
  const westEdge = baseLng - 0.04;

  async function startRider(i: number): Promise<void> {
    const start = await post(args.base, "/v1/trip", riders[i].token, {
      line: args.line,
      lat: lats[i],
      lng: lngs[i],
      acc: 10,
      bat: 75,
      chg: false,
      synthetic: true,
    });
    if (start.status !== 201) {
      errors.push(`start failed: ${start.status}`);
    } else {
      riders[i].role = "W";
      seqs[i] = 0;
    }
  }

  for (const [i] of riders.entries()) {
    await startRider(i);
  }

  while (Date.now() < deadline) {
    for (const [i, rider] of riders.entries()) {
      seqs[i] += 1;
      seq += 1;
      // Bus cruises at ~8 m/s, bouncing inside the bbox edges.
      lngs[i] += dirs[i] * (8 * Math.max(1, args.pingS || 15)) /
        (111320 * 0.947);
      if (lngs[i] > eastEdge || lngs[i] < westEdge) dirs[i] *= -1;
      const cadence = args.pingS > 0
        ? args.pingS
        : rider.role === "L"
        ? 15
        : 20;
      void cadence;
      const res = await post(args.base, "/v1/trip/ping", rider.token, {
        seq: seqs[i],
        lat: lats[i],
        lng: lngs[i],
        spd: 8,
        hdg: dirs[i] === 1 ? 90 : 270,
        acc: 10,
        bat: 75,
        chg: false,
        role: rider.role,
      });
      rider.pings += 1;
      lastPingAt = Date.now();
      const body = res.json as { r?: string; n?: number; e?: string } | null;
      if (res.status === 200 && body && typeof body.r === "string") {
        if (body.r !== rider.role) {
          roleChanges.push(`${rider.bus}:${rider.role}->${body.r}`);
          if (body.r === "L" || rider.role === "L") handovers += 1;
          rider.role = body.r;
        }
      } else if (res.status === 404) {
        // Trip ended server-side: resume like a real client (KL6) so the
        // soak keeps constant load. Counted separately from errors.
        resumes += 1;
        await startRider(i);
      } else if (res.status !== 200) {
        errors.push(`ping ${res.status} ${JSON.stringify(body)}`);
      }
    }
    const waitS = args.pingS > 0 ? args.pingS : 5;
    await new Promise((r) =>
      setTimeout(r, Math.min(waitS * 1000, Math.max(0, deadline - Date.now())))
    );
    if (Date.now() >= deadline) break;
  }

  // Abuse scenarios against localhost only.
  if (args.abuse) {
    const reg = await post(args.base, "/v1/devices", null, {});
    const token = (reg.json as { token?: string }).token;
    if (token) {
      await post(args.base, "/v1/consents", token, { version: 2 });
      // Spoof: far fixed position next to the real buses.
      const spoof = await post(args.base, "/v1/trip", token, {
        line: args.line,
        lat: baseLat + 0.05,
        lng: baseLng + 0.05,
        acc: 10,
        bat: 100,
        chg: false,
        synthetic: true,
      });
      if (spoof.status !== 201 && spoof.status !== 422) {
        errors.push(`spoof unexpected: ${spoof.status}`);
      }
      // Burst: rapid pings must be contained, never crash the server.
      for (let i = 1; i <= 12; i++) {
        await post(args.base, "/v1/trip/ping", token, {
          seq: i,
          lat: baseLat,
          lng: baseLng,
          spd: 8,
          hdg: 90,
          acc: 10,
          bat: 100,
          chg: false,
          role: "W",
        });
      }
    }
  }

  for (const rider of riders) {
    await fetch(args.base + "/v1/trip", {
      method: "DELETE",
      headers: { authorization: `Bearer ${rider.token}` },
    });
  }
  const health = await fetch(args.base + "/v1/health").then((r) => r.json());
  ws.close();

  latencies.sort((a, b) => a - b);
  const pct = (
    p: number,
  ) => (latencies.length === 0
    ? -1
    : latencies[Math.floor((p / 100) * (latencies.length - 1))]);
  const report = {
    riders: riders.length,
    pings: riders.reduce((n, r) => n + r.pings, 0),
    roleChanges: roleChanges.length,
    handovers,
    resumes,
    wsMsgs,
    wsSnapshots,
    lastVehicleAgeS,
    latencyP50Ms: pct(50),
    latencyP95Ms: pct(95),
    serverHealthy: (health as { ok?: boolean }).ok === true,
    errors,
  };
  console.log(JSON.stringify(report, null, 2));
  if (errors.length > 0 || !(health as { ok?: boolean }).ok) Deno.exit(1);
}

await main();
