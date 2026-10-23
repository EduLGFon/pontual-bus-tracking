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
- S2: Deno + Caddy + Cloudflare + postgres.js + dbmate. See V02. Done, findings
  in section 5.
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
- 2026-10-02: T02 done. Flutter 3.47.6 pinned via `.fvmrc` (INFRA-22 partial; CI
  pin lands in T03).
  `flutter create --org com.spotnik --project-name
  pontual --platforms=android,web --empty`
  confirms applicationId `com.spotnik.pontual` per D22. Added
  `flutter_riverpod 3.4.3` only (allow-list PLAN 8.2, no ADR needed). Strict
  analyzer per PLAN 14.2 with `public_member_api_docs` enabled globally. Empty
  `ProviderScope` app boots with no network on first paint. Merged-manifest
  audit: source has no location permissions; only INTERNET in debug/profile; no
  forbidden permissions. `flutter analyze` clean, `flutter test` passes.
- 2026-10-02: T03 done. CI `ci.yml` with actions pinned by SHA (checkout v4
  11d5960a, setup-java v5 b6effb05, flutter-action v2 1a449444, setup-deno v2
  22d081ff deferred, gitleaks-action v2 ff98106e; SHAs verified via
  api.github.com). Used setup-java v5, not v4, because v4 is deprecated. Jobs:
  flutter analyze, format check, test, manifest audit, web size report,
  gitleaks. Deno job deferred to T06 per PLAN. Manifest audit is source-level;
  full merged-manifest check lands in T45. Size report is non-blocking in T03:
  local `flutter build web --release` produced 40 MB uncompressed (canvaskit 37
  MB, main.dart.js 1.7 MB); compressed first-load and AAB gates land in T44/T45
  after S4 wasm/CDN work. Local verify: analyze clean, test passes, audit PASS,
  YAML parses.
- 2026-10-02: S1 done (V01). geolocator 14.1.1 (MIT, Baseflow, Flutter Favorite)
  with geolocator_android 5.1.1+1; compatible with Flutter 3.47.6 (needs >=
  3.29.0). Foreground service via AndroidSettings foregroundNotificationConfig;
  bound service stops on swipe-away per D11, no ACCESS_BACKGROUND_LOCATION
  needed. Position.isMocked available on Android. No notification action button
  (tap opens app; RF03 fallback stands). POST_NOTIFICATIONS must be declared and
  requested separately on API 33+; geolocator does not request it. Plugin
  manifest contributes only the location FGS service entry; app must declare
  FINE/COARSE, FOREGROUND_SERVICE plus FOREGROUND_SERVICE_LOCATION,
  POST_NOTIFICATIONS. Remains VERIFY on device: 30 min screen-off, swipe-away,
  denied notifications, merged manifest, isMocked, Play FGS declaration.
- 2026-10-02: S2 done (V02). Deno 2.9.7 stable pinned line 2.x; flags
  --allow-net, --allow-env (scoped), --allow-read (scoped); no write, run, ffi,
  sys. Hono 4.13.12 MIT via jsr:@hono/hono, Deno.serve plus upgradeWebSocket
  from jsr:@hono/hono/deno wrapping Deno.upgradeWebSocket (idleTimeout default
  30 s). postgres.js 3.4.9 Unlicense, TLS plus pooling options fit same-host PG;
  import specifier and TLS mode VERIFY at T06/T07. dbmate v2.36.0 MIT, linux
  amd64/arm64 assets cover VPS arches; install via release binary, VERIFY on
  VPS. Cloudflare Free supports WS, idle timeout unpublished (25 s heartbeat
  stands), Cache Rules on Free can edge-cache snapshot GETs, IP ranges via
  api.cloudflare.com/client/v4/ips, AOP available on Free. Ping bytes estimated
  0.6 to 1.2 KB per ping; S2 gate 0.6 KB per ping must be measured at 15 s vs 90
  s on staging.
- 2026-10-02: S3 done (V03). flutter_map 8.3.2 BSD-3-Clause plus latlong2 0.10.1
  Apache-2.0; cache API BuiltInMapCachingProvider with maxCacheSize supports 50
  MB cap, auto-enabled on non-web, no-op on web. OSM policy: https
  tile.openstreetmap.org only, real User-Agent via userAgentPackageName, visible
  attribution, no bulk download or prefetch, cache per headers. PLAN D12 stands
  with TileSource abstraction and exit plan before Phase 2. Remains VERIFY on
  device: 55 fps pan, 50 MB cap, first vs repeat bytes, real UA tiles, PSS
  memory.
- 2026-10-02: S4 done (V04). Flag is --wasm (dual wasm plus JS fallback);
  default is dart2js plus CanvasKit; --web-renderer removed. Single-threaded
  skwasm beats CanvasKit on 3.47.x; iOS browsers always get JS fallback.
  --no-web-resources-cdn self-hosts CanvasKit but not Roboto from
  fonts.gstatic.com (open issue). No Flutter service worker by default now; use
  Cache-Control and ETag. Wake Lock needs visible document and HTTPS; iOS
  standalone PWA broken before 18.4; geolocation stops when hidden per spec,
  matching KL4 foreground-only design. --wasm needs no COOP/COEP for
  single-threaded; credentialless keeps OSM tiles working. Remains VERIFY on
  staging and devices: no-CDN requests, wasm vs js bytes vs 3 MB budget,
  crossOriginIsolated, wake lock on recorded iOS versions.
- 2026-10-02: T06 done. Server skeleton with Deno 2.9.7, Hono 4.13.12 MIT via
  JSR, deno.lock committed. Config fail-fast per PLAN 6.3, Log wrapper with no
  coordinate or token API, GET /v1/health plus generic 404 and error handler,
  graceful shutdown, localhost-only metrics listener. Minimal flags: allow-net
  bind plus db, allow-env listed vars, allow-read DATA_DIR; no write, run, ffi,
  sys. Schema library (Valibot vs Zod) deferred to T08 where request validation
  lands. CI server job added with setup-deno v2 pinned. Local verify: deno fmt,
  lint, check clean; 5 tests pass; boot serves health and metrics; invalid env
  refuses to start.
- 2026-10-02: T07 done. Migration 0001 with devices, consents, blocked_devices,
  app_config plus pontual_app least-privilege grants; no location columns (AC22
  scan passes). Repositories for devices, consents, blocked, plus runtime config
  loader with compiled defaults and app_config overrides. postgres.js 3.4.9
  Unlicense via npm specifier. postgres.js scans PG* env at startup, so the test
  task uses broad --allow-env with dummy CI values; dev and start keep the
  scoped list. Local PG is postgres:16-alpine on 5433; prod PG version still
  VERIFY at T04. CI server job now runs postgres:16 service plus dbmate 2.36.0
  migrate plus deno task test. Local verify: migrate applies to clean DB, 11
  tests pass, fmt/lint/check clean.
- 2026-10-02: T08 done. Schema library INFRA-15 decided: Valibot 1.5.0 MIT via
  JSR, zero deps, Deno-compatible; safeParse at the boundary with strict
  objects. Middleware order per PLAN 6.9 with secure headers and exact-origin
  CORS. Token is bm1_ plus 43 base64url chars from 32 CSPRNG bytes, SHA-256
  stored, 30-day expiry, in-memory 60 s lookup cache evicted on delete. Routes:
  POST /v1/devices, POST /v1/consents (version must equal current), DELETE
  /v1/me (cascade plus evict; trip eviction lands in T10 with the engine). AC03
  note: the device id returned at registration is by design per PLAN 6.5; no
  trip or session ids exist anywhere. Per-IP and global registration caps plus
  per-device consents and delete caps. Local verify: 17 tests pass covering
  AC01, AC03, AC11, AC13, AC18, AC23; live boot register plus consent plus
  delete plus 401 paths verified via curl.
- 2026-10-02: T09 done. Pure engine per PLAN 6.6: geo helpers, validation,
  attach-at-ping with dead reckoning, election, startTrip plus applyPing plus
  endTrip, tick, snapshot builder, in-memory store. Jitter and time are
  parameters, no I/O or clock in domain. One refinement vs the literal text:
  dead-leader replacement prefers a fresh member (inside leader_dead_after_s)
  and falls back to all members, so a dead leader is never re-picked while a
  live follower waits. Engine unit tests 1-18 and 20-24 pass (23 tests); test 19
  restarts lands in T11. Full suite is 40 tests green with fmt, lint, and check
  clean.
- 2026-10-02: T10 done. Trip endpoints wired to the engine: POST /v1/trip with
  line, consent, blocklist, kill-switch, quota, and capacity checks; POST
  /v1/trip/ping with jittered follower intervals; DELETE /v1/trip idempotent.
  Line registry resolves from injected data; the file loader lands with the T14
  bundle, so production returns 404 line until then. Quota is consumed only by
  known lines. RF16 walking hint deferred to the client auto-end work. Local
  verify: 46 tests pass covering AC02, AC07, AC09, AC10, AC14; live register
  plus consent plus start plus ping plus delete flow verified via curl.
- 2026-10-02: T13 done. Driver simulator in tools/sim with buses, riders, abuse
  scenarios (localhost only), and a latency report over real HTTP plus
  WebSocket. Two fixes from the first runs: applyPing now emits vehicleUpdated
  so every position update broadcasts immediately (viewers previously waited for
  tick-driven changes), and dev/start tasks list the full PG* env set the
  postgres.js shim probes (scoped flags kept; the driver names each missing var
  at boot). LINES_JSON seeds lines for local runs until the T14 bundle lands. CI
  runs tools fmt/lint plus a 60 s sim smoke. Local verify: 90 s and 45 s runs
  with hand-overs observed, snapshots flowing, p50 latency 4 to 7 ms, no errors.
  The full 30-min run and 8-hour soak land in T46.
- 2026-10-03: T14 done. Static data pipeline: JSON Schemas for line, manifest,
  and config files; a Deno validator plus builder driven by the schema files
  with semantic checks (unique ids, codes, shorts; sorted unique HH:MM times;
  100 KB budget) and content-hashed immutable outputs plus manifest plus config
  plus server bundle. The server loads the bundle from DATA_DIR with LINES_JSON
  as fallback. data/sources.md stubbed for T15. CI has a data job with fmt,
  lint, tool tests, validation, build, and a size-budget gate. Local verify:
  tool tests pass, empty set builds, bundle-backed endpoints serve live.
- 2026-10-03: T16 partial (repo side done). The data builder writes
  build/_headers from PLAN 12.5 with the API origin from the environment, and
  deploy-static.yml builds data plus web and deploys to Pages via a pinned
  wrangler-action. Still owner-blocked: Cloudflare project and DNS (INFRA-05,
  INFRA-06), API_TOKEN and ACCOUNT_ID secrets, and the production API_ORIGIN
  value. Local verify: _headers content checked, builder test asserts the
  revalidation rules, both workflows parse.
- 2026-10-03: T17 partial (tool done). Route converter in tools/route reads GPX
  tracks or GeoJSON LineString, simplifies with Douglas-Peucker at 5 m, and
  writes data/routes/<code>.geojson; the data builder encodes precision-5
  polylines into build/routes with an 8 KB budget and wires the manifest routes
  map; the server decodes them into the route check. Verified on synthetic
  traces (300 points kept 2, 16 B polyline) with round-trip tests plus parser
  tests. Real pilot traces need owner field rides, so no geometry is committed.
- 2026-10-03: T15 done. All 21 urban lines seeded from onibus.online (retrieved
  2026-10-03): 4 pilot lines (60, 62, 64, 66) with transcribed weekday
  timetables plus Sat and Sun where published, 17 names-only lines with pilot
  false. Ids are the official line numbers; the two 62 variants share one id
  until route geometry decides otherwise. Stripped itinerary digits and
  collapsed duplicate minutes are recorded in data/sources.md with VERIFY flags.
  Validator passes, bundle is 8.6 KB, trip start on a bundle line verified live.
- 2026-10-02: T12 done. Public reads plus stream: GET /v1/lines/{id}/vehicles
  with ETag, 304, and 5 s edge cache headers; GET /v1/live with 10 s headers;
  read-only hub with per-IP and global caps, 128-byte and 10-per-minute message
  limits, and bye on shutdown. Heartbeat is two layers: Deno protocol ping/pong
  via idleTimeout 60 plus an app-level 25 s message for Cloudflare idle
  timeouts; clients ignore unknown keys. Fixed header order so routes override
  the no-store default with cache headers. Local verify: 63 tests pass covering
  AC05 (HTTP part), AC06 (unit plus live 101 upgrade and invalid-line close),
  and AC08 (device and IP floods contained); live snapshot endpoints checked via
  curl. Full WS relay through Cloudflare stays VERIFY on staging.
- 2026-10-02: T11 done. Background jobs with overlap-guarded tick, 30 s config
  refresh, daily 03:30 Sao Paulo device purge, and 10 s db health probe; all
  timers stop on shutdown. Engine test 19 passes: fresh store answers gone,
  resume rebuilds the vehicle. Full suite is 52 tests green.
- 2026-10-03: T33 done. TripController owning the full consent to end lifecycle
  with first-fix start, ping loop, role updates, auto-end, and best-effort end,
  plus the S08 trip screen with visible-only ticker and S09 end cards. Fixes
  from testing: broadcast fix stream for the start-to-loop handoff,
  fire-and-forget stops for test zones, and pump-flushed starts in widget tests.
  Staging E2E stays owner-blocked; the same calls verified live against the
  local server on bundle data. Local verify: analyze clean, 82 client tests
  pass, manifest audit clean.
- 2026-10-03: T32 done. Ping sender with one request in flight, latest-wins
  coalescing, 5 to 60 s jittered backoff with retry of the latest fix, single
  401 refresh plus retry, and typed server outcomes including auth exhaustion.
  Local verify: analyze clean, 78 client tests pass, manifest audit clean.
- 2026-10-03: T31 done. Location service with geolocator stream modes,
  foreground notification config, mock plus accuracy plus bbox plus stale
  filters, send-format rounding, and hysteresis, plus the geolocator permission
  gateway and the allow-listed manifest permissions. S1 device criteria stay
  VERIFY for the T47 field test. Local verify: analyze clean, 73 client tests
  pass, manifest audit clean.
- 2026-10-03: T30 done. Consent sheet with the S06 copy, permission education
  plus denied plus blocked plus services-off sheets with a gateway interface for
  the T31 geolocator wiring, local consent versioning, and an offline-tolerant
  consent flow that never starts a trip uncovered. Local verify: analyze clean,
  69 client tests pass, manifest audit clean.
- 2026-10-03: T29 done. Pure client trip domain: sealed TripState with a total
  reducer, sampling policy with 30 s hysteresis, and auto-end policy with
  priority order. Local verify: analyze clean, 62 client tests pass, manifest
  audit clean.
- 2026-10-03: T28 done. Map tab with live, stale, connecting, offline, and empty
  states, marker plus text-row vehicles, recenter button, non-pilot note, and
  route polyline support. Test lessons recorded: widget teardown needs
  pump-flushed disposal in FakeAsync, and the watchdog correctly heals staleness
  so the stale test fails its fetcher. Also fixed a live-with-zero-vehicles
  crash in the status row. Local verify: analyze clean, 55 client tests pass,
  manifest audit clean.
- 2026-10-03: T27 done. Vehicle stream repository with snapshot-first start,
  read-only socket, 45 s watchdog resync, 30 s polling fallback, and clean
  background stop, all on an injectable clock and fake channel. stream_channel
  added as an explicit test-only companion of the allow-listed
  web_socket_channel (same Dart team, no permissions). stop() now nulls
  cancelled timers so state reads clean. Local verify: analyze clean, 51 client
  tests pass, manifest audit clean.
- 2026-10-03: T26 done. Map widget with the OSM tile layer behind a TileSource
  seam, 50 MB cache cap, area bounds with zoom limits, and a tappable OSM
  attribution inside a RepaintBoundary. Unit tests avoid the native cache init
  with the disabled provider. Local verify: analyze clean, 45 client tests pass,
  manifest audit clean.
- 2026-10-03: T25 done. Timetable tab with day-type default from the São Mateus
  date, origin selector, next-departure card, dimmed past times, and the
  unofficial-data disclaimer; pure schedule helpers live in domain with widget
  tests. Two real bugs fixed along the way: the origin dropdown needed
  initialValue on current Flutter, and lines without any schedules crashed
  initState. Local verify: analyze clean, 43 client tests pass, manifest audit
  clean.
- 2026-10-03: T24 done. Home screen with local search, cached line list, and
  live indicators that fill in without spinners, wired through Riverpod
  providers. Fixed asset manifest parsing to real JSON decode. Local verify:
  analyze clean, 37 client tests pass, manifest audit clean.
- 2026-10-03: T23 done. Remote flags repository with bundled defaults, daily
  refresh, and version comparison, plus S13 system screens for maintenance,
  update, and unreachable states and the S14 offline banner. Local verify:
  analyze clean, 33 client tests pass, manifest audit clean.
- 2026-10-03: T22 done. Offline-first static data repository: bundled assets
  ship in the app, cache is read before any network, manifest revalidates at
  most daily, and versioned writes swap atomically with the manifest pointer
  last. Local verify: analyze clean, 27 tests pass, manifest audit clean.
- 2026-10-03: T21 done. Typed API wrappers with DTOs and error mapping for every
  endpoint, fake mapping tests plus a live contract test against the local
  server. The live run caught a real client bug: DELETE requests fell through to
  GET and are now sent correctly. Local verify: analyze clean, 21 tests pass
  with 1 live, manifest audit clean.
- 2026-10-03: T20 done. Client networking base: keep-alive HTTP factory with a
  web-safe conditional import, env.dart for dart-define URLs, token store, and
  BusApi registration on demand (one per install, never at startup). Local
  verify: analyze clean, 16 tests pass, manifest audit clean, web release build
  compiles.
- 2026-10-03: T19 done. Client core utilities: injectable Clock, Log ring buffer
  with no PII API, pure geo helpers, jittered backoff ladder, and sealed Result
  plus AppFailure types. Local verify: analyze clean, 12 widget plus unit tests
  pass, line coverage 97.4 percent on core.
- 2026-10-03: T18 done. App foundation: Material 3 tokens from PLAN 9.2, pt-BR
  string table, go_router skeleton with all ten alpha routes as placeholders.
  The 200 percent scale test caught a real welcome-screen overflow; the screen
  scrolls now. Local verify: analyze clean, 3 widget tests pass, manifest audit
  clean (go_router adds no permissions).
- 2026-10-03: T34 done. Auto-end plus RF16 prompt plus offline saver plus
  GPS-off and permission-revoked handling. New TripSupervisor owns health
  tracking and round evaluation (polls, slow clock, silence clock, sampling
  intent); TripController applies decisions to the state machine. Walking prompt
  after 4 min slow, 3 min no-answer end; GPS off pauses and ends after 5 min;
  permission revoked ends at once; offline saver after 3 failures or 120 s
  silence with heal on success; probes reuse the PingClient backoff (5 to 60 s
  plus jitter, PLAN said 30/60/120 probes; more frequent is bounded and recovers
  faster, no change needed). Two real bugs fixed: the start-to-loop handoff
  cancelled the position stream via onCancel (only the first fix ever flowed;
  removed the handler, stop() still owns shutdown), and
  LocationService.requestMode never recreated the stream (now it does,
  hysteresis kept). Server RF16 "a" flag stays unimplemented (PLAN marks it
  optional); local slow detection covers RF16. File review: trip_controller.dart
  is 490 lines; the TripSupervisor split is taken and the rest is one lifecycle
  flow, revisit past 600 lines or on new responsibilities. Local verify: analyze
  clean, 102 client tests pass (20 new), manifest audit clean, no new
  permissions or dependencies.
- 2026-10-03: HEAD faceb05 reconciled (was unrecorded). It closes the M5 sharing
  gap: `share_flow.dart` wires MapTab buttons through services check, consent
  sheet, permission education, TripController start, then navigates to /trip
  with the started controller; /trip without a controller shows the fallback
  placeholder; non-pilot lines are a no-op. Plus server hardening:
  config-refresh and purge jobs catch DB errors instead of crashing the process
  (reads stay up while the database is down), a `lines loaded` boot log with an
  empty-registry hint, and `deno task dev` reads `--env-file=.env`. AC impact:
  none beyond T33/T34 scope; no schema or contract change.
- 2026-10-03: T35 local part done (real phones stay owner-blocked, see T47). Ran
  against the local server on bundle data (21 lines) with an isolated docker PG
  (owner DB connection is recorded below). 90 s sim, 1 bus, 2 riders on line 60:
  36 pings, 2 role changes, 1 hand-over, 34 WS snapshots, last vehicle age 0 s,
  p50 latency 6 ms, p95 about 5 s (snapshot cadence), no errors. Leader-kill
  script: riders merged to one L plus one F, killing the leader promoted the
  follower in about 5 s (next ping, inside the KL1 bound), snapshot ages stayed
  under 20 s. Alpha criteria 2 and 3 hold locally. Test hygiene found: AC14
  leaves `service_enabled=false` in the shared dev database, so later runs 503
  until app_config is cleared; the 8-hour soak (T46) must reset app_config
  first. Owner-blocked: the repo-root .env database rejects the 0001 migration
  with `permission denied to create role` (restricted DB user, needs CREATEROLE
  or a one-time superuser migrate); local runs used the docker PG on 5433
  instead.
- 2026-10-03: T36 test repairs (client suite had 2 failures from the unrecorded
  HEAD commit). (1) `trip_rig.start()` hung forever under testWidgets: it
  yielded with `Future.delayed(Duration.zero)`, a timer that never fires in
  FakeAsync without pumped time. Plain `test()` uses real async so it passed
  there. Fixed with a microtask yield, which works in both zones. (2) Second
  share-flow test went silent: `shareButton` read flags through the real
  `remoteConfigRepoProvider`, whose rootBundle asset load answers only the first
  testWidgets per file and never completes later (mocked channels repeat fine;
  engine-served assets do not - verified with isolated probes). Tests now
  override the provider with literal bundle JSON per the existing home_test
  pattern, so no widget test touches rootBundle or the network. No production
  change: every silent share path either shows UI or correctly aborts a dead
  screen, and no trip starts without consent. File green (5 tests), analyze
  clean.
- 2026-10-03: Late-outcome dispose guard (production fix). The rig timing change
  exposed a real crash: a ping outcome arriving after the trip screen is gone
  called notifyListeners on a disposed TripController (same for a resumed
  auto-end check). `_onOutcome` and `_checkAutoEnd` now ignore work after
  dispose via a `_disposed` flag. The previously failing auto-end test is the
  regression cover. Targeted files green, full suite re-running.
- 2026-10-03: T36 done. Web build config: PWA manifest rebranded to Pontual with
  the app green (#0B6E4F), deploy builds with `--no-web-resources-cdn --wasm`
  (S4: single-threaded skwasm beats CanvasKit; iOS keeps the JS fallback).
  Measured first load gzipped: default path about 2.9 MB (main.dart.js 870 KB
  plus chromium canvaskit.wasm 2010 KB plus fonts), wasm path about 2.6 MB; both
  inside the 3 MB budget, so no size ADR needed. CSP unchanged and strict
  (wasm-unsafe-eval already allowed; no COOP/COEP needed for single-threaded
  skwasm); Google Fonts stays blocked so web uses fallback fonts until the S4
  font issue is resolved. Verified: full client suite green (107 passed),
  analyze clean, both builds compile. Owner-blocked deploy (Pages project, DNS,
  secrets) unchanged.
- 2026-10-03: T37 parked. Browser and on-device checks move to another machine
  (owner todo): this host has no usable browser (only a snap stub; flutter test
  needs a real Chrome) and no phones. Desktop-Chrome widget runs plus the
  shipping web build stay the verify path there. Viewer code itself is
  platform-clean (one conditional import, no dart:io in features).
- 2026-10-03: T39 done. One-time iOS install hint: pure `shouldShowInstallHint`
  (iOS web and unseen only), prefs-backed `InstallHintStore`, dismissible Safari
  share-sheet card slotted at the top of Home (no-op off iOS web). Verified: 4
  new tests green, existing home tests green, analyze clean. Real Safari PWA
  check stays on a phone (owner todo, T47).
- 2026-10-03: T40 done. S10 Settings (theme Sistema/Claro/Escuro with prefs
  persistence via `themeModeProvider`, privacy and about entries, help texts,
  timetable build date from the manifest) plus S12 About (non-affiliation
  disclaimer, onibus.online source line, OSM copyright link, licence page, repo
  link). Contact row hidden while `supportEmail` is empty (INFRA-23 still
  owner-blocked). Riverpod 3 note: `StateProvider` no longer exists, theme uses
  a tiny `ThemeModeNotifier`. Verified: full suite green (124 passed), analyze
  clean, manifest audit PASS.
- 2026-10-03: T41 done. S11 privacy center: bundled short policy/terms
  (offline), 6-line collection summary per 13.2, `PrivacyActions`
  (delete-my-data with honest offline outcome, revoke with best-effort trip
  end), policy/terms text routes, contact hidden until INFRA-23. Support code
  cut per the cut order. Verified: AC13 end-to-end in-widget (confirm clears
  token and returns to welcome; cancel and offline keep data), full suite green
  (131 passed), analyze clean.
- 2026-10-03: T42 done (docs only, no code besides the bundled-text pointer).
  `docs/privacy/policy.md` and `terms.md` drafts (pt-BR, per 13.9, with
  [DEFINIR] markers for controller, contact, domains, licences), `ripd.md`
  (RIPD-lite with KL2 residual risk), `inventory.md` (processing records from
  13.2). Owner-blocked: lawyer review, contact e-mail (INFRA-23), licences
  (INFRA-19 data half), canonical URLs (INFRA-05).
- 2026-10-03: T43 done. Ran every AC test that can run on this host: server 67
  green (first run showed 24 `TEST_DATABASE_URL is not
  set` errors, env gap
  only), client 131 green, fmt/lint/check and analyze clean, manifest source
  audit PASS. AC17 debug-log trip audit has zero hits for coordinates, tokens,
  or device ids. Wrote docs/security/review-alpha.md: no open P0/P1 in code;
  AC04, AC20, AC21 blocked on the VPS (server/deploy/ still empty, T05); AC15
  partial until the release AAB; AC16 partial until a gitleaks run (CI covers it
  per release); AC08 scale and AC06 relay need staging.
- 2026-10-03: T44 partial. Measured ping wire size by curl trace (0.62 KB per
  ping; leader ~0.15 MB/h at budget, follower ~0.025 MB/h inside) and web first
  load (JS 2.95 MB gz inside, wasm 3.08 MB gz ~3 % over). Wrote
  docs/field-tests/budgets.md. No Android SDK on this host so no AAB/APK size;
  no phones so no frame/RAM/CPU/battery/fps/latency numbers. All recorded as
  TODO for the capable machine.
- 2026-10-03: T45 done as far as this host allows (no Android SDK, so no AAB to
  inspect). In-tree: `allowBackup=false` on the application tag (AC15, token
  cannot clone via cloud backup), R8 `isMinifyEnabled` + `isShrinkResources`
  with stock `proguard-rules.pro` (rollback documented in-file), audit script
  now also fails on missing allowBackup and on cleartext, new
  `release-android.yml` (tag build with --obfuscate, merged manifest audit, AAB
  <= 15 MB gate, `gh release upload`, no new third-party action). Owner-blocked:
  upload keystore secrets, first tagged build plus install-launch,
  merged-manifest result.
- 2026-10-03: T49 done (docs only). `docs/field-tests/pilot-kit.md` with the
  1-page pt-BR guide, known-limitations summary, and a copy-paste feedback form.
  Organizer contact still [DEFINIR] (INFRA-23).
- 2026-10-03: T50 done. `docs/runbooks/ops.md` covers the PLAN 18 table plus the
  weekly check. Kill-switch drill executed on an isolated local server plus
  throwaway DB (soak untouched): pre-switch start 201, post-switch start and
  ping `503 maint` inside the 30 s refresh, reads 200 throughout, rollback
  to 201. Drill DB dropped afterwards. Next drill on the VPS after T04/T05.
- 2026-10-03: T05 files authored (repo side). `pontual.service` carries the 12.8
  sandbox (verified structurally with systemd-analyze; only the VPS deno path is
  absent here) and `deploy.sh` implements tag unpack, checksum, migrate, symlink
  swap, restart, health gate, and rollback. T04 hardening steps drafted in
  `docs/runbooks/vps-hardening.md`. Owner-blocked: all VPS execution, upload
  keystore, uptime-monitor service choice (INFRA-10), first deploy and rollback
  run.
- 2026-10-03: T46 incident and restart (no code finding). The first 8-hour soak
  was contaminated mid-run: a final verification `deno task test` against the
  shared dev DB truncated the sim device rows (`db_test` setup) and re-set
  `service_enabled=false` (AC14, known T35 hygiene gap), flipping sim pings to
  401 and writes to `503 maint`. Fixed AC14 with a finally-block teardown that
  deletes the switch row (suite re-verified 67 green, app_config clean
  afterwards). Rule: never run the suite against a live soak DB. Fresh soak
  started 13:47 UTC (3 buses, 6 riders, line 60, seed 7, resource watcher on the
  true server PID); result lands here when it completes.
- 2026-10-03: T38 done. Foreground-only web sharing: `wakelock_plus` 1.8.0
  (allow-list PLAN 8.2, no ADR needed; its Android manifest adds no permissions,
  source audit still PASS) behind a `WebWakeLock` seam in `platform/web/` with a
  fake for tests; pure `WebVisibilityTracker` pauses sends after 60 s hidden
  (`webHiddenPauseMs`) and resumes on visible; TripController drops fixes while
  `isWebHidden` (server 10-min timeout is the backstop, no explicit end needed);
  trip screen shows the always-visible PLAN banner plus brightness tip,
  wake-lock status, and hidden-paused state on web only (`kIsWeb`). Size note:
  release web build compiles; JS path 2.95 MB gz (inside budget), wasm path 3.08
  MB gz (about 3 percent over the 3 MB RNF14 target; canvaskit.wasm 2.06 MB gz
  dominates, nearest achievable without a renderer change; iOS browsers take the
  JS path). Full client suite green (116 passed, 9 new), analyze clean. Browser
  run of the banner and wake lock stays on the T37 machine (owner todo).

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
- 2026-10-04: Local verification session on a browser-capable machine. Reverted
  an uncommitted `deno run -A` in `server/deno.json` back to the minimal scoped
  flags (no `--allow-all`, ever, per PLAN 12.2). Fixed the local boot:
  `server/.env` had `METRICS_PORT` on 9093 outside the `--allow-net` list
  (crash) and a `DATABASE_URL` pointing at an unreachable database (500 on
  register); 9091 plus the local PG 16 container on 5433 boots clean with 21
  lines. Full suites green: server 67/67 (after dbmate 2.36.0 migrate), client
  VM 131 plus analyze clean, client `flutter test --platform chrome` 131 green
  (was 4 failures, all fixed below), tools data/fmt/lint clean, gitleaks 8.28.0
  scan clean (325 MB, no leaks). E2E by hand against the local server: register,
  consent, start, W-to-L promotion, vehicle snapshot, `/v1/live`, idempotent
  end, delete-my-data with 401 after; implausible-speed pings strike into
  `abuse` end as designed. Browser smoke on the release web build: welcome,
  line-60 map with real OSM tiles plus 3 soak vehicles live, and settings all
  render with no console errors; static 404s fall back to bundled data per the
  offline-first design. 8-hour soak (3 buses, 6 riders, line 60, seed 7) started
  12:54 UTC, healthy at last check (3 vehicles, zero server errors); result
  lands here on completion. Production fix: release workflows built with no
  `--dart-define`, so the AAB and PWA would call localhost; both now take
  `vars.API_ORIGIN` and `vars.STATIC_ORIGIN` with fail-fast checks (owner sets
  real domains per INFRA-05). README gained a verified local end-to-end run
  guide.
- 2026-10-04: Chrome-only test findings (production fix in one case). (1)
  `decodePolyline` used 32-bit bitwise shifts, which corrupt large deltas on
  dart2js (test: -120.2 decoded as 42829.47; iOS browsers take the JS fallback
  so this was user-facing). Rewrote with arithmetic only in
  `app/lib/core/geo/geo.dart`, verified against the canonical vector on the VM
  and green on chrome. (2) `api_test` live contract read `Platform.environment`,
  unsupported on web: now skipped on `kIsWeb`. The same test hardcoded line 7
  (CI seed only, 404 on real bundle): new `--dart-define=BUS_API_LINE=` (default
  7, use 60 on bundle data), live-passing. (3) `app_test` welcome-to-home relied
  on rootBundle plus network, empty on chrome: now pumps with literal bundle
  overrides per the home_test pattern. (4) `map_tab_test` harness overrode
  `vehicleRepoProvider(7)` only, leaking the real networked repo for the id-10
  non-pilot line: now overrides the pumped line id.
- 2026-10-04: WebSocket console errors from website testing analyzed and fixed.
  The `[flutter_map]` OSM warning is debug-only policy noise (we comply: real
  User-Agent, attribution, capped cache; silent in release). The repeated
  `WebSocketChannelException` came from the channel `ready` future: a failed
  connect completes it with an error that nobody awaited, so it escaped to the
  zone as an uncaught error even though the stream error itself was handled. The
  production `openChannel` factory now sinks `ready` errors. Same report exposed
  a real gap: the socket never reconnected after a drop (only snapshot polling
  continued), against PLAN 11.3. `VehicleRepository` now reconnects with
  5/10/20/30 s backoff plus snapshot-on-reconnect, cancelled on `stop`. Proven
  on chrome against a dead port (3 opens, contained, clean stop) and covered by
  2 new `vehicle_test` cases. Full suites: VM analyze clean plus 133 green,
  chrome 133 green.
- 2026-10-04: T46 first 8-hour soak died at ~67 min, root-caused, restarted. The
  sim drifted buses east at 8 m/s forever, exiting the city bbox (lngMax -39.55)
  after ~0.3 deg; every out-of-bbox fix strikes, so all 18 trips abuse-ended
  within minutes of each other. The engine behaved exactly as designed; the load
  driver was wrong. Fixed in `tools/sim`: buses bounce inside bbox-margin edges
  with matching headings, and the sim resumes on 404-gone like a real client
  (KL6), counting resumes apart from errors. 90 s smoke of the patched sim: 324
  pings, 3 hand-overs, 304 WS snapshots, p50 2 ms, p95 11 ms, zero errors. Fresh
  8-hour soak (3 buses, 6 riders, line 60, seed 7) started ~14:20 UTC; result
  lands here on completion (~22:20 UTC). Also settled the browser 403s in the
  access log: Deno sim connects clean (101), so the steady 403s were a browser
  page on a non-allow-listed origin (the exact case the origin check exists
  for); the reporter's console spam from that case is fixed by the ready-sink
  above.
- 2026-10-04: CORS preflight was missing server-side. The hand-rolled CORS in
  `server/src/http/app.ts` set ACAO on real responses but had no OPTIONS route,
  so browsers blocked every non-simple request (POST with JSON body, DELETE,
  authed calls) while plain GETs worked. Symptom on web: map showed "Ao vivo"
  (GET snapshot + WS ok once the origin was allow-listed) but "Estou no onibus"
  died silently at POST /v1/devices (preflight ERR_FAILED, registration never
  completed). Added an `app.options("*")` handler returning 204 with ACAO +
  allow-methods (GET, POST, DELETE, OPTIONS) + allow-headers (authorization,
  content-type) for allow-listed origins only, and extended the AC18 test with
  allowed/denied preflight cases. Verified: deno fmt, lint, check clean;
  security_test.ts 6/6 green against a throwaway local DB. Local web must still
  run on `--web-port 5000` to match ALLOWED_ORIGINS.
- 2026-10-04: VPS database had no schema: POST /v1/devices failed with
  `relation "devices" does not exist` and the config refresh kept failing, while
  in-memory GETs worked. This also motivated logging the error text (not
  secrets) in the `unhandled` and `config refresh
  failed` server log lines.
  First `dbmate up` rolled back: the VPS user lacked CREATEROLE for the
  `pontual_app` role creation in 0001_init. Owner granted CREATEROLE on the VPS,
  reran `dbmate up` (dbmate 2.36.0): 0001_init applied, 0 pending. Follow-up:
  switch server DATABASE_URL to least-privilege `pontual_app` per PLAN 6.4
  (needs a password set outside migrations).
- 2026-10-04: Trip start 403 `consent` after the DB/CORS fixes, root-caused to
  stale local consent. Earlier failed runs wrote the accepted version to local
  storage before the server POST failed, and `ensureConsent` treated local
  coverage as granted without reposting, so the server never recorded consent
  and the trip guard kept rejecting. Fixed
  `app/lib/features/trip/consent_flow.dart` to reconcile the server record on
  every start (server upserts, safe to repost); truly offline runs still return
  offlinePending. Updated the covering-version test and added a failed-reconcile
  case. Full app suite: 134 green, 1 skipped.
- 2026-10-04: Owner asked that idle buses appear on watcher maps. Checked
  against PLAN.md 6.6 step 9, which deliberately never publishes a stopped lone
  trip (phantom-bus risk). Presented the trade-off; owner chose to keep PLAN, no
  engine change. Consequence for field testing: a share started while stationary
  publishes nothing until the device moves (moving_ticks_to_publish), and
  sitting still ends the trip as idle; validate on a moving bus outdoors.
- 2026-10-04: Consent reconcile posted on every start, burning the 10/hour
  per-device consents quota during retry loops (429s in field testing). Switched
  to confirm-once: ConsentStore tracks the server-confirmed version separately;
  reconcile POSTs only while unconfirmed, at most one request per version once
  confirmed. Full app suite: 135 green, 1 skipped.
- 2026-10-04: Field testing needed stationary publishing: the movement gates
  (moving_speed_mps 3, moving_ticks_to_publish 2) mean a walking tester never
  creates a vehicle. Added local-only TEST_EASY_PUBLISH (default false):
  movingSpeedMps 0 + movingTicksToPublish 1, so the first ping publishes.
  Guarded by config validation, which refuses to start with it set unless
  APP_ENV=local, plus a warn log at boot. Production behavior unchanged. Full
  server suite: 68 green.
- 2026-10-04: Share flow never failed silently anymore. Added StartFailure
  reasons (declined/permission/offline/noGps/busy/ outsideArea/failed) to
  TripController, a 60 s first-fix timeout (was an infinite hang),
  consent-confirmation reset on server consent rejects, and a pt-BR SnackBar for
  every dead end in share_flow (declines stay silent, permission keeps its
  sheets). Full app suite: 142 green, 1 skipped.
- 2026-10-10: Phased share-start progress sheet. Tapping Estou no onibus now
  opens ShareProgressSheet at the register phase with 7 rows (services, config,
  consent, permission, register, gps, start), a GPS countdown with an open-sky
  tip, and a collapsed Detalhes tecnicos block carrying phase id, error code,
  attempt, consent version, line id, and API host only (no coordinates, tokens,
  or device ids). Failures keep the sheet open with Tentar de novo (fresh
  attempt) and Fechar; Cancelar aborts via cancelStart and returns declined.
  TripController.startTrip takes an optional onPhase callback and never throws
  (unexpected transport errors map to offline). offlinePending still continues
  like granted per T30, so permission and GPS still run when the consent POST
  merely raced a bad network. No new dependency or permission. Full app suite:
  151 green, 1 skipped; analyze clean.
- 2026-10-10: Easy-test accuracy gates. Field report: indoor fixes are inside
  the bbox but coarser than the 60 m hard gate, so sharing stalls at Aguardando
  GPS forever (`fix dropped accuracy` in the console) even with
  TEST_EASY_PUBLISH on. The easy flag now also relaxes `accuracyMaxM` to 500
  (logged at boot), and the client accepts an optional `FIX_ACCURACY_MAX_M`
  dart-define (default 60; easy-test phones set 500 in `env/phone.json`).
  Default behavior unchanged on both ends. PLAN.md 17.1 updated. Server trip
  suite green including a coarse-fix (350 m) easy-publish regression test.
- 2026-10-10: ADR: added `permission_handler` 12.0.3 for the Android 13+
  notification runtime permission (PLAN 8.2 exception clause, explicit owner
  order). Reason: the app declared POST_NOTIFICATIONS but never requested it at
  runtime, so the trip foreground-service notification stays hidden on Android
  13+ until the user allows it manually in settings. Alternatives rejected:
  `flutter_local_
  notifications` (much heavier, only viable if local
  notifications are shown), Firebase messaging (forbidden telemetry-adjacent
  infra), hand-rolled MethodChannel (duplicates tested edge-case handling).
  Version note: 13.0.2 was tried first but its Android artifact requires
  compileSdk 37 while Flutter 3.47 pins 36 (verified build failure on
  checkDebugAarMetadata); 12.0.3 (android artifact compileSdk 35) fits the
  toolchain. Size impact: debug fat-APK proxy +2.9 MB (+1.7%, 174.9 to 177.8 MB
  unoptimized); release AAB/APK unmeasurable on this machine (assembleRelease
  fails identically with and without the package: RAM-starved R8, pre-existing
  environmental issue, retry on a quiet machine or CI). Maintainer: baseflow.com
  (verified publisher, same family as `geolocator`), MIT licence, updated 2026,
  Flutter 3.47 toolchain. Manifest: injects zero permissions (verified); no new
  permission added. Use is notification-only and best-effort: one request per
  share attempt before the location education sheet, never blocks sharing, never
  throws; widget tests inject a no-op because platform channels have no native
  side under testWidgets (verified: even a raw unmocked channel never resolves
  there). Full app suite: 155 green, 1 skipped; analyze clean.
- 2026-10-10: TEST_EASY_PUBLISH was silently ineffective. main.ts mutated one
  EngineConfig for the tick jobs while tripRoutes built its own default, so
  stationary trips stayed W forever even with the flag on (field report: stuck
  at Aguardando with live []). Threaded the config through instead:
  AppOptions/TripDeps take a required engine owned by main.ts, which applies the
  easy-publish mutation before serving. readRoutes keeps its own default (it
  only reads publishTtlS, untouched by the flag). Added an HTTP regression test
  proving an injected easy engine promotes a stationary trip on the first ping
  and shows it on /v1/live. Full server suite: 69 green; fmt, lint, check clean.
- 2026-10-10: Removed the server 10-minute idle end (owner order: buses
  legitimately stand still in traffic and construction). applyPing no longer
  tracks an anchor and never emits `idle`; the Trip type and EngineConfig lose
  `anchor`, `idle_displacement_m`, `idle_end_after_s` (code-only keys, no
  migration). The `idle` end code stays recognized by clients but is no longer
  emitted. Remaining guards: movement gates still decide publishing (a
  stationary forgotten phone never becomes a vehicle in prod), client
  walking-prompt timeout ends unanswered stationary trips in ~7 min, server
  no-ping timeout 10 min, hard cap 4 h. Test 14 is now a survival regression
  (stationary pings for 16 min, trip alive, no end). PLAN.md RF04, PRV03, 6.3
  table, 6.6 order, outcomes, 15.2 lifecycle, T09 updated. Full server suite: 69
  green; fmt, lint, check clean.
- 2026-10-10: Walking prompt windows lengthened (owner choice): slow window 4 to
  15 min, unanswered-prompt timeout 3 to 5 min. A bus in a jam or construction
  stop now survives 20 min unattended; forgotten stationary trips still end.
  Tests use the constants symbolically and pass unchanged. PLAN.md RF16, 6.6,
  S08, 15.2 updated. Full app suite: 155 green, 1 skipped; analyze clean.
- 2026-10-10: CI repair after data/flutter failures. Root causes: (1)
  tools/sim/main.ts kept an unused PRNG (`rand`/`mulberry32`) after the battery
  randomization was replaced with a constant, failing `deno lint` and with it
  the whole data job. Removed the dead code; the `--seed` CLI flag is still
  accepted but currently unused. (2) app manifest set
  `usesCleartextTraffic="true"`, failing the manifest audit and violating PLAN
  SEC06/T11/AC15 (TLS only, no cleartext). Removed the attribute. Consequence:
  physical-device testing against a LAN http server is OS-blocked again; use
  staging https or document another compliant path before re-adding any
  exception. (3) env/phone.json (machine LAN IP) was committed; it is
  local-only, now untracked and gitignored (kept on disk). ci.yml hardened:
  concurrency cancel-in-progress (fewer duplicate runs and emails), per-job
  timeouts, workflow_dispatch for manual reruns, server smoke uses
  `deno task start` (same flags as dev minus --env-file, which CI does not have;
  env comes from the workflow), failing smoke prints the server log tail, data
  size step echoes the byte count. No secrets in any CI job, triggers unchanged
  (pull_request plus master), so fork PRs run the same checks. Verified: tools
  lint/fmt/data-test/data-validate/data-build green, manifest audit PASS,
  flutter analyze and dart format clean, full app suite green (154 passed, 1
  skipped, pre-change tree; post-change tree touches no Dart code). Server smoke
  still needs CI (no local DB).
- 2026-10-10: Static hosting moved from Cloudflare Pages to GitHub Pages (owner
  order). Why: deploy-static.yml never succeeded; the Cloudflare Pages project,
  DNS, and secrets were never created (step.md lists them owner-blocked), while
  Pages needs no new project or secrets, just Source: GitHub Actions plus the
  API_ORIGIN repo var. API path unchanged (still VPS behind Cloudflare); only
  the static web bundle and /data move. Workflow now builds data plus web,
  assembles pages/ (web build, data files, index.html copied to 404.html for
  go_router deep links, .nojekyll), and deploys via upload-pages-artifact v5.0.0
  plus deploy-pages v5.0.1 (SHAs pinned, verified 2026-10-10). STATIC_ORIGIN
  defaults to https://<owner>.github.io/<repo> with --base-href derived from its
  path, so forks work without extra vars; only API_ORIGIN is required (fail-fast
  message tells where to set it). Accepted limitations: Pages cannot serve the
  custom `_headers` (CSP/HSTS/ immutable-cache rules do not apply; TLS comes
  from Pages; the data tool still generates `_headers` as a draft), and
  COOP/COEP cannot be set, so `--wasm` runs single-threaded with the bootstrap
  JS fallback where isolation is absent. PLAN.md 5.2, 7.1, 12.5, 17.1, 17.2
  updated.
- 2026-10-10: release-android.yml would have failed on its first tag: pushing a
  tag does not create a GitHub release, so `gh release
  upload` had nothing to
  upload to. It now creates the release (`--generate-notes`) when missing.
  STATIC_ORIGIN got the same GitHub Pages default as deploy-static.yml, so only
  the API_ORIGIN var is required. Added a 25 min timeout. Signing story
  unchanged (debug signing until the keystore secrets exist).
- 2026-10-10: Prod API live on this VPS for the GitHub Pages build (owner order:
  same Pages URL as the workflow default, option 2, no bought domain). Adapted
  because this shell has no sudo (interactive auth required), so Caddy on 80/443
  plus system units plus firewall were impossible: user systemd units
  `pontual-api` (Deno on 127.0.0.1:8080, APP_ENV=prod, 21-line bundle) and
  `pontual-tunnel` (`cloudflared tunnel --url http://127.0.0.1:8080`), both
  enabled with Linger=yes. Public API_ORIGIN is the quick-tunnel hostname (shown
  at deploy time via the tunnel journal). DB needed no migration (0001 already
  applied); the API runs as least-privilege `pontual_app` with a fresh password
  in `~/pontual/prod.env` (0600) over 127.0.0.1 loopback instead of the
  public-IP URL, and ALLOWED_ORIGINS holds both Pages casings with
  TRUST_CLOUDFLARE=true. Verified through the public URL: health/live/vehicles
  200, CORS preflight 204 with Pages ACAO, WS sub snapshot, full write cycle
  (register 201, consent 200, start W, ping 200, end/delete 204, test device
  removed, zero 5xx). Accepted limitations: the tunnel hostname is random and
  changes on tunnel restart, so API_ORIGIN plus a Pages rebuild must follow any
  restart; no edge cache or access rules on a quick tunnel; Caddy plus hardening
  plus stable hostname still need a root session plus a domain (see
  docs/runbooks/vps-hardening.md).
- 2026-10-10: Repo renamed to `EduLGFon/pontual-bus-tracking`, so the Pages URL
  is `https://edulgfon.github.io/pontual-bus-tracking` (the deploy workflow
  derives it at runtime, no file change needed). ALLOWED_ORIGINS corrected to
  the rename (both casings) and the local git remote repointed. deploy-static
  failed at `Resolve origins`: the `API_ORIGIN` repo variable is missing (likely
  set under Secrets instead of Variables). Tunnel churn confirmed live:
  restarting the API recycled the tunnel hostname, so `pontual-tunnel.service`
  no longer BindsTo the API (API restarts keep the tunnel URL now).
- 2026-10-10: Pages showed "Sem conexao" with `/v1/stream` 403s in the API log.
  Root cause: ALLOWED_ORIGINS held the full project URLs
  (`https://<owner>.github.io/<repo>`), but browsers send only scheme plus host
  as Origin (`https://edulgfon.github.io`), so every socket upgrade was rejected
  while plain GETs worked. Fixed to bare hosts (both casings); bare-origin
  preflight 204 verified through the tunnel. No firewall change was needed: the
  quick tunnel is outbound-only, so neither the Oracle security list nor the
  host firewall needs inbound rules for the API.
- 2026-10-10: D29 - rate-limit strikes no longer end trips (PLAN 6.6 step 3
  changed). Symptom: web trips died seconds after start with server `abuse`
  (Chrome indoors) because `PingClient.queue` sends on every accepted fix with
  no pacing to the instructed `n`, and geolocator-web ignores the Android
  interval settings, so a walking phone emits ~1 ping/s into
  `minPingIntervalS=4` rate strikes (5 strikes = dead, proven by a 9-pings-in-7s
  burst in the API log). Android survived only because its stream honors the 20
  s interval. Fix: too-frequent pings are now ignored without a strike; the
  server samples fast streams at ~4 s. Spoofing defense stays via
  validate/teleport strikes (AC07 unchanged) plus the 30/min per-device bucket.
  Tests: engine 25 (rapid valid pings survive) and 26 (spaced invalid pings
  still abuse-end); read_test AC08 burst now asserts survival, which exposed a
  pre-existing hygiene bug (no truncate in read_test, so db_test's
  `service_enabled=false` row leaked 503s into it; fixed with a truncate).
  Verified: fmt, lint, check clean; full suite 71 green on a throwaway DB; prod
  restarted (tunnel URL kept) and 10 pings at 1 Hz through the public URL all
  returned 200 with no end, the trip even published (`live:[[60,1]]`, W to L).
  Remaining client work (needs the Flutter machine): pace sends to `n` in
  TripController (RF08, also fixes the data budget at 1 Hz), and debounce the
  permission-revoked poll in TripSupervisor (Firefox died by instant
  `permissionRevoked` from the Permissions API reporting `prompt`; 3 consecutive
  polls before ending).
- 2026-10-10: Field-test follow-ups. (1) TEST_EASY_PUBLISH=true with
  APP_ENV=local on this host (owner order): publish on the first ping with the
  accuracy gate at 500, verified live with a stationary spd-0 acc-300 fix
  publishing at once (`live:[[60,1]]`, W to L). Temporary for testing; revert
  before any pilot (KL2: a lone stationary phone now draws a bus). Note: the
  Pages PWA still drops fixes coarser than 60 m client-side (FIX_ACCURACY_MAX_M
  not baked into the web build), so indoor phones also need that dart-define via
  a workflow change. (2) Client fix written here without a local Flutter
  toolchain (commit `72d51dd`): paced sends plus 3-poll permission debounce plus
  tests; CI is the verifier, then deploy-static republishes the PWA on
  merge/push. (3) WS drops on good wifi: infra is stable (tunnel 0 restarts, 0
  errors; API healthy; 0 stream rejects since the origin fix). Upgrade
  timestamps cluster inside viewing sessions (~20-40 s apart while testing),
  consistent with client-side drops, but the cause needs browser console
  evidence (close codes + times) correlated with the API log. Next step is a
  console-logged repro from the phones.
- 2026-10-10: Connection review (two-reader pass, every P0 verified in code).
  Cause of the wifi drops found client-side, not in infra: (1)
  `vehicleRepoProvider` is a plain Provider.family, and MapTab never stops its
  repo, so every visited line leaks a socket plus 5 s watchdog plus 15 s poller
  plus reconnect timer; the Horarios tab keeps the Mapa stream alive, and even
  timetable-only lines opened sockets. Leaked repos multiply snapshot GETs into
  the per-IP read buckets and WS reconnects. (2) TripController.dispose never
  stopped the location stream, leaking GPS after leaving mid-trip. (3) A stale
  PingClient outcome could end the next trip (no generation guard). (4)
  Heartbeats were parsed and discarded, so quiet lines resynced pointlessly and
  the poller armed instantly instead of after 30 s. Fixed in `6ca3892`
  (liveness, delayed polling, guarded resync) and `e26d56f` (auto-dispose,
  dispose-stop, pilot-only streams, outcome generation) plus tests; CI verifies
  (no Flutter on this host). Server hardening in `f3734c8` (prune rate buckets),
  `589599e` (heartbeat backpressure, 503 capacity instead of a stillborn 101),
  `4e81e6d` (drop counters, CORS if-none-match), `2e19a1d` (guarded snapshot
  builds); full suite 74 green here, prod restarted with the tunnel URL kept.
  Deliberately deferred: per-IP read-limit raise (fine at alpha scale; revisit
  for campus NAT), ping-bucket reorder (paced clients have 7x headroom), WS
  close-tolerance (pinned by AC06), remoteAddr IP source (edge overwrites the
  header in practice).
- 2026-10-10: Optimization review (three tracks). Server hot path fixed:
  `guard()` went from 3 sequential PG queries per ping to a cached config (30 s
  refresh already existed, result was discarded) plus parallel blocked/consent
  checks (`6ba6b7e`); per-request stdout logs are debug-only (`f577d40`); line
  snapshots memoized for 304s (`93c6c50`); structured rows with no parse
  round-trips (`7e6f4c9`); direct hub iteration, Math.random jitter, capped auth
  cache, batched purge (`376f36c`). Full suite 74 green, prod restarted. Client
  (needs CI, no Flutter here): follower TLS idle 120 s, battery TTL, auto-end
  poll 30 s, map ticker 5 s, snapshot ETag with case-insensitive lookup,
  static-bundle eviction, home live refresh, plus back-button trip end and
  dispose/start guards (`46cc598`). Deferred with rationale: distanceFilter
  (would starve still detection and the server timeout), repo ChangeNotifier
  (correct fix for map rebuilds, but touches provider override patterns in
  tests), per-IP limit raise, ping-bucket reorder, home error UI and schedule
  virtualization (cosmetic at current sizes).

Append-only. Newest entries go at the end of each section. See AGENTS.md 14.

## D-U01-2026-10-14: UI_SPEC.md is truncated at section 13.5

`docs/ui/UI_SPEC.md` (v1.0, dated 2026-10-14) ends at section 13.5. Sections 14
(copy deck), 15 (brand assets), 16 (implementation plan, tasks U01 to U26), 17
(QA and measurement) and 18 (reading list) are missing, even though sections 0
to 13 reference them.

Handling: the task plan was reconstructed from the section titles and the work
actually required by sections 0 to 13; the wireframes in section 7 are used as
the copy deck. Every deviation this forces is recorded here. Owner action:
append the missing sections, or confirm this reconstruction.

## D-U02-2026-10-14: no `NEW_UI` cutover flag, old UI removed in one change set

UI_SPEC 0.3 prescribes building the new UI next to the old one and cutting over
behind `--dart-define=NEW_UI=true` (task U24). The owner asked for the old UI to
be removed.

Handling: the flag exists and defaults to **true** (the new UI runs by default),
so the old screens stay available for review with `--dart-define=NEW_UI=false`.
When the new UI reaches parity the legacy folders `app/lib/features/`,
`app/lib/app/` and `app/lib/app/theme.dart` are deleted in one commit rather
than kept alive. Two UIs permanently is double maintenance and violates "don't
make me think" for the next agent.

## D-U03-2026-10-14: variable Manrope subset instead of five static weights

UI_SPEC 4.2 asks for one bundled subsetted typeface, candidate order Manrope,
Plus Jakarta Sans, Inter, with a variable weight axis or static weights, tabular
figures, and a 70 KB budget.

Verified (docs/ui/VERIFY-NOTES.md section 3): `FontVariation('wght', w)` is
applied by the engine on Android, CanvasKit and Skwasm, and
`FontFeature.tabularFigures()` is a const constructor. The native font manifest
ignores a pubspec `weight:` key (chinmaygarde TODO in `font_collection.cc`), so
a single variable TTF is the only shape where the requested weight actually
renders.

Result: one 51,712 byte TTF (Manrope[wght].ttf subset to Latin, Latin-1,
punctuation and arrows, `tnum` and `kern` kept), built by
`tools/build_fonts/subset_manrope.py`. Five static instances measured 145 KB,
over budget. Every text style sets `fontVariations` explicitly, so no style
renders at the variable default (wght 200).

## D-U04-2026-10-14: colour token values adjusted for WCAG 2.2 AA

UI_SPEC 4.1 gives starting hex values and requires a contrast test that fails
below 4.5:1 for text and 3:1 for graphics.

Measured with the WCAG formula over every foreground/background pair used by the
UI, the starting values failed on: light `live` (2.53 on `bg`), light `warning`
(2.92 on `bg`), light `inkSubtle` on `surfaceSunken` (4.47), light `warningText`
on `surfaceSunken` (4.24), and three line palette colours against white badge
text (`#0284C7`, `#0891B2`, `#EA580C`). The dark set passed everywhere.

Final values are in `app/lib/ui/design/tokens/colors.dart` and are asserted by
`app/test/ui/contrast_test.dart`: light `live` is now `#149B5C`, `warning`
`#CC7006`, `inkSubtle` `#5E6E69`, `warningText` `#AD5009`, and the light line
palette uses `#027CBB`, `#07819E`, `#CC4D0A` instead of the starting three. The
dark line palette is the light palette lightened so near-black badge text
reaches 4.5:1 on every fill.

## D-U05-2026-10-14: `StaticLine` gained optional fields, nothing else changed

The new UI needs terminals, area tags and the active flag, which the lines JSON
already carries. UI_SPEC 0.1 rule 2 forbids changing static-data loading.

Handling: `StaticLine.fromJson` now also reads `terminals`, `area_tags` and
`is_active` as optional fields that default to empty and true. No fetch, cache,
swap or parsing rule changed, and the JSON schema is untouched. The UI never
reads the data repository directly: it goes through `lib/ui/adapters/`, as the
spec requires.

## D-U06-2026-10-14: `flutter build web --analyze-size` does not exist

UI_SPEC 11.4 lists it. Verified (docs/ui/VERIFY-NOTES.md section 5): the flag
does not exist in Flutter 3.47.6, the tool answers "Could not find an option
named analyze-size", and `--web-renderer` is gone as well (the renderer is
canvaskit by default for JS and skwasm for `--wasm`).

Handling: the web transfer size is measured from `build/web` after
`flutter build web --release` (`du -sb`, plus the gzip total the deploy workflow
already reports). Android size uses `flutter build apk
--analyze-size`, which
does exist.

## D-U07-2026-10-14: no `NEW_UI` per-screen parity flag; no route for the timetable

UI_SPEC 6.6 lists a `/timetable/:key` route. The timetable is a tab of the line
screen in every wireframe, and a second URL for the same content duplicates
state (`?tab=` already exists on `/line/:key`).

Handling: no `/timetable/:key` route; `/line/:key?tab=horarios` is the one URL,
and it deep-links on web.

## D-U08-2026-10-14: house style for the new UI

Decisions taken while implementing sections 3 to 7 that are not covered by the
spec text:

- `CertaintyStyle` is a function `styleOf(context, certainty)` in
  `lib/ui/design/components/certainty_style.dart`, not a class with a static
  table, because colours must come from the theme extension.
- The dashed predicted pill is drawn with a `CustomPainter` path
  (`DashedOutline`) rather than a package.
- The vehicle marker glyph is the same `BusIconPainter` as the badges, so the
  icon family has one visual weight.
- `SearchField` uses `InputDecoration.collapsed` with no border overrides, which
  is the cheapest way to have no Material underline.
- Live staleness uses the data layer constant `staleAfterS = 45`, mirrored by
  `liveFreshS` in the models, so the UI never invents its own threshold.
- `Offline` is a banner, never a blocking screen (UI_SPEC 7.9), and the flag
  that drives it is a provider the data layer can fill in later.

## D-U09-2026-10-14: cutover done, old UI removed in one change set

Per the owner order the old UI is removed instead of kept behind the `NEW_UI`
flag from D-U02. The flag is gone; `main.dart` boots the new UI directly.

Deleted screens: `features/home/home_screen.dart`,
`features/line/{line_screen,map_tab,schedule_tab}.dart`,
`features/map/map_widget.dart`,
`features/settings/{settings_screen,
privacy_screen,about_screen}.dart`,
`features/trip/trip_screen.dart`, `features/system/system_screen.dart`,
`app/{router,theme,strings_pt}.dart`. Kept logic (called by the new UI through
`lib/ui/adapters/` or directly): the trip controller, supervisor, location
service, ping client, consent flow and sheets, share flow and progress, tile
source, privacy actions, policy texts, install hint, wake lock, visibility
tracker, web banner, and `app/providers.dart`.

Shared copy moved to `UiStrings`: the share-flow and progress strings, the web
trip strings, the install hint, the collection summary, the OSM copyright URL,
and the repository URL. Two legacy typos were fixed in the move
(`Buscando configuracao` to `Buscando configuração`, `Detalhes tecnicos` to
`Detalhes técnicos`); their tests were updated to the corrected copy. The
repository URL was corrected to the actual remote (`.../pontual-bus-tracking`,
not `.../pontual-bus-tracking-app`).

Tests: legacy screen tests deleted with their screens (`home_test`,
`map_tab_test`, `settings_test`, `trip_status_ui_test`, the widget parts of
`map_test` and `schedule_test`). Shared-logic tests migrated: `app_test` and the
`privacy_test` journey now walk the new UI, `share_flow_test` runs against the
new router, `trip_controller_test` pumps the new trip screen and end cards,
`trip_auto_end_test` asserts the new end-card messages, `remote_config_test`
pumps the new system screens. The 8 pre-existing failures on the clean tree
(map_tab x4, auto_end x1, controller x2, status_ui x1) resolved as: map_tab and
status_ui deleted with their screens; auto_end and controller failures under
investigation in the migrated files.

## D-U10-2026-10-14: dock and trip attach fixes found by the new tests

- `tripVmProvider` was a static snapshot: the dock froze at attach time.
  Replaced by `LiveDockHost`, which watches `tripHostProvider` and rebuilds on
  every controller notification through `ListenableBuilder`.
- The global idle pill was missing (the shell only showed the dock for an active
  trip). The shell now always mounts the dock; line screens keep their
  contextual `LineDock` on a route outside the shell, so the two can never
  double.
- `TripRoute` wrote the provider in `initState` and read it in `dispose`, both
  forbidden by Riverpod. The notifier is captured in `initState`, the attach is
  deferred to the first frame, and the detach logic moved into
  `TripHost.detachIfIdle`, which reads only its own state.
- Widget tests must dispose trip controllers inline: `addTearDown` runs after
  the framework invariant check, so a 30 s supervision timer left for teardown
  fails the test.
- `EtaText` keeps the old child for its 140 ms switch: tests asserting a value
  is gone must pump the tap frame and then advance past the transition.
- `setSurfaceSize` alone does not change `MediaQuery`: tests needing a compact
  layout must also set `tester.view.physicalSize`.
- `pumpAndSettle` never returns under the shared live pulse or the trip hero
  timer; those tests pump fixed frames instead.

## D-U11-2026-10-14: three pre-existing trip test failures were test bugs

`flutter test` on the clean tree failed three controller tests. All three were
test-side assumptions invalidated by earlier production changes, not production
bugs; production code is untouched:

- `pings are paced`: the helper stamped every fix at t=100000 while the fake
  clock advanced past the 20 s freshness window, so the stale filter correctly
  dropped the fixes the test thought pacing skipped. The helper takes the fake
  now.
- `120 s offline heals`: paced sends (n:20) mean no ping is in flight when the
  hanging future completes, so nothing could heal. The test now sends one fresh
  fix after entering offline, mirroring production where fixes keep arriving.
- `late outcome ignored`: the shared hanging future also answered the second
  trip's own immediate ping, which legitimately ended it. The mock answers the
  second start with n:3600, so only the stale outcome arrives and the generation
  guard is actually isolated.
- Shared rig helper `pos()` accepts an optional timestamp for the same reason.

## D-U12-2026-10-14: stack-switch rewrite of AGENTS.md/PLAN.md reverted

During the UI build, uncommitted working-tree modifications appeared in
`AGENTS.md` and `PLAN.md` switching the client from Flutter to TypeScript
(Preact + Vite + Capacitor, PLAN v1.2). No TypeScript scaffold exists in the
tree. Per the owner order, both files were restored to the committed Flutter
versions (`git checkout HEAD -- AGENTS.md PLAN.md`) and the Flutter UI work
continues under UI_SPEC.md.

## D-U13-2026-10-14: the new consent sheet discloses, the existing flow records

The first version of `ConsentBody._accept` opened the legacy `ConsentSheet` for
show and popped with its choice, but the legacy sheet only returns a choice: the
record is written by `ensureConsent` inside the share flow. The result was the
legacy sheet opening twice (once for show, once for record). `ConsentBody` now
only discloses and pops true; the existing flow records exactly once through its
own consent call, per UI_SPEC 0.1 rule 2.

## D-U14-2026-10-14: legacy share flow suppresses its sheets for the new UI

`shareTrip` gained `legacySheets = true`. The new flow passes false, which skips
the location-off, education, denied and blocked sheets; the new flow maps every
outcome to `PermissionCard` per the UI_SPEC 7.7 matrix instead. The notification
permission request always runs. Defaults preserve the legacy behavior byte for
byte, and the legacy share-flow tests are unchanged. The new flow also threads
an injectable `ensureNotifications` seam (mirroring `shareTrip`), because the
real channel call hangs in widget tests.

## D-U15-2026-10-14: no second dispose on the suppressed denial path

The suppressed branch disposed the controller even though the shared path above
already had. The double dispose surfaced a post-dispose notification plus a
spurious "no connection" snackbar next to the permission card. The branch now
only returns.

## D-U16-2026-10-14: release R8 needs a dontwarn for Play Core

`flutter build appbundle --release --obfuscate` (CI's exact command) failed in
`minifyReleaseWithR8` on missing `com.google.android.play.core.*` classes,
referenced only by the Flutter engine's deferred-components manager. The failure
is pre-existing and environmental: no app change could cause it (no
dependencies, Java, or manifest entries were touched), and the app uses no
deferred imports, so those code paths are dead. `proguard-rules.pro` gains
`-dontwarn com.google.android.play.core.**` with the reason inline. The AAB
builds after it: 52.3 MB (arm64-v8a, armeabi-v7a, x86_64), the new size
baseline; the UI_SPEC delta budgets apply from here.

## D-U17-2026-10-11: UI_SPEC sections 14-18 arrived, D-U01 reconstruction retired

`docs/ui/UI_SPEC.md` now has 1746 lines with sections 14 (copy deck), 15 (brand
assets), 16 (tasks U01-U26), 17 (QA and measurement) and 18 (reading list).
D-U01 recorded the file as truncated at 13.5; that entry stays as history, but
the reconstruction handling is superseded: the missing sections are now the
source of truth.

Compliance pass 2026-10-11 found: copy-deck key names differ from `UiStrings`
field names (text matches under different keys, accepted, no rename); brand
web/Android assets exist except the vector source; `docs/ui/PERF.md` was absent;
one `Opacity` in `arrival_row.dart` violated 11.2; U25/U26 future scaffolding
(alerts, reliability, predictions, ghost markers, composite sources,
`localKudos`, `Saindo
agora`) is entirely absent and stays pending behind
flags-off.

## D-U18-2026-10-11: brand source, perf baseline, alpha dimming by colour

- `design/brand/pontual-mark.svg` added byte-for-byte from UI_SPEC 15. Android
  adaptive + monochrome layers and web splash/manifest already existed; the SVG
  was the only missing source.
- `docs/ui/PERF.md` added (U21): new-UI baseline (web `main.dart.js` 950 KB gz,
  Manrope 50.5 KB, CanvasKit 36.1 MB uncompressed, universal AAB 52.3 MB) with
  the old-UI baseline recorded as absent per AUDIT 4.1. Device rows (cold start,
  frames, memory, per-ABI sizes, Lighthouse) stay TODO for the capable machine
  under the 17.4 protocol.
- `arrival_row.dart` past dimming no longer uses `Opacity` (banned by 11.2,
  forces a saveLayer). `EtaText`, `LineBadge` and `CertaintyBadge` gained
  `dimmed` flags that apply 0.55 alpha to colours only, matching the 7.6 rule
  that past minutes dim by colour alpha.

## D-U19-2026-10-11: UI_SPEC sections 14-18 compliance build (U25, U26, router, copy, home, perf, a11y)

Spec sections 14-18 (copy deck, brand, U01-U26, QA) are now implemented:

- Router: unknown routes render `SystemScreen.notFound` via `errorBuilder` (web
  "Página não encontrada" per section 8); deploy already copies `index.html` to
  `404.html` for Pages deep links.
- Web scroll: `PontualScrollBehavior` drags with mouse, touch, stylus and
  trackpad (section 8).
- Edge-to-edge: transparent status and navigation bars with per-theme icon
  brightness plus `SystemUiMode.edgeToEdge` after the first frame; every screen
  keeps SafeArea (section 8).
- Copy: `tagline` ("Seu ônibus, na hora.") on About; `capacity` uses the exact
  section-14 text for the capacity error code, other limits keep the existing
  busy message (share flow failure reason stays generic because the frozen
  controller maps rate and capacity to one `busy` value).
- U25: `AlertRuleVM`, `ReliabilityVM`, `AlertsStore`, `LiveAware` and
  `Composite` arrivals sources (live wins over predicted over scheduled by
  `certaintyRank`, lower wins), `Features.localKudos`, optional
  `VehicleVM.paceFactor`, future copy (`alertTitle`, `alertSave`, `tabHistory`,
  `typicalDelayOf`, confidence levels and label, pace phrases, prediction title
  and body), `Sparkline`, `ConfidenceMeter`, `AlertSheet`, `ReliabilityCard`
  (empty hides), `PredictionInfoSheet`, all with unit and widget tests plus
  gallery entries. Flags off means shipped screens never mount them.
- U26: `GhostMarker` (dashed predicted style, `~` chip, no pulse) and
  `PredictedPath` (dashed polyline in caller-projected space) with a gallery
  demo covering the 13.1 rules (solid last fix with age, dashed ghost, path,
  confidence plus pace, info sheet, simulated fix flips to live). Real map
  wiring waits for route geometry like the rest of the route line work.
- Home `Saindo agora` feed (13.3): next arrival per shortcut target sorted by
  time, empty until a shortcut has an upcoming departure, ETA upgrades need no
  layout change.
- Perf: debug-only frame-timing logger (`summarizeBuildRaster` plus
  `installFrameTimingLogger`, hooked in the debug gallery) per 11.4.
- A11y: guideline tests over tappables and text in both themes (12.12). Two real
  findings fixed: `Segmented` is now 56 dp tall so segments reach the 48 dp
  target (was 40 with 32 dp segments), and light `scheduled` (`#576964`) plus
  `warningText` (`#9F4B07`) darkened one step so badge captions on the tinted
  pill reach 4.5:1 (rendered 4.36/4.30 before). Token-pair `contrast_test.dart`
  still green.

## D-U20-2026-10-11: map deferred import stays eager, documented

UI_SPEC 11.1 asks for a deferred map import on web. `LineMap` exposes
flutter_map types in its public API (`LatLng` route points, `MapController`
state), so deferring means splitting the widget and adding a loading state on
every platform for a library the app already ships on all of them. Web first
load sits inside the 3 MB budget with the eager import, so the refactor buys no
proven gain against real regression risk in the camera, marker and attribution
layer. Handling: keep the eager import, revisit with measurements if the web
budget regresses.

## D-U21-2026-10-11: full verification green, deploy stays owner-blocked

Verification of the sections 14-18 compliance tree (HEAD `a78320a` plus the
commits in D-U19, all on branch `dev`):

- App: `flutter analyze` clean, `dart format --set-exit-if-changed` clean (196
  files), full `flutter test` green (261 passed, 1 skipped), manifest source
  audit PASS, `flutter build web --release` EXIT 0 (build/web 42.7 MB
  uncompressed, `main.dart.js` 973,863 bytes gz, about 951 KB, no regression vs
  the 950 KB PERF baseline; PLAN 3 MB budget holds).
- Server (unchanged code): `deno fmt --check`, `deno lint`, `deno check` clean;
  `deno task test` 74 passed against an isolated throwaway PG 16 container on
  5433 (migrated with dbmate 2.36.0, dropped afterwards). Never run against a
  live soak DB (T46 rule).
- Tools/data: `deno fmt`, `lint`, `data-test` (3 passed), `data-validate` (21
  lines), `data-build` (9,473 bytes, inside 100 KB) green.
- Workflows: all three YAML files parse. Gitleaks runs in CI (not installed on
  this host).
- Deploy: not executed. `deploy-static.yml` fails fast without the repo var
  `API_ORIGIN` (INFRA-05, owner-blocked) plus the Pages setup, and
  `release-android.yml` needs the upload keystore secrets plus a `v*` tag.
  Pushing `dev` to `master` without the var would only produce a red run, so no
  push was attempted. Owner actions: set `API_ORIGIN` (and optional
  `STATIC_ORIGIN`), enable Pages, merge to `master`.

## D-U22-2026-10-11: device perf method and SDK test dependency

- `integration_test` (Flutter SDK, dev-only) added to `app/pubspec.yaml` for the
  on-device run. Reason: scripted profile measurements need the SDK test
  harness. Size impact: none, dev dependencies never ship in the release APK/AAB
  (verified: split and bundle builds succeed with it present). Maintainer:
  Flutter team, BSD-3-Clause like the SDK. New permissions: none. A transient
  `flutter build apk --analyze-size` failure naming its plugin happened once
  while a wasm compile saturated the machine; the retry on the identical tree
  was green.
- Method: `app/integration_test/perf_app.dart` (measurement-only entrypoint,
  never referenced by release builds) drives Home, Lines and line 60 on fixed
  timings; `tools/perf/device_run.py` installs the release APK, reads cold start
  from the system's Displayed line (am start -W never settles under
  SwiftShader), runs the profile app, captures PSS and screenshots on logcat
  markers, and swipes the map during the soak. Results JSON and shots stay
  gitignored; medians live in `docs/ui/PERF.md`.
- Emulator caveats (Medium_Phone_API_37.0, x86_64, SwiftShader, no KVM): cold
  start and raster are inflated and do not count against hardware budgets; build
  times, PSS and sizes are representative.

## D-U23-2026-10-11: owner-supplied app icon applied (launcher + PWA)

The owner dropped `icon.png` (1254x1254 RGBA, rounded corners transparent),
`icon.jpeg` (1003x1003, opaque, smaller) and `icon.svg` (monochrome auto-trace
silhouette, not full colour) at the repo root and asked to apply the icon and
put each file in its right place. The PNG is the master: it is the largest and
the only one with alpha.

Sources moved to `design/brand/`: `app-icon.png` (master), `app-icon.jpeg`
(reference copy), `app-icon.svg` (trace copy). Root copies removed.
`design/brand/pontual-mark.svg` (UI_SPEC 15 mint-on-pine mark) stays untouched;
the splash, theme tokens and HTML splash keep the pine brand, so launcher and
brand now diverge and a full rebrand is an owner decision for later.

Generated from the master with a throwaway Dart script using package:image 4.5.4
(cubic resampling, temp project outside the repo, no repo dependency added, so
no ADR needed for a package):

- Android legacy: `mipmap-mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi/ic_launcher.png` at
  48/72/96/144/192, transparency kept.
- Android adaptive: `drawable-<dpi>/ic_launcher_foreground.png` at
  108/162/216/324/432 canvas with the artwork inset to the 72dp safe zone on a
  navy fill; `mipmap-anydpi-v26/ic_launcher.xml` and `ic_launcher_round.xml` use
  `@color/pontual_icon_bg` (`#0D3971`, edge-band average of the master) plus the
  raster foreground. The old mint vector `drawable/ic_launcher_foreground.xml`
  is deleted and the `<monochrome>` layer is removed: themed icons fall back to
  the standard icon until someone draws a vector monochrome of the new mark.
- Web: `icons/Icon-192.png`, `icons/Icon-512.png` (rounded corners with
  transparency kept, as in the master; first generated opaque on navy, then
  redone rounded per owner order), `icons/Icon-maskable-192.png`,
  `icons/Icon-maskable-512.png` (artwork at 80 percent on navy, bus inside the
  maskable safe zone), new `icons/Icon-apple-touch-180.png` (180, opaque, iOS
  fills black on transparency), `favicon.png` upgraded from 16 to 32 per UI_SPEC
  15 (rounded with transparency, like the master). `index.html` apple-touch-icon
  points at the 180 file; `manifest.json` names are unchanged.

Verified: `file` dimensions on all 16 PNGs, visual check of the 192 web icon,
the xxxhdpi foreground (navy surround blends with the background) and the 512
maskable, manifest source audit PASS. No Dart code touched; no Android SDK on
this host, so the merged-manifest and install-launch check stays for the release
machine (owner todo).

## D-U24-2026-10-11: Android web banner downloads the release APK

Owner order: on Android, the web PWA is viewer-only; sharing needs the native
app (screen-off trips). A one-time card on Android web (`AndroidAppDownloadSlot`
on Home after welcome plus Settings) pitches the native app; tap downloads the
latest release APK from GitHub releases
(`.../releases/latest/download/app-release.apk`).

Implementation: new `app/lib/platform/web/android_app_download.dart` (gating
pure function, prefs-backed once-only store, card, slot) plus three pt-BR
strings; no new dependency (`url_launcher` externalApplication is already
allow-listed for links). `release-android.yml` now also builds a universal APK
with the same dart-defines and uploads `app-release.apk` alongside the AAB, with
a 25 MB size gate per PLAN 10.1. Display detection uses `kIsWeb` plus
`defaultTargetPlatform == android`, same pattern as the iOS hint.

Accepted limits: sideload needs "install unknown apps" for the browser and, on
certified devices in Brazil, a verified developer (PLAN 3.1); first tagged
release proves the asset name. Verified: analyze clean, targeted tests green
(android download, install hint, home, settings). Full suite timed out on this
host, not run to completion.

## D-U25-2026-10-11: home, sheet, dock and map fix sweep (10 items)

Owner-reported UI issues, fixed on branch `dev` in one commit each (the first
three were already in the tree, verified and kept):

- Home margins (`c945305` kept, plus `7159d67`): search, settings, about,
  privacy, trip, system and line-not-found now use `marginFor`; the Android
  download card uses Space tokens.
- Pill over sheets (`2aebdf0`, `eecb8db` kept, plus `182dac6`): the line pill
  also hides under modal sheets in both layouts, and every new-flow sheet uses
  the transparent safe-area chrome.
- Shortcut sheet (`182dac6`): the line list grows with its content in the outer
  sheet scroll instead of a fixed 240 dp box with a nested scrollable; the
  chooser keeps its list above the keyboard.
- Branch navigation (`ce36162`): the three home links to Linhas use `go`, so the
  bottom bar follows; line detail stays a push.
- Map controls (`409f3e3`): the circle button no longer positions itself, so
  recenter anchors bottom-right above the sheet peek and never covers the back
  button; top controls clear the status inset.
- Viewer position plus city framing (`09681b0`): first-frame fit of the service
  area above the peek sheet; one-shot low-power viewer dot only when permission
  is already granted and data saver is off, drawn only, never prompted, logged
  or sent.
- Pill size (`6f824ef`): the row hugs content with a Flexible label; height,
  margins and semantics unchanged.
- Lines scroll (`ba179ff`): the per-row FutureProvider is a synchronous family
  reading today only, so rows build once; also drops other-day times the merged
  scan could surface.

Verification: no Flutter toolchain on this host, so `flutter
analyze`,
`dart format` and `flutter test` stay for the owner machine (same as the three
kept commits). Every change was review-checked against the covering widget tests
(home, lines, search, line screen, trip flow, design system, a11y) and keeps
their asserted copy and behavior.

## D30-2026-10-11: anonymous momentum for ETA and prediction (owner-approved)

Owner order 2026-10-11: implement ETA, arrival alerts, recents, shortcut
ordering, history/delay and predicted movement under strict anonymity. Drivers
change daily and several times a day, pace swings hour to hour, so nothing may
identify a driver or link trips.

Accepted design (amends D02 narrowly, keeps D20 intent):

- Per-vehicle pace only: one smoothed speed scalar on the Vehicle, reset at
  vehicle creation, updated from accepted fixes, dropped with the vehicle. No
  driver id, no device id, no cross-trip state.
- Per-line recent passages only: in-memory ring of vehicle-sighting epoch
  seconds per line (cap 32, TTL 4 h), no positions, no ids. Source for headway,
  history/delay and reliability cards.
- Snapshot stays backward compatible: pace appended as an optional row field,
  old clients ignore it. New arrivals endpoint is additive.
- Nothing with coordinates reaches PostgreSQL, disk, logs or metrics. Existing
  `no_location_at_rest` and AC17 log audits extend to the new code.
- Recents, shortcuts (home/work/school/university), saved stops and alert rules
  stay in `shared_preferences` only, never sent.
- Predictions are always labeled `predicted` vs `live` in the UI.
- Still required before any pilot: consent-text bump, RIPD and inventory update,
  lawyer review (D20 gate recorded, not skipped).

## D30-followup-2026-10-11: PLAN deltas shipped in this change set

- RF20 (stops/ETA) partial: live hero, live-first ordering and headway history
  ship with no stop coordinates. Per-stop ETA waits for the stops file and route
  geometry.
- RF22 (notifications, favourites, history, delay) partial: favourites already
  existed; history/delay ship as 4 h memory-only aggregates; alerts ship in-app
  only, no push channel (hard limit: no background location, no FCM).
- D02 amended narrowly by D30 (pace scalar plus timestamp ring, both memory-only
  with TTL). Everything else in D02 stands: no tracks, no coordinates at rest.
- Verification split: server pure suites green here (engine 28, arrivals 5,
  no_location_at_rest, config); DB-backed suites (read/trip/security/ws/jobs)
  and every Flutter check stay for the owner machine and CI (no Flutter
  toolchain on this host).

## D-U26-2026-10-11: owner UI issue sweep (8 items)

Owner-reported UI issues, fixed in one change set (flutter checks stay for the
owner machine per the standing instruction, same verification split as D-U25):

- No-live margin: the empty card had no header and no top spacing, so it sat
  almost glued to the first-run shortcut strip. It now reserves Space.x4 above
  itself on Inicio only.
- Shortcut card layout: badge plus Spacer plus Flexible squeezed the 34 sp clock
  until "18:00" clipped to "17". The badge shares the label row now and the ETA
  keeps the full card width.
- First-run placeholders: 4 kinds (Casa, Trabalho, Escola, Faculdade) down to
  Casa and Trabalho. The add sheet still offers every kind, so the rider adds
  others later.
- Pill over sheets: every production sheet now opens with useRootNavigator, so
  it slides above the shell dock pill (the pill lives above the branch
  navigators; a branch-level sheet slid under it). The isCurrent hiding stays as
  a fallback. Root cause of the D-U25 recurrence, which hid without rebuilding.
- Sheet titles: PontualSheet titles used 4 dp side margins against 24 dp in the
  body. Titles now use Space.x6 like the body, which fixes "Adicionar atalho",
  "Em qual linha você está?" and every other PontualSheet title at once (alert,
  prediction, consent, settings info, shortcut actions).
- Clipped times: the Agora hero box was 128 dp while a 56 sp clock ("06:40")
  needs about 141, so the last digit clipped to "06:4". The box is 160 dp now
  with scale-down (never up) for longer values and large text scales; EtaText
  and LineRow fall back to ellipsis instead of a hard clip. The timetable rail
  now passes minute parts ("40" under hour "06", the gallery contract): full
  strings rebuilt "06:06:40" values, broke the past dimming and never matched
  the next-departure highlight. The Horarios hero showed the first departure of
  the day instead of the documented next one (the rail tests only masked this
  through the full-time chips); the hero now selects `next`.
- Map on poor connections: bundling or prefetching OSM tiles is rejected (OSM
  tile policy forbids bulk downloading; AGENTS.md 15 hard limit; RNF14 size
  budget). Poor connections keep the compliant path: the 50 MB organic tile
  cache seeded on good networks, the data-saver list-first mode, offline-first
  timetables, and markers plus sheet content that never need tiles. Self-hosted
  vector tiles stay a future owner decision with its own ADR.
- Day-aware arrivals: TimetableArrivalsSource merged every day type, so on
  Sunday a weekday-only line (e.g. 66) showed a weekday 18:00 as "next".
  Departures now filter to the day type of now, matching the lines list rule
  from D-U25. A day with no schedules returns empty (card shows "--", Saindo
  agora skips) instead of a wrong time.
- 2026-10-12: Home-screen brief deviations (D29, Accepted, pending owner review
  on a Flutter-capable machine). The brief `home-screen.md` asked for an
  extended FAB (C1); the app keeps the global `TripDock` pill per UI_SPEC 7.1,
  which already fixes the reported overlap via `dockClearance` and owns the
  sharing-active state. Cards stay at the 156 dp token instead of 168 dp (C2);
  the 2-line label plus direction line fixes the reported truncation. Recents
  stay as chips capped at 4 (C6) and live rows keep `LineRow` without ages (C5):
  the live endpoint exposes counts only, and ages would need a contract change
  the brief forbids. The 1-minute clock tick stays instead of a 30 s ticker
  (C8): countdowns are minute-granular and a faster tick costs battery on the
  entry-level phones in PLAN 3.3. `formatEta` keeps regular spaces (C8): its
  unit tests pin them. No cache-age line (C10): needs cache-age plumbing through
  `StaticDataRepository`, left for a follow-up. Line colors (C9) were already
  done via `line_colors.dart`. Full audit and report in
  `docs/ui/home-redesign.md`. Not verified here: no Flutter SDK on this machine,
  so `flutter analyze` and `flutter test` must run elsewhere before merge.
- 2026-10-12: Lines-screen brief deviations (D31, Accepted, pending owner review
  on a Flutter-capable machine). The brief `lines-screen.md` asked for a shared
  30-second ticker (L1); the screen keeps the 1-minute `nowTickProvider` since
  countdowns are minute-granular and a faster tick costs battery on the PLAN 3.3
  phones (same call as D29). No bottom sheet for unsupported lines (L2): the
  line detail already renders empty timetables plus the non-pilot note, so rows
  stay tappable with no sheet. The app uses the global dock pill, not a FAB
  (L8), keeping `dockClearance`. Favorites copy drops the Home clause (L7):
  favorites do not feed Home shortcuts (separate store). Inline search skipped
  (L9) via the brief escape hatch: global Busca already covers the same index
  offline for 21 rows. No `Expresso` tag: not trivially derivable. Full audit
  and report in `docs/ui/lines-redesign.md`. Not verified here: per the task
  instruction no Flutter tooling ran in this session, so `flutter
  analyze`,
  `flutter test`, screenshots and size profiling must run elsewhere before
  merge.
- 2026-10-12: Line-detail brief deviations (D32, Accepted, pending owner review
  on a Flutter-capable machine). The brief `line-screen.md` describes the old
  map plus bottom-sheet UI; the new UI already covers D1 bounds plus cache plus
  scrim, D2 snaps, D8 segmented and the shared next-departure core, so this pass
  is polish only. Full-screen sheet at D2 skipped: full stays 0.92 with the map
  behind instead of hiding the map and adding a top bar, keeping the live
  context rows act on. FAB at D5 skipped: the global dock pill plus `LineDock`
  own sharing per UI_SPEC 7.1 (same call as D29 and D31); no `Qual o sentido?`
  sheet, the line chooser plus consent flow stays. Per-line origin memory at D6
  deferred: needs a new prefs store through the timetable tab, left as a
  follow-up like lines C10. Holiday auto-detection plus 30 s ticker at D9
  skipped: 1-minute tick stays on battery grounds (same call as D29 and D31) and
  `Dom/Feriados` stays manual per UI_SPEC 7.6. Per-direction triplets at D4
  skipped: times merge origins like the D-U26 lines rule; live vehicles carry no
  direction signal. Dark `ColorFiltered` at D1 skipped: the `mapScrim` tint
  stays (no GPU cost). Header next chip hides while live (same live-wins rule as
  the lines rows). Full audit and report in `docs/ui/line-detail-redesign.md`.
  Not verified here: per the task instruction no Flutter tooling ran in this
  session, so `flutter
  analyze`, `flutter test`, screenshots and size
  profiling must run elsewhere before merge.

## D40-2026-10-12: offline vector city map pipeline (Accepted, renderer Proposed)

Plan-conformant exit of D12/R-05: one 43.6 MB Protomaps v4 `.pmtiles` extract
(build 20261012, bbox -40.46,-19.20,-39.50,-18.39 covering OSM relation 1834958
plus buffer and the app pan bounds) serves both themes via two bundled MapLibre
v8 styles (`app/assets/map/protomaps-*.json`, no sprites, relative glyphs,
`coalesce(name:pt, name)` labels). Measured: z0-15 43.6 MB, z0-14 28.1, z0-13
17.8, z0-12 10.6; even z12 breaks the 15 MB RNF14 budget, so the file is fetched
once from our own static host (range reads on web, app-storage copy on Android),
never bundled, never from a third-party tile server. Reproducible via
`deno task map-bbox|map-extract|map-verify` (tools/map). Renderer choice:
`maplibre_gl` (BSD-3-Clause, GPLv2-compatible, maintained, PMTiles on
Android/iOS/web) over stale `vector_map_tiles*` (pins flutter_map ^7,
unmaintained since 2024); NOT added here, needs its own ADR (APK delta, manifest
audit, low-end render test) plus owner approval per AGENTS.md 6. Raster fallback
rejected with numbers (tens of thousands of tiles per theme, hundreds of MB).
License findings: project treated as GPLv2-only; new items are
BSD-3/MIT/CC0/OFL/ODbL (data), all compatible; pre-existing `latlong2`
Apache-2.0 conflict flagged for INFRA-19. Full record in docs/maps.md. Verified
here: deno fmt/lint/check plus map tests green, `flutter analyze` clean, 6 new
client tests pass. Not verified here: Pages range-request check (needs deploy),
glyph generation, renderer integration, device/network measurements (no Android
SDK or phone on this host).

## D-U27-2026-10-12: single consent sheet in the new share flow

Owner report: accepting consent and location never started the trip and recorded
nothing. Root cause was the double consent: the new flow showed the ConsentBody
disclosure (writes nothing per D-U13 and UI_SPEC 0.1 rule 2), then shareTrip
showed the legacy ConsentSheet again with the same title and button. Riders
accepted once, met the identical sheet a second time, dismissed it as stuck, and
the decline path ends silently with nothing recorded.

Fix: shareTrip takes an optional consentAnswer override. The new flow passes
`() async => true` after its disclosure (or when none was needed), so
ensureConsent still writes the store and posts to the server exactly once, but
no second sheet appears. Legacy default (null) is byte-for-byte unchanged.
Permission path untouched: one pre-prompt plus the OS dialog, then the progress
sheet.

Verified: flutter analyze clean, full flutter test green (320 passed), targeted
trip_flow plus share_flow tests updated (the denial test now asserts no second
consent sheet before the permission card).

## D-U27-followup-2026-10-12: startShare used a dying context and ref

Field report on the fixed build: after accepting the disclosure the sheet closed
and nothing followed, not even the pre-prompt. Reproduced under the real router:
`consent step=true mounted=false`. Root cause: the dock hides itself under any
open sheet (D-U25 pill rule), so the BuildContext and WidgetRef captured at tap
time both die as soon as the first sheet opens. Every later `mounted` check
failed, and any `ref.read` after an async gap would throw once disposed. The
widget tests never caught it because their button never unmounts.

Fix: startShare resolves the root navigator context plus
`ProviderScope.containerOf` synchronously at tap time and threads only those
down (trip_flow, shareTrip, retry path). The `ref` parameter is gone from
startShare; shareTrip takes the container. Also fixed on the way: the
progress-sheet retry dropped consentAnswer, which would have resurrected the
double sheet on retry. Regression test
`share survives
the caller unmounting under sheets` uses a self-hiding dock and
fails without the fix. Unexpected throws still show the connection snackbar
instead of closing silently. Not pushed: owner tests locally first, production
PWA still serves the pre-fix build until master is pushed and Pages rebuilds.

## D-U28-2026-10-12: recenter targets viewer at neighbourhood zoom, sheet no longer moves camera

Request: recenter button focuses the viewer at neighbourhood scale, city centre
is the fallback everywhere (no location, map just opened), and expanding the
line details sheet stops moving the map.

Change: added `cityZoom` (13) and `neighbourhoodZoom` (14) plus
`LineMapState.centerOnViewer()` (viewer at 14, else city centre at 13). Recenter
now calls `centerOnViewer()` instead of `fitToContent()` (vehicles); removed the
duplicate fit in the button. `_initialCenter()` and `fitToContent()` fallbacks
stay city centre. Removed the sheet-settle listener (`_onSheetChanged`) so
dragging peek/half/full never refits the camera; the one enter-time
`fitToContent()` with peek padding stays. Viewer one-shot framing (no vehicles,
not panned) now uses neighbourhood zoom.

Verified: `flutter analyze` clean on both files,
`flutter test test/ui/line_screen_test.dart` 4 passed. Full suite not run to
green (timed out locally).

## D-U30-2026-10-12: test suite slimmed for speed, 46 files to 28

Request: `flutter test` too big and slow; remove the unimportant parts and make
the rest faster.

Change (tests only, no production code): deleted 8 files outright -
`future_components` and `future_models` (flagged-off, never mounted in shipped
screens), `gallery` (design-system smoke, not user-facing), `frame_timing` (two
trivial math asserts), `sharing_signals` (duplicate of `sharing_health`),
`lines_logic` (folded the one unique grouping test into `line_category`), `map`
(single tile assertion folded into `offline_map`), `trip_screen` (IssueDebouncer
cases moved to `trip_domain`; layout duplicates of `trip_settings` dropped).
Merged 11 more files into 4: seven pure-logic files into `ui/ui_logic_test.dart`
(65 tests, one process), `api` into `bus_api`, `install_hint` +
`android_app_download` into `web_prompts`, `trip_flow` into `share_flow`,
`timetable_tab` into `line_screen`. Consolidated `search_lines` 14 to 7 and
`trip_settings` 12 to 7 widget tests; replaced `pumpAndSettle` with single fixed
pumps where the screens have no entrance animation, and real `Future.delayed`
waits with `Duration.zero`/microtask flushes in unit tests. Sheet-flow tests
keep `pumpAndSettle`: a single fixed pump does not finish bottom-sheet entrance
(9 failures on the first attempt, reverted).

Kept: every PLAN 15.3 minimum (reducer, sampling, PingClient, auto-end,
VehicleRepository, static data, S03/S04/S05/S06/S08/S11 widgets).

Verified: full suite 304 passed + 1 pre-existing skip, `flutter
analyze` clean,
`dart format` clean. Wall 99 s to ~90 s on a loaded 4-core box; the bottleneck
is per-file process startup, so fewer files is what moves it.

## D-U29-2026-10-12: map tile failure recovery and deterministic enter fit

Field report: the line map stayed blank until the first gesture, and some zoom
positions rendered fully black or in blocks, despite the tile cache.

Diagnosis, all verified in code: on web the built-in caching provider is a
disabled stub, so the PWA has no tile cache at all (Android native has the 50 MB
file cache); only HTTP 200 tiles are ever cached, failures never are; the burst
fired on open hits tile.openstreetmap.org, which throttles bursty anonymous
clients (on web our User-Agent cannot even be sent); failed tiles rendered as
the surface background (near-black in dark mode) with no error or loading
surface; and the one-shot initState fit silently no-oped while lines loaded
async, so the framing never ran on cold open.

Change: tile seam exposes a coordinate-free error callback plus a reset stream
and evicts failed tiles when pruned; the map schedules a bounded backoff reload
(2/4/8 s, max 3 per 30 s burst window) through that stream; the enter fit runs
from the first build with a map plus one refit when vehicles arrive after an
empty first fit; sheet movement still never moves the camera. No coordinates are
read or logged in the error path.

Verified: flutter analyze clean, offline_map_test (4 new assertions) and
line_screen_test green. Production traffic still belongs on a self-hosted tile
host per D12/D-U26; this only makes the OSM fallback recover.

## D-U31-2026-10-12: two map locate buttons (viewer dot, closest bus)

Request: the single recenter button did not focus the right place. Split it into
two controls in one bottom-right column, shown after panning as before. The
viewer button centres the dot at neighbourhood zoom 14 (city centre at 13 when
unknown); the bus button centres the live vehicle closest to the viewer dot, or
to the camera centre when the dot is unknown, at street zoom 15, falling back to
the city centre with no live vehicles. Distance uses the shared haversine
helper. The old single button and its string are removed.

Verified: flutter analyze clean, line_screen_test plus offline_map_test green
(18 passed).

## D41-2026-10-13: docs and asset locations outside AGENTS.md section 14

AGENTS.md section 14 allows only `docs/privacy/`, `docs/security/`,
`docs/runbooks/`, `docs/field-tests/` under `docs/`, plus seven fixed root
files. The tree has three established exceptions predating this audit:
`docs/ui/` (UI_SPEC, VERIFY-NOTES, AUDIT, PERF, redesign notes), `design/brand/`
(icon masters and the brand mark source), and `docs/maps.md` (offline map
pipeline notes). Moving them now would break a dozen references for no runtime
benefit.

Handling (Accepted): keep all three where they are; propose amending AGENTS.md
section 14 to list `docs/ui/` and `design/` as allowed homes for UI spec work
and brand sources. `step.md` (stale 2026-10-04 progress notes, a root allow-list
violation) moves to `docs/runbooks/step-history.md` in this change set; the
historical prose mention of `step.md` above stays untouched per the append-only
rule.

## D42-2026-10-13: deep-audit deferred items with rationale (Accepted)

A three-track audit (app, server, tools/data/docs/CI) on 2026-10-13 found no P0.
Fixed in this change set: `stream_channel` to dev_dependencies, `trip_screen`
import order, `build.gradle.kts` TODO format, server type and logging hygiene
(TickResult dup, Ctx status type, content-length NaN guard, onError through
Log.error), auth cache token-expiry revalidation, scoped
`map-extract`/`map-verify` flags, SECURITY and PRIVACY markers on auth and
location code, and the DELETE guard rationale comment. Deferred with rationale,
each needs its own task and owner sign-off where noted:

- WS messages use hand-rolled checks in `server/src/ws/hub.ts`, not the Valibot
  strict schema. Migrating changes the public stream contract, so it needs a
  dedicated task with compatibility tests, not a drive-by.
- `app_config.max_active_trips` loads but capacity enforces the engine default
  (both 300). Wiring the DB knob into the trip path changes capacity behavior
  under load; dedicated task with a capacity test.
- `pontual_app` holds insert/update/delete on `app_config` but only selects it.
  Tightening needs a forward-only migration (0001 is merged and immutable)
  applied by the owner; dedicated task, never against prod without explicit
  authorization.
- Marker cap (20) labels use the capped list, so >20 vehicles per line would
  under-report. Unlikely at alpha scale; fix with the uncapped count when scale
  demands, with widget tests.
- `TripController` (861 lines, `startTrip` ~219) and the geolocator/http calls
  inside `viewer_location`, `trip_status`, and `line_map` are the real
  architecture debt. Splitting and re-seaming needs widget plus lifecycle tests
  per slice; one slice per task, not one big rewrite.
- `route` tool writes `data/routes/` while PLAN 14.5 says `--allow-write=build`;
  the routes directory is the committed source of truth the builder reads, so
  the write is intentional. Propose a one-line PLAN clarification instead of
  moving the output.

## D43-2026-10-13: optimization sweep, three server wins landed (Accepted)

Four-track optimization audit (server hot path, client runtime, client
rendering, build size) on 2026-10-13, every claim verified in code. Landed in
this change set, each with suite cover (83 passed, 0 failed):

- Tick events leak (HIGH, real bug): the shared `events` array passed to
  `startJobs` was never drained; every timed-out trip appended a `tripEnded` for
  process lifetime. `runTickGuarded` now clears the scratch buffer after each
  tick; nothing reads it (`onTick` uses `changedLines` only). Regression test
  asserts empty after tick.
- Teleport double haversine (MED): `impliedSpeedMps` recomputed the distance
  `applyPing` already had. It now takes the precomputed value. One haversine per
  ping on that path. No behavior change.
- Redundant prune sweep (LOW): `recordPassage` ran the full multi-line TTL scan
  on every vehicle creation; it now prunes only the touched line. The 5 s tick
  and the arrivals read keep the full sweep.

Verified non-issues (do not fix): guard DB calls already parallel, WS fan-out
and heartbeat share one payload string, tick has an idle fast-path, indexes
cover the ping path, ETag/304 and keep-alive are correct, ping pacing (D29)
holds, gallery and frame logger are release-stripped, `design/brand` masters are
not bundled.

Deferred with rationale, each a dedicated task:

- Server: cache or single-query the guard (`blocked` + consent on every ping,
  ~40 qps at 300 trips); `byVehicle` index plus a snapshot cache that excludes
  `t` from the ETag (today every poll rebuilds and the ETag turns over every
  second); route bbox pre-reject; tick without spread plus index-based member
  counts; ETag on `/v1/live`.
- Client: iOS `AppleSettings` per sampling mode (GPS never sleeps on iPhones
  today); stop viewer stream/watchdog when backgrounded; `autoDispose` on
  `vehicleTickProvider`/`vehiclesVmProvider`; pause the web location stream
  while hidden; memoize the vehicle list so the map plus sheet stop rebuilding
  every 5 s on unchanged data.
- Rendering: split `LineScreen.build` into leaf consumers, key map markers with
  `ValueKey`, gate pulse builders to live certainty, un-nest the timetable rail
  scrollable, shrink the sheet shadow.
- Size: Android arm64 is ~20.8 MB vs the 15 MB budget (structural: libflutter
  plus libapp plus dex; confirm per-ABI split delivery, audit `classes.dex`,
  report per-ABI in CI); web is ~3.10 MB gz vs 3.0 MB (serve brotli or ADR the
  overage; app JS is only a third of first load); dedupe `ink_sparkle.frag`;
  document the variable-font weight stanza.

## D44-2026-10-13: ten optimization passes, all landed green (Accepted)

Follow-up to D43. Ten focused passes, each researched, implemented, verified,
and committed separately. Server suite 88 passed 0 failed (throwaway PG16,
up-section applied via psql after the dbmate binary download proved corrupt);
app suite 307 passed 1 skipped; fmt, lint, check, and analyze clean on every
pass.

- P1 route bbox: bundle load wraps geometry in `RouteShape` with a precomputed
  box; the per-ping check skips the O(segments) scan when the box edge alone
  exceeds the max. New `geo_test` (4 tests).
- P2 guard query: `db/guard.ts` answers block plus consent in one round trip,
  halving ping-path queries. `db_test` covers all four state combinations.
- P3 dead tick: deleted watcher-less `nowSecondTickProvider` (1 s
  process-lifetime wakeup).
- P4 viewer dot: `viewerLocationProvider` is autoDispose now, matching its
  documented per-mount lookup and fixing the stale-dot case.
- P5 map markers: stable `ValueKey` on `Marker` plus `VehicleMarker` for
  incremental reconciliation across the 5 s age re-sort.
- P6 row keys: sheet vehicle rows and home live rows keyed for the same re-sort
  reason.
- P7 skeleton: `SkeletonHost` honors `TickerMode` like `LivePulse`.
- P8 socket time: one `nowMs` for subscribe rate limiting plus the snapshot
  instead of two clocks that could straddle a second.
- P9 hex dedupe: single `hashHex` in `security/token.ts`; the auth and account
  copies are gone. Revocation path unchanged.
- P10 vehicle tick: `vehicleTickProvider` plus `vehiclesVmProvider` are
  autoDispose, so the permanent 5 s isolate wakeup ends when the last line
  screen unmounts.

Still deferred (dedicated tasks): `byVehicle` index plus snapshot cache
excluding `t` from the ETag; ETag on `/v1/live`; tick without spread plus index
member counts; iOS `AppleSettings` per mode; background viewer-stream stop; web
hidden-tab GPS pause; sheet/map rebuild memoization; `LineScreen.build` leaf
split; timetable rail un-nesting; size-budget ADRs for arm64 (~20.8 vs 15 MB)
and web (~3.10 vs 3.0 MB gz).

## D45-2026-10-13: ping cadence toward 5 s map updates (Accepted)

Field report: bus positions often arrived 30 s apart, sometimes 45 s, even on
stable GPS and data. Owner order: the bus must update around every 5 s.

Change: leader moving 15 s to 5 s, leader still 30 s to 15 s, follower 90 s to
45 s, waiting 20 s to 10 s. Server `defaultEngineConfig` plus the client
`settingsFor` stream intervals move together, so the location stream always
emits at least as fast as the instructed `n`. PLAN.md RF08, section 6.3 table,
section 8.5 sampling table, KL1, and RNF03 updated in the same change set.

Trade-offs: leader data rises to about 0.45 MB/h and follower to about 0.05 MB/h
at the measured 0.62 KB per ping (RNF03 updated, still tiny in absolute terms).
Leader battery cost rises with 5 s high-accuracy GPS plus radio; RNF02 (4
percent/h) is unchanged and must be confirmed on phones in the T47 field test.
The 4 s `min_ping_interval_s` rate guard is untouched, so fast web streams still
sample safely. Follower promotion worst case halves to about 45 s (KL1).

## D45-verify-2026-10-13: 5 s cadence proven on a live smoke server

Isolated server on 8081 plus throwaway PG (owner 8080 process left untouched):
start answers W/n:10, second moving ping promotes to L/n:5, leader holds n:5,
snapshot age 6 s with pace. Sim 75 s (1 bus, 2 riders, line 60): 30 pings, 1
hand-over, 28 WS snapshots, lastVehicleAgeS 0, p95 5 s, zero errors.

## D46-2026-10-13: stops layer promoted to alpha, OSM seed (Accepted)

Field report: no stop points on the map. Owner order promotes RF20 (stops layer)
from later to alpha scope; per-stop ETA and user-relative scheduled times stay
pending on coverage plus route geometry.

Findings: OpenStreetMap holds only 8 waiting-place nodes for the whole city (6
`highway=bus_stop`, 2 `public_transport=platform`, all near the center, mostly
unnamed); `stop_position` nodes are on-road points, not waiting places, and were
excluded. City-wide coverage needs an owner field survey, like route traces
(T17). Nothing was invented: every stop carries its OSM node id and `src`.

Shipped: `data/stops.json` source plus schema, validation, and content-hashed
bundle output with a manifest key (old readers ignore it); offline-first client
load with cached-then-bundle fallback that never breaks lines; stop dots on the
line map under the vehicles; assets and Pages publish wired. Survey-scale
hundreds will need a zoom gate or cap on the marker layer.

## D47-2026-10-13: stale-pump poisoning, dead gone/auth, revive-once (Accepted)

Field report: sharing looked active but sent nothing for minutes, and a second
trip ended on its first pings. Code inspection proved three linked defects, all
fixed in one change set:

- The ping pump outlived the trip. `_stopLocal` dropped the client without
  stopping a retry parked in backoff (up to 60 s), which woke up and applied a
  stale fix to the next trip's server record: same device, so the server cannot
  tell the trips apart. Stale seq numbers got real fixes ignored as duplicates,
  stale positions jumped the marker, and bad ones spent strikes on the innocent
  trip. `PingClient.close()` (called on every local stop) ends all future sends
  and outcomes.
- Terminal record states never surfaced. The send closure collapsed every HTTP
  error to status 0, so the designed 401-refresh and 404-gone outcomes were dead
  code: trips hung offline forever on a deleted record instead of ending or
  resuming. `gone` and `auth` codes now map to 404/401 replies; everything
  transient still backs off. A persistently dead token now ends the trip.
- No resume existed. A `gone` on a live trip (own late trip-end, server restart
  per KL6) re-creates the record once with `resume: true` while the loop keeps
  running; adoption bumps the trip generation so straggler 404s cannot kill the
  revived trip. Anything else, or a second `gone`, ends exactly like before.

## D48-2026-10-13: share lifecycle races and notify guard (Accepted)

Re-audit of lifecycle races in the same family as D47:

- Double taps (or two docks at once) ran duplicate share flows with duplicate
  controllers, sheets, and server trips. `startShare` is now single-flight; the
  flag always clears in `finally`.
- `TripHost.attach` overwrote without disposing, leaking a previous controller
  that kept pinging behind the new trip. It now disposes a different previous
  controller (same instance is a no-op).
- `confirmStillRiding` called `notifyListeners` unguarded; the RF16 dialog can
  outlive the route. Now a no-op after dispose. The other notify sites were
  audited safe (disposed state, reset supervisor, or existing `_disposed`
  checks).
- Server pass: tick iteration, hub fan-out, job guards, and rate limiter state
  are safe; start/delete event lag self-heals on the 5 s tick by design, no
  change.
- Deferred with reason: home feed live rows still read "Agora" without positions
  (needs home positions plumbing), per-stop scheduled ETAs need stop coverage
  plus geometry, route-following needs T17 traces.

## D49-2026-10-13: stops resurvey, 8 to 12 OSM nodes (Accepted)

Field report said the stop dots do not reflect real stops. Checked against live
OSM via Overpass plus every outside source named:

- Client render verified correct (`LatLng(stop.lat, stop.lng)`,
  `StopPoint.fromJson` maps lat to lat): the 8 stored dots sit exactly on their
  OSM nodes, so nothing is misplaced by code. The complaint is coverage: 6
  unnamed center nodes plus 2 named "Ponto de ônibus" for a whole city.
- The first seed missed 4 in-bbox nodes that all predate it (2018-2023): named
  `Guriri`, 2x `Entrada do Jaguaré`, one unnamed northern coastal stop. Added
  with `src: osm`, ids sorted, validator plus builder green (12 stops).
- No other licensed coordinates exist: operator site and onibus.online carry
  street itineraries only, SGBus/Mobilibus has no public API or open data,
  Google/Moovit are proprietary (Moovit scraping is a hard limit), no GTFS feed.
  Full coverage still needs the owner field survey with mapping into OSM (T17
  pattern).

## D50-2026-10-13: prediction horizon starts at staleness onset (Accepted)

Bug: `vehicleVmOf` checked `ageS <= predictedWhileS` (30 s) after the live
branch already took every age under `liveFreshS` (45 s), so the predicted branch
was unreachable dead code. No bus ever rendered as a labeled moving prediction,
and the `liveHeroOf` predicted fallback plus the ghost-marker chain never fired:
stale buses flipped straight from live to gray hold, and the hero ETA vanished
instead of degrading. The df71a38 cap (120 to 30 s) caused it by shrinking the
window below the live threshold, and its test used age 25 (live, not stale), so
the red test hid inside a green-file claim.

Fix: the 30 s window now runs past the staleness onset
(`ageS <= liveFreshS + predictedWhileS`, 75 s total horizon). Tests use
genuinely stale ages: 50 for predict-forward, 80 for hold-at-fix. Stopped and
very-old cases unchanged.

## D51-2026-10-13: predicted arrivals exempt from staleness flip (Accepted)

Follow-up to D50: `isStaleArrival` marked every non-scheduled arrival with
`asOf` older than 45 s as stale, including predicted ones (age 46-75 by design).
Any caller would have flipped a labeled prediction back to a stale "Última
posição" row. Narrowed to live-only aging; scheduled never stales, predicted
carries its horizon upstream. No production caller today; the helper plus one
new test pin the contract for the next caller.

## D52-2026-10-13: per-stop ETA and user-relative times hunt list (Proposed)

Owner order: keep this list open and work it until done. Status per item;
nothing here invents stop coordinates or line-stop mapping.

- Per-stop ETA (bus arrives at stop X in N min). Needs all three: (a) stop
  coverage (12 OSM nodes after D49; hundreds needed, owner field survey mapping
  into OSM), (b) line-to-stop mapping (no source: itineraries are street names,
  no GTFS, SGBus API is private), (c) route geometry for along-route distance
  (T17 traces). Until then any "ETA" is straight-line distance over pace, a
  lower bound only. No code ships until (a) plus (b) exist; (c) upgrades
  accuracy later. Next action is owner-side: survey plus outreach to the
  operator for the stop registry.
- Scheduled user-relative times ("your bus in 12 min"). Same blocker: timetables
  are per line plus origin, and without (b) no departure can be attributed to a
  stop. Ships with the same data.
- Home live rows read "Agora" with no distance. Verified honest: `isLive` comes
  from the server `/v1/live` counts, so a row means a bus is actually out on
  that line; tap leads to the live map. Positions plumbing (one stream per
  shortcut line) is a proposed enhancement, not a fix: it reintroduces
  multi-socket fan-out with battery and data cost, so it needs an owner decision
  plus budget measurement first. Not built here.
- Stops layer itself (RF20 first half) is done: D46 seed, D49 resurvey to 12,
  dots on the line map, offline-first repo.

## D53-2026-10-13: progress sheet popped on the wrong navigator (Accepted)

Bug: the share progress sheet opens with `useRootNavigator: true` (above the
shell dock pill, D-U26), but the success path closed it with a branch
`Navigator.of(context).pop()`. Under the production `StatefulShellRoute` that
pop is a silent no-op, stranding the stale progress sheet over the trip screen
until the rider manually closes it. Widget tests never caught it:
single-navigator harnesses make root and branch pops identical.

Fix: pop through the root navigator on success, and clear the `sheetOpen` flag
synchronously in every sheet-button callback so a user close racing a start
completion cannot double-pop. Verified by reading only; needs a shell-harness
widget test plus a device pass (no Flutter toolchain on this host).

## D54-2026-10-13: consent revoke half-life (Accepted client half, Proposed server half)

Bug: "revogar consentimento" cleared only the local acceptance key. The server
confirmation key survived, so the next acceptance skipped the POST and rode on
the pre-revoke server record: revocation never reached the server in any form.
Fixed client-side: revoke now also forgets the confirmation, so the next
acceptance re-posts (reaffirmation within the current contract, quota-safe).

Proposed, pending owner: true server-side revocation needs a
`DELETE /v1/consents` endpoint (device-scoped delete, no migration). That is a
public contract addition, so it ships only with a PLAN amendment and owner
sign-off. Until then the privacy text must not claim server-side revocation; it
promises re-asking, which holds.

## D55-2026-10-13: live dots survive a failed poll (Accepted)

Bug: any failed `GET /v1/live` made `liveProvider` return empty, so every live
badge across home, lines, and search blanked for up to 30 s on any network blip
(flickering dots, unstable visualization). Fixed with a last-good holder:
success refreshes it, failure serves it, and the very first failure still serves
empty. Covered by a new `live_provider_test.dart` (keeps dots, starts empty).

## D56-2026-10-13: cancel racing the create POST opened zombie trips (Accepted)

Bug: `cancelStart` during the `POST /v1/trip` window left `_cancelled` set but
nothing checked it after the POST returned, so the flow confirmed the start and
opened a trip with no fixes, no pings, and no supervisor (rounds early-return on
null). The trip screen showed a fake-active share; the orphan server record
lingered unpublished to its timeout. Hittable on slow networks where the POST
window is seconds, not milliseconds.

Fix: check `aborted()` after the create POST like every other step; on cancel,
end the fresh record best-effort via `_finish` and report `declined` (silent,
like every other cancel). Regression test feeds a fix, cancels under a hanging
POST, and asserts `false`, `declined`, idle, plus exactly one DELETE.

## D57-2026-10-14: ping refresh zone-escape and refresh loop (Accepted)

Two defects in `PingClient` found by code audit:

- A throwing `refreshToken` (registration transport trouble) escaped `_pump`
  into the zone as an uncaught async error. Now it backs off and retries the fix
  like any transient failure.
- `_refreshed` reset on every non-first-401 reply, so an alternating 401/500
  sequence refreshed forever, burning the registration rate caps. Only a 200
  re-arms the single refresh now; a later 401 ends the trip via the `auth`
  outcome as designed.

Covered by two new `ping_test` cases (failing-refresh recovery, single refresh
across transient errors). Needs `flutter test` on a Flutter machine; none here.

## D58-2026-10-14: CI and deploy repair (Accepted)

CI (`ci.yml`) was red on branch `dev` and `deploy-static.yml` could not build
offline tiles. Four root causes, all fixed on `dev`:

- `flutter analyze` errors: `test/live_provider_test.dart` used `<Override>`
  without importing it (Riverpod 3 moved `Override` to
  `package:flutter_riverpod/misc.dart`, the pattern
  `test/ui/line_screen_test.dart` already uses), and
  `test/ui/ui_logic_test.dart` had an ambiguous `LatLng` (latlong2 vs
  `core/geo`): the geo import is now prefixed as `geo` like the adapter does,
  with the two `predictPosition` uses qualified. Also fixed the
  `unawaited_return_in_try_block` warning in `lib/app/providers.dart` (await
  into a local, then return).
- `dart format` drift on 6 files: reformatted in place, no semantic change.
- `flutter test`: 3 `startShare` cases in `test/share_flow_test.dart` failed
  only in full-file runs (each passes alone). The static `_shareInFlight` guard
  in `lib/ui/features/trip/trip_flow.dart` leaked across tests: the chooser test
  abandoned an open sheet, so every later `startShare` returned immediately.
  Production is unaffected (a flow always resolves while the process lives), so
  the fix is test-side only: each test dismisses its sheet at the end, letting
  the flow finish and release the guard.
- Deploy tiles: `tools/deno.json` `map-extract` and `map-verify` could not touch
  their output (`../build/sao_mateus.pmtiles`): the tasks allowed reads of
  `./map`, `../data/routes` and `.` only, so `Deno.stat` failed with
  `NotCapable` (proven with a stub `pmtiles` on PATH). Added `../build` to the
  allow-read lists; no allow-write needed (the child process writes, Deno only
  stats). Verified with the stub: extract and verify exit 0.

Verified on this host: `flutter analyze` clean, `dart format` clean, full app
suite green (331 passed, 1 skipped), `deno fmt`/`lint`/`check` clean, server
suite 88 green on a throwaway docker PG 16 (migrated with dbmate 2.36.0, dropped
afterwards), tools `data-test`/`map-test`/`data-validate` green, `data-build`
10,546 bytes inside the 100 KB gate, manifest audit PASS,
`flutter build web --release` exit 0, and the CI-shaped server smoke (60 s sim,
line 7) clean. All three workflows parse. Owner side unchanged: `API_ORIGIN`
repo var plus Pages setup for `deploy-static`, keystore secrets plus a `v*` tag
for `release-android`.

## D59-2026-10-16: background survival plus 5 s map latency (Accepted)

Field report on two phones (sharer plus viewer, moving bus, Samsung and Xiaomi
OEM skins): background sharing stops in all three forms (notification gone and
trip ended, trip active but no pings, viewer map frozen), and steady-state bus
positions arrive every 15-25 s instead of the D45 5 s target.

Root causes, each verified in code:

- Hysteresis blocked the 5 s rate. `decideMode` and
  `LocationService.requestMode` held every mode switch for 30 s, so a fresh
  leader stayed on the 10 s waiting stream for up to 30 s after promotion.
  Effective leader cadence was 10 s, not 5 s, for the first half minute of every
  trip.
- Battery reads blocked every fix. `_listen` awaited two platform channels (up
  to 3 s each in the background) before emitting the fix, adding seconds to
  every ping on the exact path that must be fastest.
- The foreground notification was dismissible and the paused mode dropped the
  service. `setOngoing` defaulted to false, and `paused` returned a bare
  `LocationSettings` with no notification, so a GPS gap released the foreground
  service and let OEM skins kill the process.
- A frozen position stream waited 60 s. The stall restart matched no other
  window, so a screen-off freeze without an error cost a full minute of silence.
- The viewer waited too long when the socket dropped. Fallback polling armed
  after 30 s down and polled every 15 s, with a 45 s watchdog, so a mobile-data
  socket drop froze the map for 15-30 s. Heartbeats every 25 s prove liveness,
  so the tighter windows add no steady-state cost.

Change (client only, no server contract change, no new permission):

- `setOngoing: true` on every `settingsFor` notification; `paused` keeps the
  same low-power foreground service instead of a bare settings object. No
  `WAKE_LOCK`, no background location, no exemption: manifest audit still PASS.
- Fixes emit immediately with the last known battery bucket and refresh the
  cache in the background with 3 s timeouts. First fix carries the 100 default,
  the next fix after the refresh carries the real bucket.
- Upgrades to a faster cadence bypass hysteresis in both `decideMode` (new
  `intervalSForMode` table: 5, 10, 15, 45) and `requestMode`; downgrades still
  wait 30 s. Stall restart 60 s to 30 s with a restart log for field diagnosis.
- Viewer: watchdog 45 s to 30 s, socket-down fallback 30 s to 15 s, poll
  interval 15 s to 10 s. Polling runs only while the socket is down; heartbeats
  still suppress resyncs on quiet connected lines. `staleAfterS` stays 45 s.

Not changed and why: cold publish still needs 2 moving pings at the 10 s waiting
rate (about 20 s to first vehicle). Cutting it to 1 tick or a 5 s waiting rate
would halve cold start but raises the phantom-bus risk PLAN 6.6 step 9
deliberately blocks, so it needs an owner decision plus budget updates, not a
drive-by. `WAKE_LOCK` and battery-exemption fixes are rejected by the AGENTS.md
15 hard limit and PLAN 14.7 unless a spike proves them indispensable; the FGS
type location plus an ongoing notification is the compliant path. OEM manual
steps stay owner-side: set Pontual battery to Unrestricted, lock it in recents,
start sharing from the visible trip screen outdoors while moving.

Verified: `flutter analyze` clean, `dart format` clean, full app suite green
(335 passed, 1 skipped), manifest source audit PASS (no background location, no
WAKE_LOCK). Server pure suites green here (engine, arrivals, geo, config,
health); DB-backed suites need a throwaway PG 16 plus dbmate migrate and stay
for CI or a capable host (no local DB on this run).

## D60-2026-10-16: cold start removed, first vehicle on the first moving ping (Accepted)

Owner order: remove the cold start.

Change: `movingTicksToPublish` 2 to 1 and `waitingIntervalS` 10 s to 5 s in
`server/src/domain/types.ts`; client waiting stream 10 s to 5 s in `settingsFor`
so the stream always emits at least as fast as the instructed `n`. First vehicle
now publishes one interval (about 5 s) after motion starts instead of two
intervals (about 20 s). Waiting and leaderMoving share the 5 s rate; the W to L
switch still bypasses hysteresis on accuracy (medium to high) in both
`decideMode` and `requestMode`, so the fresh leader reaches high accuracy on the
next fix.

Trade-offs: a single GPS speed glitch can now create a vehicle where two
consecutive moving fixes were needed before. Mitigations kept: the 3 m/s speed
gate, 60 m accuracy gate, bbox, teleport and route checks, and 5-strike abuse
end all still apply, and a stopped lone trip still never publishes. Waiting data
doubles while waiting (transient only, still tiny in absolute terms); leader,
follower, and viewer budgets in RNF03 are untouched. PLAN.md RF08, 6.3 table,
and 8.5 sampling table updated in the same change set.

Verified: `flutter analyze` clean, `dart format` clean, full app suite green
(335 passed, 1 skipped), manifest source audit PASS (no background location, no
WAKE_LOCK). Server `deno fmt`, `lint`, `check` clean; pure suites green (engine
28 including the updated distant-rider second-vehicle case, arrivals, geo,
config: 41 passed). DB-backed server suites need a throwaway PG plus migrate and
stay for CI.

## D61-2026-10-16: battery exemption requested from the offline card (Accepted)

Owner order: request the battery-optimization exemption at the right moment.
This is the approved exception to the AGENTS.md 15 hard limit and the PLAN 8.6
ban (both name this permission explicitly): field tests on Samsung and Xiaomi
skins show background sharing stopping in all three forms even with the
location-type foreground service plus an ongoing notification (D59), so the
spike is proven by field evidence, not theory.

Design (what "right moment" means):

- Never at startup, never automatically, never while healthy. The card renders
  only when the trip health issue is already offline (3 failed sends or 120 s
  without success) on Android. That is exactly the stall the exemption fixes, so
  only at-risk users ever see it.
- User-tapped only. The "Manter ativo" action fires the system dialog through
  `permission_handler`; denial only toasts and sharing keeps retrying. No
  background-location wording anywhere, no ACCESS_BACKGROUND_LOCATION, no boot
  receiver, no WAKE_LOCK.
- One code path: `platform/android/battery_optimization.dart` (best-effort,
  Android-only, never throws, injectable seam for tests). The trip screen card
  owns the request; Settings keeps the existing manual "Sem restrições" help row
  unchanged.

Change: manifest declares REQUEST_IGNORE_BATTERY_OPTIMIZATIONS with an
owner-order comment; `manifest_audit.sh` and the release merged-manifest audit
moved it from forbidden to expected; PLAN.md 8.6 updated in the same change set.

Verified: `flutter analyze` clean, `dart format` clean, full app suite green
(337 passed, 1 skipped: battery helper plus offline-card tap), manifest source
audit PASS with the exemption declared. Merged-manifest proof and the release
AAB stay for the release machine (no Android SDK on this host).

## D62-2026-10-16: test-only force-ping button on the trip screen (Accepted)

Owner order: add a button to force-send a location ping while sharing, for
testing only.

Design: `TripController.forcePingNow()` queues the last accepted fix past the
pacing slot and returns false when no trip runs or no fix arrived yet. A tap
with no newer fix resends the latest one (the server answers it as a duplicate),
so the full HTTP path is still exercised. The per-device ping bucket (30/min)
still applies, so it cannot be spammed into an abuse end. The button renders
only behind the `FORCE_PING_BUTTON` dart-define (default false, `env.dart` plus
`env/example.json`, PLAN.md 17.1): production builds never include it. Test
builds set `--dart-define=FORCE_PING_BUTTON=true`.

Verified: `flutter analyze` clean, `dart format` clean, full app suite green
(341 passed, 1 skipped: 2 controller plus 2 widget cases), manifest audit PASS
(no manifest change).

## D63-2026-10-16: follower stream uses balanced accuracy (Accepted)

Owner order: most accurate, precise, fast and reliable GPS without tightening
the meter gate in weak-GPS areas. This is Phase 0 step 1 of that plan; the rest
(smoothing tiers, speed/heading accuracy use, native HDOP channel) stays as
dedicated tasks.

Problem: `settingsFor` put followers on `LocationAccuracy.low`
(`PRIORITY_LOW_POWER`, cell/WiFi, often 50 m to 1 km). Follower fixes must pass
the same 60 m gate as leader fixes (client `fixAccuracyMaxM`, server
`accuracyMaxM`), so in weak-GPS areas followers starved exactly when the next
leader handover needed a live candidate. Promotion then waited for the next 45 s
ping of a phone with nothing usable.

Change (client only, no server contract change, no new permission):
`SamplingMode.follower` now requests `LocationAccuracy.medium` (balanced) at the
same 45 s interval. `offlineSaver` and `paused` stay low: probes and GPS-off
waits carry no handover duty and must cost the least battery.

Not changed and why: the 60 m gate is untouched on both ends per the owner
constraint; `distanceFilter` stays unset per the D43 deferral (it would starve
still detection and the server timeout); leader and waiting modes are unchanged
(D59/D60 already fixed their hysteresis and cadence); web behavior is unchanged
(browsers ignore these settings; pacing per D29 still guards fast streams).

Trade-off: follower battery cost rises from low-power to balanced radio use.
RNF02 (follower 2 percent/h) is unchanged and must be confirmed on phones in the
T47 field test, split by open-sky vs weak-GPS so low-GPS areas prove no
regression.

Verified: `flutter analyze` clean, `dart format` clean (0 changed),
`location_test` 14 green, supervisor plus controller plus health 45 green,
manifest audit PASS (no manifest change). Full app suite not re-run (tree
carries unrelated uncommitted battery plus force-ping work); stays for the owner
machine and CI.

## D64-2026-10-16: degraded downgrade hold keeps GPS on (Accepted)

Phase 0 step 2 of the GPS plan (D63 was step 1). Owner constraint holds: the 60
m publish gate is untouched on both ends.

Problem: the 30 s downgrade hysteresis treated all downgrades alike. Dropping
from high accuracy to a 45 s cadence right when fixes turn coarse powers down
GPS exactly when it is needed most, so the next sub-60 m fix arrives a full slow
interval later and weak-GPS patches cost more map gaps than they should.

Change (client only, no server contract change, no new permission):
`LocationService.requestMode` tracks the last accepted fix accuracy and extends
the downgrade guard from 30 s to 60 s while that accuracy is at or above 40 m
(`degradedAccuracyM`, `degradedHoldMs`). Upgrades, dead-stream restarts, and
stall restarts bypass unchanged; offline saver and paused keep the 30 s guard
because faster GPS buys nothing with no uploads. PLAN.md 8.6 updated in the same
change set.

Not changed and why: no fix is dropped or kept by this (the 60 m gate owns
that); `distanceFilter` stays unset per the D43 deferral; follower medium from
D63 is the stream the hold protects on handover demotions.

Trade-off: up to 30 s of extra faster-cadence GPS per degraded episode. Bounded
per episode and self-clearing on the next good fix; RNF02 confirmation stays
with the T47 field test.

Verified: `flutter analyze` clean, `dart format` clean, `location_test` 17 green
(3 new: degraded hold, good-accuracy guard, saver plus paused exemption),
supervisor plus controller plus health 45 green, manifest audit PASS (no
manifest change).

## D65-2026-10-16: trip start anchors on the first good fix (Accepted)

Phase 0 step 3 of the GPS plan (D63 step 1, D64 step 2). Owner constraint holds:
the 60 m publish gate is untouched on both ends.

Problem: `startTrip` published the first accepted fix, even a 59 m one, as the
trip anchor. That coarse point seeds the server vehicle (wrong attach, coherence
fail) when a sub-30 m fix follows seconds later on the same 5 s waiting stream.

Change (client only, no server contract change, no new permission): the GPS
phase waits for the first fix at or under 30 m (`firstFixGoodAccuracyM`) inside
the existing 60 s window and falls back to the best-seen (lowest accuracy)
accepted fix. Worst case is today plus nothing: same window bound, accuracy
equal or better. Cancel and dispose paths are unchanged (stream close still
reports declined; nothing seen still reports noGps). PLAN.md 8.6 updated in the
same change set.

Found while testing: the first draft looped on real-time timeouts against a
fixed fake clock without terminating. Timeouts now end the window (break)
instead of retrying, so the loop terminates under both clocks; the fake-clock
deadline stays the bound.

Verified: `flutter analyze` clean, `dart format` clean, `trip_controller_test`
21 green (2 new: good-fix preference with start-body coordinates, best-seen
fallback with start-body coordinates), location plus supervisor plus auto-end
plus share-flow plus health 62 green, manifest audit PASS (no manifest change).

## D66-2026-10-16: no heading published at standstill (Accepted)

Phase 0 step 4 of the GPS plan (D63 step 1, D64 step 2, D65 step 3). Owner
constraint holds: no fix is dropped by this; the 60 m gate is untouched.

Problem: the client forwarded the chip bearing at any speed, including at stops
where GPS bearings are pure noise (bearing is derived from motion). The server
then dead-reckoned the vehicle along a random direction for the publish TTL and
the map arrow spun.

Change (client only, no server contract change, no new permission):
`normalizeHeading` takes the normalized speed and returns null under 0.5 m/s
(`stillSpeedMaxMps`, the same threshold the server uses for still ticks).
Verified null-safe end to end before changing: the ping schema accepts nullable
`hdg`, attach skips projection on null headings, and null headings widen attach
tolerance instead. PLAN.md 8.6 updated in the same change set.

Not changed and why: moving bearings pass through exactly as before;
`speedAccuracy`/`headingAccuracy` fields stay unused because their unknown-value
semantics are unverified on the target skins (a wrong threshold there would
silently drop or corrupt fixes, against the owner constraint). They stay a
candidate for the native HDOP task with device evidence.

Verified: `flutter analyze` clean, `dart format` clean, location plus controller
plus supervisor 51 green (extended heading cases including the 0.5 boundary),
manifest audit PASS (no manifest change).

## D67-2026-10-16: approximate-only grants fail fast with guidance (Accepted)

Phase 0 step 5 of the GPS plan (D63-D66 before it). Owner constraint holds: no
gate changed; this only explains a state that could never share.

Problem: an approximate-location grant reports granted, then every fix lands at
kilometer accuracy and dies at the 60 m gate. The trip stalled 60 s at "waiting
for GPS" with no actionable guidance, and field support could not tell it apart
from weak GPS.

Change (client only, no server contract change, no new permission):
`PermissionGateway.preciseAccuracy()` wraps `Geolocator.getLocationAccuracy()`
(verified: real API on Android, `UnimplementedError` on web where browsers grant
precise-or-nothing) and fail-opens to true on unknown status or any error, so a
broken check never blocks sharing. `startTrip` fails fast with
`StartFailure.imprecise` right after the permission grant, before any GPS wait
or trip call. The legacy flow shows the guidance as a snackbar; the new UI maps
it to a `PermissionCardState.imprecise` card opening settings (UI_SPEC 7.7 gains
one matrix row; spec text update stays owner-side).

Verified: `flutter analyze` clean, `dart format` clean, controller 22 green (new
fail-fast case asserting no trip call), share-flow widget green (card copy plus
settings action, no GPS hang), supervisor plus location 30 green, manifest audit
PASS (no manifest change).

## D68-2026-10-16: native GNSS quality channel, plumbing only (Accepted)

Phase 1 step 1 of the GPS plan (Phase 0 was D63-D67). No behavior changes:
nothing listens to the channel yet, so sampling, gating, and publishing are
byte-for-byte what they were.

What it is: `GnssQualityPlugin.kt` (EventChannel `pontual/gnss_quality`,
registered from MainActivity) forwards `GnssStatus` at most 1 Hz as
`{satsUsed, satsView, meanSnrDb}`. `lib/platform/android/gnss_quality.dart`
parses it into `GnssQuality` and exposes `watchGnssQuality()` behind an
injectable reader seam. No coordinates cross the channel, so it carries no
location data and needs no permission beyond the location grant the trip already
holds; no manifest change.

API and scope choices, all verified against the pinned sources:
`registerGnssStatusCallback` plus `getUsedInFix`/`getCn0DbHz` are API 24
members, guarded by an SDK check for older devices; `getLocationAccuracy`-style
unknowns do not exist here (counts are counts). True HDOP needs NMEA (GGA
sentences), whose registration is version-dependent and deprecated on newer
APIs: deliberately deferred to a follow-up with device verification instead of
half-supported now. D66 already recorded why unverified accuracy-field
thresholds stay out.

Limits of this verification: no Android SDK on this host, so the Kotlin compiles
only on the release machine or CI (`assembleDebug` plus merged-manifest audit
plus install-launch per T45). The Dart side is fully green: analyze clean, 6 new
tests (contract, parsing, malformed events, seam, lazy creation). Wiring the
stream into trip health and smoothing is the next step and gets its own ADR.

Verified: `flutter analyze` clean, `dart format` clean, `gnss_quality` 6 green
plus location 17 plus controller 22 green, manifest audit PASS (no manifest
change).

## D69-2026-10-16: GNSS quality wired into the trip screen (Accepted)

Phase 1 step 2 (D68 built the channel). Owner constraint holds: the signal only
displays, it never gates, drops, or smooths a fix, and the 60 m gate is
untouched.

Change (client only, no server contract change, no new permission):
`TripController` subscribes to `watchGnssQuality` in `_runLoop` (behind the
injectable `TripDeps.gnssReader`, production default uses the real channel),
keeps the latest sample in `lastGnssQuality`, and unsubscribes plus clears it in
`_stopLocal` and `dispose`. It notifies only when the displayed satellite count
changes, so the 1 Hz native stream does not rebuild the screen every second.
`StatusTiles` takes an optional `gnss` and appends "N satélites" to the GPS tile
while weak or unfixed; every other tile and state is unchanged. PLAN.md 8.6
updated in the same change set.

Test finding: a rig-driven widget variant of this hung in teardown under
FakeAsync and was replaced with direct `StatusTiles` tests plus a real-async
controller lifecycle test. Production teardown is the same audited path as the
fix stream (cancel in `_stopLocal` and `dispose`); the race is test-side. If it
recurs on another machine, suspect unawaited-cancel versus awaited-close
ordering in FakeAsync before suspecting production code.

Verified: `flutter analyze` clean, `dart format` clean, controller 23 green (new
record-and-drop lifecycle case), trip-settings 11 green (new subtitle plus
no-subtitle cases), location plus gnss plus supervisor plus share-flow 72 green
across the runs, manifest audit PASS (no manifest change).

## D70-2026-10-16: GPS acceptance protocol (docs only, Accepted)

No code changed in this step. The remaining code items (SNR-weighted smoothing,
NMEA true HDOP) need field numbers by the project's own VERIFY discipline, so
this step writes down what passing looks like:
`docs/field-tests/gps-acceptance.md` with the accuracy tiers as built, per-step
gates for D63-D69 each measured open-sky and weak-GPS, the two-phone collection
procedure on production-equivalent builds, and a checklist. Thresholds cited in
the doc were re-verified against the constants (60, 40, 30, 0.5). Failing gates
produce fix plans, never silent relaxes.

Verified: em-dash scan clean; thresholds re-checked against code; docs-only, so
no test suite re-run (previous greens stand).

## D71-2026-10-16: mid-trip approximate downgrade detected, sends held (Accepted)

Gap found on review: D67 failed fast only at the permission grant.
`TripSupervisor.pollEnvironment` never re-checked accuracy, so a user flipping
to Approximate mid-trip starved silently at the 60 m gate until the server
10-minute timeout ended the trip.

Change (client only, no server contract change, no new permission): the
supervisor polls `preciseAccuracy()` each round with the same 3-poll debounce as
revocation (fail-open on broken reads; accepted fixes cannot forgive it because
coarse fixes never reach `onFix`) and reports `Supervision.imprecise`. While
set, sampling drops to low-power like paused (GPS stays warm for a fast resume),
outgoing pings hold (fixes that pass the gate are still too coarse to publish as
a bus position), and the trip screen shows the D67 Precise guidance as tile plus
banner. Deliberately no client auto-end: the server no-ping timeout bounds the
zombie, and a fixed grant resumes without a restart. Health model gains
`SharingIssue.imprecise` (outranking offline, next to permission) and
`GpsValue.imprecise` ("Aproximada"); PLAN.md 8.6 updated in the same change set.

Real bug caught by existing tests while building this: the D68 channel touched
`EventChannel` unconditionally, which throws without a Flutter binding in plain
unit tests (`trip_auto_end_test` failed with a binding error).
`watchGnssQuality` now returns an empty stream with no binding, and that suite
is the regression cover.

Verified: `flutter analyze` clean, `dart format` clean, full app suite green
(362 passed, 1 skipped: supervisor debounce plus forgiveness, controller
hold-and-resume with ping counts, health priority, banner widget), manifest
audit PASS (no manifest change).

## D72-2026-10-19: GNSS used-in-fix compat after stub removal (Accepted)

Correction to D68: `GnssStatus.getUsedInFix(int)` is not available in the
current compile stubs. Checked with `javap` against the installed platforms:
`android-35`, `android-36` and `android-37.0` expose only `usedInFix(int)` (API
30+) and have no `getUsedInFix`. D68 verified the API level from docs but had no
Android SDK on the host, so the release compile was the first real check; it
failed with `Unresolved reference 'getUsedInFix'` at `GnssQualityPlugin.kt:101`.

Change (native plugin only): API 30+ calls `usedInFix(int)`; API 24-29, where
the old method still exists on the device, reaches `getUsedInFix(int)` through a
lazily resolved reflective lookup. No minSdk bump, no new dependency, no
permission or manifest change, and no behavior change on API 30+. If the legacy
lookup ever fails the plugin reports zero used satellites rather than crashing;
the view count still arrives.

Not verified: the reflective path on a real API 24-29 device (no such device on
this host). It should be covered by the T45 install-launch pass when an older
device is available.

Verified: `flutter build apk --release` succeeds (universal APK containing
arm64-v8a, armeabi-v7a and x86_64; 58.5 MB). That is above the 25 MB universal
budget in PLAN.md 10.1, but the universal APK packs three ABIs and this change
adds only a few lines of dex; the arm64 release split is the meaningful budget
measure. `flutter
analyze` clean. No Dart code changed, so the Dart suites were
not re-run.

## D73-2026-10-19: last known bus position keeps its ping age (Accepted)

Implementing PLAN.md 8.8.5: viewer ages were taken verbatim from the server row
and never advanced locally. While connected the label lagged by up to one
snapshot interval; after the socket dropped the last bus position stayed on the
map but "há N s" froze at the value received at the drop, so the ping time lied.

Change (client only, no server contract change): `ClientVehicle` records the
monotonic receipt time of its row. Both the initial or polled snapshot and every
stream snapshot stamp their rows with one receipt time per frame. The
repository's `vehicles` getter returns copies whose `ageS` is
`server age at receipt + local elapsed`, per PLAN 8.8.5, without mutating the
stored rows. The UI ticks every 5 s already, so rows and markers age honestly
while the socket is down.

Retention scope: a failed snapshot refresh keeps the last known positions (no
blanking), which is the "before the connection dropped" case. A successful
snapshot still replaces the list and removes vehicles absent from it, per PLAN
8.8.6; an authoritative server answer is not overridden by client cache. Nothing
is persisted, no new data is collected, and no wall clock is used for ages.

Verified: `flutter analyze` clean, `dart format` clean, full app suite green
(365 passed, 1 skipped), including new tests for local aging after a socket
drop, age reset on a fresh frame, and retention through a failed refresh.

## D74-2026-10-19: web gap recovery stays foreground-only (Accepted)

Owner decision: implement option B from `docs/web-background-sharing.md` now,
without changing the foreground-only web contract. The app does not request
background location, a new permission, a new dependency, telemetry, a local
database, or a server contract change. The web banner continues to say that the
screen must stay open and unlocked, and the Android native app remains the
screen-off path.

On a web visible transition, `TripScreen` re-requests the wake lock and
`TripController.recoverWebSharing` clears the hidden pause and asks
`LocationService.recoverNow` for one high-accuracy one-shot position with a 15 s
timeout. The service restarts a dead or silent stream and feeds the one-shot
through the existing accuracy, mock, freshness, speed, and heading filters. The
accepted fix enters the normal `_nextPingAtMs` path, so recovery cannot bypass
the server interval. A fix that was accepted before the hide but delivered after
recovery is dropped when it is already older than `fixMaxAgeMs`;
`TripFix.acceptedAtMs` carries the acceptance time without adding data to the
wire.

When a hide lasted at least `webTripTimeoutFallbackMs` (10 min, the server
default), the next `gone` is rendered as `TripEndKind.automatic` with detail
`timeout` and a new end-card string. The client never ends a trip by itself: the
fallback only classifies the server's answer. A shorter hide keeps the existing
one-time revive path for a server restart or lost record. Clearing the flag on a
successful outcome means a stale prediction cannot end a healthy trip.

The implementation is in `location_service.dart`, `trip_controller.dart`,
`trip_screen.dart`, `trip_end_card.dart`, `ui_strings.dart`, and
`visibility.dart`. Unit and widget tests cover the one-shot filter path and
failure, stream restart, one paced ping, stale queued fix rejection,
hidden-duration tracking, the short-gap revive, the long-gap timeout end,
wake-lock re-request on resume, and the end-card copy.

Verified: `flutter analyze` clean, `dart format
--set-exit-if-changed` clean
(203 files), full app suite green (370 passed, 1 skipped),
`flutter build web --release` exit 0 (`main.dart.js` 993,825 bytes gzip, about
970 KiB), and `bash tools/ci/manifest_audit.sh` PASS. No Android manifest or
dependency changed; the source audit still shows no
`ACCESS_BACKGROUND_LOCATION`, `WAKE_LOCK`, or boot receiver. Not verified: the
field protocol, real recovery latency, and wake-lock behavior on Android Chrome
and iOS Safari/PWA. This ADR does not claim background or screen-off coverage.

## D75-2026-10-20: static deploy dry run repaired (Accepted)

Testing `tools/ci/check.sh --with-tiles` exposed two deploy-static failures that
a clean GitHub runner would not have hidden.

Map input: the pinned Protomaps daily build `20261012` now returns HTTP 404. The
daily bucket keeps the past week plus the latest build for each patch version,
and `20261012` was not the latest 4.15.2 build. Bumped `protomaps_build` to
`20261019` (4.15.2, OSM data to 2026-10-19 04:00 UTC), updated the pinned-URL
test and `docs/maps.md`, and re-extracted the city archive. New measurements:
41.6 MB at z0-15, 46 MB transferred, 77 requests, about 21 s; bbox and verify
pass. The old build's z0-14/13/12 variant sizes in `docs/maps.md` are marked as
not re-measured. This is a data-input refresh only; no app, server, schema,
permission, or retention change.

Dry-run script: the tile step built an inner `PATH` with single quotes, so the
literal `$PATH` replaced the environment and `deno` was not found. It now uses
an escaped double-quoted assignment and runs `map-bbox`, `map-extract`, and
`map-verify` successfully. The first full run also measured a stale 42 MB
`sao_mateus.pmtiles` inside the local `build/` directory against the 100 KB
data-bundle budget. That file is a gitignored local artifact and not part of the
data bundle. Both CI and the local mirror now sum every file in `build/` except
`*.pmtiles`, so routes, JSON, and `_headers` stay in the budget while the
separately built map extract does not. The current bundle is 10,546 bytes.

Verified: a final `tools/ci/check.sh --with-tiles` run passed 28 steps with 0
failures: app analyze, format, 370 tests (1 skipped), manifest audit, and web
build; server 88 tests plus the simulator smoke; all 6 tools checks with a
10,546-byte bundle; and the 7-step deploy dry run including the 41.6 MB extract,
verify, Pages assembly, and removal. gitleaks found no leaks. Remaining risk:
the deploy workflow still hotlinks a Protomaps daily build. Protomaps retires
builds outside its retention window and discourages hotlinking, so the pin must
be refreshed or mirrored before the next patch-version change. A stable
project-owned mirror remains follow-up work.

## D76-2026-10-20: gitleaks allowlist for UI storage keys (Accepted)

The local CI mirror skipped the gitleaks job because the binary was not
installed. A full-history scan with gitleaks 8.30.1 found three
`generic-api-key` hits, all false positives: the SharedPreferences storage-key
constants `coachmarkSeenKey = 'ui_coachmark_seen_v1'`,
`recentsKey = 'ui_recents_v1'`, and `favoritesKey =
'ui_favorites_v1'`, plus the
audit table quoting the last one. The rule treats identifiers ending in `Key` as
credentials.

Added a root `.gitleaks.toml` that extends the default rules and allowlists only
the three exact UI key values. The allowlist is a value regex, not a whole-file
exclusion, so a real credential in those files still fails. The root config is
gitleaks' default path, so both the local scan and a repo-root CI scan pick it
up.

Verified: `gitleaks 8.30.1 detect --source . --redact` scans the full history
(over 350 commits, about 3.2 MB) with zero findings. No code, permission,
manifest, or data changed. The local `check.sh` still skips the step when the
binary is absent; install gitleaks or add it to PATH to make the mirror cover
it.

## D77-2026-10-20: Trip minimize returns to the previous screen (Accepted)

`shareTrip` and the active dock both opened `/trip` with `go`, which replaced
the navigation stack. The minimize chevron and system back then called
`go('/')`, so a rider who started sharing from line details lost the line, its
sheet position, and its map state on return.

`/trip` is now pushed over the current route. Minimize and system back pop it,
so the screen that started sharing (line details, a tab, search) returns with
its state intact; home remains the fallback when there is no route below (a deep
link or a bare test harness). The back handler uses `PopScope.canPop` with
`Navigator.of(context)` so plain `MaterialApp` harnesses keep working, while
minimize and the end card use go_router's `context.pop()` to keep the router's
location in sync.

A `RouteObserver<PageRoute<dynamic>>` (`appPageRouteObserver`) is attached to
the root navigator. The line screen subscribes to it, closes its viewer
repository in `didPushNext`, and reopens it in `didPopNext` (PLAN.md 8.8.4 and
10.4.6). The observer is deliberately typed to `PageRoute`: modal bottom sheets
and dialogs are `PopupRoute`s, so the share flow's consent, progress, and
permission sheets do not stop the stream. Closing and reopening are serialized
through a pending-stop future and a generation counter, so a fast
cover-then-back cannot overlap a close with a reconnect or start two sockets.

Consequences: one extra route stays on the stack while sharing, which is the
intent; the line socket is closed while covered, while its 5 s vehicle tick
still rebuilds the mounted screen (a small accepted residual). The trip's own
state and the foreground service are unchanged, so the dock keeps sharing after
minimizing.

Rejected: storing a return location and keeping `go`. It would lose the line
screen's sheet and map state and need extra state plumbing. Rejected: pausing
through `ModalRoute.isCurrent`, because modal sheets would stop the stream while
the rider is still on the line screen.

Verified: `flutter analyze` reports no issues; targeted trip, line, and
share-flow widget tests pass, including minimize, system back, the
no-previous-route fallback, the end-card return, and cover/modal stream
lifecycle; the full `flutter test` suite passes 376 tests with 1 skipped.

Build and size: the release web build succeeds with
`flutter build web --release --no-web-resources-cdn`. `main.dart.js` measures
3.2 MB raw, 987 KB gzip, and 763 KB brotli; local assets add 1.8 MB. The web
output includes 37 MB of local Canvaskit because this build disables the
resources CDN; production serves it from the CDN and caches it. The change adds
a few kilobytes of Dart, so it does not move the budget.
`tools/ci/manifest_audit.sh` passes with the same permission set; no dependency,
permission, retention, or data change.

Android: `flutter build appbundle --release` succeeds and produces a 56.9 MB
universal AAB. The merged release manifest keeps the same allowed permission
set, `allowBackup="false"`, and no cleartext traffic. The universal artifact
contains all ABIs, so the per-download arm64 budget (15 MB) is not measured from
it and remains the T45 release gate.

## D78-2026-10-20: Trip sharing screen shows measured metrics (Accepted)

The `/trip` screen described the phone, GPS and connection with short words
alone ("Bom", "Tela ligada", "Conectado"). That met the truth rules but hid
values the app already has: the last accepted fix carries accuracy and a 5
percent battery bucket, Android reports satellites used and in view, and the
server sends the next send interval on every trip and ping response. The screen
now shows those values instead of inventing a score.

One tonal card holds three metrics. GPS shows accuracy in meters and the
satellite count, with a meter against the existing 60 m publish gate. Celular
shows the battery percentage from the last accepted fix, the charging state, and
a level meter. Envio shows the server interval in seconds plus the role
explanation (waiting, leader, follower or offline); it deliberately has no meter
because no honest denominator exists. When a value is missing the copy says so
("Procurando sinal", "Sem leitura", "Sem conexão") instead of showing a
placeholder number. A 5 s tick refreshes values that arrive on fixes but do not
notify the controller.

Only read-only signals were added: `TripController.role` and
`TripController.intervalS`. No new field is collected, stored, logged or sent;
accuracy, battery and GNSS quality already existed. No dependency changed. New
copy lives in `UiStrings`; the big value uses a new `PontualText.metric` token.
Empty accuracy is treated as searching even if the seeded success clock would
otherwise read "good".

Rejected: a derived "GPS percentage". It would look precise while measuring
nothing. Rejected: send success percentage. The ping client keeps no counters,
and adding them would create a stat the product does not need. Rejected: moving
coordinates or a map into this screen.

Verified: `flutter analyze` clean; the trip widget tests cover accuracy and
satellites, battery percentage and charging, server interval and roles, offline
and stale sends; targeted `trip_controller_test` covers the interval getter.
Full `flutter test` passes. No manifest, permission, retention or data change.

## D79-2026-10-20: Satellites replace battery in the trip metrics (Accepted)

The metrics card from D78 showed the phone battery percentage and charging
state. The owner removed it: on a trip screen the battery number is noise, and
the low level already raises its own banner with the same 15 percent rule. The
card now shows satellites used and in view from the Android GNSS channel, with a
meter built from that real fraction. This explains the GPS accuracy beside it
and helps the user move the phone when the sky view is poor.

Satellites were already collected for D69 and already appeared as the GPS
caption; this only promotes them to a cell. No new field, counter, log,
permission or persisted value was added, and the send metric still has no meter
because no honest denominator exists. When the receiver sees none the cell says
"Sem satélites"; on platforms without the native channel it reads "Indisponível
no navegador" instead of waiting forever.

Rejected: showing speed. The browser maps a missing speed to 0.0, so the web
build would report "Parado" for a moving bus. Rejected: a positions-sent or
distance counter; one adds a stat the product does not need and the other
derives location history in memory. Rejected: last-send age, already shown in
the hero proof line.

Verified: `flutter analyze` clean; trip widget tests cover satellites used, in
view, none and unavailable, plus accuracy, send interval, roles, offline and
stale sends. Full `flutter test` passes.

## D80-2026-10-20: second owner-supplied app icon applied (launcher + PWA)

The owner placed a new `icon.png` (161x157 RGBA, rounded corners transparent)
and `icon.svg` (161x157 monochrome trace) at the repo root and asked to replace
the launcher and website icon and the loading screen icon. The PNG is the visual
master. The SVG is not a full-colour source: it draws the rounded tile minus the
bus, so a mint layer behind its dark paths produces the mint bus. That negative
was used to rebuild the icon as a vector instead of upscaling the 161 px PNG to
512 px and 432 px.

Sources: `design/brand/app-icon.png` (master) and `app-icon.svg` (trace)
replaced the previous files. The stale `app-icon.jpeg` from the previous icon
was removed; Git history keeps it. Root copies removed. The live signal mark
`design/brand/pontual-mark.svg` and the theme tokens are unchanged: the app icon
is the bus tile, while the in-app motif remains the mint dot and arcs. The
launcher tile is `#0B3228` and the bus is `#77E9A3`, sampled from the new
master; the UI brand pine `#0B3D36` is still the splash background, so the icon
tile sits on a slightly different green.

Generated with the host's ImageMagick and rsvg-convert (throwaway commands
outside the repo, no dependency added):

- Android legacy: `mipmap-mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi/ic_launcher.png` at
  48/72/96/144/192, rounded corners transparent.
- Android adaptive: `drawable-<dpi>/ic_launcher_foreground.png` at
  108/162/216/324/432 with the tile at 60 percent of the canvas and the rest
  transparent; `mipmap-anydpi-v26/ic_launcher.xml` and `ic_launcher_round.xml`
  use `@color/pontual_icon_bg` (`#0B3228`). No monochrome layer was added.
- Web: `icons/Icon-192.png` and `icons/Icon-512.png` (rounded, transparent
  corners), `icons/Icon-maskable-192.png` and `Icon-maskable-512.png` (tile at
  80 percent on `#0B3228`), `Icon-apple-touch-180.png` (tile at 92 percent on
  `#0B3228`), `favicon.png` (32 px) and a new `favicon.svg` with the coloured
  vector. `index.html` links the SVG favicon before the PNG, keeps the manifest
  icon names, and replaces the inline splash SVG with the app icon at the same
  88 px pulsing size. The splash still paints from the first frame with no
  network request.

Verified: `identify` dimensions and alpha on all generated PNGs; visual check of
the 512 web and maskable icons, the 180 apple touch, the 32 favicon, the xxxhdpi
foreground and the 88 px inline splash; the inline SVG was extracted from
`index.html` and rendered at 88 px, matching the source.
`flutter build web --release` passed and the built `index.html` and icon files
in `app/build/web/` match the sources (only the base href differs). No Dart code
changed. Android SDK is not installed on this host, so the merged-manifest and
install-launch checks were not run.

## D81-2026-10-20: permanent Android download link in web Settings

Owner order: "On app/website settings, add a link to download app for android".
The web build now shows a permanent "Baixar app para Android" row in the
Settings About section. Tap opens the latest release APK
(`.../releases/latest/download/app-release.apk`) in the system browser through
the existing allow-listed `url_launcher`. The one-time Android web card from
D-U24 stays on Home and Settings; after dismissal the permanent row remains. The
row is web only because it would be pointless inside the native Android app and
cannot install on iOS.

Implementation: shared `openAndroidAppDownload` helper in
`app/lib/platform/web/android_app_download.dart` (the card reuses it) and
`AndroidAppDownloadRow` in
`app/lib/ui/features/settings/android_app_download_row.dart`; two pt-BR strings.
No new dependency and no new data handling.

Verified: `dart format` clean, `flutter analyze` clean, targeted
`flutter test test/web_prompts_test.dart test/ui/trip_settings_test.dart` passes
(28 tests).

## D82-2026-10-20: passenger reports ("Sinalizações") (target model superseded by D83)

Owner order: add a flag system for "still waiting at this stop", "bus broken",
"gate blocked", "at max capacity", with a timestamp. Owner answers during the
design review: accept the device token; in-memory for alpha; implement both
line-level and stop-level; confirm the four kinds; no votes now; line-level
direction is enough for v1; research real stop names on the internet where
possible.

Decision:

- UI name **Sinalizações**, internal name **reports**. `flag` stays reserved for
  feature flags.
- Four closed kinds: `waiting` (line + stop), `full` (line), `broken` (line),
  `blocked` (line + stop). No free text, no photos, no driver or plate data.
- Reports are ephemeral and live in API process memory only. TTL default:
  waiting 10 min, full 15 min, broken/blocked 30 min; hard max age 30 min / 45
  min / 2 h / 2 h. A repeat from the same device refreshes freshness but does
  not increase the distinct-reporter count. No confirm/deny votes.
- Server owns timestamps. Clients never send `at`; the snapshot exposes
  `created_age_s`, `updated_age_s` and `expires_in_s`.
- Reads ride on the existing `GET /v1/lines/{id}/vehicles` payload and the
  WebSocket snapshot as an additive `r` array. Old clients ignore it. Writes use
  one route, `POST /v1/reports`, with `op` `report` or `retract`. No report ids,
  no report ids in URLs, no vehicle ids from clients.
- The device token is required, as AGENTS.md section 8 requires for every
  state-changing endpoint. A viewer who reports for the first time creates a
  pseudonymous `devices` row after a clear in-app disclosure. The report itself
  is not persisted and is not linked to the device record in storage.
- `DELETE /v1/me` removes the device from in-memory reporter sets, so a report
  whose only reporter was that device disappears.
- Stop ids are validated against the built static bundle when stop data is
  loaded. Local runs without a bundle accept well-formed ids so the feature can
  be tested; production bundles validate the exact set.
- Line-level only for direction in v1: a broken bus in one direction shows for
  both. `blocked` is also line-scoped until stop-line associations exist, so a
  blocked stop reported from line 7 does not appear on line 8. The stop picker
  lists all mapped stops because stop-line associations are still pending. All
  are recorded as known limitations.

Stop-name research (2026-10-20): queried the OSM API for the 12 node ids in
`data/stops.json`. The tags still expose only `Guriri`, `Entrada do Jaguaré`
(two nodes) and the generic "Ponto de ônibus" (two nodes); the other seven have
no `name`. No new reliable posted names were found. No name was invented. The
existing generic names were left untouched to avoid a data rebuild outside this
change; a field survey (T17/RF20) is still the prerequisite for good stop-level
labels. The picker gives unnamed nodes a local ordinal that is never written
back to the data.

Privacy and LGPD: the data inventory and policy drafts now include public
reports (kind, line, chosen stop, server timestamps, distinct count), memory
only, TTL at most 2 h, no coordinates and no identifier in durable storage. The
device record created on first report is disclosed. Lawyer/DPO review of the
wording and legal basis remains owner-blocked, as with the rest of the privacy
drafts.

Verification: `deno fmt --check`, `deno check src/main.ts`,
`deno check
test/*.ts` and `deno lint` pass. The full server suite ran against a
throwaway PostgreSQL 16 container on 127.0.0.1:5433: 94 passed, 0 failed,
including the six report tests (auth, schema, target validation, snapshot `r`,
kill switch, delete-me cleanup, TTL/count/retract). `dart format`,
`flutter analyze` and the full `flutter test` suite (388 tests, 1 skipped) pass.
The Android manifest audit, size measurement and device checks were not run on
this host. No database migration was added.

## D83-2026-10-20: reports use a coarse location area, not a stop picker

Owner order after reviewing D82: manually choosing a bus stop is a bad flow
because the app already has the user's location and the mapped stop set is
incomplete and not always correct. Use the current location instead. A person
does not need to be on the bus to report that they are waiting, so the flow must
be available to any viewer, not only to riders. Refactor the feature.

Decision:

- Waiting and blocked reports target a **coarse ~150 m grid cell**, not a stop
  id and not a coordinate. The app reads the device location once, converts it
  to the cell on-device, and sends only the cell id. Exact coordinates never
  leave the device.
- The grid is deterministic: 150 m cells, fixed reference latitude -18.7, id
  `g<latIndex>_<lngIndex>`. The server validates the id and that its center is
  inside the served bbox with one cell of margin. The Dart and TypeScript
  implementations share test vectors.
- The server keeps the cell in memory only for the report TTL, never logs it,
  and never writes it to the database or metrics. `DELETE /v1/me` still removes
  the device from reporter sets.
- The manual stop picker and the stop sheet are removed. Stop dots stay on the
  map as decorative information. There is no stop dependency in the report API,
  and `server/src/data/stops.ts` is deleted.
- Waiting is available to any viewer on a pilot line, without a trip, consent
  for location sharing, or a device relationship to the bus. The line sheet's
  `Sinalizar` action is the entry point; the trip screen keeps its shortcut.
- Location UX: a one-time in-app notice explains that one location read becomes
  a ~150 m area, not a pin, and that the exact position is not sent or stored.
  Acceptance is stored locally (`report_location_notice_v1`), then the OS
  permission prompt runs. Denied, blocked, services-off, imprecise (>150 m) and
  timeout states get a report-specific card with retry and, on Android, "Abrir
  ajustes". A decline leaves the map usable.
- The report chip shows the count and age; the detail sheet shows the rounded
  distance to the area ("cerca de 100 m") when the viewer location is known, or
  "Área aproximada de 150 m" otherwise. Waiting reports sort by distance when
  available. No precise coordinate is ever rendered.
- No votes remains: a report disappears by TTL or when its reporters retract.
- API contract change: `area` replaces `stop`. This feature has not shipped, so
  the break is accepted pre-release; there is no installed-client compatibility
  obligation for a feature that only exists in the current build.

Privacy: the report is a public coarse presence claim chosen by the user. The
cell is location data, but it is approximate, ephemeral, memory-only, and never
logged. The data inventory, policy, terms, RIPD and UI spec are updated. The
one-time notice plus OS permission is not a server-recorded consent yet; before
public release, legal review must confirm whether a versioned server consent
record is required. Until then the app remains a draft alpha and the policy
status stays "minuta". No exact coordinates are persisted, logged or sent.

Verification: `deno fmt --check`, `deno check src/main.ts test/*.ts`,
`deno lint` and the full server suite against a throwaway PostgreSQL 16
container (94 passed, 0 failed). `dart format`, `flutter analyze`, the report
area/location unit tests and the full app suite pass (397 passed, 1 skipped).
`flutter build web --release` passes and the source-manifest audit passes (no
new permission). The merged Android manifest, size measurement and device checks
were not run on this host.

- 2026-10-20: INFRA-05 resolved (domains and DNS). App/PWA:
  `https://pontual.spotnik.space`, a GitHub Pages custom domain with a DNS-only
  CNAME `pontual` -> `edulgfon.github.io` at Cloudflare. API:
  `https://api-pontual.spotnik.space`, routed by the `pontual` Cloudflare Tunnel
  to `http://127.0.0.1:8080`. The originally requested
  `api.pontual.spotnik.space` is a second-level name: free Universal SSL covers
  only the apex and first level, and Total TLS does not issue for Tunnel
  hostnames, so it needs Advanced Certificate Manager (USD 10/month). Given the
  R$0 recurring-infra rule, the alpha uses the first-level hostname; the
  second-level DNS route and tunnel ingress stay configured for a later ACM
  decision. Root causes fixed: the `pontual` DNS record did not exist;
  `ALLOWED_ORIGINS` was `http://pontual.spotnik.space` only, so every browser
  origin failed CORS. It is now
  `https://pontual.spotnik.space,https://edulgfon.github.io`. Verified:
  `GET https://api-pontual.spotnik.space/v1/health` returns 200 and the
  preflight with `Origin: https://pontual.spotnik.space` returns 204 with
  `access-control-allow-origin`; `http://pontual.spotnik.space` returns 200 from
  GitHub Pages. Still pending: GitHub Pages has not issued the custom domain
  certificate yet, so HTTPS there still presents `*.github.io`. The live Pages
  build is stale: it bakes the retired quick-tunnel API host and the
  `/pontual-bus-tracking/` base href. Rebuilding needs repo vars
  `API_ORIGIN=https://api-pontual.spotnik.space` and
  `STATIC_ORIGIN=https://pontual.spotnik.space` plus a `deploy-static` run. The
  owner chose to skip that rebuild in this change.
- 2026-10-20: CI origin follow-up. `deploy-static` and `release-android` now
  read the Pages custom domain with `gh api repos/{repo}/pages` when
  `STATIC_ORIGIN` is unset, so the base href and `/data` URL follow
  `pontual.spotnik.space` without a second repo variable. `API_ORIGIN` remains
  required. `deploy-static` also greps the built `main.dart.js` for the resolved
  API origin, so a stale build fails before upload. The build jobs gained
  `pages: read` for the lookup. This keeps the custom domain out of the
  workflows while removing the manual `STATIC_ORIGIN` step.

## D72-2026-10-22: waiting phase uses high accuracy to engage GPS (Accepted)

Investigation of "waiting for GPS" stalls (often >30 s, sometimes failing on
ok-GPS areas, and no GPS indicator on the status bar). Root cause: `settingsFor`
put `SamplingMode.waiting` on `LocationAccuracy.medium`
(`PRIORITY_BALANCED_POWER_ACCURACY`), which can resolve on WiFi/cell towers and
never powers the GPS receiver. Resulting fixes are coarse (often >60 m) and
never pass `fixAccuracyMaxM`, so the D65 loop waited the full 60 s window for a
sub-30 m fix that never came, then either anchored on a coarse fix or reported
noGps. The missing GPS indicator confirms GPS was never requested.

Change (client only, no server contract, no new permission):
`SamplingMode.waiting` now requests `LocationAccuracy.high`
(`PRIORITY_HIGH_ACCURACY`), matching `leaderMoving` and the visible-resume
one-shot. The waiting window stays bounded at 60 s and the phase is short-lived,
so the battery cost is acceptable. The 60 m publish gate is untouched.

Verified: `flutter analyze` clean, `dart format` clean, `location_test` 19
green, `trip_controller_test` 24 green.

## D84-2026-10-22: live dots on demand, one trip clock, tighter HTTP timeouts (Accepted)

Code audit against `AGENTS.md` and `PLAN.md`, plus a battery and performance pass
on the app and the server. No API, schema, or user-visible contract changed.

Decision:

- **Live dots (client).** `PLAN.md` 9.5 S03 asks for `GET /v1/live` on open, on
  `resumed`, and on pull-to-refresh, at most once every 10 s, with no polling
  timer. The app still polled every 30 s through `liveTickProvider`. That
  provider is gone; `LiveRefresher` owns the cadence. `markFetched()` records
  each fetch start, so the floor also covers the app-start read. `refresh()`
  returns early inside the floor, otherwise invalidates `liveProvider` and
  awaits it, so the pull-to-refresh spinner ends with the new dots. Triggers:
  app resume (`main.dart` lifecycle observer), branch select for Home and
  Linhas, and the new `RefreshIndicator` on both screens. A failed fetch still
  serves the last good payload (D55).
- **Trip screen clock.** The hero, the status block, and (on web) the
  visibility tracker each ran their own 5 s timer, so one open screen owned
  three periodic timers. The screen now owns a single 5 s `_ticker` that
  rebuilds the tree and feeds the web visibility check. `_TripTimes` is
  stateless again and `metricsRefresh` is gone. The ticker pauses on every
  non-`resumed` lifecycle state and resumes with an immediate tick, because the
  trip process stays alive under the foreground service and background ticks
  only rebuilt an invisible screen. On web the resume path clears the hidden
  state before that tick, so a resumed session is never paused by stale hidden
  time.
- **Home rebuilds.** The greeting comes from
  `currentNowProvider.select(greetingFor)`, so the home widget rebuilds when
  the greeting changes (three times a day) instead of every minute. Sections
  that show countdowns keep watching the clock directly.
- **HTTP timeouts.** `PLAN.md` 11.2 asks for a 5 s connect timeout and an 8 s
  total request timeout; the client had 10 s for both. Aligned, which stops a
  stalled request from holding a socket and the radio for 10 s.
- **Server.** `domain/` must stay pure, but it imported the state module for
  the store shape. The shape and its pure map helpers moved to
  `server/src/domain/store.ts`; `state/store.ts` keeps the factory and
  re-exports the type. `routes.ts` and `tripRoutes.ts` each carried their own
  JSON body reader with its own size cap; both now use `http/body.ts`. The
  generated `server/db/schema.sql` was deleted: migrations are the only schema
  source and nothing referenced it.

Verified: `deno check src/main.ts`, `deno lint`, and `deno fmt --check` clean in
`server/`; full `deno task test` 94 passed, 0 failed against PostgreSQL 16,
including `no_location_at_rest`.

Not verified: the app. This machine is aarch64 and Flutter publishes no Linux
arm64 host build, so `dart format`, `flutter analyze`, and `flutter test` could
not run here. The app changes were kept format-clean by inspection (no added
line exceeds 80 columns, and new constructs copy shapes the formatter already
produced elsewhere in the tree), but CI or the owner's machine must confirm
them before merge. `.github/workflows/ci.yml` already runs those three commands
on `ubuntu-latest`.

Deferred: 27 app files exceed the `PLAN.md` 14.2 review threshold of about 300
lines (largest: `ui_strings.dart` 1431, `trip_controller.dart` 1197,
`vehicle_repository.dart` 616, `search_screen.dart` 580,
`location_service.dart` 563); `server/src/domain/ping.ts` is the single server
file over it at 358. Splitting them is a separate change set, since splitting
without an analyzer trades a verified tree for an unverified one.

Deferred: `offlineFlagProvider` is still a constant `false`, so the global
offline banner (S03) never shows. Wiring it needs a real connectivity source
from the data layer plus widget tests, which this pass could not run.

## ADR: First-party diagnostics (opt-out, 14-day retention)

- Added `POST /v1/diagnostics` storing redacted bundles in a new `diagnostics`
  table with 14-day purge (not 90). No coordinates, tokens, session/user ids,
  IPs or device identifiers beyond the hashed token linkage (cascades on delete).
- Client captures warnings/errors + crash summaries into an append-only
  SharedPreferences list, uploaded on app resume if opted in (default on,
  opt-out in settings). Opt-out clears the pending list.
- No third-party SDK; first-party only, consistent with PRV06/RNF18.
