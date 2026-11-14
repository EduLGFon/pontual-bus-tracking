# DECISIONS.md

Compacted decision index, current as of 2026-11-13. Full history in git. New decisions append to the relevant section. IDs stable and resolvable via "See DECISIONS.md#Dxx". ARCHITECTURE.md is the build contract. Statuses: Accepted, Proposed, Pending owner, Superseded.

## 1. Conventions

- IDs D01-D21 imported from ARCHITECTURE.md v1.1 (Accepted). New deviations use next Dxx.
- Pending infra questions use INFRA-xx until decided, then Dxx.
- Spikes S1-S4 from ARCHITECTURE.md 16. VERIFY items V01-V07.
- UI decisions use D-Uxx. Follow-ups use "-followup"/"-verify" suffix.

## 2. Imported decisions D01-D21 (Accepted, 2026-10-02)

| ID | Decision |
| --- | --- |
| D01 | geolocator directly; smart_location wrapper lacks claimed features |
| D02 | no ping history, no location at rest; location only in API memory |
| D03 | clients talk only to Deno API, never PostgreSQL |
| D04 | <a id="D04"></a>attach-at-ping online clustering with dead reckoning, pure TS engine |
| D05 | vehicle position is newest accepted fix, not centroid |
| D06 | role and interval returned in ping; two-phase hand-over |
| D07 | timetables static versioned JSON, not a DB table |
| D08 | server time only, no client recorded_at |
| D09 | revised data budgets (leader ~0.15 MB/h) |
| D10 | consent (LGPD art. 7, I) for location sharing |
| D11 | no ACCESS_BACKGROUND_LOCATION; FGS type location only |
| D12 | OSM raster tiles via flutter_map cache, behind TileSource |
| D13 | compact JSON over WebSocket, not binary |
| D14 | owner VPS with PostgreSQL, not Supabase |
| D15 | read-only WebSocket stream served by API |
| D16 | anonymous opaque device tokens (256-bit, SHA-256 hash, 30-day sliding) |
| D17 | in-process tick loop every ~5 s |
| D18 | hot state in memory, single instance; restart drops live state |
| D19 | Cloudflare proxy in front; container-only tunnel; no host Caddy; Deno binds inside container |
| D20 | future analytics only on de-identified aggregates |
| D21 | server libs: Hono, postgres.js, one schema lib, dbmate |

## 3. Infra decisions INFRA-01..24

- INFRA-01 (2026-10-02, Accepted): VPS baseline Oracle SP 1 oCPU/6GB/50GB; PostgreSQL localhost (D24).
- INFRA-02 (pending, Pending owner): staging instance optional.
- INFRA-03 (pending, Pending owner): swap/disk encryption.
- INFRA-04 (pending, Pending owner): SSH/admin access.
- INFRA-05 (2026-10-20, Accepted): app pontual.spotnik.space, API api-pontual.spotnik.space via CF Tunnel.
- INFRA-06 (pending, Pending owner): CF plan/features (WS timeout, edge cache, AOP).
- INFRA-07 (2026-11-12, Resolved by D102): no origin TLS listener; public edge is container-only CF Tunnel.
- INFRA-08 (2026-11-12, Resolved by D102): no host Caddy; cloudflared logs at info, no request bodies.
- INFRA-09 (pending, Pending owner): backup target/key holder (30-day).
- INFRA-10 (pending, Pending owner): uptime monitor.
- INFRA-11 (pending, Pending owner): deploy method (manual by owner default).
- INFRA-12 (pending, Pending owner): secret rotation (6-month).
- INFRA-13 (2026-10-02, Accepted): Hono 4.13.12 MIT via JSR.
- INFRA-14 (2026-10-02, Accepted): postgres.js 3.4.9 Unlicense, TLS/pooling.
- INFRA-15 (2026-10-02, Accepted): schema lib Valibot 1.5.0 (T08).
- INFRA-16 (2026-10-02, Accepted): dbmate v2.36.0 verified.
- INFRA-17 (2026-10-02, Accepted): Deno pin 2.9.7.
- INFRA-18 (2026-11-12, Resolved by D102): no host systemd unit; container sandbox in D101/D102.
- INFRA-19 (2026-10-02, Accepted): code licence GPLv2 (D23); data licence open.
- INFRA-20 (2026-10-02, Accepted): applicationId com.spotnik.pontual (D22).
- INFRA-21 (pending, Pending owner): Play account path/closed-test timing.
- INFRA-22 (2026-10-02, Accepted): Flutter pin 3.47.6.
- INFRA-23 (pending, Pending owner): controller identity/contact e-mail.
- INFRA-24 (2026-10-02, Accepted): pilot lines 66, 62x2, 64, 60 (D25).

## 4. VERIFY list V01-V07

- V01 (2026-10-02, Open): geolocator FGS screen-off/swipe-away/isMocked/notification action/POST_NOTIFICATIONS.
- V02 (2026-10-02, Resolved): Deno/Hono/postgres/dbmate/CF/ping bytes verified (S2).
- V03 (2026-10-02, Resolved): flutter_map cache/OSM policy (S3).
- V04 (2026-10-02, Resolved): Flutter Web wasm/service worker/wake lock (S4).
- V05 (pending, Open): Play FGS declaration/closed-test/Data safety wording.
- V06 (pending, Open): ANPD/ECA Digital legal deadlines/wording.
- V07 (pending, Open): host MemoryDenyWriteExecute/disk encryption/bbox vs routes.

## 5. Spikes S1-S4 (2026-10-02)

- S1 (Done): geolocator 14.1.1 FGS via AndroidSettings; swipe-away stops; isMocked; no notification action.
- S2 (Done): Deno 2.9.7; Hono 4.13.12; postgres.js 3.4.9; dbmate v2.36.0; CF Free WS.
- S3 (Done): flutter_map 8.3.2; 50 MB cache cap; OSM policy compliance.
- S4 (Done): --wasm dual; skwasm beats CanvasKit; no service worker; wake lock needs HTTPS.

## 6. Current status (2026-11-13)

- Alpha on owner VPS behind container-only Cloudflare Tunnel; API in container, no host port; static on GitHub Pages.
- Server/client/web tests green; security suite passes no_location_at_rest.
- Shared location stays in API process memory only; nothing persisted.
- Owner-blocked: first tagged release, Play closed test, phone field tests, legal review.
- Budgets: web first load ~0.95 MB gz; AAB ~52 MB; ping ~0.6 KB.
- Full history removed; see git log and CHANGELOG.md.

## 7. Owner answers round 1 D22-D28 (Accepted 2026-10-02)

- D22: product name Pontual; applicationId com.spotnik.pontual.
- D23: code licence GPLv2; data licence open.
- D24: VPS baseline Oracle Sao Paulo.
- D25: pilot lines 66, 62x2, 64, 60.
- D26: web sharing in alpha scope.
- D27: deferred controller identity, lawyer/DPO, Play account, manual deploy.
- D28: D20 roadmap confirmed de-identified aggregates only.

## 8. UI decisions D-U01-D-U31

- D-U01 (2026-10-14, Accepted, superseded by D-U17): UI_SPEC truncated; reconstructed sections 14-18.
- D-U02 (2026-10-14, Accepted, superseded by D-U09): no NEW_UI cutover flag; old UI removed.
- D-U03 (2026-10-14, Accepted): variable Manrope subset (51,712-byte TTF), not five static weights.
- D-U04 (2026-10-14, Accepted): colour tokens adjusted for WCAG 2.2 AA.
- D-U05 (2026-10-14, Accepted): StaticLine gained optional terminals/area_tags/is_active.
- D-U06 (2026-10-14, Accepted): web size measured from build/web; Android uses --analyze-size.
- D-U07 (2026-10-14, Accepted): no per-screen parity flag; /line/:key?tab=horarios is timetable URL.
- D-U08 (2026-10-14, Accepted): house style (CertaintyStyle, dashed predicted pill, BusIconPainter).
- D-U09 (2026-10-14, Accepted): cutover done; old UI removed; shared copy moved to UiStrings.
- D-U10 (2026-10-14, Accepted): dock and trip attach fixes (LiveDockHost, deferred attach).
- D-U11 (2026-10-14, Accepted): three pre-existing trip test failures were test bugs.
- D-U12 (2026-10-14, Accepted): stack-switch rewrite reverted; Flutter restored per owner order.
- D-U13 (2026-10-14, Accepted): new consent sheet discloses; existing flow records once.
- D-U14 (2026-10-14, Accepted): legacy share flow suppresses sheets for new UI.
- D-U15 (2026-10-14, Accepted): no second dispose on suppressed denial path.
- D-U16 (2026-10-14, Accepted): R8 dontwarn for Play Core; AAB 52.3 MB baseline.
- D-U17 (2026-10-11, Accepted): UI_SPEC sections 14-18 arrived; D-U01 retired.
- D-U18 (2026-10-11, Accepted): brand source, perf baseline, alpha dimming by colour.
- D-U19 (2026-10-11, Accepted): UI_SPEC compliance build (U25, U26, router, copy, home, perf, a11y).
- D-U20 (2026-10-11, Accepted): map deferred import stays eager, documented.
- D-U21 (2026-10-11, Accepted): full verification green; deploy owner-blocked.
- D-U22 (2026-10-11, Accepted): device perf method and SDK test dependency.
- D-U23 (2026-10-11, Accepted): owner-supplied app icon applied (launcher + PWA).
- D-U24 (2026-10-11, Accepted): Android web banner downloads release APK.
- D-U25 (2026-10-11, Accepted): home/sheet/dock/map fix sweep (10 items).
- D-U26 (2026-10-11, Accepted): owner UI issue sweep (8 items) + home-screen brief deviations.
- D-U27 (2026-10-12, Accepted): single consent sheet in new share flow.
- D-U27-followup (2026-10-12, Accepted): startShare used dying context/ref; fixed.
- D-U28 (2026-10-12, Accepted): recenter targets viewer at neighbourhood zoom.
- D-U29 (2026-10-12, Accepted): map tile failure recovery and deterministic enter fit.
- D-U30 (2026-10-12, Accepted): test suite slimmed 46 files to 28.
- D-U31 (2026-10-12, Accepted): two map locate buttons (viewer dot, closest bus).

## 9. Later decisions D29-D113

- D29 (2026-10-10, Accepted): rate-limit strikes no longer end trips; fast streams sampled ~4 s.
- <a id="D30"></a>D30 (2026-10-11, Accepted): anonymous momentum for ETA/prediction; amends D02 narrowly.
- D30-followup (2026-10-11, Accepted): PLAN deltas shipped (RF20/RF22 partial).
- D31 (2026-10-12, Accepted, pending owner review): lines-screen brief deviations.
- D32 (2026-10-12, Accepted, pending owner review): line-detail brief deviations.
- D40 (2026-10-12, Accepted, renderer Proposed): offline vector city map pipeline (Protomaps pmtiles).
- D41 (2026-10-13, Accepted): docs/asset locations outside AGENTS.md 14.
- D42 (2026-10-13, Accepted): deep-audit deferred items with rationale.
- D43 (2026-10-13, Accepted): optimization sweep; three server wins landed.
- D44 (2026-10-13, Accepted): ten optimization passes landed green.
- D45 (2026-10-13, Accepted): ping cadence toward 5 s map updates.
- D45-verify (2026-10-13, Accepted): 5 s cadence proven on live smoke server.
- D46 (2026-10-13, Accepted): stops layer promoted to alpha, OSM seed.
- D47 (2026-10-13, Accepted): stale-pump poisoning fixed; revive-once.
- D48 (2026-10-13, Accepted): share lifecycle races and notify guard fixed.
- D49 (2026-10-13, Accepted): stops resurvey 8 to 12 OSM nodes.
- D50 (2026-10-13, Accepted): prediction horizon starts at staleness onset.
- D51 (2026-10-13, Accepted): predicted arrivals exempt from staleness flip.
- D52 (2026-10-13, Proposed): per-stop ETA hunt list.
- D53 (2026-10-13, Accepted): progress sheet popped on wrong navigator fixed.
- D54 (2026-10-13, Accepted client half, Proposed server half): consent revoke half-life.
- D55 (2026-10-13, Accepted): live dots survive a failed poll.
- D56 (2026-10-13, Accepted): cancel racing create POST fixed.
- D57 (2026-10-14, Accepted): ping refresh zone-escape and refresh loop fixed.
- D58 (2026-10-14, Accepted): CI and deploy repair.
- D59 (2026-10-16, Accepted): background survival plus 5 s map latency.
- D60 (2026-10-16, Accepted): cold start removed; first vehicle on first moving ping.
- D61 (2026-10-16, Accepted): battery exemption requested from offline card.
- D62 (2026-10-16, Accepted): test-only force-ping button.
- D63 (2026-10-16, Accepted): follower stream uses balanced accuracy.
- D64 (2026-10-16, Accepted): degraded downgrade hold keeps GPS on.
- D65 (2026-10-16, Accepted): trip start anchors on first good fix.
- D66 (2026-10-16, Accepted): no heading published at standstill.
- D67 (2026-10-16, Accepted): approximate-only grants fail fast with guidance.
- D68 (2026-10-16, Accepted): native GNSS quality channel, plumbing only.
- D69 (2026-10-16, Accepted): GNSS quality wired into trip screen.
- D70 (2026-10-16, Accepted): GPS acceptance protocol (docs only).
- D71 (2026-10-16, Accepted): mid-trip approximate downgrade detected, sends held.
- D72 (2026-10-19, Accepted): GNSS used-in-fix compat after stub removal.
- D72 (2026-10-22, Accepted): waiting phase uses high accuracy to engage GPS.
- D73 (2026-10-19, Accepted): last known bus position keeps its ping age.
- D74 (2026-10-19, Accepted): web gap recovery stays foreground-only.
- D75 (2026-10-20, Accepted): static deploy dry run repaired.
- D76 (2026-10-20, Accepted): gitleaks allowlist for UI storage keys.
- <a id="D77"></a><a id="D77-2026-10-20"></a>D77 (2026-10-20, Accepted): trip minimize returns to previous screen.
- D78 (2026-10-20, Accepted): trip sharing screen shows measured metrics.
- D79 (2026-10-20, Accepted): satellites replace battery in trip metrics.
- D80 (2026-10-20, Accepted): second owner-supplied app icon applied.
- D81 (2026-10-20, Accepted): permanent Android download link in web settings.
- <a id="D82"></a>D82 (2026-10-20, Accepted, target model superseded by D83): passenger reports.
- <a id="D83"></a>D83 (2026-10-20, Accepted): reports use coarse location area not stop picker.
- D84 (2026-10-22, Accepted): live dots on demand, one trip clock, tighter HTTP timeouts.
- D85 (2026-10-27, Accepted): Protomaps source pin updated to available build 20261026 after 20261019 returned 404; extracted and verified city PMTiles at 41.6 MB.
- D86 (2026-10-31, Accepted): GPS wait keeps `stream.first` loop per T34; cancel checked before gps-timeout so Cancelar reports declined, not noGps.
- D87 (2026-10-31, Accepted): place search pre-normalizes gazetteer, single route scan per pair, code map lookup, 180 ms debounce; radii 500/300 unchanged.
- D88 (2026-10-31, Accepted): line map decodes route once per input via memoized provider; vehicle tick only re-sorts markers.
- D89 (2026-10-31, Accepted): remote-config check timestamp written only on successful fetch; bundled flags parsed once per instance.
- D90 (2026-11-01, Accepted): foreground-service teardown serialized, startup handshake, single-trip guard. Root cause of silent trips with no notification on first start/rapid restarts: native geolocator teardown is async and process-wide, every stop fire-and-forget, so a new subscription could race the previous disable; stacked /trip routes plus TripHost.attach dispose amplified it. Fix: process-wide teardown gate in LocationService (stop registers bounded 2 s cancel, start awaits quiescent up to 3 s), non-blocking stop that never stalls test zones, startup handshake failing visibly as StartFailure.service when no native subscription exists after create POST, single-trip guard reopening live trip instead of starting a second. No new deps, no wake lock, no background location, cadence/budgets unchanged.
- D91 (2026-11-01, Accepted): permanent anti-regression for background sharing. Startup handshake extended into mid-trip subscription invariant (every supervision round ends visibly with detail service when native subscription or fix broadcast gone, never silent); process-wide TripController._active blocks any second concurrent start with busy even if a future caller bypasses UI guard; dock never stacks a second /trip on live one; new endService end-card copy; architecture test fails on any direct getPositionStream outside LocationService; teardown gate plus active-trip state reset per test so suites cannot poison each other.
- D92 (2026-11-03, Accepted): Android release build restored/tuned for 4-core/16 GiB dev machine. `permission_handler` re-pinned to ^12.0.0 (12.0.3 / android 13.0.1) after 2026-10-30 blanket update re-selected 13.0.2 / android 14.1.1, which fails checkReleaseAarMetadata (requires compileSdk 37 while Flutter 3.47/AGP 9.1 pin 36); restores 2026-10-10 decision. Gradle daemon heap 8 GiB/4 GiB -> 4 GiB/1 GiB with ParallelGC, local build cache and parallel execution; configuration cache stays off because Flutter 3.47 compileFlutterBuild* tasks call Task.project at execution. Android builds arm64 only (`--target-platform android-arm64` plus ndk.abiFilters); release uses `--dart-define-from-file=env/phone.json --obfuscate --split-debug-info`. Iterate with debug `flutter run`; release AOT+R8 CPU-bound. `--no-pub` not used after `flutter pub get` because pub get writes a debug-mode plugin registrant including integration_test that breaks release Java compilation.
- D93 (2026-11-03, Accepted): stall watchdog stops churning foreground service. Root cause of location usage dropping/returning ~30 s: watchdog measured silence since last accepted fix with fixed 30 s window, but follower/offline saver/paused sampled at 45 s and filter can drop every fix in a coarse patch. Both looked like frozen stream, so every supervision round cancelled/recreated native position stream, stopping/restarting Android FGS. Fix: track last position event (accepted or filtered) and scale window to one sampling interval plus 30 s stall window (30 s for 5 s and 15 s modes, 75 s for 45 s modes). Genuine frozen streams still recreate, at most once per window. No dependency/permission/cadence/budget change.
- D94 (2026-11-03, Accepted, owner directive): every role reports at 5 s cadence. `waiting`, `leaderMoving`, `leaderStill`, `follower` request location every 5 s and instruct `n=5`; `offlineSaver` and `paused` keep 45 s (no uploads, stay cheap). Server follower jitter pinned to 0 in main.ts so instructed follower interval exactly 5 s not 5+/-10 s. Next send slot measured from last send, not response, so slow RTT cannot stretch 5 s into 10 s (PLAN 8.7). Consequences: follower data/battery budgets rise to leader levels (PLAN RNF02/RNF03, 10.1), promotion latency (KL1) drops to about one ping, D64 degraded hold now delays high-to-balanced accuracy change rather than cadence downgrade. D93 stall window keeps 30 s for all role modes and 75 s for two remaining 45 s power modes. No permission/dependency/FGS change.
- D95 (2026-11-04, Accepted, owner directive): RN battery exemption parity with D61 and Flutter copy. Lack of data (sharing health issue offline: 3 failed sends or 120 s without success) shows persuasive Manter ativo card on RN trip screen, Android only. Card names cause (battery optimization paused sharing) and fires direct system exemption pop-up only from its tap via expo-intent-launcher REQUEST_IGNORE_BATTERY_OPTIMIZATIONS with package data, checked via expo-battery isBatteryOptimizationEnabledAsync. Never auto-fires, never blocks sharing, never throws. Deps added via bunx expo install: expo-battery, expo-intent-launcher, expo-application. Manifest permission REQUEST_IGNORE_BATTERY_OPTIMIZATIONS added to rn/app.json. Covers AGENTS.md 15 hard-limit ADR requirement alongside D61 and PLAN 8.6.
- D96 (2026-11-10, Accepted, owner directive): personal arrival at rider's stop on line screen. Rider opts in with one tap and one-shot foreground fix (native precise-only, 120 m gate; web 200 m), snaps locally to nearest learned stop within 300 m, app calls existing GET /v1/lines/:id/eta?stop=<id>. Only line id and stop id sent; coordinates never logged, persisted or sent. ETA refreshes at most every 10 s on existing 5 s vehicle tick, pauses off-route and in data saver, adds no timer. Only live vehicles get ETA; heading filters opposite-direction buses; passed buses labeled and never shown as "Chegando"; server confidence and sample count shown. No new dependency/server/schema change. Deviation from UI_SPEC 2.1 "no new network calls from UI layer" and viewer-location change in UI_SPEC 7.5: call is one existing read endpoint on demand, not UI poll loop, server caches 10 s. viewerLocationProvider now derives from explicit fix and no longer auto-prompts on web.
- D97 (2026-11-10, Accepted, owner directive): learning_min_route_trips default 20 to 5. Single-rider pilot lines publish learned polyline after 5 completed trips in one direction instead of 20. Runtime override via app_config key learning_min_route_trips still wins. Tradeoff: smaller aggregate weakens k-anonymity for routes; 5-trip route can reflect one rider's commute. Mitigations kept: trimEndsS 120 s, no device/trip ids in aggregates, no raw tracks stored, stops/ETA still gated by minStopPasses/kMin/distinct-days. Revisit before public release.
- D98 (2026-11-10, Accepted, owner directive): partial-trip learning with absolute corridor. Per-trip progress binning stretched partial trip over whole route and corrupted geometry, so learning now accumulates fixes in 50 m metric grid per (line, direction), builds ordered chain from observed directed cell graph, assigns stop ordinals by projection. A device with at least 5 started trips unlocks aggregates; counter is devices.learning_trips, incremented once per non-resume trip start after consent/opt-out checks, retained with device row (30 days). LEARNING_PRIVACY_MODE selects gate: "all" (default, learning phase) publishes stops and dwell/segment stats from single pass; "route_stops" keeps minStopPasses, distinct-days and kMin. Terminus dwell suppression stays on in both modes. Tradeoff: kMin counted samples, not distinct people, so single-rider aggregates already possible; new gate makes that explicit for learning phase. Coordinator review before public release.
- D99 (2026-11-11, Accepted): location lifecycle and diagnostics fidelity from first-party field bundles (LOGS-REPORT T1-T6). Root causes from 30 bundles/60 records: Android 14+ rejects startForeground when backgrounded supervision round cancels/recreates geolocator stream (14/30 bundles), dead stream still reported attached subscription so trips showed sharing with no fixes (3 fully silent bundles), recovery then cancelled stream that never started ("No active stream to cancel", 12 records), stall watchdog recreated streams every 30-60 s in background. Fix: native stream creation/recreation banned while app not resumed; background stall/mode changes deferred and exactly one recovery runs on next resume; foreground dead/silent restarts budgeted to one per stall window of requested mode; two recoveries without any position event mark stream dead; coarse-but-alive fixes never restart; unawaited cancels carry error handlers; concurrent relistens serialized; relisten parked on slow cancel cannot subscribe after stop. hasActiveSubscription requires attached non-dead stream; startup handshake requires produced fix; mid-trip invariant ends trip visibly as automatic/service in foreground, defers while backgrounded, ends on failed resume retry, so sharing never silently dead. No background location permission, wake lock, telemetry, local DB, or new dependency. Diagnostics: real build from APP_VERSION with CI deriving from pubspec (blank falls back "unknown"); real platform and OS (conditional import, no dart:io on web); random per-bundle UUID v4 stable across retries, never device identifier; crash payload with exception, FlutterError context, first 1000 stack chars capped at server 4000; serialized persisted writes; one cold-start upload after 8 s debounce plus one on resume; success clears only uploaded record. (truncated in source)
- D100 (2026-11-11, Accepted): Protomaps source pin updated from 20261026 to 20261110 after 20261026 returned 404 (builds expire ~1 week); verified HEAD 200 and pmtiles show header read.
- D101 (2026-11-12, Accepted, owner directive): container deployment. `server/deploy/Dockerfile` multi-stage build on pinned `denoland/deno:2.9.8`. Build stage caches `server/deno.lock` with --frozen-lockfile and builds static data bundle from data/ and tools/; runtime stage copies only server, data bundle, read-only module cache. No secret, .env, app, RN or docs tree enters image. Runtime user deno; root filesystem read-only with 16 MiB noexec /tmp; all capabilities dropped; no-new-privileges; PIDs/memory/CPU/log size bounded. `start:container` runs with --cached-only and denies write/run/ffi/sys; network limited to 0.0.0.0:8080, loopback metrics, db:5432, host.docker.internal:5432. Compose publishes only 127.0.0.1:8080 for Caddy/CF tunnel; metrics and PostgreSQL not published. HOST is 0.0.0.0 only inside container. Env files remain only secret source (`server/.env` or PONTUAL_ENV_FILE, plus `server/.env.db` or PONTUAL_DB_ENV_FILE for DB-only secrets). Systemd unit stays as non-container option. Bundled compose also runs PostgreSQL 16.15 (Debian, for openssl) with named volume and no published port. First-start init script generates self-signed cert in volume, enables ssl=on with TLSv1.2 minimum, switches TCP rules to hostssl so cleartext rejected, creates least-privilege pontual_app role with password from env. pontual_migrator owns schema and used only by one-shot amacneil/dbmate:2.36.0 service running --no-dump-schema before API starts; pontual_app remains only credential in API DATABASE_URL (sslmode=require). DB credentials in separate env file so API container does not receive migrator password. No schema/endpoint/app behavior change. (truncated in source)
- D102 (2026-11-12, Accepted, owner directive): container-only public edge. Public edge is CF Tunnel running inside `pontual-api` Compose stack as `cloudflared` service. Stack has four services (db, migrate, api, cloudflared) and three networks: edge (internal, api+cloudflared), data (internal, api+db+migrate), egress (non-internal, cloudflared only). API has no internet egress and no published port; DB not on tunnel network. cloudflared uses image cloudflare/cloudflared:2026.11.0, distroless, uid 65532, read-only root FS, drops all capabilities, no-new-privileges, exposes no host ports. Reads locally managed config mounted at /etc/cloudflared/config.yml (PONTUAL_TUNNEL_CONFIG_FILE, default server/secrets/cloudflared.yml) plus credentials JSON mounted at /run/secrets/cloudflared_credentials (PONTUAL_TUNNEL_CREDENTIALS_FILE, default server/secrets/cloudflared_credentials.json). Config identifies tunnel by UUID because no cert.pem mounted. Live tunnel locally managed, so token connector would ignore local ingress; config carries ingress rules. Tunnel outbound-only; public hostname declared in config, service target http://api:8080. extra_hosts keeps host.docker.internal available so shared tunnel can route api-ephemeron.spotnik.space to host on 8091. No dashboard-managed ingress required. TRUST_CLOUDFLARE=true safe because API unpublished and only tunnel shares internal edge network. No host Caddy and no pontual.service systemd unit; Docker restart: unless-stopped and Docker enabled at boot handle restarts. Secrets are server/.env, server/.env.db and server/secrets/cloudflared_credentials.json locally, and /etc/pontual/api.env, /etc/pontual/db.env, /etc/pontual/cloudflared_credentials.json on VPS; config non-secret and world-readable 0644/0444 or owner uid 65532 owner-read, credentials never in compose/env examples/git/logs/docs. deploy.sh deploy <tag> builds pontual-api:<tag>, runs docker compose up -d, checks API health via docker compose exec -T api deno eval..., checks tunnel via docker compose exec -T cloudflared cloudflared tunnel --metrics 127.0.0.1:2000 ready, records current/previous tags under /opt/pontual by default, rolls back on failure; rollback reactivates previous tag; status runs docker compose ps. Rollback by image tag. Supersedes D101 on: API no host-published port or host.docker.internal allow-list, systemd unit and host Caddy removed, tunnel uses locally managed config plus credentials.
- D103 (2026-11-12, Accepted, owner directive): host-provided Compose override for shared tunnel. `server/deploy/deploy.sh` automatically includes /etc/pontual/compose.override.yaml when present (PONTUAL_COMPOSE_OVERRIDE overrides path). This host uses it to attach cloudflared container to Ephemeron Docker network so shared `pontual` tunnel can serve api-ephemeron.spotnik.space without publishing host port. Override root-owned mode 0644, must not be group/world-writable, stays outside repo. A host service bound to loopback is not reachable through host.docker.internal; use external-network override or bridge-reachable address. Supersedes D102's extra_hosts note for that case.
- D104 (2026-11-12, Accepted, owner directive): UX 2.0 answer-first pass across Início, Linha, Linhas, Busca and shell; UI and copy only, no new dependency, no new network call, no change to consent/auth/ping cadence/location persistence/privacy. Início leads with "Sua próxima saída", earliest scheduled departure across favourites and shortcuts (shortcut origin wins over favourite for same line, tomorrow fallback, live chip only when line has live vehicles, never fabricated live arrival); first-run line picker saves favourites; empty live section becomes actionable share card; old dock coachmark removed. Linha moves hero above tabs: vertical NextBusCard (ETA first) when personal arrival card not ready, personal card as hero when ready; header shows live count, source of hero, or end-of-day state instead of repeating live-empty sentence; personal card adds walking estimate (straight-line distance at 80 m/min, min 1 min) and leave-now/leave-soon/still-time verdict as estimate; location prompt compact card; peek minimum 220 to 270 dp so header plus hero ETA fit at 320x568. Shell: idle global floating dock removed, active trip bar renders in normal layout above navigation so cannot cover content, Início and Linha carry share entry points, line screen keeps contextual idle dock, branch selection keeps selectionClick haptic. Linhas and Busca share one LineStatusLine and one favourite action; Linhas gains search icon and honest live summary; typed search rows show same status and star as browse rows. Evidence: targeted suites reported green by implementing branches (home, line/personal arrival, lines/search, shell) with analyze clean, including 320x568 2x and 800x600 wide line tests; full suite pass. (truncated in source)
- D105 (2026-11-12, Accepted, owner directive): minimalist sharing screen. /trip hero keeps live state, headline, line identity, terminals, elapsed time; trust line and separate last-send proof row removed (substance stays in consent/settings). Three-cell metrics card became one compact status line opening details sheet with same measured values; header flag became pinned full-width "Avisar problema" secondary action above stop block. No new report kinds, no API/server change, no change to TripController, ping cadence, location or privacy. Evidence: full app suite 597 tests (1 skipped), flutter analyze and dart format clean; targeted trip/layout/report tests green; share screen review PASS.
- D106 (2026-11-12, Accepted): true 5 s sharing cadence. Client now schedules each ping from last send start at server interval with injected one-shot timer, sends latest fresh unsent fix, never sends sooner than interval after previous send start, defers fix queued during in-flight request to next slot. Live map rebuilds on throttled repository change signal (at most one rebuild per second in normal mode) while existing 5 s/30 s tick keeps age labels and data saver; socket remains repository's. Server keeps 4 s min-interval defense but returns additive `rl` flag and increments aggregate rate-limited counter so silent drops visible. Rationale: fix-arrival gating produced 7-11 s gaps, in-flight immediate resend produced 3-4 s bursts, 5 s-only UI tick coalesced updates. Cadence still depends on GPS fix availability and server RTT. Evidence: deterministic cadence tests with injected timers cover 5 s and 10 s gaps, early-fix deferral, in-flight deferral, end cancellation; full app suite and server ping/metrics tests green.
- D107 (2026-11-12, Accepted, owner directive): line 66 learning diagnosis and safeguards without schema change. Diagnosis: line 66 has no static route polyline, so map draws only active learned_routes row; publication needs 5 corridor-contributing trips in same (line, direction) inside one API process; corridor counters memory-only and reset on restart; 2026-11-12 container deployment uses new PostgreSQL volume with no dump/restore, so fresh DB would drop learned routes/devices/tokens while app keeps sharing. App's "trips shared" counter is local kudos, not server learning count. Changes: corrected docs/data-learning.md, added docs/runbooks/learning-verification.md, added read-only deploy preflight refusing new/empty DB volume unless PONTUAL_ALLOW_EMPTY_DB=1 (deploy path only, never rollback), added aggregate-only learning drop-reason counters. No schema/threshold/eligibility/publication change. Production verification remains: check VPS volume/data counts and restore old DB if not imported.
- D108 (2026-11-12, Accepted, owner directive): humanized pt-BR copy. Deck and bundled privacy/terms summaries rewritten, inline widget copy moved into deck, passenger-report vocabulary unified to "Avisar/Aviso", AI-slop/marketing/exclamation/em-dash patterns removed. Privacy claims tightened to what app actually does (location only on user request, including personal-stop reads and reports), permission and sharing-failure titles truthful, Android notification/search label/vehicle screen-reader copy corrected. Owner approved rewriting legal text; every disclosed fact preserved and summaries consistent with docs/privacy, but lawyer/DPO review still required before release. Evidence: full app suite 597 tests (1 skipped), flutter analyze and dart format clean, copy review PASS.
- D109 (2026-11-12, Accepted, owner directive): learning aggregates v2. Every organic trip from consenting, non-opted-out device contributes; confidence is sample count, not gate. Supersedes D97 and D98 and removes 5-trip device gate (devices.learning_trips), learning_min_route_trips, learning_min_trip_route_m, corridorMinCells, minRouteLengthM, minStopPasses, stopMinDistinctDays, kMin, route_stops mode and LEARNING_PRIVACY_MODE. Synthetic/test traffic has no marker in API; simulator excluded operationally by running only against disposable DB, dedicated marker needs separate ADR. Migration 0006 adds DB-backed accumulators (learning_route_cells, learning_route_edges, learning_route_state, learning_dwell_bins, learning_travel_bins) on fixed 50 m grid anchored lat -18.72, lng -39.85 so cell keys survive restarts, drops learning_watermarks and devices.learning_trips. Route publishes after first contributing trip; new geometry within 15 m median deviation updates active row in place, otherwise old version retired and new one inserted, with 8192-char polyline cap and 2-point validity as only remaining publication limits. Stops publish on first dwell with weighted centroid and sample_passes; dwell/travel histograms cumulative, bucketed by dwell start or destination arrival in America/Sao_Paulo, never trip start; stop_dwell_stats and segment_stats recomputed from all retained bins with nearest-rank p50/p90 and served from one sample with count attached. Normal trips trim 120 s per end; trips shorter than 240 s trim at most 10% per end and fall back to all fixes if fewer than 2 remain. Contributions run in async per-trip queue and periodic flush republishes stale routes as crash-window safety net; queued contribution lost on process death not recoverable because no raw trip stored. Retention follows... (truncated in source)
- D110 (2026-11-12, Accepted): synthetic-trip exclusion and closing v2 database-test gap. POST /v1/trip now accepts optional `synthetic` boolean, default false. Value client-supplied and untrusted: can only suppress that trip's contribution to learning, never grant access, change ownership, bypass quotas or alter live sharing. Not persisted in any table or log. Learning consumer ignores synthetic tripStarted event before creating working state. Simulator sends synthetic:true for rider starts and abuse starts. Additive field does not break old clients. D109 DB-test limitation closed: portable PostgreSQL 16.15 build initialized local cluster, migrations 0001-0006 applied cleanly, 0006 down migration rolled back and reapplied cleanly, full server suite passed with TEST_DATABASE_URL (136 passed, 0 failed, 0 ignored). Targeted learning/schema/retention/no-location/metrics/config suites passed (37 passed, 4 ignored by own test options). No production DB/deploy/push. Client opt-out toggle and legal sign-off remain open.
- D111 (2026-11-12, Accepted): one-way stop-contributing action in privacy center. Existing DELETE /v1/me/learning now reachable from app as confirmed "Parar de contribuir com dados agregados" row. Deliberately one-way: no re-enable endpoint/toggle, confirmation body says so, policy discloses. Offline reports nothing changed and leaves local state untouched; missing token is no-op success because no server record to stop. Past aggregates not rewritten because cannot be attributed to device. Added BusApi.stopLearning, PrivacyActions.stopLearning, privacy row/dialog, pt-BR strings, aggregate line in collection summary. No new dependency/permission/network call on screen load/local persistence. Closes D110 client opt-out gap. Evidence: dart format clean, flutter analyze clean, targeted privacy/settings tests 27 passed, full app suite 600 passed (1 skipped). Legal review of new copy remains pending.
- D112 (2026-11-12, Accepted, owner directive): PostgreSQL 18.6. Bundled Compose DB moves from postgres:16.15 to postgres:18.6, using 18 volume layout (pontual-db:/var/lib/postgresql, PGDATA=/var/lib/postgresql/18/docker). CI and README move to postgres:18.6-alpine / PostgreSQL 18. Deploy preflight now detects old PostgreSQL 16 PG_VERSION at volume root and prints migration hint when 18 cluster empty/unqueryable; successfully restored 18 cluster still deploys. Prevents unmigrated 16 volume from silently becoming empty 18 cluster without blocking post-restore deploy. 16 to 18 data directory not compatible: next deploy requires dump/restore in docs/runbooks/docker.md (or pg_upgrade), no in-place image swap. Supersedes D101's postgres:16.15 pin and repeats D110 test evidence on 18.6. Verification: PostgreSQL 18.6 portable binaries, migrations 0001-0006 applied, 0006 down migration rolled back and reapplied cleanly, full server suite passed with TEST_DATABASE_URL (136 passed, 0 failed, 0 ignored). Not verified: Docker Compose runtime with 18 image (no Docker daemon here) and production VPS migration. Client remains on same API contract.
- D113 (2026-11-13, Accepted, owner directive): every active line is live-capable. All 24 active files in data/lines/ now set pilot:true (60, 62, 63, 64, 66 and 99 already did); a line with is_active:false stays pilot:false and remains timetable-only. pilot stays in v1 data schema for backward compat and remains per-line capability switch read by StaticLine. On those lines same flag also enables live map, passenger reports and personal arrival, not only trip sharing. No server/API/auth/consent/retention/schema/Dart code change; server already accepts trips for any active line and ignores pilot. Routes remain learned from trips because no static route files exist; hand-recorded polylines used only where available. Static bundle and bundled app asset regenerated (lines.46d8ef1eb611.json, data_version 46d8ef1eb611). Verification: deno task data-validate valid 24 line files and 0 stops; deno task data-test 5 passed, negative run with line 10 temporarily pilot:false failed new test (4 passed, 1 failed) before restore; deno task data-build produced 46d8ef1eb611; deno fmt --check and deno lint clean; copied asset manifest names new lines file and jq reports 0 active lines without pilot:true; dart format --output=none --set-exit-if-changed lib test 0 changed; flutter analyze no issues; flutter test --concurrency=1 600 passed, 1 skipped. No deploy/migration/push/production action.
- D114 (2026-11-13, Accepted, owner directive): dependency refresh for app and server. Flutter: flutter_riverpod 3.5.0, go_router 18.1.4, permission_handler 13.0.2; permission_handler 13 requires compileSdk 37, so app/android/app/build.gradle.kts pins compileSdk = 37 while Flutter 3.47/AGP 9.1 default 36 and only warn that the SDK is untested (debug APK, release AAB and checkReleaseAarMetadata pass). wakelock_plus stays 1.8.0: 1.8.2 requires dbus ^0.8.0 while geolocator_linux 0.2.6 requires dbus ^0.7.3; no dependency override added. Server: @hono/hono 4.13.14 -> 4.13.18, postgres 4.0.0 -> 4.1.1; lockfile-only change, no source, schema, auth or API contract change. Verification: flutter analyze and dart format clean, flutter test 600 passed (1 skipped), release appbundle with CI flags 19,761,208 bytes vs 21,055,557 pre-change baseline, bundletool arm64 download 8.98-9.02 MB within the 15 MB 10.1 budget, merged release manifest permissions unchanged (no background location, boot receiver or wake lock), release web build OK; server deno fmt/lint/check clean and full suite 136 passed against PostgreSQL 18.7. D92 permission_handler pin is superseded; its Gradle tuning stands. Not verified: on-device permission_handler 13 permanent-denial behavior, production deploy. Pre-existing issue found: release-android CI size gate compares raw AAB bytes (19.8 MB) with the 15 MB gate even though Play arm64 download is about 9 MB and the pre-change baseline was 21 MB; gate and 10.1 definition need alignment separately.

## 10. ADRs

- ADR (2026-10-26, Accepted): first-party diagnostics (opt-out, 14-day retention).
- ADR (2026-10-26, Accepted): enable learning subsystem by default; learned route persistence.
- ADR (2026-11-01, Accepted): migrate RN client package manager/runtime from npm to Bun. Trusted dependencies: @parcel/watcher, unrs-resolver. Node.js retained for expo prebuild/templates. EAS auto-detects Bun via bun.lock; no eas.json version pin (default image version). No app/runtime behavior change.

## 11. Pending / owner-blocked

- Lawyer/DPO; operator outreach owner/timing; backup target/key holder (INFRA-09).
- Uptime monitor (INFRA-10); controller identity/contact e-mail (INFRA-23).
- Play account path/closed-test timing (INFRA-21); staging instance (INFRA-02).
- Swap/disk encryption (INFRA-03); SSH/admin access (INFRA-04).
- CF plan/features (INFRA-06).
- Secret rotation (INFRA-12); deploy method (INFRA-11, manual by owner).
- VPS execution of T04/T05 hardening and first deploy; upload keystore secrets.
- First tagged release + install launch; merged manifest result; Android SDK on capable machine.
- Phone field tests (T47); browser run of banner/wake lock (T37).
- Pages custom domain cert issuance; API_ORIGIN/STATIC_ORIGIN repo vars and deploy-static run.
- Pending proposals: D52; D54 server half; D40 renderer; INFRA-19 data licence; INFRA-21.
- Resolved by D102: INFRA-07 (origin TLS), INFRA-08 (Caddy logs), INFRA-18 (systemd sandbox).

## 12. Spikes results

See section 5. All four spikes done 2026-10-02; device VERIFY items remain open.

## 13. Notes

- Append-only. Newest entries go at the end of each section. See AGENTS.md 14.
- Full history removed; see git log and CHANGELOG.md.
- Compacted decision index; current as of 2026-11-13.
