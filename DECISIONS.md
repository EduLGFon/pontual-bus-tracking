# DECISIONS.md

Compacted decision index, current as of 2026-10-26. Full history is in git.
New decisions append to the relevant section. IDs are stable and resolvable via
"See DECISIONS.md#Dxx". PLAN.md is the build contract.
Statuses: Accepted, Proposed, Pending owner, Superseded.

## 1. Conventions

- IDs D01-D21 imported from PLAN.md v1.1 (Accepted). New deviations use next Dxx.
- Pending infra questions use INFRA-xx until decided, then Dxx.
- Spikes S1-S4 from PLAN.md 16. VERIFY items V01-V07.
- UI decisions use D-Uxx.
- Follow-ups use "-followup"/"-verify" suffix.

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

INFRA-01 (2026-10-02, Accepted): VPS baseline Oracle SP 1 oCPU/6GB/50GB PG localhost (D24).
INFRA-02 (pending, Pending owner): staging instance optional.
INFRA-03 (pending, Pending owner): swap/disk encryption.
INFRA-04 (pending, Pending owner): SSH/admin access.
INFRA-05 (2026-10-20, Accepted): app pontual.spotnik.space, API api-pontual.spotnik.space CF Tunnel.
INFRA-06 (pending, Pending owner): CF plan/features (WS timeout, edge cache, AOP).
INFRA-07 (2026-11-12, Resolved by D102): origin TLS mode - no origin TLS listener; the public edge is the container-only Cloudflare Tunnel.
INFRA-08 (2026-11-12, Resolved by D102): Caddy log policy - no host Caddy; cloudflared logs at info with no request bodies.
INFRA-09 (pending, Pending owner): backup target/key holder (30-day).
INFRA-10 (pending, Pending owner): uptime monitor.
INFRA-11 (pending, Pending owner): deploy method (manual by owner default).
INFRA-12 (pending, Pending owner): secret rotation (6-month).
INFRA-13 (2026-10-02, Accepted): Hono 4.13.12 MIT via JSR.
INFRA-14 (2026-10-02, Accepted): postgres.js 3.4.9 Unlicense, TLS/pooling.
INFRA-15 (2026-10-02, Accepted): schema lib Valibot 1.5.0 (T08).
INFRA-16 (2026-10-02, Accepted): dbmate v2.36.0 verified.
INFRA-17 (2026-10-02, Accepted): Deno pin 2.9.7.
INFRA-18 (2026-11-12, Resolved by D102): systemd sandbox flags - no host systemd unit; container sandbox in D101/D102.
INFRA-19 (2026-10-02, Accepted): code licence GPLv2 (D23); data licence open.
INFRA-20 (2026-10-02, Accepted): applicationId com.spotnik.pontual (D22).
INFRA-21 (pending, Pending owner): Play account path/closed-test timing.
INFRA-22 (2026-10-02, Accepted): Flutter pin 3.47.6.
INFRA-23 (pending, Pending owner): controller identity/contact e-mail.
INFRA-24 (2026-10-02, Accepted): pilot lines 66, 62x2, 64, 60 (D25).

## 4. VERIFY list V01-V07

V01 (2026-10-02, Open): geolocator FGS screen-off/swipe-away/isMocked/notification action/POST_NOTIFICATIONS.
V02 (2026-10-02, Resolved): Deno/Hono/postgres/dbmate/CF/ping bytes verified (S2).
V03 (2026-10-02, Resolved): flutter_map cache/OSM policy (S3).
V04 (2026-10-02, Resolved): Flutter Web wasm/service worker/wake lock (S4).
V05 (pending, Open): Play FGS declaration/closed-test/Data safety wording.
V06 (pending, Open): ANPD/ECA Digital legal deadlines/wording.
V07 (pending, Open): host MemoryDenyWriteExecute/disk encryption/bbox vs routes.

## 5. Spikes S1-S4 (2026-10-02)

S1 (2026-10-02, Done): geolocator 14.1.1 FGS via AndroidSettings; swipe-away stops; isMocked; no notification action.
S2 (2026-10-02, Done): Deno 2.9.7; Hono 4.13.12; postgres.js 3.4.9; dbmate v2.36.0; CF Free WS.
S3 (2026-10-02, Done): flutter_map 8.3.2; 50 MB cache cap; OSM policy compliance.
S4 (2026-10-02, Done): --wasm dual; skwasm beats CanvasKit; no service worker; wake lock needs HTTPS.

## 6. Current status (2026-10-26)

- Alpha runs on owner VPS behind a container-only Cloudflare Tunnel; the API is in a container with no host port; static on GitHub Pages.
- Server/client/web tests green; security suite passes no_location_at_rest.
- Shared location stays in API process memory only; nothing persisted.
- Owner-blocked: first tagged release, Play closed test, phone field tests, legal review.
- Budgets: web first load ~0.95 MB gz; AAB ~52 MB; ping ~0.6 KB.
- Full history removed; see git log and CHANGELOG.md.

## 7. Owner answers round 1 D22-D28 (Accepted 2026-10-02)

D22 (2026-10-02, Accepted): product name Pontual; applicationId com.spotnik.pontual.
D23 (2026-10-02, Accepted): code licence GPLv2; data licence open.
D24 (2026-10-02, Accepted): VPS baseline Oracle Sao Paulo.
D25 (2026-10-02, Accepted): pilot lines 66, 62x2, 64, 60.
D26 (2026-10-02, Accepted): web sharing in alpha scope.
D27 (2026-10-02, Accepted): deferred controller identity, lawyer/DPO, Play account, manual deploy.
D28 (2026-10-02, Accepted): D20 roadmap confirmed de-identified aggregates only.

## 8. UI decisions D-U01-D-U31

D-U01 (2026-10-14, Accepted, superseded by D-U17): UI_SPEC truncated; reconstructed sections 14-18.
D-U02 (2026-10-14, Accepted, superseded by D-U09): no NEW_UI cutover flag; old UI removed.
D-U03 (2026-10-14, Accepted): variable Manrope subset (51,712-byte TTF) not five static weights.
D-U04 (2026-10-14, Accepted): colour tokens adjusted for WCAG 2.2 AA.
D-U05 (2026-10-14, Accepted): StaticLine gained optional terminals/area_tags/is_active.
D-U06 (2026-10-14, Accepted): web size measured from build/web; Android uses --analyze-size.
D-U07 (2026-10-14, Accepted): no per-screen parity flag; /line/:key?tab=horarios is timetable URL.
D-U08 (2026-10-14, Accepted): house style (CertaintyStyle, dashed predicted pill, BusIconPainter).
D-U09 (2026-10-14, Accepted): cutover done; old UI removed; shared copy moved to UiStrings.
D-U10 (2026-10-14, Accepted): dock and trip attach fixes (LiveDockHost, deferred attach).
D-U11 (2026-10-14, Accepted): three pre-existing trip test failures were test bugs.
D-U12 (2026-10-14, Accepted): stack-switch rewrite reverted; Flutter restored per owner order.
D-U13 (2026-10-14, Accepted): new consent sheet discloses; existing flow records once.
D-U14 (2026-10-14, Accepted): legacy share flow suppresses sheets for new UI.
D-U15 (2026-10-14, Accepted): no second dispose on suppressed denial path.
D-U16 (2026-10-14, Accepted): R8 dontwarn for Play Core; AAB 52.3 MB baseline.
D-U17 (2026-10-11, Accepted): UI_SPEC sections 14-18 arrived; D-U01 retired.
D-U18 (2026-10-11, Accepted): brand source, perf baseline, alpha dimming by colour.
D-U19 (2026-10-11, Accepted): UI_SPEC compliance build (U25, U26, router, copy, home, perf, a11y).
D-U20 (2026-10-11, Accepted): map deferred import stays eager, documented.
D-U21 (2026-10-11, Accepted): full verification green; deploy owner-blocked.
D-U22 (2026-10-11, Accepted): device perf method and SDK test dependency.
D-U23 (2026-10-11, Accepted): owner-supplied app icon applied (launcher + PWA).
D-U24 (2026-10-11, Accepted): Android web banner downloads release APK.
D-U25 (2026-10-11, Accepted): home/sheet/dock/map fix sweep (10 items).
D-U26 (2026-10-11, Accepted): owner UI issue sweep (8 items) + home-screen brief deviations.
D-U27 (2026-10-12, Accepted): single consent sheet in new share flow.
D-U27-followup (2026-10-12, Accepted): startShare used dying context/ref; fixed.
D-U28 (2026-10-12, Accepted): recenter targets viewer at neighbourhood zoom.
D-U29 (2026-10-12, Accepted): map tile failure recovery and deterministic enter fit.
D-U30 (2026-10-12, Accepted): test suite slimmed 46 files to 28.
D-U31 (2026-10-12, Accepted): two map locate buttons (viewer dot, closest bus).

## 9. Later decisions D29-D84

D29 (2026-10-10, Accepted): rate-limit strikes no longer end trips; fast streams sampled ~4 s.
<a id="D30"></a>D30 (2026-10-11, Accepted): anonymous momentum for ETA/prediction; amends D02 narrowly.
D30-followup (2026-10-11, Accepted): PLAN deltas shipped (RF20/RF22 partial).
D31 (2026-10-12, Accepted, pending owner review): lines-screen brief deviations.
D32 (2026-10-12, Accepted, pending owner review): line-detail brief deviations.
D40 (2026-10-12, Accepted, renderer Proposed): offline vector city map pipeline (Protomaps pmtiles).
D41 (2026-10-13, Accepted): docs/asset locations outside AGENTS.md 14.
D42 (2026-10-13, Accepted): deep-audit deferred items with rationale.
D43 (2026-10-13, Accepted): optimization sweep; three server wins landed.
D44 (2026-10-13, Accepted): ten optimization passes landed green.
D45 (2026-10-13, Accepted): ping cadence toward 5 s map updates.
D45-verify (2026-10-13, Accepted): 5 s cadence proven on live smoke server.
D46 (2026-10-13, Accepted): stops layer promoted to alpha, OSM seed.
D47 (2026-10-13, Accepted): stale-pump poisoning fixed; revive-once.
D48 (2026-10-13, Accepted): share lifecycle races and notify guard fixed.
D49 (2026-10-13, Accepted): stops resurvey 8 to 12 OSM nodes.
D50 (2026-10-13, Accepted): prediction horizon starts at staleness onset.
D51 (2026-10-13, Accepted): predicted arrivals exempt from staleness flip.
D52 (2026-10-13, Proposed): per-stop ETA hunt list.
D53 (2026-10-13, Accepted): progress sheet popped on wrong navigator fixed.
D54 (2026-10-13, Accepted client half, Proposed server half): consent revoke half-life.
D55 (2026-10-13, Accepted): live dots survive a failed poll.
D56 (2026-10-13, Accepted): cancel racing create POST fixed.
D57 (2026-10-14, Accepted): ping refresh zone-escape and refresh loop fixed.
D58 (2026-10-14, Accepted): CI and deploy repair.
D59 (2026-10-16, Accepted): background survival plus 5 s map latency.
D60 (2026-10-16, Accepted): cold start removed; first vehicle on first moving ping.
D61 (2026-10-16, Accepted): battery exemption requested from offline card.
D62 (2026-10-16, Accepted): test-only force-ping button.
D63 (2026-10-16, Accepted): follower stream uses balanced accuracy.
D64 (2026-10-16, Accepted): degraded downgrade hold keeps GPS on.
D65 (2026-10-16, Accepted): trip start anchors on first good fix.
D66 (2026-10-16, Accepted): no heading published at standstill.
D67 (2026-10-16, Accepted): approximate-only grants fail fast with guidance.
D68 (2026-10-16, Accepted): native GNSS quality channel, plumbing only.
D69 (2026-10-16, Accepted): GNSS quality wired into trip screen.
D70 (2026-10-16, Accepted): GPS acceptance protocol (docs only).
D71 (2026-10-16, Accepted): mid-trip approximate downgrade detected, sends held.
D72 (2026-10-19, Accepted): GNSS used-in-fix compat after stub removal.
D72 (2026-10-22, Accepted): waiting phase uses high accuracy to engage GPS.
D73 (2026-10-19, Accepted): last known bus position keeps its ping age.
D74 (2026-10-19, Accepted): web gap recovery stays foreground-only.
D75 (2026-10-20, Accepted): static deploy dry run repaired.
D76 (2026-10-20, Accepted): gitleaks allowlist for UI storage keys.
<a id="D77"></a><a id="D77-2026-10-20"></a>D77 (2026-10-20, Accepted): trip minimize returns to previous screen.
D78 (2026-10-20, Accepted): trip sharing screen shows measured metrics.
D79 (2026-10-20, Accepted): satellites replace battery in trip metrics.
D80 (2026-10-20, Accepted): second owner-supplied app icon applied.
D81 (2026-10-20, Accepted): permanent Android download link in web settings.
<a id="D82"></a>D82 (2026-10-20, Accepted, target model superseded by D83): passenger reports.
<a id="D83"></a>D83 (2026-10-20, Accepted): reports use coarse location area not stop picker.
D84 (2026-10-22, Accepted): live dots on demand, one trip clock, tighter HTTP timeouts.
D85 (2026-10-27, Accepted): Protomaps source pin updated to available build 20261026 after 20261019 returned 404; extracted and verified the city PMTiles at 41.6 MB.
D86 (2026-10-31, Accepted): GPS wait keeps `stream.first` loop per T34; cancel checked before gps-timeout so Cancelar reports declined, not noGps.
D87 (2026-10-31, Accepted): place search pre-normalizes gazetteer, single route scan per pair, code map lookup, 180 ms debounce; radii 500/300 unchanged.
D88 (2026-10-31, Accepted): line map decodes route once per input via memoized provider; vehicle tick only re-sorts markers.
D89 (2026-10-31, Accepted): remote-config check timestamp written only on successful fetch; bundled flags parsed once per instance.
D90 (2026-11-01, Accepted): foreground-service teardown serialized, startup handshake, single-trip guard. Root cause of silent trips with no notification on first start and on rapid restarts: native geolocator teardown is async and process-wide, and every stop was fire-and-forget, so a new subscription could race the previous disable; stacked /trip routes plus TripHost.attach dispose amplified it. Fix: process-wide teardown gate in LocationService (stop registers bounded 2 s cancel, start awaits quiescent up to 3 s), non-blocking stop that never stalls test zones, startup handshake that fails visibly as StartFailure.service when no native subscription exists after the create POST, single-trip guard that reopens the live trip instead of starting a second one. No new dependencies, no wake lock, no background location, cadence and budgets unchanged.
D91 (2026-11-01, Accepted): permanent anti-regression for background sharing. Startup handshake extended into a mid-trip subscription invariant (every supervision round ends visibly with detail service when the native subscription or fix broadcast is gone, never silent); process-wide TripController._active blocks any second concurrent start with busy even if a future caller bypasses the UI guard; dock never stacks a second /trip on the live one; new endService end-card copy; new architecture test fails on any direct getPositionStream outside LocationService; teardown gate plus active-trip state are reset per test so suites cannot poison each other.
D92 (2026-11-03, Accepted): Android release build restored and tuned for the 4-core/16 GiB dev machine. `permission_handler` is re-pinned to ^12.0.0 (12.0.3 / android 13.0.1) after the 2026-10-30 blanket dependency update re-selected 13.0.2 / android 14.1.1, which fails `checkReleaseAarMetadata` because it requires compileSdk 37 while Flutter 3.47 and AGP 9.1 pin 36; this restores the 2026-10-10 decision. Gradle daemon heap drops from 8 GiB heap/4 GiB metaspace to 4 GiB/1 GiB with ParallelGC, local build cache and parallel execution; the configuration cache stays off because Flutter 3.47 `compileFlutterBuild*` tasks call `Task.project` at execution. Android builds are arm64 only (`--target-platform android-arm64` plus `ndk.abiFilters`), and release uses `--dart-define-from-file=env/phone.json --obfuscate --split-debug-info`. Iterate with debug `flutter run`; release AOT plus R8 is CPU-bound. `--no-pub` is not used after `flutter pub get`, because pub get writes a debug-mode plugin registrant that includes `integration_test` and breaks release Java compilation.
D93 (2026-11-03, Accepted): stall watchdog stops churning the foreground service. Root cause of location usage dropping and returning every ~30 s: the watchdog measured silence since the last accepted fix with a fixed 30 s window, but follower (at the time), offline saver, and paused sampled at 45 s and the filter can drop every fix in a coarse patch. Both cases looked like a frozen stream, so every supervision round cancelled and recreated the native position stream, which stops and restarts the Android foreground service. Fix: track the last position event (accepted or filtered) and scale the window to one sampling interval plus the 30 s stall window (30 s for 5 s and 15 s modes, 75 s for 45 s modes). Genuine frozen streams still recreate, at most once per window. No dependency, permission, cadence, or budget change.
D94 (2026-11-03, Accepted, owner directive): every role reports at a 5 s cadence. `waiting`, `leaderMoving`, `leaderStill`, and `follower` now request location every 5 s and instruct `n=5`; `offlineSaver` and `paused` keep 45 s because they carry no uploads and must stay cheap. The server's follower jitter is pinned to 0 in `main.ts` so the instructed follower interval is exactly 5 s instead of 5 s +/- 10 s. The next send slot is measured from the last send, not the response, so a slow round trip cannot stretch the 5 s cadence into 10 s (PLAN 8.7). Consequences recorded: follower data and battery budgets rise to leader levels (PLAN RNF02/RNF03 and section 10.1), promotion latency (KL1) drops to about one ping, and the D64 degraded hold now delays the high-to-balanced accuracy change rather than a cadence downgrade. The D93 stall window keeps 30 s for all role modes and 75 s for the two remaining 45 s power modes. No permission, dependency, or foreground-service change.
D95 (2026-11-04, Accepted, owner directive): RN battery exemption parity with D61 and the Flutter copy. Lack of data (sharing health issue offline: 3 failed sends or 120 s without success) shows the persuasive Manter ativo card on the RN trip screen, Android only. The card names the cause (battery optimization paused sharing) and fires the direct system exemption pop-up only from its tap via expo-intent-launcher REQUEST_IGNORE_BATTERY_OPTIMIZATIONS with package data, checked via expo-battery isBatteryOptimizationEnabledAsync. Never auto-fires, never blocks sharing, never throws. Deps added via bunx expo install: expo-battery, expo-intent-launcher, expo-application. Manifest permission REQUEST_IGNORE_BATTERY_OPTIMIZATIONS added to rn/app.json. Covers the AGENTS.md 15 hard-limit ADR requirement alongside D61 and PLAN 8.6.

D96 (2026-11-10, Accepted, owner directive): personal arrival at the rider's stop on the line screen. The rider opts in with one tap and a one-shot foreground fix (native precise-only, 120 m gate; web 200 m), snaps locally to the nearest learned stop within 300 m, and the app calls the existing GET /v1/lines/:id/eta?stop=<id>. Only the line id and stop id are sent; coordinates are never logged, persisted or sent. The ETA refreshes at most every 10 s on the existing 5 s vehicle tick, pauses off-route and in data saver, and adds no timer. Only live vehicles get an ETA; heading filters opposite-direction buses; passed buses are labeled and never shown as "Chegando"; the server confidence and sample count are shown. No new dependency, no server or schema change. This records the deviation from UI_SPEC 2.1 "no new network calls from the UI layer" and the viewer-location change in UI_SPEC 7.5: the call is one existing read endpoint on demand, not a UI poll loop, and the server caches it for 10 s. viewerLocationProvider now derives from the explicit fix and no longer auto-prompts on web.
D97 (2026-11-10, Accepted, owner directive): learning_min_route_trips default 20 to 5. Single-rider pilot lines publish a learned polyline after 5 completed trips in one direction instead of 20. Runtime override via app_config key learning_min_route_trips still wins. Tradeoff accepted: smaller aggregate weakens k-anonymity for routes; a 5-trip route can reflect one rider's commute. Mitigations kept: trimEndsS 120 s, no device/trip ids in aggregates, no raw tracks stored, stops/ETA still gated by minStopPasses/kMin/distinct-days. Revisit before public release.
D98 (2026-11-10, Accepted, owner directive): partial-trip learning with an absolute corridor. The per-trip progress binning stretched a partial trip over the whole route and corrupted geometry, so learning now accumulates fixes in a 50 m metric grid per (line, direction), builds an ordered chain from the observed directed cell graph, and assigns stop ordinals by projection. A device with at least 5 started trips unlocks aggregates; the counter is devices.learning_trips, incremented once per non-resume trip start after consent and opt-out checks, retained with the device row (30 days). LEARNING_PRIVACY_MODE selects the gate: "all" (default, learning phase) publishes stops and dwell/segment stats from a single pass; "route_stops" keeps minStopPasses, distinct-days and kMin. Terminus dwell suppression stays on in both modes. Tradeoff: kMin counted samples, not distinct people, so single-rider aggregates were already possible; the new gate makes that explicit for the learning phase. Coordinator review before public release.
D99 (2026-11-11, Accepted): location lifecycle and diagnostics fidelity from first-party field bundles (LOGS-REPORT T1-T6). Root causes proven by 30 bundles/60 records: Android 14+ rejects `startForeground` when a backgrounded supervision round cancels and recreates the geolocator stream (14/30 bundles), a dead stream still reported an attached subscription so trips showed sharing with no fixes (3 fully silent bundles), recovery then cancelled a stream that never started ("No active stream to cancel", 12 records), and the stall watchdog recreated streams every 30-60 s in the background. Fix: native stream creation and recreation are banned while the app is not resumed; background stall/mode changes are deferred and exactly one recovery runs on the next resume; foreground dead/silent restarts are budgeted to one per stall window of the requested mode; two recoveries without any position event mark the stream dead; coarse-but-alive fixes never restart; unawaited cancels carry error handlers, concurrent relistens are serialized, and a relisten parked on a slow cancel cannot subscribe after stop. `hasActiveSubscription` requires an attached, non-dead stream; the startup handshake requires a produced fix; the mid-trip invariant ends the trip visibly as automatic/service in the foreground, defers while backgrounded, and ends on a failed resume retry, so sharing is never silently dead. No background location permission, wake lock, telemetry, local database, or new dependency. Diagnostics: real build from APP_VERSION with CI deriving it from pubspec (blank falls back to "unknown"), real platform and OS (conditional import, no dart:io on web), a random per-bundle UUID v4 stable across retries and never a device identifier, crash payload with exception, FlutterError context, and the first 1000 stack characters capped at the server's 4000, serialized persisted writes, one cold-start upload after an 8 s debounce plus one on resume, and success clears only the uploaded record prefix and an unchanged crash payload. The diagnostics schema accepts an optional `id` (max 64) additively, with no migration. Trip screen content and header scroll while Desci stays pinned in the bottom bar, and the end card scrolls, both verified at 320x568 with 2x text. Verification: 528 app tests (location unit), 523 (diagnostics), 516 (layout), all with 1 skipped; server fmt/lint/check plus 3 DB-free schema tests. Not verified: the full server suite (no PostgreSQL on the host), physical Android background/resume behavior, and the exact 444 px field overflow (the bundle had no widget context; 32 px and 80 px variants were reproduced and fixed).

## 10. ADRs

ADR (2026-10-26, Accepted): first-party diagnostics (opt-out, 14-day retention).
ADR (2026-10-26, Accepted): enable learning subsystem by default; learned route persistence.

ADR (2026-11-01, Accepted): migrate RN client package manager/runtime from npm to Bun. Trusted dependencies: @parcel/watcher, unrs-resolver. Node.js retained for expo prebuild/templates. EAS auto-detects Bun via bun.lock; no eas.json version pin (default image version). No app/runtime behavior change.

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

D100 (2026-11-11, Accepted): Protomaps source pin updated from 20261026 to 20261110 after 20261026 returned 404 (builds expire ~1 week); verified HEAD 200 and pmtiles show header read.

D101 (2026-11-12, Accepted, owner directive): container deployment. `server/deploy/Dockerfile` is a multi-stage build on the pinned `denoland/deno:2.9.8` image. The build stage caches `server/deno.lock` with `--frozen-lockfile` and builds the static data bundle from `data/` and `tools/`; the runtime stage copies only the server, the data bundle and the read-only module cache. No secret, `.env`, app, RN or docs tree enters the image. The runtime user is `deno`, the root filesystem is read-only with a 16 MiB noexec `/tmp`, all capabilities are dropped, `no-new-privileges` is set, and PIDs, memory, CPU and log size are bounded. `start:container` runs with `--cached-only` and denies write, run, ffi and sys; network access is limited to `0.0.0.0:8080`, the loopback metrics listener, `db:5432` and `host.docker.internal:5432`. Compose publishes only `127.0.0.1:8080` for Caddy or the Cloudflare tunnel; metrics and PostgreSQL are not published. `HOST` is `0.0.0.0` only inside the container. Env files remain the only secret source (`server/.env` or `PONTUAL_ENV_FILE`, plus `server/.env.db` or `PONTUAL_DB_ENV_FILE` for database-only secrets). The systemd unit stays as the non-container option. The bundled compose file also runs PostgreSQL `16.15` (Debian, for openssl) with a named volume and no published port. A first-start init script generates a self-signed certificate in the volume, enables `ssl=on` with `TLSv1.2` as the minimum, switches TCP rules to `hostssl` so cleartext connections are rejected, and creates the least-privilege `pontual_app` role with a password from the environment. `pontual_migrator` owns the schema and is used only by a one-shot `amacneil/dbmate:2.36.0` service that runs with `--no-dump-schema` before the API starts; `pontual_app` remains the only credential in the API `DATABASE_URL` (`sslmode=require`). Database credentials live in a separate env file so the API container does not receive the migrator password. No schema, endpoint or app behavior changes. Verified locally: image builds, Compose starts the database, runs migrations to completion, starts the API read-only against the container database, `/v1/health` answers, the Docker healthcheck reports healthy, a device create/delete round trip reaches the database as `pontual_app`, TLS is used on TCP, cleartext TCP is rejected, `pontual_app` cannot create tables, Compose config validates, `deno fmt --check`, `deno lint` and `deno check` pass, and the full server suite passes (130 tests). Not verified: production Docker, Caddy and Cloudflare routing, certificate rotation.

D102 (2026-11-12, Accepted, owner directive): container-only public edge. The
public edge is a Cloudflare Tunnel running inside the `pontual-api` Compose stack as
the `cloudflared` service. The stack has four services (`db`, `migrate`, `api`,
`cloudflared`) and three networks: `edge` (internal, `api` + `cloudflared`),
`data` (internal, `api` + `db` + `migrate`) and `egress` (non-internal,
`cloudflared` only). The API has no internet egress and no published port; the
database is not on the tunnel network. `cloudflared` uses image
`cloudflare/cloudflared:2026.11.0`, is distroless, runs as uid 65532, has a
read-only root filesystem, drops all capabilities, sets `no-new-privileges`, and
exposes no host ports. It reads a locally managed config file mounted at
`/etc/cloudflared/config.yml` (`PONTUAL_TUNNEL_CONFIG_FILE`, default
`server/secrets/cloudflared.yml`) plus the credentials JSON mounted at
`/run/secrets/cloudflared_credentials` (`PONTUAL_TUNNEL_CREDENTIALS_FILE`,
default `server/secrets/cloudflared_credentials.json`). The config
identifies the tunnel by UUID because no cert.pem is mounted. The live tunnel is
locally managed, so a token connector would ignore its local ingress; the
config carries the ingress rules. The tunnel is outbound-only; the public
hostname is declared in the config and its service target is `http://api:8080`.
`extra_hosts` keeps `host.docker.internal` available so the shared tunnel can
route `api-ephemeron.spotnik.space` to the host on 8091. No dashboard-managed
ingress is required. `TRUST_CLOUDFLARE=true` is safe because the API is
unpublished and only the tunnel shares the internal `edge` network with it.
There is no host Caddy and no `pontual.service` systemd unit; Docker
`restart: unless-stopped` and Docker enabled at boot handle restarts. Secrets
are `server/.env`, `server/.env.db` and `server/secrets/cloudflared_credentials.json`
locally, and `/etc/pontual/api.env`, `/etc/pontual/db.env`,
`/etc/pontual/cloudflared_credentials.json` on the VPS; the config is
non-secret and world-readable `0644`/`0444` or owner uid 65532 with owner-read, and credentials are never placed in compose, env
examples, git, logs or documentation. `deploy.sh deploy <tag>` builds
`pontual-api:<tag>`, runs
`docker compose up -d`, checks API health with
`docker compose exec -T api deno eval ...`, checks the tunnel with
`docker compose exec -T cloudflared cloudflared tunnel --metrics 127.0.0.1:2000 ready`,
records current and previous tags under `/opt/pontual` by default, and rolls
back on failure; `deploy.sh rollback` reactivates the previous tag;
`deploy.sh status` runs `docker compose ps`. Rollback is by image tag. Supersedes D101 on: the API no longer has a host-published port or the host.docker.internal allow-list, the systemd unit and host Caddy are removed, and the tunnel uses a locally managed config plus credentials.

No
production verification is claimed; the checks above are the documented
procedure.

D103 (2026-11-12, Accepted, owner directive): host-provided Compose override for a shared tunnel. `server/deploy/deploy.sh` automatically includes `/etc/pontual/compose.override.yaml` when present (`PONTUAL_COMPOSE_OVERRIDE` overrides the path). This host uses it to attach the cloudflared container to the Ephemeron Docker network so the shared `pontual` tunnel can serve `api-ephemeron.spotnik.space` without publishing a host port. The override is root-owned mode 0644, must not be group/world-writable, and stays outside the repo. A host service bound to loopback is not reachable through `host.docker.internal`; use the external-network override or a bridge-reachable address. This supersedes D102's `extra_hosts` note for that case.
D104 (2026-11-11, Accepted, owner directive): UX 2.0 answer-first pass across Início, Linha, Linhas, Busca and the shell; UI and copy only, with no new dependency, no new network call, and no change to consent, auth, ping cadence, location persistence or privacy behavior. Início leads with "Sua próxima saída", the earliest scheduled departure across favourites and shortcuts (a shortcut origin wins over a favourite for the same line, tomorrow is the fallback, and a live chip appears only when the line has live vehicles, never as a fabricated live arrival); the first-run line picker saves favourites; the empty live section becomes an actionable share card; the old dock coachmark is removed. Linha moves the hero above the tabs: a vertical NextBusCard (ETA first) when the personal arrival card is not ready, and the personal card as the hero when it is; the header shows the live count, the source of the hero, or the end-of-day state instead of repeating the live-empty sentence; the personal card adds a walking estimate (straight-line distance at 80 m per minute, minimum 1 minute) and a leave-now/leave-soon/still-time verdict, presented as an estimate; the location prompt is a compact card; the peek minimum rises from 220 to 270 dp so the header plus the hero ETA fit at 320x568. Shell: the idle global floating dock is removed, the active trip bar renders in normal layout above the navigation so it cannot cover content, Início and Linha carry the share entry points, the line screen keeps its contextual idle dock, and branch selection keeps its selectionClick haptic. Linhas and Busca share one LineStatusLine and one favourite action; Linhas gains a search icon and an honest live summary, and typed search rows show the same status and star as browse rows. Evidence: the targeted suites were reported green by the implementing branches (home, line/personal arrival, lines/search, shell) with analyze clean, including the 320x568 2x and 800x600 wide line tests; the full suite passed on 2026-11-11 with 591 tests and 1 skipped (`flutter test --concurrency=1`, `flutter analyze` clean on the integrated tree); the pass also fixed a double São Mateus wall-clock conversion in the line sheet and timetable tab.

D105 (2026-11-12, Accepted, owner directive): minimalist sharing screen. The `/trip` hero keeps the live state, headline, line identity, terminals and elapsed time; the trust line and separate last-send proof row were removed (their substance stays in consent and settings). The three-cell metrics card became one compact status line that opens a details sheet with the same measured values, and the header flag became a pinned full-width "Avisar problema" secondary action above the stop block. No new report kinds, no API or server change, and no change to TripController, ping cadence, location or privacy behavior. Evidence: full app suite 597 tests with 1 skipped, `flutter analyze` and `dart format` clean; targeted trip, layout and report tests green; share screen review PASS.
D106 (2026-11-12, Accepted): true 5 s sharing cadence. The client now schedules each ping from the last send start at the server interval with an injected one-shot timer, sends the latest fresh unsent fix, never sends sooner than the interval after the previous send start, and defers a fix queued during an in-flight request to the next slot. The live map rebuilds on a throttled repository change signal (at most one rebuild per second in normal mode) while the existing 5 s/30 s tick keeps age labels and data saver behavior; the socket remains the repository's. The server keeps the 4 s min-interval defense but returns an additive `rl` flag and increments an aggregate rate-limited counter so silent drops are visible. Rationale: fix-arrival gating produced 7-11 s gaps, the in-flight immediate resend produced 3-4 s bursts, and the 5 s-only UI tick coalesced updates. Cadence still depends on GPS fix availability and server RTT. Evidence: deterministic cadence tests with injected timers cover 5 s and 10 s gaps, early-fix deferral, in-flight deferral and end cancellation; full app suite and server ping/metrics tests green.
D107 (2026-11-12, Accepted, owner directive): line 66 learning diagnosis and safeguards without a schema change. Diagnosis: line 66 has no static route polyline, so the map draws only an active `learned_routes` row; publication needs 5 corridor-contributing trips in the same `(line, direction)` inside one API process; corridor counters are memory-only and reset on restart; the 2026-11-12 container deployment uses a new PostgreSQL volume with no dump/restore step, so a fresh database would drop learned routes, devices and tokens while the app keeps sharing. The app's "trips shared" counter is local kudos, not the server learning count. Changes: corrected `docs/data-learning.md`, added `docs/runbooks/learning-verification.md`, added a read-only deploy preflight that refuses a new or empty database volume unless `PONTUAL_ALLOW_EMPTY_DB=1` (deploy path only, never rollback), and added aggregate-only learning drop-reason counters. No schema, threshold, eligibility or publication change. Production verification remains: check the VPS volume/data counts and restore the old database if it was not imported.
D108 (2026-11-12, Accepted, owner directive): humanized pt-BR copy. The deck and bundled privacy/terms summaries were rewritten, inline widget copy moved into the deck, passenger-report vocabulary unified to "Avisar/Aviso", and AI-slop, marketing, exclamation and em-dash patterns removed. Privacy claims were tightened to what the app actually does (location only on user request, including personal-stop reads and reports), permission and sharing-failure titles were made truthful, and the Android notification, search label and vehicle screen-reader copy were corrected. The owner approved rewriting legal text; every disclosed fact was preserved and the summaries remain consistent with `docs/privacy`, but lawyer/DPO review is still required before release. Evidence: full app suite 597 tests with 1 skipped, `flutter analyze` and `dart format` clean, copy review PASS.

D109 (2026-11-12, Accepted, owner directive): learning aggregates v2. Every organic trip from a consenting, non-opted-out device contributes; confidence is a sample count, not a gate. Supersedes D97 and D98 and removes the 5-trip device gate (`devices.learning_trips`), `learning_min_route_trips`, `learning_min_trip_route_m`, `corridorMinCells`, `minRouteLengthM`, `minStopPasses`, `stopMinDistinctDays`, `kMin`, the `route_stops` mode and `LEARNING_PRIVACY_MODE`. Synthetic/test traffic has no marker in the API; the simulator is excluded operationally by running it only against a disposable database, and a dedicated marker needs a separate ADR. Migration 0006 adds DB-backed accumulators (`learning_route_cells`, `learning_route_edges`, `learning_route_state`, `learning_dwell_bins`, `learning_travel_bins`) on a fixed 50 m grid anchored at lat -18.72, lng -39.85 so cell keys survive restarts, and drops `learning_watermarks` and `devices.learning_trips`. A route publishes after the first contributing trip; a new geometry within 15 m median deviation updates the active row in place, otherwise the old version is retired and a new one inserted, with the 8192-character polyline cap and 2-point validity as the only remaining publication limits. Stops publish on the first dwell with a weighted centroid and `sample_passes`; dwell and travel histograms are cumulative, bucketed by the dwell start or the destination arrival in America/Sao_Paulo, never the trip start; `stop_dwell_stats` and `segment_stats` are recomputed from all retained bins with nearest-rank p50/p90 and served from one sample with the count attached. Normal trips trim 120 s per end; trips shorter than 240 s trim at most 10% per end and fall back to all fixes if fewer than 2 remain. Contributions run in an async per-trip queue and the periodic flush republishes stale routes as a crash-window safety net; a queued contribution lost on process death is not recoverable because no raw trip is stored. Retention follows the stop lifecycle: a stop with no pass for 90 days is deactivated and deleted after 180 days, cascading bins and stats; retired routes are deleted after 30 days; route cells and edges are kept while the line and direction exist. This replaces the earlier rolling 90-day stat delete, which could not remove cumulative bins and would have been undone by the next recompute. Privacy: no raw tracks, device ids, trip ids or client timestamps; `learned_stops` and `learning_route_cells` keep cross-trip aggregate centroids, the only location at rest, and the `no_location_at_rest` test allows exactly those columns. Accepted risk: one consenting trip can shape a route, stop or histogram, so lawyer/DPO review remains a release gate. Evidence: `deno fmt --check`, `deno lint` and `deno check src/main.ts` clean; targeted server tests 35 passed and 4 ignored across learning, corridor, eligibility, no-location, metrics, config and retention suites. The migration and histogram SQL were not run against PostgreSQL because `TEST_DATABASE_URL` is unset; they are type-checked and exercised through the fake SQL layer only. No production database or deploy action was taken.

D110 (2026-11-12, Accepted): synthetic-trip exclusion and closing the v2 database-test gap. `POST /v1/trip` now accepts an optional `synthetic` boolean, default false. The value is client-supplied and untrusted: it can only suppress that trip's contribution to learning, never grant access, change ownership, bypass quotas or alter live sharing. It is not persisted in any table or log. The learning consumer ignores a synthetic `tripStarted` event before creating working state. The simulator sends `synthetic: true` for its rider starts and abuse starts. The additive field does not break old clients. D109's database-test limitation is closed: a portable PostgreSQL 16.15 build initialized a local cluster, migrations 0001 through 0006 applied cleanly, the 0006 down migration rolled back and reapplied cleanly, and the full server suite passed with `TEST_DATABASE_URL` set (136 passed, 0 failed, 0 ignored). Targeted learning, schema, retention, no-location, metrics and config suites passed (37 passed, 4 ignored by their own test options). No production database, deploy or push action was taken. The client opt-out toggle and legal sign-off remain open.

D111 (2026-11-12, Accepted): one-way stop-contributing action in the privacy center. The existing `DELETE /v1/me/learning` endpoint is now reachable from the app as a confirmed "Parar de contribuir com dados agregados" row. It is deliberately one-way: there is no re-enable endpoint or toggle, the confirmation body says so, and the policy discloses it. Offline reports that nothing changed and leaves local state untouched; a missing token is a no-op success because there is no server record to stop. Past aggregates are not rewritten because they cannot be attributed to a device. Added `BusApi.stopLearning`, `PrivacyActions.stopLearning`, the privacy row and dialog, pt-BR strings, and the aggregate line in the collection summary. No new dependency, permission, network call on screen load, or local persistence. This closes D110's client opt-out gap. Evidence: `dart format` clean, `flutter analyze` clean, targeted privacy/settings tests 27 passed, full app suite 600 passed with 1 skipped. Legal review of the new copy remains pending.

D112 (2026-11-12, Accepted, owner directive): PostgreSQL 18.6. The bundled Compose database moves from `postgres:16.15` to `postgres:18.6`, using the 18 volume layout (`pontual-db:/var/lib/postgresql`, `PGDATA=/var/lib/postgresql/18/docker`). CI and the README move to `postgres:18.6-alpine` / PostgreSQL 18. The deploy preflight now detects the old PostgreSQL 16 `PG_VERSION` at the volume root and prints the migration hint when the 18 cluster is empty or unqueryable; a successfully restored 18 cluster still deploys. This prevents an unmigrated 16 volume from silently becoming an empty 18 cluster without blocking the post-restore deploy. A 16 to 18 data directory is not compatible: the next deploy requires the dump/restore procedure in `docs/runbooks/docker.md` (or `pg_upgrade`), and no in-place image swap is supported. This supersedes D101's `postgres:16.15` pin and repeats D110's test evidence on 18.6. Verification: PostgreSQL 18.6 portable binaries, migrations 0001 to 0006 applied, the 0006 down migration rolled back and reapplied cleanly, and the full server suite passed with `TEST_DATABASE_URL` (136 passed, 0 failed, 0 ignored). Not verified: Docker Compose runtime with the 18 image (no Docker daemon here) and the production VPS migration. The client remains on the same API contract.
