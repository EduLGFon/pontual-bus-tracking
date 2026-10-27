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

## 10. ADRs

ADR (2026-10-26, Accepted): first-party diagnostics (opt-out, 14-day retention).
ADR (2026-10-26, Accepted): enable learning subsystem by default; learned route persistence.

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
