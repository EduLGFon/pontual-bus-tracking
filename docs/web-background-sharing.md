# Web/PWA background location sharing: feasibility and test plan

Status: option B (foreground-only gap recovery) approved and implemented 2026-10-19 (D74). Field protocol (section 7) still pending; platform behavior unverified outside unit/widget tests. No background coverage claimed.

Related: PLAN.md 8.12; D11 (no background location on Android); D-U24 (Android web viewer-only); D59 (background survival); D63-D69; docs/field-tests/gps-acceptance.md.

## 0. Short answer

Pure web/PWA background location is unavailable. The blocker is the Geolocation API itself, not a missing permission, manifest flag, service worker trick, or installed-app mode. The spec only delivers position updates to a fully active, visible document; browsers suspend hidden pages; installing the PWA adds no native privileges. PiP and notifications do not change this on mobile. Desktop Document PiP is an exception (section 5.12).

Useful pure-web options: (1) foreground-only sharing with screen on and trip screen visible (current design, only reliable web mode); (2) prompt resume and gap recovery on visible (shortens post-return gap, no background coverage); (3) native Android app for screen-off sharing (existing, foreground service type `location`, no `ACCESS_BACKGROUND_LOCATION`).

TWA, Capacitor shell, or WebView wrapper can host a native foreground service, but that is a native app strategy, not a web workaround, and duplicates the existing Android app. iOS screen-off sharing is a separate native product decision.

Recommendation: keep the foreground-only contract, add gap recovery (done), do not build a wrapper, keep the native Android app as the screen-off path.

## 1. What "background" means

| State | Trigger | What the web app can rely on |
| --- | --- | --- |
| Visible, screen on | Trip screen open, unlocked | Location updates and timers run; wake lock can be held |
| Visible, screen off | Power button, timeout, lock | No reliable updates; wake lock released or not applicable |
| Hidden tab | Another tab, minimized browser | Visibility `hidden`; updates stop |
| App switched | Home, another app, switcher | Page hidden; browser/OS may freeze |
| Frozen | Browser resource policy | Timers, fetch callbacks, most tasks suspended |
| Discarded | Memory pressure | No JS runs; page may reload later |
| Terminated | Tab closed, browser/OS kill | Nothing runs; in-memory trip state lost |
| Native foreground service | Android app only | Continues with persistent notification |

Current web policy pauses sends after 60 s hidden (product policy, not platform guarantee; Chrome stops on hide).

## 2. Platform evidence (sources accessed 2026-10-19)

2.1 Spec: Geolocation is `[Exposed=Window]`, not workers/service workers. `watchPosition()` waits if document not fully active or visibility != `visible`; note "Position updates are exclusively for fully-active visible documents." `getCurrentPosition()` waits for visibility; `timeout` does not cover wait time. Consequences: hidden page gets no fixes; keeping a subscription does not override the gate; service worker cannot acquire position. Source: W3C Geolocation (sections 5, 6.3, 6.5, 7.2).

2.2 Chrome: geolocation runs only in the foreground tab and is "paused as soon as the page is in the background"; no background geolocation. One-time grant can expire after >=5 min background. Source: Chrome one-time permissions.

2.3 Page Lifecycle: hidden -> frozen -> discarded -> terminated. Hidden page may never get `freeze`/`resume`/`pagehide`; Chrome treats hidden as last reliable point to persist state. Heartbeat timer best effort; page can die without notice. Source: Page Lifecycle API.

2.4 Screen Wake Lock: only visible documents can acquire; auto-released on hidden; not applicable after manual screen off; advisory (low battery, power saver). Useful for foreground mode only. Source: W3C Screen Wake Lock.

2.5 Workers/service workers: no `navigator.geolocation`. Background Sync retries data; Periodic Background Sync is installed-app-only, engagement-gated, browser-scheduled, not continuous; push wakes a worker but it still has no location. All data-only. Sources: MDN Service Worker; Chrome Periodic Background Sync.

2.6 PWA install: WebAPK/WebKit rendering; no native entitlement; no manifest field grants background geolocation. TWA host has no direct access to page state/cookies/storage; postMessage bridge only. Sources: Chrome TWA overview/postMessage.

2.7 iOS: background location is native Core Location capability (location background mode, continuous updates, indicator); not available to web content. Behavior version-dependent; treat Safari tab and home-screen app as separate targets. Sources: Apple Developer.

2.8 Android foreground services: Android 14+ requires foreground service type; `location` type needs `FOREGROUND_SERVICE_LOCATION`, runtime location permission, visible notification; can start while visible and continue in background; starting from background needs `ACCESS_BACKGROUND_LOCATION` (not requested, D11). Existing app does this. Source: Android foreground service types.

## 3. Capability matrix

| Mechanism | Pure web? | Location while hidden/screen off? | Why |
| --- | --- | --- | --- |
| Visible page + `watchPosition` | Yes | No | Spec waits for visible document |
| Visible page + Screen Wake Lock | Yes | No | Lock only while visible; screen-off releases it |
| Hidden tab with timers | Yes | No | Browser pauses/freezes page |
| Dedicated/shared worker | Yes | No | Geolocation is `Window`-only |
| Service worker | Yes | No | No DOM/Geolocation API |
| Background Sync | Yes | No | Retries data, no location |
| Periodic Background Sync | Yes | No | Browser-scheduled refresh; no location |
| Push notification | Yes | No | Wakes worker, but no location |
| Web notification as keepalive | Yes | No | Display/click target only |
| Android video PiP | Yes | No | Video plays, page hidden, geolocation paused |
| Document PiP (desktop Chromium) | Yes, desktop only | Only while PiP window visible | PiP document can request geolocation; no Android/iOS/Safari |
| Installed PWA/WebAPK | Yes | No | Same engine, no native entitlement |
| TWA + native foreground service | No | Yes, while service runs | Host collects/sends location natively |
| Capacitor/WebView + native plugin | No | Yes, with native work | Native shell, not a PWA |
| Native Android app | No | Yes | Foreground service type `location` |
| Native iOS app | No | Yes, with Always auth | Core Location background updates |

## 4. Current implementation (foreground-only + gap recovery)

- `TripScreen` requests wake lock while alive, returns on `resumed`, re-requests on every visible transition (`app/lib/ui/features/trip/trip_screen.dart`).
- `WebVisibilityTracker` pauses after 60 s hidden; keeps hidden-since timestamp even if 5 s check timer frozen; reports real gap to controller on resume (`app/lib/platform/web/visibility.dart`).
- `TripController.setWebHidden(true)` drops fixes while hidden. On visible, `recoverWebSharing` clears pause and asks `LocationService` for one high-accuracy one-shot; service restarts stream if dead/silent; one-shot emitted through normal filter (`trip_controller.dart`, `location_service.dart`).
- Accepted fix uses `_nextPingAtMs` pacing; recovery does not bypass server interval. `TripFix.acceptedAtMs` lets controller drop a fix queued across the hide that would otherwise be published stale.
- If hidden >= 10 min server-timeout fallback, next `gone` shown as `TripEndKind.automatic` detail `timeout`; not revived with stale fix. Short gaps keep one-time revive path for server restart/lost record.
- `WebTripBanner` always visible during web trip: "Mantenha esta tela aberta e o celular desbloqueado."
- Server ends trip after 600 s without ping (`trip_timeout_s = 600`); viewer hides vehicle after 120 s without fix.

Limits: no background acquisition; pause flag not guaranteed if frozen (tracker reports gap on resume); wake-lock reacquisition unverified on devices; timeout fallback is prediction, server authoritative; client never ends trip on its own.

Unit/widget tests cover visible transition, stream restart, one-shot filter path, one paced ping, stale queued fix rejection, wake-lock re-request, explicit timeout end. Device protocol (section 7) still required for real latency/lifecycle.

## 5. Candidate approaches

| ID | Approach | Coverage while hidden | Verdict |
| --- | --- | --- | --- |
| A | Foreground sharing with wake lock | None | Keep |
| B | Immediate gap recovery on visible | None (shortens post-return gap) | Implemented |
| C | Silent audio/video keepalive | None/accidental | Reject |
| D | Service worker, Background Sync, Periodic Sync | None | Reject |
| E | Push notification wake-up | None | Reject |
| F | Last known position / dead reckoning | Fake coverage | Reject |
| G | Installed PWA / WebAPK | None | Not a solution |
| H | TWA + native foreground service | Yes, if native service collects | Reject for now |
| I | Capacitor/WebView + native plugin | Yes, with native work | Reject for now |
| J | Native Android app | Yes | Use |
| K | Native iOS app | Yes, with Always auth | Separate decision |
| L | Longer server timeout | Keeps stale trip alive | Reject |
| M | Browser flags/experiments | None for users | Reject |
| N | Document PiP (desktop) | Only while PiP window visible | Reject for this product |
| O | Web notification / ongoing notification | None | Reject |

Notes on non-obvious verdicts:
- A (keep): only reliable web mode; screen stays on; costs battery, screen burn-in, user cannot use phone otherwise; banner and brightness note disclose this. Do not describe as background sharing.
- B (implemented): smallest useful pure-web improvement; no new permission/wire field/server change/retention change. Behavior: one-shot `getCurrentPosition()` (15 s timeout) on visible fed through existing filter (60 m accuracy, mock rejection, 20 s age gate); restart stream if dead/silent; one paced ping when fresh fix accepted; wake-lock re-request + `enabled` re-check on visible; explicit ended state after server timeout, no silent revival; reject queued fix accepted >20 s before delivery.
- J (use): existing app uses foreground service type `location`, persistent notification, no `ACCESS_BACKGROUND_LOCATION` (D11); stops when swiped away. Web banner points Android users to native app (D-U24).
- K (separate): native iOS app with Core Location background updates, `location` background mode, Always auth, system indicator; product/review decision, outside this investigation.
- N (desktop only): Chromium desktop 116+; PiP window can stay visible while user works in another app; PiP document is top-level fully active same-origin, so geolocation not blocked by visibility gate while window visible and origin has permission. Needs a second location loop inside a small HTML/JS document with its own permission check, filtering, interval pacing, token use, ping sender; forwarding to a throttled Flutter opener is insufficient. Not available on Chrome for Android/Safari/iOS; stops when window closes/covered/screen locks; requires user gesture; one PiP window; duplicates location/credential logic (security/maintenance cost); untested on this project. Only pure-web mechanism that can keep location flowing while user works in another desktop app, but not mobile and not worth alpha. Prototype separately if desktop sharing becomes a requirement, explicitly best-effort.
- O (reject): notification is a display surface, not execution context; no ongoing/foreground-service notification API for websites; an installed PWA is still a website. Never use notification as keepalive or sharing indicator.
- C (reject): silent audio/video keepalive does not override geolocation gate; Chrome pauses geolocation in background regardless of media; iOS can suspend web app; risks media session/notification, battery, user-hostile experience. Existing `wakelock_plus` fallback video acceptable only as foreground screen-wake fallback.
- D/E (reject): workers cannot call `navigator.geolocation`; Periodic Background Sync installed-only, engagement-gated, browser-scheduled; push wakes worker but no location. No useful combination.
- F (reject): showing last known position useful as stale marker (viewer already 120 s hide rule); pretending live is not; dead reckoning fabricates movement. Keep as stale marker only.
- G (reject): no web API for background geolocation; Chrome app-level location permission is not a website permission.
- H (reject): TWA host cannot directly access page state/cookies/storage; while page hidden Chrome may suspend it; if native service collects/sends, web page is only UI and location acquisition, token handling, retry, server contract move to native code (that is a native app). Requires new Android app, Play Console foreground-service declaration, location permission, persistent notification, release process; existing Android app already does this. No advantage.
- I (reject): Capacitor geolocation plugin "does not support background geolocation directly"; iOS needs native background mode + Always auth. Separate app, not web workaround.
- L (reject): 10 min timeout is safety/privacy feature (no pings -> trip ended, in-memory location dropped). Extending creates ghost trip, conflicts with freshness/retention. Viewer already hides vehicle after 120 s.
- M (reject): not shippable.

## 6. Expected behavior and failure modes

| Situation | Platform behavior | Current app behavior | Product requirement |
| --- | --- | --- | --- |
| Screen on, trip screen visible | Fixes and pings flow | Works | Keep; wake lock held; banner visible |
| Brief hide <60 s | Updates may stop immediately | No pause flag; return triggers one-shot recovery | Do not claim continuity; recover promptly |
| Hide 60 s-10 min | No updates while hidden | Pause flag after 60 s if timers run; resume restarts dead stream and one-shots | Resume on return; show gap/age |
| Hide >10 min | No updates; server timeout | Long-gap `gone` shows explicit `timeout` end; no revival | Show ended or explicit restart; never silent ghost |
| Screen locked | Wake lock released; updates stop | Same as hide; resume recovery best effort | Screen-off not supported on web |
| App switched | Page hidden/frozen | Same as hide; recovery on visible | Same |
| Another app, Android video PiP | Video plays; page hidden; geolocation paused | Not implemented | Do not treat video PiP as sharing |
| Another app, desktop Document PiP | PiP window stays visible; can keep fixes while opener hidden; closing/covering stops | Not implemented | Desktop-only best effort; never offered as mobile sharing |
| Another app, web notification | Notification shown, no code runs; location stops | Not implemented | Never present notification as proof of sharing |
| Low battery/power saver | Wake lock may be ignored; timers throttled | Banner may say wake lock unsupported | Warn; do not promise |
| Process killed/tab discarded | No JS; in-memory trip lost | Trip lost; server times out | Restart required; no resurrection |
| Permission revoked | Stream errors/stops | Supervisory end | End with guidance |
| Network loss | No pings; offline saver | Offline saver, probes | Recover when online; no background claim |
| Viewer after 120 s without fix | Vehicle hidden | Viewer hides | No stale "live" marker |
| Native Android, screen off | Foreground service continues | Works with notification | Supported path |
| Native iOS, screen off | Core Location background mode | Not in this app | Separate product decision |

Regression cover:
- Silent revival after timeout: long-gap `gone` ends with detail `timeout` instead of reviving; controller test asserts explicit end. Short gap still revives once (server restart or lost record).
- Stale wake-lock state: widget test asserts visible transition re-requests lock. Device behavior on Android Chrome and iOS Safari/PWA still needs field protocol (browser can refuse/release).

## 7. Device test protocol

Complements `docs/field-tests/gps-acceptance.md`. Same privacy rules: no coordinates in logs/notes, no raw GPS traces, no production personal data. Use staging server or test receiver that discards bodies and records only timestamps/status.

7.1 Goals: confirm foreground baseline (wake lock, cadence, pings visible+screen on); confirm platform boundary (screen off, app switch, lock, low power, long hidden); measure post-return recovery (time to first accepted fix and first ping); confirm honest product (no false live, no silent revival, no stale fix published); compare Android Chrome tab, Android installed PWA, iOS Safari, iOS home-screen web app.

7.2 Pass criteria (background scenarios expected to stop; pass means app handles correctly, not defeats platform):
- Foreground baseline: >=90% expected pings at server interval; wake lock held; banner visible.
- Hidden/screen off: no crash, no false "sharing" claim, no coordinates in logs, no ping with stale fix after return.
- Resume: first accepted fix within 15 s and first ping within 20 s after visible (proposed targets; record misses, do not relax silently).
- Timeout: after >10 min hidden, UI shows ended trip or explicit restart; silent new trip is failure.
- Wake lock: held again after hide/show; if refused, banner must say so.
- PWA parity: installed PWA matches tab or difference recorded with OS/browser version.
If a background scenario delivers fixes by accident, record duration and do not turn into product guarantee.

7.3 Devices/builds: Android Chrome stable tab (reference Android web); Android installed PWA (confirms install changes nothing); second OEM skin if available (Samsung/Xiaomi); iPhone Safari tab; iPhone home-screen web app; second phone/desktop viewer. Release web build over HTTPS with staging API origin; grant precise location; start unplugged, battery saver off; repeat low-power with saver on. Record OS/browser/PWA install method. No debug build with extra logging that changes timing.

7.4 Scenario matrix (run S0 first on every target; fresh trip per cell; repeat twice):

| ID | Scenario | Duration | Expected platform | Product check |
| --- | --- | --- | --- | --- |
| S0 | Visible, screen on, no interaction | 5 min | Pings at server cadence | Wake lock, banner, no pause |
| S1 | App switch | 30 s | Updates stop/sparse | Return resumes; gap measured |
| S2 | App switch | 61 s | No updates while hidden | Pause threshold observed |
| S3 | App switch | 2 min | No updates while hidden | Resume; first fix/ping measured |
| S4 | Screen lock (power) | 2 min | Wake lock released; no updates | Return resumes; lock reacquired |
| S5 | Screen lock | 9 min | No updates; within timeout | Resume before timeout |
| S6 | Screen lock | 11 min | Server timeout | UI ends or explicitly restarts |
| S7 | Installed PWA: S0,S2,S4,S6 | as above | Same limits as tab | No extra privilege |
| S8 | Battery saver/low power, visible+locked | 2 min | Wake lock may fail; timers throttled | Banner honest; no crash |
| S9 | Wi-Fi to cellular while visible | 1 min | Network transition | Reconnect; no duplicate trip |
| S10 | Swipe away/force-stop | immediate | No JS; trip lost | Restart required; server timeout |
| S11 | Revoke location or approximate | immediate | Stream stops or fixes fail gate | Trip ends with guidance |
| S12 | iOS Safari vs home-screen app | S0,S2,S4,S6 | Version-dependent | Record differences |

7.5 Procedure: prepare test receiver/staging (record only timestamp, route, status, random run id; discard body; never log coordinates/tokens/device ids). Open viewer on second device, keep awake. On sharer clear app data, grant precise location, start trip on test line, confirm viewer shows vehicle. Record t0 and last server ping. Apply scenario exactly; note wall-clock time. At checkpoints (30 s, 60 s, 2, 5, 9, 11 min) record viewer last-update age and server last ping; do not wake sharer to inspect. Return, unlock, start stopwatch; record first accepted fix, first new ping, banner state, wake-lock state. If trip ended, record end reason; if new trip, record start time and first position age. End trip and clean up test record. Repeat cell twice (third if runs differ, record range).

7.6 Measurements: server ping timestamps/status only (no bodies); time to first accepted fix after visible; time to first new ping; wake-lock state on return; trip state (active/paused/ended/revived); battery % change; network transition if tested; screenshots/UI state with no real location visible. Never record coordinates, raw GPS traces, tokens, device ids, or IPs. Client logs event names/reasons only; if remote debugging, filter to lifecycle/wake-lock events.

7.7 Result template:

| Field | Value |
| --- | --- |
| Date | |
| Device, OS, browser | |
| Install mode (tab/PWA) | |
| Build and API origin | |
| Scenario ID | |
| Duration | |
| Pings while hidden | |
| Last update age at return | |
| First fix after visible | |
| First ping after visible | |
| Wake lock on return | |
| Trip state / end reason | |
| Battery delta | |
| Notes (no coordinates) | |

## 8. Recommendation

8.1 Adopt: foreground-only product contract (banner states it; native Android covers screen-off). Gap recovery implemented as small pure-web improvement: one-shot position on visible through existing filter; immediate stream restart when dead/silent; one paced ping on fresh fix; wake-lock re-request and `enabled` re-check on visible; explicit ended state after server timeout with no silent revival; rejection of queued fix already stale by delivery. No server change, new permission, dependency, or data field. Unit/widget tests cover visible transition, one-shot path, stream restart, pacing, stale queued fix, wake lock, timeout end. S1-S6 field cells still required before claiming measured latency.

8.2 Do not adopt: silent audio/video keepalive; service worker/Background Sync/Periodic Sync/push as location mechanism; Document PiP as mobile workaround; web notifications as keepalive or "ongoing sharing" indicator; Android video PiP as sharing mode; last-fix dead reckoning as if live (stale marker only); TWA or Capacitor wrapper (native app, duplicates existing); longer server timeout (ghost trips, weakens retention); browser flags/undocumented behavior.

8.3 If owner wants more: iOS screen-off -> native iOS app with Core Location background updates and Always auth (separate product with review, battery, privacy, App Store work; not a PWA feature). Web-UI shell with native location on Android -> new native app, not TWA side project (existing app already implements service, token, retry, notification).

## 9. Open questions

1. Is foreground-only web sharing acceptable for alpha given Android users can install native app?
2. Should gap recovery be implemented now or only after device tests confirm current recovery latency?
3. Is iOS screen-off sharing a real requirement? If yes, funded and reviewed native iOS app?
4. After server timeout, should web app always show ended trip, or may it offer explicit "continue sharing"? Current revive path ambiguous.
5. Is 15 s first-fix and 20 s first-ping target after return acceptable, or longer "reconnecting" state?
6. Should trip screen show age of last position on web, in addition to banner?
7. Is desktop web sharing in scope at all? If yes, is desktop-only Document PiP prototype worth second location loop (still stops on screen lock/PiP close)?

D74 answers 1, 2, 4: foreground-only accepted for alpha, gap recovery implemented now, long-gap server timeout shown as explicit end. Questions 3, 5, 6, 7 remain open. This document is evidence; decisions live in `DECISIONS.md`.

## 10. Sources

All web sources accessed 2026-10-19.

- W3C, Geolocation, Candidate Recommendation Snapshot, 26 March 2026. https://www.w3.org/TR/geolocation/
- Chrome for Developers, "One-time permissions in Chrome". https://developer.chrome.com/blog/one-time-permissions
- MDN, Document Picture-in-Picture API. https://developer.mozilla.org/en-US/docs/Web/API/Document_Picture-in-Picture_API
- WICG, Document Picture-in-Picture specification. https://wicg.github.io/document-picture-in-picture/
- Chrome for Developers, "Picture-in-Picture for any Element, not just video". https://developer.chrome.com/docs/web-platform/document-picture-in-picture
- Can I use, DocumentPictureInPicture API. https://caniuse.com/mdn-api_documentpictureinpicture
- MDN, Notifications API. https://developer.mozilla.org/en-US/docs/Web/API/Notifications_API
- Chrome for Developers, "Page Lifecycle API". https://developer.chrome.com/docs/web-platform/page-lifecycle-api
- W3C, Screen Wake Lock. https://w3c.github.io/screen-wake-lock/
- Chrome for Developers, "Richer offline experiences with the Periodic Background Sync API". https://developer.chrome.com/docs/capabilities/periodic-background-sync
- MDN, Service Worker API. https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API
- Chrome for Developers, "Trusted Web Activity overview". https://developer.chrome.com/docs/android/trusted-web-activity/overview
- Chrome for Developers, "PostMessage for TWA". https://developer.chrome.com/docs/android/post-message-twa
- Capacitor, Geolocation plugin. https://capacitorjs.com/docs/apis/geolocation
- Android Developers, "Foreground service types", Location. https://developer.android.com/develop/background-work/services/fgs/service-types
- Apple Developer, "Handling location updates in the background". https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background
- Apple Developer, "allowsBackgroundLocationUpdates". https://developer.apple.com/documentation/corelocation/cllocationmanager/allowsbackgroundlocationupdates
- WebKit, "WebKit Features in Safari 16.4". https://webkit.org/blog/13966/webkit-features-in-safari-16-4/

Project references: PLAN.md 8.12, 13.2, 13.4, RF04, PRV03; DECISIONS.md D11, D-U24, D59, D63-D69; app/lib/platform/web/visibility.dart; app/lib/platform/web/wake_lock.dart; app/lib/platform/web/web_banner.dart; app/lib/ui/features/trip/trip_screen.dart; app/lib/features/trip/location_service.dart; app/lib/features/trip/trip_controller.dart; server/src/domain/types.ts (tripTimeoutS); docs/field-tests/gps-acceptance.md.