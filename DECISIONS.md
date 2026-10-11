# DECISIONS.md

Append-only record of architecture decisions (ADRs), spike results, and
deviations from PLAN.md. PLAN.md is the build contract. This file records what
was decided, why, and what is still pending.

Conventions:

- Status: `Accepted`, `Proposed`, `Pending owner`, `Superseded`.
- IDs `D01-D21` are imported from PLAN.md v1.1 section 2 and are `Accepted`
  unless noted.
- New deviations use the next `Dxx` number. Pending infra questions use
  `INFRA-xx` until the owner decides, then they become `Dxx`.
- Spikes use `S1-S4` from PLAN.md section 16.
- No em dashes in this repo. Use hyphens.
- Language: English.

## 1. Imported decisions (PLAN.md v1.1, Accepted)

These are binding per PLAN.md section 2. Summarized here so builders do not need
to re-derive them.

| ID  | Decision                                                                                                    | Why (short)                                                    |
| --- | ----------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| D01 | Use `geolocator` directly, not `smart_location`                                                             | Claimed features do not exist; wrapper is tiny and new         |
| D02 | No ping history, no location at rest                                                                        | LGPD minimization; location lives only in API memory           |
| D03 | Clients talk only to our Deno API, never to PostgreSQL                                                      | One enforcement point; stream cannot be spoofed                |
| D04 | Attach-at-ping online clustering with dead reckoning, pure TypeScript engine                                | Followers report rarely; windowed DBSCAN would split one bus   |
| D05 | Vehicle position is newest accepted fix, not centroid                                                       | Centroid of mixed-age fixes is biased backwards                |
| D06 | Role and interval returned in `ping` response; two-phase hand-over                                          | No extra connection; no gap at hand-over                       |
| D07 | Timetables are static versioned JSON, not a DB table                                                        | Zero DB load; cacheable; works offline                         |
| D08 | Server time only, no client `recorded_at`                                                                   | Client clocks are wrong or spoofable                           |
| D09 | Revised data budgets (leader <= ~0.15 MB/h, etc.)                                                           | Real HTTP header cost measured; old budget unreachable         |
| D10 | Consent (LGPD art. 7, I) for location sharing                                                               | Opt-in per trip; matches Play prominent disclosure             |
| D11 | No `ACCESS_BACKGROUND_LOCATION`; foreground service type `location` only                                    | Avoids strict Play review; more private; swipe ends trip       |
| D12 | OSM raster tiles via `flutter_map` cache, behind `TileSource` abstraction                                   | Light-use policy compliance; exit plan before Phase 2          |
| D13 | Compact JSON over WebSocket, not binary                                                                     | ~45 bytes per vehicle; binary only if spike proves gain        |
| D14 | Owner VPS with PostgreSQL, not Supabase                                                                     | Owner decision; R$0 recurring; owner operates host             |
| D15 | Read-only WebSocket stream served by API                                                                    | No client publish path; viewers need no login                  |
| D16 | Anonymous opaque device tokens (256-bit, SHA-256 hash stored, 30-day sliding expiry)                        | Small requests; instant revocation; nothing stored for viewers |
| D17 | In-process tick loop every ~5 s                                                                             | No cold starts; no scheduler quota; low map latency            |
| D18 | Hot state in memory, single instance; restart drops live state                                              | Privacy and simplicity; clients resume via `resume`            |
| D19 | Cloudflare proxy in front; Caddy at origin; Deno binds localhost; firewall accepts web only from Cloudflare | Hides origin; absorbs floods; free TLS and snapshot caching    |
| D20 | Future analytics only on de-identified aggregates; raw tracks never stored                                  | Keeps roadmap open without breaking privacy design             |
| D21 | Server libs: Hono, postgres.js, one schema lib (Valibot or Zod), dbmate                                     | Small Deno-friendly stack; each needs version ADR below        |

## 2. Infra decisions needed (Pending owner - do not guess)

Per AGENTS.md section 1 and PLAN.md section 19.2, the items below MUST be asked,
not guessed. They affect security, LGPD, persisted data, or public contracts.
Status is `Pending owner` until answered.

### 2.1 Host and database

- INFRA-01 - VPS facts. Needed: provider, region, CPU/RAM/disk, OS
  (Debian/Ubuntu LTS + version), PostgreSQL version, Postgres on same host or
  private net. PLAN prefers Brazil region for LGPD transfer simplicity and
  latency (D14, 13.7). Blocks T04, T06, T07.
- INFRA-02 - Staging instance. Needed: yes or no to a second API instance +
  separate DB/subdomain on the same VPS for simulator and field tests. PLAN
  marks staging optional. Blocks T04 and T13.
- INFRA-03 - Swap and disk encryption. Needed: what the provider offers (swap
  off or encrypted, full-disk encryption yes/no). Affects LGPD art. 46 memory
  hygiene (12.8). Blocks T04.
- INFRA-04 - SSH and admin access. Needed: admin username, SSH source
  restriction possible or not, 2FA on provider account confirmed. Blocks T04.

### 2.2 Network, TLS, Cloudflare

- INFRA-05 - Domains and DNS. Needed: API domain (proposal `api.<domain>`),
  static site domain, confirmation DNS is on Cloudflare. Until decided, use
  `*.pages.dev` and localhost only. Blocks T04, T05, T16, T20. See PLAN 19.2
  items 1 and 10.
- INFRA-06 - Cloudflare plan and features. Needed: plan name, WebSocket idle
  timeout behavior, whether free plan can cache `GET /v1/lines/{id}/vehicles`
  and `GET /v1/live` with a cache rule, current IP ranges refresh method,
  Authenticated Origin Pulls yes/no. VERIFY in S2. Blocks T04, T12.
- INFRA-07 - Origin TLS mode. Needed: Caddy automatic TLS vs Cloudflare origin
  certificate. Blocks T04.
- INFRA-08 - Caddy log policy. Needed: confirm no access logs or IP-free format
  with short retention (12.8, 13.2). Affects privacy. Blocks T04.

### 2.3 Backups, monitoring, ops

- INFRA-09 - Backup target and key holder. Needed: off-host storage location,
  who holds the `age` encryption key, confirm 30-day retention. Backups hold
  pseudonymous device rows only, no location. Blocks T04. See PLAN 19.2 item 11.
- INFRA-10 - Uptime monitor. Needed: which external service pings
  `GET /v1/health`. It receives only the health URL, no user data. Blocks T05.
  See PLAN 19.2 item 12.
- INFRA-11 - Deploy method for alpha. Needed: confirm manual deploy by owner via
  T05 script (default) vs a restricted GitHub workflow with deploy key and
  approval environment. No production server credentials in CI beyond the
  approved path. Blocks T05. See PLAN 17.2.
- INFRA-12 - Secret rotation schedule. Needed: confirm 6-month rotation for DB
  password, env file, SSH keys, tokens, plus on-suspicion rotation. Blocks T04
  runbook.

### 2.4 Server runtime pins (ADR required by D21)

Pending S2 results. One ADR each with version, licence, Deno compatibility. Do
not add other deps without ADR.

- INFRA-13 - Hono version + JSR source + licence + `Deno.upgradeWebSocket` path.
  Fallback if poor fit: bare `Deno.serve` plus ~100-line router.
- INFRA-14 - `postgres` (postgres.js) version + licence + TLS/pooling on Deno.
- INFRA-15 - Schema library: Valibot vs Zod. Needed: version, licence, Deno
  compat, bundle size irrelevance on server but API clarity. Pick one only.
- INFRA-16 - dbmate availability on target OS. VERIFY. Fallback: tiny Deno
  runner with checksums (PLAN 6.1).
- INFRA-17 - Deno version pin. Needed: latest stable at T06, pinned in
  `deno.json` and systemd unit, plus exact `--allow-net`, `--allow-env`,
  `--allow-read` flags. No `--allow-write`, `--allow-run`, `--allow-ffi`,
  `--allow-sys`.
- INFRA-18 - systemd sandbox flags. Needed: confirm full list in 12.8 works on
  target OS, esp. `MemoryDenyWriteExecute`, `LimitNOFILE` value, `LimitCORE=0`.

### 2.5 Client and release infra (blocks M0-M9)

- INFRA-19 - Code and data licences. Needed: code licence (suggest AGPL-3.0 or
  MIT) and compiled data licence (suggest CC BY 4.0 or ODbL). Current `LICENSE`
  is GPLv2 and conflicts with PLAN 19.2 item 3. Must be resolved in T01 before
  wider distribution.
- INFRA-20 - Android `applicationId` (proposal `app.pontual`), app name
  confirmation. Cannot change after first store upload. Blocks T02. See PLAN
  19.2 item 1.
- INFRA-21 - Play account path: limited-distribution (<= 20 devices, no fee) for
  Phase 0-1 vs Play Console (US$25) with early closed test. VERIFY current
  tester count and days. Blocks T48. See PLAN 19.2 item 5.
- INFRA-22 - Flutter version pin at M0 (`.fvmrc` or CI `flutter-version`) and
  `minSdk`/`targetSdk` VERIFY at release. Blocks T02.
- INFRA-23 - Controller identity and contact e-mail for policy and data-subject
  requests. Blocks T42. See PLAN 19.2 item 2.
- INFRA-24 - Pilot lines (1-3) and first route traces. Blocks T15, T17. See PLAN
  19.2 item 6.

Out of infra scope but still pending owner (PLAN 19.2): lawyer/DPO who and when,
operator outreach owner and timing, web sharing in alpha yes/no (default viewer
first), history/analytics roadmap confirm per D20.

## 3. VERIFY list (must check against official sources, record result here)

Collected from PLAN 3.2 and 19.3. Each gets a dated result entry under section 5
when its spike or task runs.

- V01 (S1): `geolocator` foreground-service with screen off 30 min, swipe-away
  behavior, `Position.isMocked`, notification action support, Android 13
  `POST_NOTIFICATIONS` flow.
- V02 (S2): Deno stable version, permission flags, Hono +
  `Deno.upgradeWebSocket`, postgres.js TLS/pooling, dbmate on target OS,
  Cloudflare WebSocket timeout, edge-cache rule, IP ranges, bytes per ping at 15
  s vs 90 s cadence.
- V03 (S3): `flutter_map` >= 8.2.0 `BuiltInMapCachingProvider` 50 MB cap API,
  OSM User-Agent and attribution, fps on low-end device.
- V04 (S4): Flutter Web `--wasm` size/startup, `--no-web-resources-cdn` flag
  name, service worker default, Screen Wake Lock on iOS PWA, COOP/COEP vs OSM
  tiles.
- V05 (release): Play foreground-service declaration, closed-test tester count
  and days, target audience and Data safety wording for location.
- V06 (legal): ANPD Res. CD/ANPD no. 2/2022 small-agent applicability, Res.
  CD/ANPD no. 15/2024 breach deadline (currently 3 business days), ECA Digital
  Lei 15.211/2025 applicability, minimum-age wording, 15-day declaration
  deadline.
- V07 (host): `MemoryDenyWriteExecute` support on target systemd, provider
  disk-encryption and swap options, `bbox` values against real municipal routes.

## 4. Spikes (S1-S4 done 2026-10-02)

- S1: geolocator foreground service. See V01. Done, findings in section 5.
- S2: Deno + Caddy + Cloudflare + postgres.js + dbmate. See V02. Done,
  findings in section 5.
- S3: flutter_map cache and perf. See V03. Done, findings in section 5.
- S4: Flutter Web wasm, PWA, wake lock. See V04. Done, findings in section 5.

Rule: run spikes before building on their assumptions (AGENTS.md section 3,
PLAN.md 0.3).

## 5. Results log (append-only, newest at bottom)

- 2026-10-02: File created. D01-D21 imported from PLAN.md v1.1 as Accepted.
  INFRA-01 to INFRA-24 opened as Pending owner. V01-V07 opened. No spikes run
  yet. No code changes yet.
- 2026-10-02: Owner answers round 1 recorded in section 6 (D22-D28). VPS
  baseline set. App name and applicationId set. Web sharing in scope. D20
  confirmed.
- 2026-10-02: T01 fix. Restored `app/` skeleton directory (was misplaced as
  `docs/app/`). Verified no `build/`, no real `.env`, no keystore, no private
  keys. `DATABASE_URL` appears only in `server/.env.example` dummy value plus
  spec text in PLAN, AGENTS, step.
- 2026-10-02: T02 done. Flutter 3.47.6 pinned via `.fvmrc` (INFRA-22 partial;
  CI pin lands in T03). `flutter create --org com.spotnik --project-name
  pontual --platforms=android,web --empty` confirms applicationId
  `com.spotnik.pontual` per D22. Added `flutter_riverpod 3.4.3` only
  (allow-list PLAN 8.2, no ADR needed). Strict analyzer per PLAN 14.2 with
  `public_member_api_docs` enabled globally. Empty `ProviderScope` app boots
  with no network on first paint. Merged-manifest audit: source has no
  location permissions; only INTERNET in debug/profile; no forbidden
  permissions. `flutter analyze` clean, `flutter test` passes.
- 2026-10-02: T03 done. CI `ci.yml` with actions pinned by SHA (checkout v4
  11d5960a, setup-java v5 b6effb05, flutter-action v2 1a449444, setup-deno v2
  22d081ff deferred, gitleaks-action v2 ff98106e; SHAs verified via
  api.github.com). Used setup-java v5, not v4, because v4 is deprecated.
  Jobs: flutter analyze, format check, test, manifest audit, web size report,
  gitleaks. Deno job deferred to T06 per PLAN. Manifest audit is source-level;
  full merged-manifest check lands in T45. Size report is non-blocking in T03:
  local `flutter build web --release` produced 40 MB uncompressed (canvaskit
  37 MB, main.dart.js 1.7 MB); compressed first-load and AAB gates land in
  T44/T45 after S4 wasm/CDN work. Local verify: analyze clean, test passes,
  audit PASS, YAML parses.
- 2026-10-02: S1 done (V01). geolocator 14.1.1 (MIT, Baseflow, Flutter
  Favorite) with geolocator_android 5.1.1+1; compatible with Flutter 3.47.6
  (needs >= 3.29.0). Foreground service via AndroidSettings
  foregroundNotificationConfig; bound service stops on swipe-away per D11, no
  ACCESS_BACKGROUND_LOCATION needed. Position.isMocked available on Android.
  No notification action button (tap opens app; RF03 fallback stands).
  POST_NOTIFICATIONS must be declared and requested separately on API 33+;
  geolocator does not request it. Plugin manifest contributes only the
  location FGS service entry; app must declare FINE/COARSE,
  FOREGROUND_SERVICE plus FOREGROUND_SERVICE_LOCATION, POST_NOTIFICATIONS.
  Remains VERIFY on device: 30 min screen-off, swipe-away, denied
  notifications, merged manifest, isMocked, Play FGS declaration.
- 2026-10-02: S2 done (V02). Deno 2.9.7 stable pinned line 2.x; flags
  --allow-net, --allow-env (scoped), --allow-read (scoped); no write, run,
  ffi, sys. Hono 4.13.12 MIT via jsr:@hono/hono, Deno.serve plus
  upgradeWebSocket from jsr:@hono/hono/deno wrapping Deno.upgradeWebSocket
  (idleTimeout default 30 s). postgres.js 3.4.9 Unlicense, TLS plus pooling
  options fit same-host PG; import specifier and TLS mode VERIFY at
  T06/T07. dbmate v2.36.0 MIT, linux amd64/arm64 assets cover VPS arches;
  install via release binary, VERIFY on VPS. Cloudflare Free supports WS,
  idle timeout unpublished (25 s heartbeat stands), Cache Rules on Free can
  edge-cache snapshot GETs, IP ranges via api.cloudflare.com/client/v4/ips,
  AOP available on Free. Ping bytes estimated 0.6 to 1.2 KB per ping; S2 gate
  0.6 KB per ping must be measured at 15 s vs 90 s on staging.
- 2026-10-02: S3 done (V03). flutter_map 8.3.2 BSD-3-Clause plus latlong2
  0.10.1 Apache-2.0; cache API BuiltInMapCachingProvider with maxCacheSize
  supports 50 MB cap, auto-enabled on non-web, no-op on web. OSM policy:
  https tile.openstreetmap.org only, real User-Agent via
  userAgentPackageName, visible attribution, no bulk download or prefetch,
  cache per headers. PLAN D12 stands with TileSource abstraction and exit
  plan before Phase 2. Remains VERIFY on device: 55 fps pan, 50 MB cap,
  first vs repeat bytes, real UA tiles, PSS memory.
- 2026-10-02: S4 done (V04). Flag is --wasm (dual wasm plus JS fallback);
  default is dart2js plus CanvasKit; --web-renderer removed. Single-threaded
  skwasm beats CanvasKit on 3.47.x; iOS browsers always get JS fallback.
  --no-web-resources-cdn self-hosts CanvasKit but not Roboto from
  fonts.gstatic.com (open issue). No Flutter service worker by default now;
  use Cache-Control and ETag. Wake Lock needs visible document and HTTPS;
  iOS standalone PWA broken before 18.4; geolocation stops when hidden per
  spec, matching KL4 foreground-only design. --wasm needs no COOP/COEP for
  single-threaded; credentialless keeps OSM tiles working. Remains VERIFY on
  staging and devices: no-CDN requests, wasm vs js bytes vs 3 MB budget,
  crossOriginIsolated, wake lock on recorded iOS versions.
- 2026-10-02: T06 done. Server skeleton with Deno 2.9.7, Hono 4.13.12 MIT via
  JSR, deno.lock committed. Config fail-fast per PLAN 6.3, Log wrapper with
  no coordinate or token API, GET /v1/health plus generic 404 and error
  handler, graceful shutdown, localhost-only metrics listener. Minimal flags:
  allow-net bind plus db, allow-env listed vars, allow-read DATA_DIR; no
  write, run, ffi, sys. Schema library (Valibot vs Zod) deferred to T08 where
  request validation lands. CI server job added with setup-deno v2 pinned.
  Local verify: deno fmt, lint, check clean; 5 tests pass; boot serves health
  and metrics; invalid env refuses to start.
- 2026-10-02: T07 done. Migration 0001 with devices, consents,
  blocked_devices, app_config plus pontual_app least-privilege grants; no
  location columns (AC22 scan passes). Repositories for devices, consents,
  blocked, plus runtime config loader with compiled defaults and
  app_config overrides. postgres.js 3.4.9 Unlicense via npm specifier.
  postgres.js scans PG* env at startup, so the test task uses broad
  --allow-env with dummy CI values; dev and start keep the scoped list.
  Local PG is postgres:16-alpine on 5433; prod PG version still VERIFY at
  T04. CI server job now runs postgres:16 service plus dbmate 2.36.0 migrate
  plus deno task test. Local verify: migrate applies to clean DB, 11 tests
  pass, fmt/lint/check clean.
- 2026-10-02: T08 done. Schema library INFRA-15 decided: Valibot 1.5.0 MIT via
  JSR, zero deps, Deno-compatible; safeParse at the boundary with strict
  objects. Middleware order per PLAN 6.9 with secure headers and exact-origin
  CORS. Token is bm1_ plus 43 base64url chars from 32 CSPRNG bytes, SHA-256
  stored, 30-day expiry, in-memory 60 s lookup cache evicted on delete.
  Routes: POST /v1/devices, POST /v1/consents (version must equal current),
  DELETE /v1/me (cascade plus evict; trip eviction lands in T10 with the
  engine). AC03 note: the device id returned at registration is by design
  per PLAN 6.5; no trip or session ids exist anywhere. Per-IP and global
  registration caps plus per-device consents and delete caps. Local verify:
  17 tests pass covering AC01, AC03, AC11, AC13, AC18, AC23; live boot
  register plus consent plus delete plus 401 paths verified via curl.
- 2026-10-02: T09 done. Pure engine per PLAN 6.6: geo helpers, validation,
  attach-at-ping with dead reckoning, election, startTrip plus applyPing
  plus endTrip, tick, snapshot builder, in-memory store. Jitter and time are
  parameters, no I/O or clock in domain. One refinement vs the literal text:
  dead-leader replacement prefers a fresh member (inside
  leader_dead_after_s) and falls back to all members, so a dead leader is
  never re-picked while a live follower waits. Engine unit tests 1-18 and
  20-24 pass (23 tests); test 19 restarts lands in T11. Full suite is 40
  tests green with fmt, lint, and check clean.
- 2026-10-02: T10 done. Trip endpoints wired to the engine: POST /v1/trip
  with line, consent, blocklist, kill-switch, quota, and capacity checks;
  POST /v1/trip/ping with jittered follower intervals; DELETE /v1/trip
  idempotent. Line registry resolves from injected data; the file loader
  lands with the T14 bundle, so production returns 404 line until then.
  Quota is consumed only by known lines. RF16 walking hint deferred to the
  client auto-end work. Local verify: 46 tests pass covering AC02, AC07,
  AC09, AC10, AC14; live register plus consent plus start plus ping plus
  delete flow verified via curl.
- 2026-10-02: T13 done. Driver simulator in tools/sim with buses, riders,
  abuse scenarios (localhost only), and a latency report over real HTTP
  plus WebSocket. Two fixes from the first runs: applyPing now emits
  vehicleUpdated so every position update broadcasts immediately (viewers
  previously waited for tick-driven changes), and dev/start tasks list the
  full PG* env set the postgres.js shim probes (scoped flags kept; the
  driver names each missing var at boot). LINES_JSON seeds lines for local
  runs until the T14 bundle lands. CI runs tools fmt/lint plus a 60 s sim
  smoke. Local verify: 90 s and 45 s runs with hand-overs observed,
  snapshots flowing, p50 latency 4 to 7 ms, no errors. The full 30-min run
  and 8-hour soak land in T46.
- 2026-10-03: T14 done. Static data pipeline: JSON Schemas for line,
  manifest, and config files; a Deno validator plus builder driven by the
  schema files with semantic checks (unique ids, codes, shorts; sorted
  unique HH:MM times; 100 KB budget) and content-hashed immutable outputs
  plus manifest plus config plus server bundle. The server loads the bundle
  from DATA_DIR with LINES_JSON as fallback. data/sources.md stubbed for
  T15. CI has a data job with fmt, lint, tool tests, validation, build,
  and a size-budget gate. Local verify: tool tests pass, empty set builds,
  bundle-backed endpoints serve live.
- 2026-10-03: T16 partial (repo side done). The data builder writes
  build/_headers from PLAN 12.5 with the API origin from the environment,
  and deploy-static.yml builds data plus web and deploys to Pages via a
  pinned wrangler-action. Still owner-blocked: Cloudflare project and DNS
  (INFRA-05, INFRA-06), API_TOKEN and ACCOUNT_ID secrets, and the
  production API_ORIGIN value. Local verify: _headers content checked,
  builder test asserts the revalidation rules, both workflows parse.
- 2026-10-03: T17 partial (tool done). Route converter in tools/route
  reads GPX tracks or GeoJSON LineString, simplifies with Douglas-Peucker
  at 5 m, and writes data/routes/<code>.geojson; the data builder encodes
  precision-5 polylines into build/routes with an 8 KB budget and wires
  the manifest routes map; the server decodes them into the route check.
  Verified on synthetic traces (300 points kept 2, 16 B polyline) with
  round-trip tests plus parser tests. Real pilot traces need owner field
  rides, so no geometry is committed.
- 2026-10-03: T15 done. All 21 urban lines seeded from onibus.online
  (retrieved 2026-10-03): 4 pilot lines (60, 62, 64, 66) with transcribed
  weekday timetables plus Sat and Sun where published, 17 names-only lines
  with pilot false. Ids are the official line numbers; the two 62 variants
  share one id until route geometry decides otherwise. Stripped itinerary
  digits and collapsed duplicate minutes are recorded in data/sources.md
  with VERIFY flags. Validator passes, bundle is 8.6 KB, trip start on a
  bundle line verified live.
- 2026-10-02: T12 done. Public reads plus stream: GET
  /v1/lines/{id}/vehicles with ETag, 304, and 5 s edge cache headers; GET
  /v1/live with 10 s headers; read-only hub with per-IP and global caps,
  128-byte and 10-per-minute message limits, and bye on shutdown. Heartbeat
  is two layers: Deno protocol ping/pong via idleTimeout 60 plus an
  app-level 25 s message for Cloudflare idle timeouts; clients ignore
  unknown keys. Fixed header order so routes override the no-store default
  with cache headers. Local verify: 63 tests pass covering AC05 (HTTP part),
  AC06 (unit plus live 101 upgrade and invalid-line close), and AC08
  (device and IP floods contained); live snapshot endpoints checked via
  curl. Full WS relay through Cloudflare stays VERIFY on staging.
- 2026-10-02: T11 done. Background jobs with overlap-guarded tick, 30 s
  config refresh, daily 03:30 Sao Paulo device purge, and 10 s db health
  probe; all timers stop on shutdown. Engine test 19 passes: fresh store
  answers gone, resume rebuilds the vehicle. Full suite is 52 tests green.
- 2026-10-03: T33 done. TripController owning the full consent to end
  lifecycle with first-fix start, ping loop, role updates, auto-end, and
  best-effort end, plus the S08 trip screen with visible-only ticker and
  S09 end cards. Fixes from testing: broadcast fix stream for the
  start-to-loop handoff, fire-and-forget stops for test zones, and
  pump-flushed starts in widget tests. Staging E2E stays owner-blocked;
  the same calls verified live against the local server on bundle data.
  Local verify: analyze clean, 82 client tests pass, manifest audit clean.
- 2026-10-03: T32 done. Ping sender with one request in flight,
  latest-wins coalescing, 5 to 60 s jittered backoff with retry of the
  latest fix, single 401 refresh plus retry, and typed server outcomes
  including auth exhaustion. Local verify: analyze clean, 78 client tests
  pass, manifest audit clean.
- 2026-10-03: T31 done. Location service with geolocator stream modes,
  foreground notification config, mock plus accuracy plus bbox plus stale
  filters, send-format rounding, and hysteresis, plus the geolocator
  permission gateway and the allow-listed manifest permissions. S1
  device criteria stay VERIFY for the T47 field test. Local verify:
  analyze clean, 73 client tests pass, manifest audit clean.
- 2026-10-03: T30 done. Consent sheet with the S06 copy, permission
  education plus denied plus blocked plus services-off sheets with a
  gateway interface for the T31 geolocator wiring, local consent
  versioning, and an offline-tolerant consent flow that never starts a
  trip uncovered. Local verify: analyze clean, 69 client tests pass,
  manifest audit clean.
- 2026-10-03: T29 done. Pure client trip domain: sealed TripState with a
  total reducer, sampling policy with 30 s hysteresis, and auto-end policy
  with priority order. Local verify: analyze clean, 62 client tests pass,
  manifest audit clean.
- 2026-10-03: T28 done. Map tab with live, stale, connecting, offline,
  and empty states, marker plus text-row vehicles, recenter button,
  non-pilot note, and route polyline support. Test lessons recorded:
  widget teardown needs pump-flushed disposal in FakeAsync, and the
  watchdog correctly heals staleness so the stale test fails its fetcher.
  Also fixed a live-with-zero-vehicles crash in the status row. Local
  verify: analyze clean, 55 client tests pass, manifest audit clean.
- 2026-10-03: T27 done. Vehicle stream repository with snapshot-first
  start, read-only socket, 45 s watchdog resync, 30 s polling fallback,
  and clean background stop, all on an injectable clock and fake channel.
  stream_channel added as an explicit test-only companion of the
  allow-listed web_socket_channel (same Dart team, no permissions).
  stop() now nulls cancelled timers so state reads clean. Local verify:
  analyze clean, 51 client tests pass, manifest audit clean.
- 2026-10-03: T26 done. Map widget with the OSM tile layer behind a
  TileSource seam, 50 MB cache cap, area bounds with zoom limits, and a
  tappable OSM attribution inside a RepaintBoundary. Unit tests avoid the
  native cache init with the disabled provider. Local verify: analyze
  clean, 45 client tests pass, manifest audit clean.
- 2026-10-03: T25 done. Timetable tab with day-type default from the
  São Mateus date, origin selector, next-departure card, dimmed past
  times, and the unofficial-data disclaimer; pure schedule helpers live
  in domain with widget tests. Two real bugs fixed along the way: the
  origin dropdown needed initialValue on current Flutter, and lines
  without any schedules crashed initState. Local verify: analyze clean,
  43 client tests pass, manifest audit clean.
- 2026-10-03: T24 done. Home screen with local search, cached line list,
  and live indicators that fill in without spinners, wired through
  Riverpod providers. Fixed asset manifest parsing to real JSON decode.
  Local verify: analyze clean, 37 client tests pass, manifest audit clean.
- 2026-10-03: T23 done. Remote flags repository with bundled defaults,
  daily refresh, and version comparison, plus S13 system screens for
  maintenance, update, and unreachable states and the S14 offline banner.
  Local verify: analyze clean, 33 client tests pass, manifest audit clean.
- 2026-10-03: T22 done. Offline-first static data repository: bundled
  assets ship in the app, cache is read before any network, manifest
  revalidates at most daily, and versioned writes swap atomically with the
  manifest pointer last. Local verify: analyze clean, 27 tests pass,
  manifest audit clean.
- 2026-10-03: T21 done. Typed API wrappers with DTOs and error mapping for
  every endpoint, fake mapping tests plus a live contract test against the
  local server. The live run caught a real client bug: DELETE requests fell
  through to GET and are now sent correctly. Local verify: analyze clean,
  21 tests pass with 1 live, manifest audit clean.
- 2026-10-03: T20 done. Client networking base: keep-alive HTTP factory
  with a web-safe conditional import, env.dart for dart-define URLs, token
  store, and BusApi registration on demand (one per install, never at
  startup). Local verify: analyze clean, 16 tests pass, manifest audit
  clean, web release build compiles.
- 2026-10-03: T19 done. Client core utilities: injectable Clock, Log ring
  buffer with no PII API, pure geo helpers, jittered backoff ladder, and
  sealed Result plus AppFailure types. Local verify: analyze clean, 12
  widget plus unit tests pass, line coverage 97.4 percent on core.
- 2026-10-03: T18 done. App foundation: Material 3 tokens from PLAN 9.2,
  pt-BR string table, go_router skeleton with all ten alpha routes as
  placeholders. The 200 percent scale test caught a real welcome-screen
  overflow; the screen scrolls now. Local verify: analyze clean, 3 widget
  tests pass, manifest audit clean (go_router adds no permissions).
- 2026-10-03: T34 done. Auto-end plus RF16 prompt plus offline saver plus
  GPS-off and permission-revoked handling. New TripSupervisor owns health
  tracking and round evaluation (polls, slow clock, silence clock,
  sampling intent); TripController applies decisions to the state machine.
  Walking prompt after 4 min slow, 3 min no-answer end; GPS off pauses and
  ends after 5 min; permission revoked ends at once; offline saver after
  3 failures or 120 s silence with heal on success; probes reuse the
  PingClient backoff (5 to 60 s plus jitter, PLAN said 30/60/120 probes;
  more frequent is bounded and recovers faster, no change needed).
  Two real bugs fixed: the start-to-loop handoff cancelled the position
  stream via onCancel (only the first fix ever flowed; removed the
  handler, stop() still owns shutdown), and LocationService.requestMode
  never recreated the stream (now it does, hysteresis kept). Server RF16
  "a" flag stays unimplemented (PLAN marks it optional); local slow
  detection covers RF16. File review: trip_controller.dart is 490 lines;
  the TripSupervisor split is taken and the rest is one lifecycle flow,
  revisit past 600 lines or on new responsibilities. Local verify:
  analyze clean, 102 client tests pass (20 new), manifest audit clean,
  no new permissions or dependencies.
- 2026-10-03: HEAD faceb05 reconciled (was unrecorded). It closes the M5
  sharing gap: `share_flow.dart` wires MapTab buttons through services check,
  consent sheet, permission education, TripController start, then navigates
  to /trip with the started controller; /trip without a controller shows the
  fallback placeholder; non-pilot lines are a no-op. Plus server hardening:
  config-refresh and purge jobs catch DB errors instead of crashing the
  process (reads stay up while the database is down), a `lines loaded`
  boot log with an empty-registry hint, and `deno task dev` reads
  `--env-file=.env`. AC impact: none beyond T33/T34 scope; no schema or
  contract change.
- 2026-10-03: T35 local part done (real phones stay owner-blocked, see T47).
  Ran against the local server on bundle data (21 lines) with an isolated
  docker PG (owner DB connection is recorded below). 90 s sim, 1 bus,
  2 riders on line 60: 36 pings, 2 role changes, 1 hand-over, 34 WS
  snapshots, last vehicle age 0 s, p50 latency 6 ms, p95 about 5 s
  (snapshot cadence), no errors. Leader-kill script: riders merged to one
  L plus one F, killing the leader promoted the follower in about 5 s
  (next ping, inside the KL1 bound), snapshot ages stayed under 20 s.
  Alpha criteria 2 and 3 hold locally. Test hygiene found: AC14 leaves
  `service_enabled=false` in the shared dev database, so later runs 503
  until app_config is cleared; the 8-hour soak (T46) must reset app_config
  first. Owner-blocked: the repo-root .env database rejects the 0001
  migration with `permission denied to create role` (restricted DB user,
  needs CREATEROLE or a one-time superuser migrate); local runs used the
  docker PG on 5433 instead.
- 2026-10-03: T36 test repairs (client suite had 2 failures from the
  unrecorded HEAD commit). (1) `trip_rig.start()` hung forever under
  testWidgets: it yielded with `Future.delayed(Duration.zero)`, a timer
  that never fires in FakeAsync without pumped time. Plain `test()` uses
  real async so it passed there. Fixed with a microtask yield, which works
  in both zones. (2) Second share-flow test went silent: `shareButton`
  read flags through the real `remoteConfigRepoProvider`, whose
  rootBundle asset load answers only the first testWidgets per file and
  never completes later (mocked channels repeat fine; engine-served
  assets do not - verified with isolated probes). Tests now override the
  provider with literal bundle JSON per the existing home_test pattern,
  so no widget test touches rootBundle or the network. No production
  change: every silent share path either shows UI or correctly aborts a
  dead screen, and no trip starts without consent. File green (5 tests),
  analyze clean.
- 2026-10-03: Late-outcome dispose guard (production fix). The rig timing
  change exposed a real crash: a ping outcome arriving after the trip
  screen is gone called notifyListeners on a disposed TripController
  (same for a resumed auto-end check). `_onOutcome` and `_checkAutoEnd`
  now ignore work after dispose via a `_disposed` flag. The previously
  failing auto-end test is the regression cover. Targeted files green,
  full suite re-running.
- 2026-10-03: T36 done. Web build config: PWA manifest rebranded to
  Pontual with the app green (#0B6E4F), deploy builds with
  `--no-web-resources-cdn --wasm` (S4: single-threaded skwasm beats
  CanvasKit; iOS keeps the JS fallback). Measured first load gzipped:
  default path about 2.9 MB (main.dart.js 870 KB plus chromium
  canvaskit.wasm 2010 KB plus fonts), wasm path about 2.6 MB; both
  inside the 3 MB budget, so no size ADR needed. CSP unchanged and
  strict (wasm-unsafe-eval already allowed; no COOP/COEP needed for
  single-threaded skwasm); Google Fonts stays blocked so web uses
  fallback fonts until the S4 font issue is resolved. Verified: full
  client suite green (107 passed), analyze clean, both builds compile.
  Owner-blocked deploy (Pages project, DNS, secrets) unchanged.
- 2026-10-03: T37 parked. Browser and on-device checks move to another
  machine (owner todo): this host has no usable browser (only a snap
  stub; flutter test needs a real Chrome) and no phones. Desktop-Chrome
  widget runs plus the shipping web build stay the verify path there.
  Viewer code itself is platform-clean (one conditional import, no
  dart:io in features).
- 2026-10-03: T39 done. One-time iOS install hint: pure
  `shouldShowInstallHint` (iOS web and unseen only), prefs-backed
  `InstallHintStore`, dismissible Safari share-sheet card slotted at
  the top of Home (no-op off iOS web). Verified: 4 new tests green,
  existing home tests green, analyze clean. Real Safari PWA check
  stays on a phone (owner todo, T47).
- 2026-10-03: T40 done. S10 Settings (theme Sistema/Claro/Escuro
  with prefs persistence via `themeModeProvider`, privacy and about
  entries, help texts, timetable build date from the manifest) plus
  S12 About (non-affiliation disclaimer, onibus.online source line,
  OSM copyright link, licence page, repo link). Contact row hidden
  while `supportEmail` is empty (INFRA-23 still owner-blocked).
  Riverpod 3 note: `StateProvider` no longer exists, theme uses a
  tiny `ThemeModeNotifier`. Verified: full suite green (124 passed),
  analyze clean, manifest audit PASS.
- 2026-10-03: T41 done. S11 privacy center: bundled short
  policy/terms (offline), 6-line collection summary per 13.2,
  `PrivacyActions` (delete-my-data with honest offline outcome,
  revoke with best-effort trip end), policy/terms text routes,
  contact hidden until INFRA-23. Support code cut per the cut
  order. Verified: AC13 end-to-end in-widget (confirm clears token
  and returns to welcome; cancel and offline keep data), full suite
  green (131 passed), analyze clean.
- 2026-10-03: T42 done (docs only, no code besides the bundled-text
  pointer). `docs/privacy/policy.md` and `terms.md` drafts (pt-BR,
  per 13.9, with [DEFINIR] markers for controller, contact,
  domains, licences), `ripd.md` (RIPD-lite with KL2 residual risk),
  `inventory.md` (processing records from 13.2). Owner-blocked:
  lawyer review, contact e-mail (INFRA-23), licences (INFRA-19
  data half), canonical URLs (INFRA-05).
- 2026-10-03: T43 done. Ran every AC test that can run on this host:
  server 67 green (first run showed 24 `TEST_DATABASE_URL is not
  set` errors, env gap only), client 131 green, fmt/lint/check and
  analyze clean, manifest source audit PASS. AC17 debug-log trip
  audit has zero hits for coordinates, tokens, or device ids. Wrote
  docs/security/review-alpha.md: no open P0/P1 in code; AC04, AC20,
  AC21 blocked on the VPS (server/deploy/ still empty, T05); AC15
  partial until the release AAB; AC16 partial until a gitleaks run
  (CI covers it per release); AC08 scale and AC06 relay need
  staging.
- 2026-10-03: T44 partial. Measured ping wire size by curl trace
  (0.62 KB per ping; leader ~0.15 MB/h at budget, follower ~0.025
  MB/h inside) and web first load (JS 2.95 MB gz inside, wasm 3.08
  MB gz ~3 % over). Wrote docs/field-tests/budgets.md. No Android
  SDK on this host so no AAB/APK size; no phones so no
  frame/RAM/CPU/battery/fps/latency numbers. All recorded as TODO
  for the capable machine.
- 2026-10-03: T45 done as far as this host allows (no Android SDK,
  so no AAB to inspect). In-tree: `allowBackup=false` on the
  application tag (AC15, token cannot clone via cloud backup),
  R8 `isMinifyEnabled` + `isShrinkResources` with stock
  `proguard-rules.pro` (rollback documented in-file), audit script
  now also fails on missing allowBackup and on cleartext, new
  `release-android.yml` (tag build with --obfuscate, merged
  manifest audit, AAB <= 15 MB gate, `gh release upload`, no new
  third-party action). Owner-blocked: upload keystore secrets,
  first tagged build plus install-launch, merged-manifest result.
- 2026-10-03: T49 done (docs only). `docs/field-tests/pilot-kit.md`
  with the 1-page pt-BR guide, known-limitations summary, and a
  copy-paste feedback form. Organizer contact still [DEFINIR]
  (INFRA-23).
- 2026-10-03: T50 done. `docs/runbooks/ops.md` covers the PLAN 18
  table plus the weekly check. Kill-switch drill executed on an
  isolated local server plus throwaway DB (soak untouched):
  pre-switch start 201, post-switch start and ping `503 maint`
  inside the 30 s refresh, reads 200 throughout, rollback to 201.
  Drill DB dropped afterwards. Next drill on the VPS after T04/T05.
- 2026-10-03: T05 files authored (repo side). `pontual.service`
  carries the 12.8 sandbox (verified structurally with
  systemd-analyze; only the VPS deno path is absent here) and
  `deploy.sh` implements tag unpack, checksum, migrate, symlink
  swap, restart, health gate, and rollback. T04 hardening steps
  drafted in `docs/runbooks/vps-hardening.md`. Owner-blocked: all
  VPS execution, upload keystore, uptime-monitor service choice
  (INFRA-10), first deploy and rollback run.
- 2026-10-03: T46 incident and restart (no code finding). The first
  8-hour soak was contaminated mid-run: a final verification
  `deno task test` against the shared dev DB truncated the sim
  device rows (`db_test` setup) and re-set `service_enabled=false`
  (AC14, known T35 hygiene gap), flipping sim pings to 401 and
  writes to `503 maint`. Fixed AC14 with a finally-block teardown
  that deletes the switch row (suite re-verified 67 green,
  app_config clean afterwards). Rule: never run the suite against
  a live soak DB. Fresh soak started 13:47 UTC (3 buses, 6 riders,
  line 60, seed 7, resource watcher on the true server PID);
  result lands here when it completes.
- 2026-10-03: T38 done. Foreground-only web sharing: `wakelock_plus`
  1.8.0 (allow-list PLAN 8.2, no ADR needed; its Android manifest adds
  no permissions, source audit still PASS) behind a `WebWakeLock` seam
  in `platform/web/` with a fake for tests; pure `WebVisibilityTracker`
  pauses sends after 60 s hidden (`webHiddenPauseMs`) and resumes on
  visible; TripController drops fixes while `isWebHidden` (server
  10-min timeout is the backstop, no explicit end needed); trip screen
  shows the always-visible PLAN banner plus brightness tip, wake-lock
  status, and hidden-paused state on web only (`kIsWeb`). Size note:
  release web build compiles; JS path 2.95 MB gz (inside budget), wasm
  path 3.08 MB gz (about 3 percent over the 3 MB RNF14 target;
  canvaskit.wasm 2.06 MB gz dominates, nearest achievable without a
  renderer change; iOS browsers take the JS path). Full client suite
  green (116 passed, 9 new), analyze clean. Browser run of the banner
  and wake lock stays on the T37 machine (owner todo).

## 6. Owner answers round 1 (2026-10-02, Accepted)

Source: owner message answering PLAN.md 19.2. Section 2 above stays as the
request history; the entries below supersede it where decided.

- D22 - Product name `Pontual`, Android `applicationId` `com.spotnik.pontual`.
  Repo name stays `pontual`. API and static domains TBD; until then use
  `*.pages.dev` for static and localhost for API. Unblocks T02 appId. See
  INFRA-05 (still pending), INFRA-20 (decided).
- D23 - Code licence stays GPLv2 (file `LICENSE` already in tree). This
  overrides the PLAN suggestion of AGPL-3.0 or MIT. Compiled data licence still
  open; default is repo licence until the owner picks CC BY 4.0 or ODbL in
  T14/T15. See INFRA-19 (code decided, data pending).
- D24 - VPS baseline: Oracle Cloud, region Sao Paulo Brazil, Ubuntu LTS (owner
  wrote 24/26; T04 must confirm exact image), 1 oCPU, 6 GB RAM, 50 GB disk,
  PostgreSQL on localhost (owner wrote 16/18; T07 must confirm exact version and
  pin it). Brazil region satisfies the LGPD preference in D14 and 13.7. See
  INFRA-01 (baseline decided, exact OS and PG versions to verify in T04/T07).
- D25 - Pilot lines: 66 (Centro / Ufes-Ifes), 62 (Guriri / Ufes-Ifes via Jacui),
  62 (Guriri / Ufes-Ifes via BR-101), 64 (Villages), 60 (Litoraneo). Notes: this
  is 5 service patterns, above the 1-3 pilot guidance in PLAN 1.5; accepted as
  the owner set. T15 must assign stable numeric ids, slugs, and shorts, and
  confirm whether both 62 variants share one line id or get separate ids. No
  route traces yet. See INFRA-24 (set decided, formalization pending in
  T15/T17).
- D26 - Web shares location in alpha. T38 stays in scope and is not cut.
  Viewer-first still applies; sharing is foreground only with wake lock and
  banner per PLAN 8.12. Cut order in PLAN 16 still applies to the rest.
- D27 - Deferred: controller identity and contact e-mail, lawyer/DPO, Play
  account path and closed-test timing, operator outreach, backup target and key
  holder, uptime monitor, Cloudflare Authenticated Origin Pulls and edge-cache
  rules (default for alpha: AOP off; S2/T12 verify WebSocket timeout and whether
  snapshot caching is used). Deploy stays manual by owner per PLAN 17.2 until
  decided otherwise. See INFRA-02, INFRA-03, INFRA-04, INFRA-06, INFRA-07,
  INFRA-08, INFRA-09, INFRA-10, INFRA-11, INFRA-12, INFRA-21, INFRA-23 (still
  pending).
- D28 - D20 roadmap confirmed: history and analytics only on de-identified
  aggregates, raw per-trip tracks never stored, consent bump plus RIPD update
  plus legal review before any such work.
- 2026-10-04: Local verification session on a browser-capable machine.
  Reverted an uncommitted `deno run -A` in `server/deno.json` back to the
  minimal scoped flags (no `--allow-all`, ever, per PLAN 12.2). Fixed the
  local boot: `server/.env` had `METRICS_PORT` on 9093 outside the
  `--allow-net` list (crash) and a `DATABASE_URL` pointing at an unreachable
  database (500 on register); 9091 plus the local PG 16 container on 5433
  boots clean with 21 lines. Full suites green: server 67/67 (after dbmate
  2.36.0 migrate), client VM 131 plus analyze clean, client
  `flutter test --platform chrome` 131 green (was 4 failures, all fixed
  below), tools data/fmt/lint clean, gitleaks 8.28.0 scan clean (325 MB,
  no leaks). E2E by hand against the local server: register, consent,
  start, W-to-L promotion, vehicle snapshot, `/v1/live`, idempotent end,
  delete-my-data with 401 after; implausible-speed pings strike into
  `abuse` end as designed. Browser smoke on the release web build:
  welcome, line-60 map with real OSM tiles plus 3 soak vehicles live,
  and settings all render with no console errors; static 404s fall back
  to bundled data per the offline-first design. 8-hour soak (3 buses,
  6 riders, line 60, seed 7) started 12:54 UTC, healthy at last check
  (3 vehicles, zero server errors); result lands here on completion.
  Production fix: release workflows built with no `--dart-define`, so the
  AAB and PWA would call localhost; both now take `vars.API_ORIGIN` and
  `vars.STATIC_ORIGIN` with fail-fast checks (owner sets real domains
  per INFRA-05). README gained a verified local end-to-end run guide.
- 2026-10-04: Chrome-only test findings (production fix in one case).
  (1) `decodePolyline` used 32-bit bitwise shifts, which corrupt large
  deltas on dart2js (test: -120.2 decoded as 42829.47; iOS browsers take
  the JS fallback so this was user-facing). Rewrote with arithmetic only
  in `app/lib/core/geo/geo.dart`, verified against the canonical vector
  on the VM and green on chrome. (2) `api_test` live contract read
  `Platform.environment`, unsupported on web: now skipped on `kIsWeb`.
  The same test hardcoded line 7 (CI seed only, 404 on real bundle):
  new `--dart-define=BUS_API_LINE=` (default 7, use 60 on bundle data),
  live-passing. (3) `app_test` welcome-to-home relied on rootBundle plus
  network, empty on chrome: now pumps with literal bundle overrides per
  the home_test pattern. (4) `map_tab_test` harness overrode
  `vehicleRepoProvider(7)` only, leaking the real networked repo for the
  id-10 non-pilot line: now overrides the pumped line id.
- 2026-10-04: WebSocket console errors from website testing analyzed and
  fixed. The `[flutter_map]` OSM warning is debug-only policy noise (we
  comply: real User-Agent, attribution, capped cache; silent in release).
  The repeated `WebSocketChannelException` came from the channel `ready`
  future: a failed connect completes it with an error that nobody
  awaited, so it escaped to the zone as an uncaught error even though
  the stream error itself was handled. The production `openChannel`
  factory now sinks `ready` errors. Same report exposed a real gap: the
  socket never reconnected after a drop (only snapshot polling
  continued), against PLAN 11.3. `VehicleRepository` now reconnects with
  5/10/20/30 s backoff plus snapshot-on-reconnect, cancelled on `stop`.
  Proven on chrome against a dead port (3 opens, contained, clean stop)
  and covered by 2 new `vehicle_test` cases. Full suites: VM analyze
  clean plus 133 green, chrome 133 green.
- 2026-10-04: T46 first 8-hour soak died at ~67 min, root-caused, restarted.
  The sim drifted buses east at 8 m/s forever, exiting the city bbox
  (lngMax -39.55) after ~0.3 deg; every out-of-bbox fix strikes, so all
  18 trips abuse-ended within minutes of each other. The engine behaved
  exactly as designed; the load driver was wrong. Fixed in `tools/sim`:
  buses bounce inside bbox-margin edges with matching headings, and the
  sim resumes on 404-gone like a real client (KL6), counting resumes
  apart from errors. 90 s smoke of the patched sim: 324 pings,
  3 hand-overs, 304 WS snapshots, p50 2 ms, p95 11 ms, zero errors.
  Fresh 8-hour soak (3 buses, 6 riders, line 60, seed 7) started ~14:20
  UTC; result lands here on completion (~22:20 UTC). Also settled the
  browser 403s in the access log: Deno sim connects clean (101), so the
  steady 403s were a browser page on a non-allow-listed origin (the
  exact case the origin check exists for); the reporter's console spam
  from that case is fixed by the ready-sink above.
- 2026-10-04: CORS preflight was missing server-side. The hand-rolled
  CORS in `server/src/http/app.ts` set ACAO on real responses but had no
  OPTIONS route, so browsers blocked every non-simple request (POST with
  JSON body, DELETE, authed calls) while plain GETs worked. Symptom on
  web: map showed "Ao vivo" (GET snapshot + WS ok once the origin was
  allow-listed) but "Estou no onibus" died silently at POST /v1/devices
  (preflight ERR_FAILED, registration never completed). Added an
  `app.options("*")` handler returning 204 with ACAO + allow-methods
  (GET, POST, DELETE, OPTIONS) + allow-headers (authorization,
  content-type) for allow-listed origins only, and extended the AC18
  test with allowed/denied preflight cases. Verified: deno fmt, lint,
  check clean; security_test.ts 6/6 green against a throwaway local DB.
  Local web must still run on `--web-port 5000` to match ALLOWED_ORIGINS.
- 2026-10-04: VPS database had no schema: POST /v1/devices failed with
  `relation "devices" does not exist` and the config refresh kept
  failing, while in-memory GETs worked. This also motivated logging the
  error text (not secrets) in the `unhandled` and `config refresh
  failed` server log lines. First `dbmate up` rolled back: the VPS user
  lacked CREATEROLE for the `pontual_app` role creation in 0001_init.
  Owner granted CREATEROLE on the VPS, reran `dbmate up` (dbmate 2.36.0):
  0001_init applied, 0 pending. Follow-up: switch server DATABASE_URL to
  least-privilege `pontual_app` per PLAN 6.4 (needs a password set
  outside migrations).
- 2026-10-04: Trip start 403 `consent` after the DB/CORS fixes, root-caused
  to stale local consent. Earlier failed runs wrote the accepted version
  to local storage before the server POST failed, and `ensureConsent`
  treated local coverage as granted without reposting, so the server
  never recorded consent and the trip guard kept rejecting. Fixed
  `app/lib/features/trip/consent_flow.dart` to reconcile the server
  record on every start (server upserts, safe to repost); truly offline
  runs still return offlinePending. Updated the covering-version test
  and added a failed-reconcile case. Full app suite: 134 green, 1 skipped.
- 2026-10-04: Owner asked that idle buses appear on watcher maps. Checked
  against PLAN.md 6.6 step 9, which deliberately never publishes a
  stopped lone trip (phantom-bus risk). Presented the trade-off; owner
  chose to keep PLAN, no engine change. Consequence for field testing:
  a share started while stationary publishes nothing until the device
  moves (moving_ticks_to_publish), and sitting still ends the trip as
  idle; validate on a moving bus outdoors.
- 2026-10-04: Consent reconcile posted on every start, burning the
  10/hour per-device consents quota during retry loops (429s in field
  testing). Switched to confirm-once: ConsentStore tracks the
  server-confirmed version separately; reconcile POSTs only while
  unconfirmed, at most one request per version once confirmed. Full app
  suite: 135 green, 1 skipped.
- 2026-10-04: Field testing needed stationary publishing: the movement
  gates (moving_speed_mps 3, moving_ticks_to_publish 2) mean a walking
  tester never creates a vehicle. Added local-only TEST_EASY_PUBLISH
  (default false): movingSpeedMps 0 + movingTicksToPublish 1, so the
  first ping publishes. Guarded by config validation, which refuses to
  start with it set unless APP_ENV=local, plus a warn log at boot.
  Production behavior unchanged. Full server suite: 68 green.
- 2026-10-04: Share flow never failed silently anymore. Added
  StartFailure reasons (declined/permission/offline/noGps/busy/
  outsideArea/failed) to TripController, a 60 s first-fix timeout
  (was an infinite hang), consent-confirmation reset on server consent
  rejects, and a pt-BR SnackBar for every dead end in share_flow
  (declines stay silent, permission keeps its sheets). Full app suite:
  142 green, 1 skipped.
- 2026-10-10: Phased share-start progress sheet. Tapping Estou no
  onibus now opens ShareProgressSheet at the register phase with 7
  rows (services, config, consent, permission, register, gps, start),
  a GPS countdown with an open-sky tip, and a collapsed Detalhes
  tecnicos block carrying phase id, error code, attempt, consent
  version, line id, and API host only (no coordinates, tokens, or
  device ids). Failures keep the sheet open with Tentar de novo
  (fresh attempt) and Fechar; Cancelar aborts via cancelStart and
  returns declined. TripController.startTrip takes an optional
  onPhase callback and never throws (unexpected transport errors map
  to offline). offlinePending still continues like granted per T30,
  so permission and GPS still run when the consent POST merely raced
  a bad network. No new dependency or permission. Full app suite:
  151 green, 1 skipped; analyze clean.
- 2026-10-10: Easy-test accuracy gates. Field report: indoor fixes are
  inside the bbox but coarser than the 60 m hard gate, so sharing
  stalls at Aguardando GPS forever (`fix dropped accuracy` in the
  console) even with TEST_EASY_PUBLISH on. The easy flag now also
  relaxes `accuracyMaxM` to 500 (logged at boot), and the client
  accepts an optional `FIX_ACCURACY_MAX_M` dart-define (default 60;
  easy-test phones set 500 in `env/phone.json`). Default behavior
  unchanged on both ends. PLAN.md 17.1 updated. Server trip suite
  green including a coarse-fix (350 m) easy-publish regression test.
- 2026-10-10: ADR: added `permission_handler` 12.0.3 for the Android
  13+ notification runtime permission (PLAN 8.2 exception clause,
  explicit owner order). Reason: the app declared POST_NOTIFICATIONS
  but never requested it at runtime, so the trip foreground-service
  notification stays hidden on Android 13+ until the user allows it
  manually in settings. Alternatives rejected: `flutter_local_
  notifications` (much heavier, only viable if local notifications
  are shown), Firebase messaging (forbidden telemetry-adjacent
  infra), hand-rolled MethodChannel (duplicates tested edge-case
  handling). Version note: 13.0.2 was tried first but its Android
  artifact requires compileSdk 37 while Flutter 3.47 pins 36
  (verified build failure on checkDebugAarMetadata); 12.0.3
  (android artifact compileSdk 35) fits the toolchain.
  Size impact: debug fat-APK proxy +2.9 MB (+1.7%, 174.9 to
  177.8 MB unoptimized); release AAB/APK unmeasurable on this
  machine (assembleRelease fails identically with and without the
  package: RAM-starved R8, pre-existing environmental issue, retry
  on a quiet machine or CI). Maintainer: baseflow.com
  (verified publisher, same family as `geolocator`), MIT licence,
  updated 2026, Flutter 3.47 toolchain.
  Manifest: injects zero permissions (verified); no new permission
  added. Use is notification-only and best-effort: one request per
  share attempt before the location education sheet, never blocks
  sharing, never throws; widget tests inject a no-op because
  platform channels have no native side under testWidgets (verified:
  even a raw unmocked channel never resolves there). Full app suite:
  155 green, 1 skipped; analyze clean.
- 2026-10-10: TEST_EASY_PUBLISH was silently ineffective. main.ts
  mutated one EngineConfig for the tick jobs while tripRoutes built
  its own default, so stationary trips stayed W forever even with the
  flag on (field report: stuck at Aguardando with live []).
  Threaded the config through instead: AppOptions/TripDeps take a
  required engine owned by main.ts, which applies the easy-publish
  mutation before serving. readRoutes keeps its own default (it only
  reads publishTtlS, untouched by the flag). Added an HTTP regression
  test proving an injected easy engine promotes a stationary trip on
  the first ping and shows it on /v1/live. Full server suite:
  69 green; fmt, lint, check clean.
- 2026-10-10: Removed the server 10-minute idle end (owner order: buses
  legitimately stand still in traffic and construction). applyPing no
  longer tracks an anchor and never emits `idle`; the Trip type and
  EngineConfig lose `anchor`, `idle_displacement_m`, `idle_end_after_s`
  (code-only keys, no migration). The `idle` end code stays recognized
  by clients but is no longer emitted. Remaining guards: movement
  gates still decide publishing (a stationary forgotten phone never
  becomes a vehicle in prod), client walking-prompt timeout ends
  unanswered stationary trips in ~7 min, server no-ping timeout
  10 min, hard cap 4 h. Test 14 is now a survival regression
  (stationary pings for 16 min, trip alive, no end). PLAN.md RF04,
  PRV03, 6.3 table, 6.6 order, outcomes, 15.2 lifecycle, T09 updated.
  Full server suite: 69 green; fmt, lint, check clean.
- 2026-10-10: Walking prompt windows lengthened (owner choice): slow
  window 4 to 15 min, unanswered-prompt timeout 3 to 5 min. A bus in a
  jam or construction stop now survives 20 min unattended; forgotten
  stationary trips still end. Tests use the constants symbolically and
  pass unchanged. PLAN.md RF16, 6.6, S08, 15.2 updated. Full app suite:
  155 green, 1 skipped; analyze clean.
- 2026-10-10: CI repair after data/flutter failures. Root causes: (1)
  tools/sim/main.ts kept an unused PRNG (`rand`/`mulberry32`) after the
  battery randomization was replaced with a constant, failing
  `deno lint` and with it the whole data job. Removed the dead code;
  the `--seed` CLI flag is still accepted but currently unused.
  (2) app manifest set `usesCleartextTraffic="true"`, failing the
  manifest audit and violating PLAN SEC06/T11/AC15 (TLS only, no
  cleartext). Removed the attribute. Consequence: physical-device
  testing against a LAN http server is OS-blocked again; use staging
  https or document another compliant path before re-adding any
  exception. (3) env/phone.json (machine LAN IP) was committed; it is
  local-only, now untracked and gitignored (kept on disk). ci.yml
  hardened: concurrency cancel-in-progress (fewer duplicate runs and
  emails), per-job timeouts, workflow_dispatch for manual reruns,
  server smoke uses `deno task start` (same flags as dev minus
  --env-file, which CI does not have; env comes from the workflow),
  failing smoke prints the server log tail, data size step echoes the
  byte count. No secrets in any CI job, triggers unchanged
  (pull_request plus master), so fork PRs run the same checks.
  Verified: tools lint/fmt/data-test/data-validate/data-build green,
  manifest audit PASS, flutter analyze and dart format clean, full app
  suite green (154 passed, 1 skipped, pre-change tree; post-change tree
  touches no Dart code). Server smoke still needs CI (no local DB).
- 2026-10-10: Static hosting moved from Cloudflare Pages to GitHub
  Pages (owner order). Why: deploy-static.yml never succeeded; the
  Cloudflare Pages project, DNS, and secrets were never created
  (step.md lists them owner-blocked), while Pages needs no new
  project or secrets, just Source: GitHub Actions plus the
  API_ORIGIN repo var. API path unchanged (still VPS behind
  Cloudflare); only the static web bundle and /data move. Workflow
  now builds data plus web, assembles pages/ (web build, data files,
  index.html copied to 404.html for go_router deep links, .nojekyll),
  and deploys via upload-pages-artifact v5.0.0 plus deploy-pages
  v5.0.1 (SHAs pinned, verified 2026-10-10). STATIC_ORIGIN defaults
  to https://<owner>.github.io/<repo> with --base-href derived from
  its path, so forks work without extra vars; only API_ORIGIN is
  required (fail-fast message tells where to set it). Accepted
  limitations: Pages cannot serve the custom `_headers` (CSP/HSTS/
  immutable-cache rules do not apply; TLS comes from Pages; the data
  tool still generates `_headers` as a draft), and COOP/COEP cannot
  be set, so `--wasm` runs single-threaded with the bootstrap JS
  fallback where isolation is absent. PLAN.md 5.2, 7.1, 12.5, 17.1,
  17.2 updated.
- 2026-10-10: release-android.yml would have failed on its first tag:
  pushing a tag does not create a GitHub release, so `gh release
  upload` had nothing to upload to. It now creates the release
  (`--generate-notes`) when missing. STATIC_ORIGIN got the same
  GitHub Pages default as deploy-static.yml, so only the API_ORIGIN
  var is required. Added a 25 min timeout. Signing story unchanged
  (debug signing until the keystore secrets exist).
- 2026-10-10: Prod API live on this VPS for the GitHub Pages build
  (owner order: same Pages URL as the workflow default, option 2, no
  bought domain). Adapted because this shell has no sudo (interactive
  auth required), so Caddy on 80/443 plus system units plus firewall
  were impossible: user systemd units `pontual-api` (Deno on
  127.0.0.1:8080, APP_ENV=prod, 21-line bundle) and `pontual-tunnel`
  (`cloudflared tunnel --url http://127.0.0.1:8080`), both enabled
  with Linger=yes. Public API_ORIGIN is the quick-tunnel hostname
  (shown at deploy time via the tunnel journal). DB needed no
  migration (0001 already applied); the API runs as least-privilege
  `pontual_app` with a fresh password in `~/pontual/prod.env` (0600)
  over 127.0.0.1 loopback instead of the public-IP URL, and
  ALLOWED_ORIGINS holds both Pages casings with TRUST_CLOUDFLARE=true.
  Verified through the public URL: health/live/vehicles 200, CORS
  preflight 204 with Pages ACAO, WS sub snapshot, full write cycle
  (register 201, consent 200, start W, ping 200, end/delete 204, test
  device removed, zero 5xx). Accepted limitations: the tunnel hostname
  is random and changes on tunnel restart, so API_ORIGIN plus a Pages
  rebuild must follow any restart; no edge cache or access rules on a
  quick tunnel; Caddy plus hardening plus stable hostname still need a
  root session plus a domain (see docs/runbooks/vps-hardening.md).
- 2026-10-10: Repo renamed to `EduLGFon/pontual-bus-tracking`, so the
  Pages URL is `https://edulgfon.github.io/pontual-bus-tracking` (the
  deploy workflow derives it at runtime, no file change needed).
  ALLOWED_ORIGINS corrected to the rename (both casings) and the local
  git remote repointed. deploy-static failed at `Resolve origins`:
  the `API_ORIGIN` repo variable is missing (likely set under Secrets
  instead of Variables). Tunnel churn confirmed live: restarting the
  API recycled the tunnel hostname, so `pontual-tunnel.service` no
  longer BindsTo the API (API restarts keep the tunnel URL now).
- 2026-10-10: Pages showed "Sem conexao" with `/v1/stream` 403s in the
  API log. Root cause: ALLOWED_ORIGINS held the full project URLs
  (`https://<owner>.github.io/<repo>`), but browsers send only scheme
  plus host as Origin (`https://edulgfon.github.io`), so every socket
  upgrade was rejected while plain GETs worked. Fixed to bare hosts
  (both casings); bare-origin preflight 204 verified through the
  tunnel. No firewall change was needed: the quick tunnel is
  outbound-only, so neither the Oracle security list nor the host
  firewall needs inbound rules for the API.
- 2026-10-10: D29 - rate-limit strikes no longer end trips (PLAN 6.6
  step 3 changed). Symptom: web trips died seconds after start with
  server `abuse` (Chrome indoors) because `PingClient.queue` sends on
  every accepted fix with no pacing to the instructed `n`, and
  geolocator-web ignores the Android interval settings, so a walking
  phone emits ~1 ping/s into `minPingIntervalS=4` rate strikes (5
  strikes = dead, proven by a 9-pings-in-7s burst in the API log).
  Android survived only because its stream honors the 20 s interval.
  Fix: too-frequent pings are now ignored without a strike; the server
  samples fast streams at ~4 s. Spoofing defense stays via
  validate/teleport strikes (AC07 unchanged) plus the 30/min
  per-device bucket. Tests: engine 25 (rapid valid pings survive) and
  26 (spaced invalid pings still abuse-end); read_test AC08 burst now
  asserts survival, which exposed a pre-existing hygiene bug (no
  truncate in read_test, so db_test's `service_enabled=false` row
  leaked 503s into it; fixed with a truncate). Verified: fmt, lint,
  check clean; full suite 71 green on a throwaway DB; prod restarted
  (tunnel URL kept) and 10 pings at 1 Hz through the public URL all
  returned 200 with no end, the trip even published (`live:[[60,1]]`,
  W to L). Remaining client work (needs the Flutter machine): pace
  sends to `n` in TripController (RF08, also fixes the data budget at
  1 Hz), and debounce the permission-revoked poll in TripSupervisor
  (Firefox died by instant `permissionRevoked` from the Permissions
  API reporting `prompt`; 3 consecutive polls before ending).
- 2026-10-10: Field-test follow-ups. (1) TEST_EASY_PUBLISH=true with
  APP_ENV=local on this host (owner order): publish on the first ping
  with the accuracy gate at 500, verified live with a stationary
  spd-0 acc-300 fix publishing at once (`live:[[60,1]]`, W to L).
  Temporary for testing; revert before any pilot (KL2: a lone
  stationary phone now draws a bus). Note: the Pages PWA still drops
  fixes coarser than 60 m client-side (FIX_ACCURACY_MAX_M not baked
  into the web build), so indoor phones also need that dart-define via
  a workflow change. (2) Client fix written here without a local
  Flutter toolchain (commit `72d51dd`): paced sends plus 3-poll
  permission debounce plus tests; CI is the verifier, then
  deploy-static republishes the PWA on merge/push. (3) WS drops on
  good wifi: infra is stable (tunnel 0 restarts, 0 errors; API
  healthy; 0 stream rejects since the origin fix). Upgrade timestamps
  cluster inside viewing sessions (~20-40 s apart while testing),
  consistent with client-side drops, but the cause needs browser
  console evidence (close codes + times) correlated with the API log.
  Next step is a console-logged repro from the phones.
- 2026-10-10: Connection review (two-reader pass, every P0 verified
  in code). Cause of the wifi drops found client-side, not in infra:
  (1) `vehicleRepoProvider` is a plain Provider.family, and MapTab
  never stops its repo, so every visited line leaks a socket plus 5 s
  watchdog plus 15 s poller plus reconnect timer; the Horarios tab
  keeps the Mapa stream alive, and even timetable-only lines opened
  sockets. Leaked repos multiply snapshot GETs into the per-IP read
  buckets and WS reconnects. (2) TripController.dispose never stopped
  the location stream, leaking GPS after leaving mid-trip. (3) A stale
  PingClient outcome could end the next trip (no generation guard).
  (4) Heartbeats were parsed and discarded, so quiet lines resynced
  pointlessly and the poller armed instantly instead of after 30 s.
  Fixed in `6ca3892` (liveness, delayed polling, guarded resync) and
  `e26d56f` (auto-dispose, dispose-stop, pilot-only streams, outcome
  generation) plus tests; CI verifies (no Flutter on this host).
  Server hardening in `f3734c8` (prune rate buckets), `589599e`
  (heartbeat backpressure, 503 capacity instead of a stillborn 101),
  `4e81e6d` (drop counters, CORS if-none-match), `2e19a1d` (guarded
  snapshot builds); full suite 74 green here, prod restarted with the
  tunnel URL kept. Deliberately deferred: per-IP read-limit raise
  (fine at alpha scale; revisit for campus NAT), ping-bucket reorder
  (paced clients have 7x headroom), WS close-tolerance (pinned by
  AC06), remoteAddr IP source (edge overwrites the header in
  practice).
- 2026-10-10: Optimization review (three tracks). Server hot path
  fixed: `guard()` went from 3 sequential PG queries per ping to a
  cached config (30 s refresh already existed, result was discarded)
  plus parallel blocked/consent checks (`6ba6b7e`); per-request stdout
  logs are debug-only (`f577d40`); line snapshots memoized for 304s
  (`93c6c50`); structured rows with no parse round-trips (`7e6f4c9`);
  direct hub iteration, Math.random jitter, capped auth cache,
  batched purge (`376f36c`). Full suite 74 green, prod restarted.
  Client (needs CI, no Flutter here): follower TLS idle 120 s,
  battery TTL, auto-end poll 30 s, map ticker 5 s, snapshot ETag with
  case-insensitive lookup, static-bundle eviction, home live refresh,
  plus back-button trip end and dispose/start guards (`46cc598`).
  Deferred with rationale: distanceFilter (would starve still
  detection and the server timeout), repo ChangeNotifier (correct
  fix for map rebuilds, but touches provider override patterns in
  tests), per-IP limit raise, ping-bucket reorder, home error UI and
  schedule virtualization (cosmetic at current sizes).

Append-only. Newest entries go at the end of each section. See AGENTS.md 14.

## D-U01-2026-10-14: UI_SPEC.md is truncated at section 13.5

`docs/ui/UI_SPEC.md` (v1.0, dated 2026-10-14) ends at section 13.5.
Sections 14 (copy deck), 15 (brand assets), 16 (implementation plan,
tasks U01 to U26), 17 (QA and measurement) and 18 (reading list) are
missing, even though sections 0 to 13 reference them.

Handling: the task plan was reconstructed from the section titles and the
work actually required by sections 0 to 13; the wireframes in section 7 are
used as the copy deck. Every deviation this forces is recorded here.
Owner action: append the missing sections, or confirm this reconstruction.

## D-U02-2026-10-14: no `NEW_UI` cutover flag, old UI removed in one change set

UI_SPEC 0.3 prescribes building the new UI next to the old one and cutting
over behind `--dart-define=NEW_UI=true` (task U24). The owner asked for the
old UI to be removed.

Handling: the flag exists and defaults to **true** (the new UI runs by
default), so the old screens stay available for review with
`--dart-define=NEW_UI=false`. When the new UI reaches parity the legacy
folders `app/lib/features/`, `app/lib/app/` and `app/lib/app/theme.dart`
are deleted in one commit rather than kept alive. Two UIs permanently is
double maintenance and violates "don't make me think" for the next agent.

## D-U03-2026-10-14: variable Manrope subset instead of five static weights

UI_SPEC 4.2 asks for one bundled subsetted typeface, candidate order
Manrope, Plus Jakarta Sans, Inter, with a variable weight axis or static
weights, tabular figures, and a 70 KB budget.

Verified (docs/ui/VERIFY-NOTES.md section 3): `FontVariation('wght', w)`
is applied by the engine on Android, CanvasKit and Skwasm, and
`FontFeature.tabularFigures()` is a const constructor. The native font
manifest ignores a pubspec `weight:` key (chinmaygarde TODO in
`font_collection.cc`), so a single variable TTF is the only shape where
the requested weight actually renders.

Result: one 51,712 byte TTF (Manrope[wght].ttf subset to Latin,
Latin-1, punctuation and arrows, `tnum` and `kern` kept), built by
`tools/build_fonts/subset_manrope.py`. Five static instances measured
145 KB, over budget. Every text style sets `fontVariations` explicitly,
so no style renders at the variable default (wght 200).

## D-U04-2026-10-14: colour token values adjusted for WCAG 2.2 AA

UI_SPEC 4.1 gives starting hex values and requires a contrast test that
fails below 4.5:1 for text and 3:1 for graphics.

Measured with the WCAG formula over every foreground/background pair used
by the UI, the starting values failed on: light `live` (2.53 on `bg`),
light `warning` (2.92 on `bg`), light `inkSubtle` on `surfaceSunken`
(4.47), light `warningText` on `surfaceSunken` (4.24), and three line
palette colours against white badge text (`#0284C7`, `#0891B2`,
`#EA580C`). The dark set passed everywhere.

Final values are in `app/lib/ui/design/tokens/colors.dart` and are asserted
by `app/test/ui/contrast_test.dart`: light `live` is now `#149B5C`,
`warning` `#CC7006`, `inkSubtle` `#5E6E69`, `warningText` `#AD5009`, and the
light line palette uses `#027CBB`, `#07819E`, `#CC4D0A` instead of the
starting three. The dark line palette is the light palette lightened so
near-black badge text reaches 4.5:1 on every fill.

## D-U05-2026-10-14: `StaticLine` gained optional fields, nothing else changed

The new UI needs terminals, area tags and the active flag, which the lines
JSON already carries. UI_SPEC 0.1 rule 2 forbids changing static-data
loading.

Handling: `StaticLine.fromJson` now also reads `terminals`, `area_tags`
and `is_active` as optional fields that default to empty and true. No
fetch, cache, swap or parsing rule changed, and the JSON schema is
untouched. The UI never reads the data repository directly: it goes through
`lib/ui/adapters/`, as the spec requires.

## D-U06-2026-10-14: `flutter build web --analyze-size` does not exist

UI_SPEC 11.4 lists it. Verified (docs/ui/VERIFY-NOTES.md section 5): the
flag does not exist in Flutter 3.47.6, the tool answers "Could not find an
option named analyze-size", and `--web-renderer` is gone as well (the
renderer is canvaskit by default for JS and skwasm for `--wasm`).

Handling: the web transfer size is measured from `build/web` after
`flutter build web --release` (`du -sb`, plus the gzip total the deploy
workflow already reports). Android size uses `flutter build apk
--analyze-size`, which does exist.

## D-U07-2026-10-14: no `NEW_UI` per-screen parity flag; no route for the timetable

UI_SPEC 6.6 lists a `/timetable/:key` route. The timetable is a tab of the
line screen in every wireframe, and a second URL for the same content
duplicates state (`?tab=` already exists on `/line/:key`).

Handling: no `/timetable/:key` route; `/line/:key?tab=horarios` is the one
URL, and it deep-links on web.

## D-U08-2026-10-14: house style for the new UI

Decisions taken while implementing sections 3 to 7 that are not covered by
the spec text:

- `CertaintyStyle` is a function `styleOf(context, certainty)` in
  `lib/ui/design/components/certainty_style.dart`, not a class with a
  static table, because colours must come from the theme extension.
- The dashed predicted pill is drawn with a `CustomPainter` path
  (`DashedOutline`) rather than a package.
- The vehicle marker glyph is the same `BusIconPainter` as the badges, so
  the icon family has one visual weight.
- `SearchField` uses `InputDecoration.collapsed` with no border
  overrides, which is the cheapest way to have no Material underline.
- Live staleness uses the data layer constant `staleAfterS = 45`, mirrored
  by `liveFreshS` in the models, so the UI never invents its own threshold.
- `Offline` is a banner, never a blocking screen (UI_SPEC 7.9), and the
  flag that drives it is a provider the data layer can fill in later.

## D-U09-2026-10-14: cutover done, old UI removed in one change set

Per the owner order the old UI is removed instead of kept behind the
`NEW_UI` flag from D-U02. The flag is gone; `main.dart` boots the new UI
directly.

Deleted screens: `features/home/home_screen.dart`,
`features/line/{line_screen,map_tab,schedule_tab}.dart`,
`features/map/map_widget.dart`, `features/settings/{settings_screen,
privacy_screen,about_screen}.dart`, `features/trip/trip_screen.dart`,
`features/system/system_screen.dart`, `app/{router,theme,strings_pt}.dart`.
Kept logic (called by the new UI through `lib/ui/adapters/` or directly):
the trip controller, supervisor, location service, ping client, consent
flow and sheets, share flow and progress, tile source, privacy actions,
policy texts, install hint, wake lock, visibility tracker, web banner, and
`app/providers.dart`.

Shared copy moved to `UiStrings`: the share-flow and progress strings, the
web trip strings, the install hint, the collection summary, the OSM
copyright URL, and the repository URL. Two legacy typos were fixed in the
move (`Buscando configuracao` to `Buscando configuração`,
`Detalhes tecnicos` to `Detalhes técnicos`); their tests were updated to
the corrected copy. The repository URL was corrected to the actual remote
(`.../pontual-bus-tracking`, not `.../pontual-bus-tracking-app`).

Tests: legacy screen tests deleted with their screens (`home_test`,
`map_tab_test`, `settings_test`, `trip_status_ui_test`, the widget parts
of `map_test` and `schedule_test`). Shared-logic tests migrated:
`app_test` and the `privacy_test` journey now walk the new UI,
`share_flow_test` runs against the new router, `trip_controller_test`
pumps the new trip screen and end cards, `trip_auto_end_test` asserts the
new end-card messages, `remote_config_test` pumps the new system screens.
The 8 pre-existing failures on the clean tree (map_tab x4, auto_end x1,
controller x2, status_ui x1) resolved as: map_tab and status_ui deleted
with their screens; auto_end and controller failures under investigation
in the migrated files.

## D-U10-2026-10-14: dock and trip attach fixes found by the new tests

- `tripVmProvider` was a static snapshot: the dock froze at attach time.
  Replaced by `LiveDockHost`, which watches `tripHostProvider` and rebuilds
  on every controller notification through `ListenableBuilder`.
- The global idle pill was missing (the shell only showed the dock for an
  active trip). The shell now always mounts the dock; line screens keep
  their contextual `LineDock` on a route outside the shell, so the two can
  never double.
- `TripRoute` wrote the provider in `initState` and read it in `dispose`,
  both forbidden by Riverpod. The notifier is captured in `initState`,
  the attach is deferred to the first frame, and the detach logic moved
  into `TripHost.detachIfIdle`, which reads only its own state.
- Widget tests must dispose trip controllers inline: `addTearDown` runs
  after the framework invariant check, so a 30 s supervision timer left
  for teardown fails the test.
- `EtaText` keeps the old child for its 140 ms switch: tests asserting a
  value is gone must pump the tap frame and then advance past the
  transition.
- `setSurfaceSize` alone does not change `MediaQuery`: tests needing a
  compact layout must also set `tester.view.physicalSize`.
- `pumpAndSettle` never returns under the shared live pulse or the trip
  hero timer; those tests pump fixed frames instead.

## D-U11-2026-10-14: three pre-existing trip test failures were test bugs

`flutter test` on the clean tree failed three controller tests. All three
were test-side assumptions invalidated by earlier production changes, not
production bugs; production code is untouched:

- `pings are paced`: the helper stamped every fix at t=100000 while the
  fake clock advanced past the 20 s freshness window, so the stale filter
  correctly dropped the fixes the test thought pacing skipped. The helper
  takes the fake now.
- `120 s offline heals`: paced sends (n:20) mean no ping is in flight when
  the hanging future completes, so nothing could heal. The test now sends
  one fresh fix after entering offline, mirroring production where fixes
  keep arriving.
- `late outcome ignored`: the shared hanging future also answered the
  second trip's own immediate ping, which legitimately ended it. The mock
  answers the second start with n:3600, so only the stale outcome arrives
  and the generation guard is actually isolated.
- Shared rig helper `pos()` accepts an optional timestamp for the same
  reason.

## D-U12-2026-10-14: stack-switch rewrite of AGENTS.md/PLAN.md reverted

During the UI build, uncommitted working-tree modifications appeared in
`AGENTS.md` and `PLAN.md` switching the client from Flutter to TypeScript
(Preact + Vite + Capacitor, PLAN v1.2). No TypeScript scaffold exists in
the tree. Per the owner order, both files were restored to the committed
Flutter versions (`git checkout HEAD -- AGENTS.md PLAN.md`) and the
Flutter UI work continues under UI_SPEC.md.

## D-U13-2026-10-14: the new consent sheet discloses, the existing flow records

The first version of `ConsentBody._accept` opened the legacy `ConsentSheet`
for show and popped with its choice, but the legacy sheet only returns a
choice: the record is written by `ensureConsent` inside the share flow.
The result was the legacy sheet opening twice (once for show, once for
record). `ConsentBody` now only discloses and pops true; the existing flow
records exactly once through its own consent call, per UI_SPEC 0.1 rule 2.

## D-U14-2026-10-14: legacy share flow suppresses its sheets for the new UI

`shareTrip` gained `legacySheets = true`. The new flow passes false, which
skips the location-off, education, denied and blocked sheets; the new flow
maps every outcome to `PermissionCard` per the UI_SPEC 7.7 matrix instead.
The notification permission request always runs. Defaults preserve the
legacy behavior byte for byte, and the legacy share-flow tests are
unchanged. The new flow also threads an injectable `ensureNotifications`
seam (mirroring `shareTrip`), because the real channel call hangs in
widget tests.

## D-U15-2026-10-14: no second dispose on the suppressed denial path

The suppressed branch disposed the controller even though the shared path
above already had. The double dispose surfaced a post-dispose notification
plus a spurious "no connection" snackbar next to the permission card. The
branch now only returns.

## D-U16-2026-10-14: release R8 needs a dontwarn for Play Core

`flutter build appbundle --release --obfuscate` (CI's exact command)
failed in `minifyReleaseWithR8` on missing
`com.google.android.play.core.*` classes, referenced only by the Flutter
engine's deferred-components manager. The failure is pre-existing and
environmental: no app change could cause it (no dependencies, Java, or
manifest entries were touched), and the app uses no deferred imports, so
those code paths are dead. `proguard-rules.pro` gains
`-dontwarn com.google.android.play.core.**` with the reason inline. The
AAB builds after it: 52.3 MB (arm64-v8a, armeabi-v7a, x86_64), the new
size baseline; the UI_SPEC delta budgets apply from here.

## D-U17-2026-10-11: UI_SPEC sections 14-18 arrived, D-U01 reconstruction retired

`docs/ui/UI_SPEC.md` now has 1746 lines with sections 14 (copy deck),
15 (brand assets), 16 (tasks U01-U26), 17 (QA and measurement) and 18
(reading list). D-U01 recorded the file as truncated at 13.5; that entry
stays as history, but the reconstruction handling is superseded: the
missing sections are now the source of truth.

Compliance pass 2026-10-11 found: copy-deck key names differ from
`UiStrings` field names (text matches under different keys, accepted, no
rename); brand web/Android assets exist except the vector source;
`docs/ui/PERF.md` was absent; one `Opacity` in `arrival_row.dart`
violated 11.2; U25/U26 future scaffolding (alerts, reliability,
predictions, ghost markers, composite sources, `localKudos`, `Saindo
agora`) is entirely absent and stays pending behind flags-off.

## D-U18-2026-10-11: brand source, perf baseline, alpha dimming by colour

- `design/brand/pontual-mark.svg` added byte-for-byte from UI_SPEC 15.
  Android adaptive + monochrome layers and web splash/manifest already
  existed; the SVG was the only missing source.
- `docs/ui/PERF.md` added (U21): new-UI baseline (web `main.dart.js`
  950 KB gz, Manrope 50.5 KB, CanvasKit 36.1 MB uncompressed, universal
  AAB 52.3 MB) with the old-UI baseline recorded as absent per AUDIT
  4.1. Device rows (cold start, frames, memory, per-ABI sizes,
  Lighthouse) stay TODO for the capable machine under the 17.4 protocol.
- `arrival_row.dart` past dimming no longer uses `Opacity` (banned by
  11.2, forces a saveLayer). `EtaText`, `LineBadge` and `CertaintyBadge`
  gained `dimmed` flags that apply 0.55 alpha to colours only, matching
  the 7.6 rule that past minutes dim by colour alpha.

## D-U19-2026-10-11: UI_SPEC sections 14-18 compliance build (U25, U26, router, copy, home, perf, a11y)

Spec sections 14-18 (copy deck, brand, U01-U26, QA) are now implemented:

- Router: unknown routes render `SystemScreen.notFound` via `errorBuilder`
  (web "Página não encontrada" per section 8); deploy already copies
  `index.html` to `404.html` for Pages deep links.
- Web scroll: `PontualScrollBehavior` drags with mouse, touch, stylus and
  trackpad (section 8).
- Edge-to-edge: transparent status and navigation bars with per-theme icon
  brightness plus `SystemUiMode.edgeToEdge` after the first frame; every
  screen keeps SafeArea (section 8).
- Copy: `tagline` ("Seu ônibus, na hora.") on About; `capacity` uses the
  exact section-14 text for the capacity error code, other limits keep the
  existing busy message (share flow failure reason stays generic because
  the frozen controller maps rate and capacity to one `busy` value).
- U25: `AlertRuleVM`, `ReliabilityVM`, `AlertsStore`, `LiveAware` and
  `Composite` arrivals sources (live wins over predicted over scheduled by
  `certaintyRank`, lower wins), `Features.localKudos`, optional
  `VehicleVM.paceFactor`, future copy (`alertTitle`, `alertSave`,
  `tabHistory`, `typicalDelayOf`, confidence levels and label, pace
  phrases, prediction title and body), `Sparkline`, `ConfidenceMeter`,
  `AlertSheet`, `ReliabilityCard` (empty hides), `PredictionInfoSheet`,
  all with unit and widget tests plus gallery entries. Flags off means
  shipped screens never mount them.
- U26: `GhostMarker` (dashed predicted style, `~` chip, no pulse) and
  `PredictedPath` (dashed polyline in caller-projected space) with a
  gallery demo covering the 13.1 rules (solid last fix with age, dashed
  ghost, path, confidence plus pace, info sheet, simulated fix flips to
  live). Real map wiring waits for route geometry like the rest of the
  route line work.
- Home `Saindo agora` feed (13.3): next arrival per shortcut target sorted
  by time, empty until a shortcut has an upcoming departure, ETA upgrades
  need no layout change.
- Perf: debug-only frame-timing logger (`summarizeBuildRaster` plus
  `installFrameTimingLogger`, hooked in the debug gallery) per 11.4.
- A11y: guideline tests over tappables and text in both themes (12.12).
  Two real findings fixed: `Segmented` is now 56 dp tall so segments reach
  the 48 dp target (was 40 with 32 dp segments), and light `scheduled`
  (`#576964`) plus `warningText` (`#9F4B07`) darkened one step so badge
  captions on the tinted pill reach 4.5:1 (rendered 4.36/4.30 before).
  Token-pair `contrast_test.dart` still green.

## D-U20-2026-10-11: map deferred import stays eager, documented

UI_SPEC 11.1 asks for a deferred map import on web. `LineMap` exposes
flutter_map types in its public API (`LatLng` route points, `MapController`
state), so deferring means splitting the widget and adding a loading state
on every platform for a library the app already ships on all of them. Web
first load sits inside the 3 MB budget with the eager import, so the
refactor buys no proven gain against real regression risk in the camera,
marker and attribution layer. Handling: keep the eager import, revisit with
measurements if the web budget regresses.

## D-U21-2026-10-11: full verification green, deploy stays owner-blocked

Verification of the sections 14-18 compliance tree (HEAD `a78320a`
plus the commits in D-U19, all on branch `dev`):

- App: `flutter analyze` clean, `dart format --set-exit-if-changed`
  clean (196 files), full `flutter test` green (261 passed, 1 skipped),
  manifest source audit PASS, `flutter build web --release` EXIT 0
  (build/web 42.7 MB uncompressed, `main.dart.js` 973,863 bytes gz, about
  951 KB, no regression vs the 950 KB PERF baseline; PLAN 3 MB budget
  holds).
- Server (unchanged code): `deno fmt --check`, `deno lint`,
  `deno check` clean; `deno task test` 74 passed against an isolated
  throwaway PG 16 container on 5433 (migrated with dbmate 2.36.0, dropped
  afterwards). Never run against a live soak DB (T46 rule).
- Tools/data: `deno fmt`, `lint`, `data-test` (3 passed), `data-validate`
  (21 lines), `data-build` (9,473 bytes, inside 100 KB) green.
- Workflows: all three YAML files parse. Gitleaks runs in CI (not
  installed on this host).
- Deploy: not executed. `deploy-static.yml` fails fast without the repo
  var `API_ORIGIN` (INFRA-05, owner-blocked) plus the Pages setup, and
  `release-android.yml` needs the upload keystore secrets plus a `v*`
  tag. Pushing `dev` to `master` without the var would only produce a
  red run, so no push was attempted. Owner actions: set `API_ORIGIN`
  (and optional `STATIC_ORIGIN`), enable Pages, merge to `master`.

## D-U22-2026-10-11: device perf method and SDK test dependency

- `integration_test` (Flutter SDK, dev-only) added to `app/pubspec.yaml`
  for the on-device run. Reason: scripted profile measurements need the
  SDK test harness. Size impact: none, dev dependencies never ship in the
  release APK/AAB (verified: split and bundle builds succeed with it
  present). Maintainer: Flutter team, BSD-3-Clause like the SDK. New
  permissions: none. A transient `flutter build apk --analyze-size`
  failure naming its plugin happened once while a wasm compile saturated
  the machine; the retry on the identical tree was green.
- Method: `app/integration_test/perf_app.dart` (measurement-only
  entrypoint, never referenced by release builds) drives Home, Lines and
  line 60 on fixed timings; `tools/perf/device_run.py` installs the
  release APK, reads cold start from the system's Displayed line (am
  start -W never settles under SwiftShader), runs the profile app,
  captures PSS and screenshots on logcat markers, and swipes the map
  during the soak. Results JSON and shots stay gitignored; medians live
  in `docs/ui/PERF.md`.
- Emulator caveats (Medium_Phone_API_37.0, x86_64, SwiftShader, no KVM):
  cold start and raster are inflated and do not count against hardware
  budgets; build times, PSS and sizes are representative.

## D-U23-2026-10-11: owner-supplied app icon applied (launcher + PWA)

The owner dropped `icon.png` (1254x1254 RGBA, rounded corners transparent),
`icon.jpeg` (1003x1003, opaque, smaller) and `icon.svg` (monochrome
auto-trace silhouette, not full colour) at the repo root and asked to apply
the icon and put each file in its right place. The PNG is the master: it is
the largest and the only one with alpha.

Sources moved to `design/brand/`: `app-icon.png` (master),
`app-icon.jpeg` (reference copy), `app-icon.svg` (trace copy). Root copies
removed. `design/brand/pontual-mark.svg` (UI_SPEC 15 mint-on-pine mark)
stays untouched; the splash, theme tokens and HTML splash keep the pine
brand, so launcher and brand now diverge and a full rebrand is an owner
decision for later.

Generated from the master with a throwaway Dart script using package:image
4.5.4 (cubic resampling, temp project outside the repo, no repo dependency
added, so no ADR needed for a package):

- Android legacy: `mipmap-mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi/ic_launcher.png`
  at 48/72/96/144/192, transparency kept.
- Android adaptive: `drawable-<dpi>/ic_launcher_foreground.png` at
  108/162/216/324/432 canvas with the artwork inset to the 72dp safe zone
  on a navy fill; `mipmap-anydpi-v26/ic_launcher.xml` and
  `ic_launcher_round.xml` use `@color/pontual_icon_bg` (`#0D3971`,
  edge-band average of the master) plus the raster foreground. The old
  mint vector `drawable/ic_launcher_foreground.xml` is deleted and the
  `<monochrome>` layer is removed: themed icons fall back to the standard
  icon until someone draws a vector monochrome of the new mark.
- Web: `icons/Icon-192.png`, `icons/Icon-512.png` (rounded corners with
  transparency kept, as in the master; first generated opaque on navy,
  then redone rounded per owner order),
  `icons/Icon-maskable-192.png`, `icons/Icon-maskable-512.png` (artwork at
  80 percent on navy, bus inside the maskable safe zone), new
  `icons/Icon-apple-touch-180.png` (180, opaque, iOS fills black on
  transparency), `favicon.png` upgraded from 16 to 32 per UI_SPEC 15
  (rounded with transparency, like the master).
  `index.html` apple-touch-icon points at the 180 file; `manifest.json`
  names are unchanged.

Verified: `file` dimensions on all 16 PNGs, visual check of the 192 web
icon, the xxxhdpi foreground (navy surround blends with the background)
and the 512 maskable, manifest source audit PASS. No Dart code touched;
no Android SDK on this host, so the merged-manifest and install-launch
check stays for the release machine (owner todo).

## D-U24-2026-10-11: Android web banner downloads the release APK

Owner order: on Android, the web PWA is viewer-only; sharing needs the
native app (screen-off trips). A one-time card on Android web
(`AndroidAppDownloadSlot` on Home after welcome plus Settings) pitches
the native app; tap downloads the latest release APK from GitHub
releases (`.../releases/latest/download/app-release.apk`).

Implementation: new `app/lib/platform/web/android_app_download.dart`
(gating pure function, prefs-backed once-only store, card, slot) plus
three pt-BR strings; no new dependency (`url_launcher` externalApplication
is already allow-listed for links). `release-android.yml` now also builds
a universal APK with the same dart-defines and uploads `app-release.apk`
alongside the AAB, with a 25 MB size gate per PLAN 10.1. Display detection
uses `kIsWeb` plus `defaultTargetPlatform == android`, same pattern as the
iOS hint.

Accepted limits: sideload needs "install unknown apps" for the browser
and, on certified devices in Brazil, a verified developer (PLAN 3.1);
first tagged release proves the asset name. Verified: analyze clean,
targeted tests green (android download, install hint, home, settings).
Full suite timed out on this host, not run to completion.
