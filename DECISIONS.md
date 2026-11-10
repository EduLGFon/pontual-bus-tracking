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
| D19 | Cloudflare proxy in front; Caddy at origin; Deno binds localhost |
| D20 | future analytics only on de-identified aggregates |
| D21 | server libs: Hono, postgres.js, one schema lib, dbmate |

## 3. Infra decisions INFRA-01..24

INFRA-01 (2026-10-02, Accepted): VPS baseline Oracle SP 1 oCPU/6GB/50GB PG localhost (D24).
INFRA-02 (pending, Pending owner): staging instance optional.
INFRA-03 (pending, Pending owner): swap/disk encryption.
INFRA-04 (pending, Pending owner): SSH/admin access.
INFRA-05 (2026-10-20, Accepted): app pontual.spotnik.space, API api-pontual.spotnik.space CF Tunnel.
INFRA-06 (pending, Pending owner): CF plan/features (WS timeout, edge cache, IP ranges, AOP).
INFRA-07 (pending, Pending owner): origin TLS mode.
INFRA-08 (pending, Pending owner): Caddy log policy.
INFRA-09 (pending, Pending owner): backup target/key holder (30-day).
INFRA-10 (pending, Pending owner): uptime monitor.
INFRA-11 (pending, Pending owner): deploy method (manual by owner default).
INFRA-12 (pending, Pending owner): secret rotation (6-month).
INFRA-13 (2026-10-02, Accepted): Hono 4.13.12 MIT via JSR.
INFRA-14 (2026-10-02, Accepted): postgres.js 3.4.9 Unlicense, TLS/pooling.
INFRA-15 (2026-10-02, Accepted): schema lib Valibot 1.5.0 (T08).
INFRA-16 (2026-10-02, Accepted): dbmate v2.36.0 verified.
INFRA-17 (2026-10-02, Accepted): Deno pin 2.9.7.
INFRA-18 (pending, Pending owner): systemd sandbox flags.
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

- Alpha runs on owner VPS behind Cloudflare Tunnel; API on localhost; static on GitHub Pages.
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

## 10. ADRs

ADR (2026-10-26, Accepted): first-party diagnostics (opt-out, 14-day retention).
ADR (2026-10-26, Accepted): enable learning subsystem by default; learned route persistence.

ADR (2026-11-01, Accepted): migrate RN client package manager/runtime from npm to Bun. Trusted dependencies: @parcel/watcher, unrs-resolver. Node.js retained for expo prebuild/templates. EAS auto-detects Bun via bun.lock; no eas.json version pin (default image version). No app/runtime behavior change.

## 11. Pending / owner-blocked

- Lawyer/DPO; operator outreach owner/timing; backup target/key holder (INFRA-09).
- Uptime monitor (INFRA-10); controller identity/contact e-mail (INFRA-23).
- Play account path/closed-test timing (INFRA-21); staging instance (INFRA-02).
- Swap/disk encryption (INFRA-03); SSH/admin access (INFRA-04).
- CF plan/features (INFRA-06); origin TLS mode (INFRA-07); Caddy log policy (INFRA-08).
- Secret rotation (INFRA-12); deploy method (INFRA-11, manual by owner).
- VPS execution of T04/T05 hardening and first deploy; upload keystore secrets.
- First tagged release + install launch; merged manifest result; Android SDK on capable machine.
- Phone field tests (T47); browser run of banner/wake lock (T37).
- Pages custom domain cert issuance; API_ORIGIN/STATIC_ORIGIN repo vars and deploy-static run.
- Pending proposals: D52; D54 server half; D40 renderer; INFRA-19 data licence; INFRA-21.

## 12. Spikes results

See section 5. All four spikes done 2026-10-02; device VERIFY items remain open.

## 13. Notes

- Append-only. Newest entries go at the end of each section. See AGENTS.md 14.
- Full history removed; see git log and CHANGELOG.md.
