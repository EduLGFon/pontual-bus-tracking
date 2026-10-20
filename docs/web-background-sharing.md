# Web/PWA background location sharing: feasibility and test plan

Status: investigation only. No product decision recorded, no code changed.
Date: 2026-10-19.
Related design: `PLAN.md` 8.12 (web/PWA specifics), D11 (no background
location on Android), D-U24 (Android web is viewer-only), D59 (background
survival), and the GPS gates in `docs/field-tests/gps-acceptance.md`.

## 0. Short answer

Pure web/PWA background location is not available. The blocker is the
Geolocation API itself, not a missing permission, manifest flag, service
worker trick, or installed-app mode. The specification only delivers
position updates to a fully active, visible document, and browsers suspend
hidden pages. Installing the PWA does not add native privileges.

Picture-in-picture and notifications do not change this on mobile. A web
notification is a display surface, not an execution environment. Android video
picture-in-picture keeps the video playing, but the page is hidden and
geolocation is paused. Document Picture-in-Picture is a desktop-only
exception: a Chromium desktop PiP window can stay visible while the user works
in another app and can request geolocation from its own document. It is not
available in Chrome for Android, Safari, or iOS, so it is not a mobile
workaround. Section 5.12 covers it.

The useful pure-web options are therefore:

1. Keep sharing foreground-only, with the screen on and the trip screen
   visible. This is the current design and the only reliable web mode.
2. Add prompt resume and gap recovery when the page becomes visible again.
   This shortens the post-return gap, but it does not create background
   coverage.
3. Use the native Android app for screen-off sharing. It already exists and
   uses a foreground service with the `location` type, without
   `ACCESS_BACKGROUND_LOCATION`.

A TWA, Capacitor shell, or WebView wrapper can host a native foreground
service, but that is a native app strategy, not a web workaround. It would
duplicate the existing Android app. If iOS screen-off sharing is required,
that is a separate native iOS product decision.

Recommendation: keep the foreground-only contract, add gap recovery, do not
build a wrapper, and keep the Android native app as the screen-off path.

## 1. What "background" means here

The word covers several different platform states. They share one property:
the page cannot be trusted to run JavaScript or receive geolocation.

| State | Typical trigger | What the web app can rely on |
| --- | --- | --- |
| Visible, screen on | Trip screen open, device unlocked | Location updates and timers can run; wake lock can be held |
| Visible, screen off | Power button, timeout, lock screen | No reliable updates; wake lock is released or not applicable |
| Hidden tab | Another tab, minimized browser | Page visibility is `hidden`; updates stop |
| App switched | Home, another app, app switcher | Page is hidden; browser or OS may freeze it |
| Frozen | Browser resource policy | Timers, fetch callbacks, and most tasks are suspended |
| Discarded | Browser memory pressure | No JavaScript runs at all; the page may reload later |
| Terminated | Tab closed, browser killed, OS kill | Nothing runs; in-memory trip state is lost |
| Native foreground service | Android app only | Can continue with a persistent notification |

The current web policy pauses sends after 60 s hidden. That is a product
policy, not a platform guarantee. Chrome and the Geolocation specification
stop delivering updates earlier, as soon as the document is hidden. A brief
hide may produce a few opportunistic fixes in some browsers, but no test
should treat that as supported behavior.

## 2. Platform evidence

### 2.1 The specification requires a visible document

The W3C Geolocation Candidate Recommendation (26 March 2026) defines
`Geolocation` as `[Exposed=Window]`. It is not exposed to workers or service
workers. The algorithm for `watchPosition()` says that if the document is not
fully active or its visibility state is not `visible`, the user agent waits
for a significant position change and checks again. The specification's own
note is explicit: "Position updates are exclusively for fully-active visible
documents." Updates are silently dropped while hidden and resume only when
the document is active and visible again.

`getCurrentPosition()` follows the same rule. If the document is hidden, the
request waits for the page visibility change steps before acquiring a
position. The `timeout` option does not cover time spent waiting for the page
to become visible.

Consequences:

- A hidden page does not receive a stream of fixes.
- Keeping a `watchPosition()` subscription alive does not override the
  visibility gate.
- A service worker cannot acquire a position on behalf of the page.

Source: W3C Geolocation, sections 5, 6.3, 6.5, and 7.2
(https://www.w3.org/TR/geolocation/).

### 2.2 Chrome pauses geolocation in the background

Chrome's one-time-permissions documentation states that geolocation can only
run in the foreground tab and is "paused as soon as the page is in the
background." It also states that Chrome does not allow background geolocation
access. This is separate from the permission lifetime: even a persistent
grant does not make geolocation work in a hidden tab.

The same page notes that a one-time grant can expire after the page has been
in the background for at least five minutes. That expiry is an additional
reason not to rely on a long-lived hidden page, but it is not the primary
blocker. The primary blocker is that position updates stop while hidden.

Source: Chrome for Developers, "One-time permissions in Chrome", background
tab section (https://developer.chrome.com/blog/one-time-permissions).

### 2.3 Hidden pages can be frozen or discarded

The Page Lifecycle API describes what happens after `visibilitychange`:

- Hidden: the page is not visible. It may still run briefly, but the browser
  is free to freeze or discard it.
- Frozen: freezable tasks, including JavaScript timers and fetch callbacks,
  are suspended.
- Discarded: no tasks, event callbacks, or JavaScript run. The page must be
  reloaded to be used again.
- Terminated: the page is unloaded and cleared from memory.

A hidden page is not guaranteed a `freeze`, `resume`, or `pagehide` event.
Chrome's guidance treats the hidden state as the last reliable point at which
to persist state, because the page may never become visible again.

Consequences:

- A heartbeat timer or a retry loop is best effort only.
- A hidden page can die without notifying the app.
- A service worker wake-up is not a substitute for a live geolocation stream.

Source: Chrome for Developers, "Page Lifecycle API"
(https://developer.chrome.com/docs/web-platform/page-lifecycle-api).

### 2.4 The Screen Wake Lock is not a background lock

The Screen Wake Lock specification allows only visible documents to acquire a
screen wake lock. A request from a hidden document is rejected. The lock is
automatically released when the document becomes hidden and is not applicable
after the user manually switches the screen off. It is advisory: the browser
may release it for low battery, power-saving mode, or abnormal operation.

The wake lock is still useful for the foreground mode: it prevents the screen
from turning off while the trip screen is visible. It cannot keep the page
alive when the user locks the phone or switches apps.

Source: W3C Screen Wake Lock
(https://w3c.github.io/screen-wake-lock/), sections "Wake Locks", "The
request() method", and "Auto-releasing wake locks".

### 2.5 Workers and service workers cannot obtain location

The Geolocation interface is exposed only to `Window`. A dedicated worker,
shared worker, or service worker has no `navigator.geolocation` that can
acquire a position. Service workers are event-driven and have no DOM. They can
cache assets, intercept requests, and react to push or sync events, but they
cannot ask the device for a location.

The background sync family is also data-only:

- Background Sync retries a failed network operation when connectivity
  returns.
- Periodic Background Sync lets an installed PWA refresh data on a schedule
  chosen by the browser. It requires installation and user engagement, is not
  available in a normal tab, and is not a continuous execution environment.
- Push notifications can wake a service worker, but the worker still cannot
  call the Geolocation API.

None of these mechanisms can produce a position. They can only send data the
page already has, which is the last known fix at best.

Sources: MDN Service Worker API
(https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API); Chrome
for Developers, "Richer offline experiences with the Periodic Background Sync
API" (https://developer.chrome.com/docs/capabilities/periodic-background-sync).

### 2.6 Installing the PWA grants no background privileges

An installed PWA on Android is still rendered by Chrome (WebAPK), and an
installed web app on iOS is still rendered by WebKit. Installation changes how
the app is launched and displayed, not what the browser engine is allowed to
do. There is no web manifest field, service worker registration, or install
prompt that grants background geolocation.

A TWA is also rendered by the user's browser, in fullscreen. The Android host
does not get direct access to the web page's state, cookies, or local storage.
The host can coordinate through URLs or the postMessage bridge, but the web
content remains web content and keeps the same visibility rules.

Sources: Chrome for Developers, "Trusted Web Activity overview"
(https://developer.chrome.com/docs/android/trusted-web-activity/overview);
Chrome for Developers, "PostMessage for TWA"
(https://developer.chrome.com/docs/android/post-message-twa).

### 2.7 iOS does not expose a web background mode

Safari and installed home-screen web apps are subject to WebKit and iOS
lifecycle management. Apple documents background location as a native Core
Location capability: the app enables the `location` background mode, receives
continuous updates, and shows the background location indicator. That
capability is available to native apps, not to web content.

iOS behavior has changed across releases, and installed-PWA behavior is not
identical to Safari-tab behavior. This report does not assume a specific iOS
version. The device protocol below treats iOS Safari and the home-screen app
as separate test targets.

Source: Apple Developer, "Handling location updates in the background"
(https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background);
"allowsBackgroundLocationUpdates"
(https://developer.apple.com/documentation/corelocation/cllocationmanager/allowsbackgroundlocationupdates).

### 2.8 Android foreground services are a native feature

Android 14 and later require a foreground service type. The `location` type
requires `FOREGROUND_SERVICE_LOCATION`, a runtime location permission, and a
visible notification. A location foreground service can be started while the
app is visible and continue when the app goes to the background. Starting it
from the background requires `ACCESS_BACKGROUND_LOCATION`, which this project
does not request (D11).

This is exactly what the existing Android app does. It is not something a web
page can start or control.

Source: Android Developers, "Foreground service types", Location section
(https://developer.android.com/develop/background-work/services/fgs/service-types).

## 3. Capability matrix

| Mechanism | Pure web? | Location while hidden or screen off? | Why |
| --- | --- | --- | --- |
| Visible page + `watchPosition` | Yes | No | Spec waits for a visible document |
| Visible page + Screen Wake Lock | Yes | No | Lock only applies while visible; screen-off releases it |
| Hidden tab with timers | Yes | No | Browser pauses or freezes the page |
| Dedicated or shared worker | Yes | No | Geolocation is `Window`-only |
| Service worker | Yes | No | No DOM and no Geolocation API |
| Background Sync | Yes | No | Retries data, does not acquire location |
| Periodic Background Sync | Yes | No | Browser-scheduled data refresh; no location |
| Push notification | Yes | No | Wakes a worker, but the worker has no location |
| Web notification as a keepalive | Yes | No | Display and click target only; it does not execute location code |
| Android video picture-in-picture | Yes | No | Video keeps playing, but the page is hidden and geolocation is paused |
| Document Picture-in-Picture (desktop Chromium) | Yes, desktop only | Only while the PiP window stays visible | A same-origin PiP document can request geolocation; unsupported in Chrome for Android, Safari, and iOS |
| Installed PWA / WebAPK | Yes | No | Same browser engine; no native entitlement |
| TWA + native foreground service | No | Yes, while the service runs | The host app collects and sends location natively |
| Capacitor/WebView + native plugin | No | Yes, with native service and permissions | Native shell, not a PWA |
| Native Android app | No | Yes | Foreground service type `location` |
| Native iOS app | No | Yes, with background location mode | Core Location background updates |

## 4. What the current implementation does

The current web mode is a deliberate foreground-only design:

- `TripScreen` requests a wake lock while the trip screen is alive
  (`app/lib/ui/features/trip/trip_screen.dart`).
- `WebVisibilityTracker` pauses after 60 s hidden and clears the pause on
  visible (`app/lib/platform/web/visibility.dart`).
- `TripController.setWebHidden(true)` makes the fix subscription drop fixes
  while hidden (`app/lib/features/trip/trip_controller.dart`).
- `WebTripBanner` is always visible during a web trip and says: "Mantenha esta
  tela aberta e o celular desbloqueado."
- The server ends a trip after 600 s without a ping
  (`trip_timeout_s = 600`), and the viewer hides a vehicle after 120 s without
  a fix.

This is honest and matches the platform. The gaps are around recovery, not
background acquisition:

1. **No immediate recovery on visible.** The screen becomes visible and
   `setWebHidden(false)` runs, but no one-shot position is requested. The
   location service's stall watchdog runs from supervision rounds, and its
   threshold is 30 s. The first new fix after returning can therefore take up
   to roughly the next supervision round plus GPS acquisition time.
2. **Wake-lock reacquisition is unverified.** The app calls `enable()` once
   when the trip screen starts. `wakelock_plus` 1.8.0 contains a web
   visibility hook in its fallback script, but the release path has not been
   device-tested after a hide/show cycle. The browser releases the lock on
   hidden; the app should confirm that it is held again on visible.
3. **Timeout semantics need a product test.** When the server ends a trip for
   `timeout`, the next ping returns `gone`. The client has a one-time `_revive`
   path for `gone` that calls `startTrip(resume: true)` with the last accepted
   fix. That can be correct for a server restart or a lost record, but after a
   deliberate 10-minute timeout it may silently create a new trip when the
   user returns. The UI must not present that as an uninterrupted trip.
4. **The pause flag is not a guarantee.** If the page is frozen, the 5 s
   visibility timer does not run. The `paused` state may only be observed
   after the page resumes, at which point `onVisible()` clears it. This is a
   UI/policy signal, not proof that the page was running while hidden.
5. **There is no background acquisition.** No amount of client refactoring
   changes that while the app is a web page.

These are code-reading findings, not device results. The test protocol below
is designed to confirm or reject them.

## 5. Candidate approaches

| ID | Approach | Coverage while hidden | Main trade-off | Verdict |
| --- | --- | --- | --- | --- |
| A | Foreground sharing with wake lock | None | Screen stays on; battery; user cannot use the phone | Keep |
| B | Immediate gap recovery on visible | None, but shortens the post-return gap | Small pure-web change; no new data | Recommend |
| C | Silent audio or video keepalive | None or accidental | Does not override the geolocation gate; battery; policy and trust risk | Reject |
| D | Service worker, Background Sync, Periodic Sync | None | No Geolocation API in workers | Reject |
| E | Push notification wake-up | None | Worker still has no location | Reject |
| F | Last known position or dead reckoning | Fake coverage | Shows a position the device may no longer be at | Reject |
| G | Installed PWA / WebAPK | None | No native privilege | Not a solution |
| H | TWA + native foreground service | Yes, if the native service collects location | Native app, Play policy, duplicate of existing app | Reject for now |
| I | Capacitor/WebView + native plugin | Yes, with native work | Separate app, App Store review, custom plugin | Reject for now |
| J | Native Android app | Yes | Already exists; persistent notification | Use |
| K | Native iOS app | Yes, with Always authorization | Separate product, review, battery indicator | Separate decision |
| L | Longer server timeout | Keeps a stale trip alive | Ghost position; contradicts freshness and retention | Reject |
| M | Browser flags or experiments | None for users | Not shippable | Reject |
| N | Document Picture-in-Picture (desktop) | Only while the PiP window is visible | Desktop Chromium only; needs a second location loop; not available on Android or iOS | Reject for this product |
| O | Web notification or ongoing notification | None | Display surface only; no script, no location; a website cannot create a foreground-service notification | Reject |

### 5.1 A: foreground sharing with wake lock

This is the current mode and the only reliable web mode. It works because the
document is visible, the wake lock keeps the screen on, and the user is told
to keep the screen open and unlocked. It has real costs: battery, screen
burn-in risk, and the user cannot use the phone for anything else. The banner
and brightness note already disclose this.

Keep it. Do not describe it as background sharing.

### 5.2 B: immediate gap recovery on visible

This is the smallest useful improvement that stays pure web. It does not
extend coverage while hidden. It reduces the period after return in which the
map still shows the old position and no new ping has arrived.

Proposed behavior:

- On `visible` after a hidden period, clear the pause flag and, if a trip is
  active, request one high-accuracy `getCurrentPosition()` with a short
  timeout. Feed the result through the existing `LocationService` filter, so
  the 60 m accuracy gate, mock rejection, and 20 s age gate still apply.
- Restart or kick the position stream if it is dead or silent, instead of
  waiting for the 30 s supervision round. Keep the existing stall watchdog as
  the fallback.
- If the fix is accepted and the server's interval allows a send, queue one
  immediate ping. Do not bypass the per-device rate limit.
- Re-request the wake lock on visible and listen for its release event. Do not
  assume the original sentinel is still held.
- Show a short "retomando" state and the age of the last position. If the
  server ended the trip, show the ended state explicitly; do not silently
  revive it.
- Do not queue fixes collected while hidden. There should be none, and stale
  fixes must not be published.

This is a frontend-only change: no new permission, no new field, no server
change, no retention change. It needs unit tests for the visible transition
and field tests for the actual latency.

### 5.3 C: silent audio or video keepalive

A silent looping video or Web Audio graph can keep some browsers from
freezing a page, and libraries such as NoSleep use that trick for screen
wake. It does not change the Geolocation visibility gate. Chrome explicitly
pauses geolocation in the background regardless of media playback, and iOS
can suspend the web app. The trick also risks a media session or notification,
extra battery drain, and a user-hostile "why is this page playing audio?"
experience. It is not reliable enough to ship and not honest enough to
promise.

Reject. The existing `wakelock_plus` fallback video is acceptable only as a
screen-wake fallback in the foreground; it is not a background mechanism.

### 5.4 D and E: service workers, background sync, push

These mechanisms are useful for data refresh and retry, not for location
acquisition. A service worker cannot call `navigator.geolocation`. Periodic
Background Sync is installed-app-only, engagement-gated, and scheduled by the
browser; it is not a continuous stream. Push can wake a worker, but the worker
still has no location.

There is no useful combination here. Reject.

### 5.5 F: last known position and dead reckoning

Showing the last known position is useful as a stale marker, which the viewer
already does with its 120 s hide rule. Pretending it is live is not. Dead
reckoning from speed and heading would fabricate movement and could place a
bus where it is not, which is worse than showing a gap.

Reject as a sharing mechanism. Keep the existing stale-state presentation.

### 5.6 G: installed PWA or browser setting

There is no web API to request background geolocation. Chrome's app-level
location permission ("allow all the time" for Chrome as an Android app) is not
a website permission and does not change the foreground rule. Browser flags
and origin trials are not a shipping strategy.

Not a solution.

### 5.7 H: TWA with an Android foreground service

A TWA is a native Android host that opens web content in Chrome. The host can
run an Android foreground service with the `location` type, show the required
notification, and keep collecting while the user switches apps or turns the
screen off. That part is technically feasible.

The hard part is the bridge and the product:

- TWA content is rendered by Chrome, and the host does not have direct access
  to the page's state, cookies, or local storage.
- The postMessage bridge (Chrome 115+) can exchange messages after Digital
  Asset Links validation, but it is a message channel, not a general native
  API. While the page is hidden, Chrome may suspend it.
- If the native service collects positions and sends pings, the web page is
  only a UI. The location acquisition, token handling, retry policy, and
  server contract have moved into native code. That is a native app.
- It requires a new Android app, Play Console foreground-service declaration,
  location permission, a persistent notification, and a release process. The
  repository already has an Android app that does this and is distributed as
  an APK/AAB.

There is no advantage over the existing native app. Reject for now. If the
owner ever wants a web-UI shell with native location, treat it as a new native
product with its own ADR, privacy review, and Play policy work, not as a PWA
feature.

### 5.8 I: Capacitor or WebView wrapper

Capacitor's official geolocation plugin says it "does not support background
geolocation directly"; background behavior needs a native plugin or service.
On iOS, background location needs the native background mode and Always
authorization. A WebView wrapper has the same shape: native shell, native
location service, native permissions, app-store review.

This is a separate app, not a web workaround. Reject for the same reasons as
the TWA. The existing Android app is the better path.

Source: Capacitor Geolocation
(https://capacitorjs.com/docs/apis/geolocation).

### 5.9 J: native Android app

The existing app uses a foreground service with the `location` type, a
persistent notification, and no `ACCESS_BACKGROUND_LOCATION` (D11). It stops
when the user swipes the app away. This is the supported way to share with
the screen off on Android.

The web banner already points Android users to the native app (D-U24). Keep
that path. Do not duplicate it in a wrapper.

### 5.10 K: native iOS app

If iOS screen-off sharing is a product requirement, the supported path is a
native iOS app with Core Location background updates, the `location` background
mode, Always authorization, and the system's background location indicator.
That is a product and review decision, not a web fix. It is outside this
investigation.

### 5.11 L: longer server timeout

The 10-minute timeout is a safety and privacy feature: a trip with no pings is
ended, and its in-memory location is dropped. Extending it for web users would
keep a ghost trip alive and conflict with the freshness rules. The viewer
already hides a vehicle after 120 s without a fix.

Reject.

### 5.12 N: Document Picture-in-Picture (desktop only)

Document Picture-in-Picture (Document PiP) opens an always-on-top window
containing arbitrary same-origin HTML. It is available in Chrome and Edge
desktop 116 and later. It is not available in Chrome for Android, Safari, or
iOS, and it is not the Android video PiP surface.

Unlike a background tab, the PiP window can stay visible while the user works
in another desktop application. The PiP document is a top-level, fully active,
same-origin document, so geolocation requested from that document is not
blocked by the visibility gate while the PiP window is visible and the origin
already has location permission. The specification warns that the opener may
be throttled and recommends running application logic inside the PiP window.
A real implementation would therefore need a second location loop inside a
small HTML and JavaScript document, with its own permission check, filtering,
interval pacing, token use, and ping sender. Forwarding fixes to a throttled
Flutter opener is not enough.

Limits:

- No Chrome for Android, Safari, or iOS. It cannot help a phone user who
  switches to another app, which is the requirement that matters here.
- The PiP window must stay open and visible. Closing it, covering it with a
  fullscreen app, locking the screen, or closing the opener stops the loop.
- It requires a user gesture to open, and only one PiP window exists.
- It duplicates location and credential logic outside the Dart app, which is
  a security and maintenance cost. CSP and Permissions-Policy inheritance for
  the PiP document would need review before it handled a device token.
- It is untested on this project and is not part of the mobile device matrix.

Verdict: this is the only pure-web mechanism that can technically keep
location updates flowing while the user works in another desktop app. It is
not a mobile solution and not worth adding to the alpha. If desktop web
sharing ever becomes a product requirement, prototype it separately and keep
it explicitly best-effort.

### 5.13 O: Notifications

A web notification is a user-visible message, not an execution context. A page
can display one while it is alive, and a service worker can display one from a
push or notification event, but the notification itself runs no JavaScript.
Clicking it is handled by the page or service worker, which can focus or open
the app. A notification action wakes the service worker briefly; the worker
still has no Geolocation API. Push can wake the worker, but the worker cannot
acquire a position, and the browser shuts it down after the event.

There is no web API for an ongoing or foreground-service notification. An
installed PWA is still a website and cannot declare an Android foreground
service. A notification displayed during a web trip would be cosmetic: it
would not prove that pings are flowing, and it would be misleading if the page
were hidden. The only persistent notification that keeps location alive is
the one from the native Android foreground service, which the existing app
already uses.

Reject. Do not use a notification as a keepalive or as a sharing indicator.

## 6. Expected behavior and failure modes

This table describes what the product should do when the platform stops
sharing. "Expected" is about honest behavior, not about keeping the ping
alive.

| Situation | Platform behavior | Current app behavior | Product requirement |
| --- | --- | --- | --- |
| Screen on, trip screen visible | Fixes and pings flow | Works | Keep; wake lock held; banner visible |
| Brief hide, under 60 s | Updates may stop immediately | No pause flag; fixes may stop; return resumes | Do not claim continuity; recover promptly |
| Hide 60 s to 10 min | No updates while hidden | Pause flag after 60 s if timers run; trip alive | Resume on return; show gap/age |
| Hide over 10 min | No updates; server timeout | Next ping returns `gone`; one-time revive path may create a new trip | Show ended or explicit restart; never silent ghost |
| Screen locked | Wake lock released; updates stop | Same as hide | Screen-off is not supported on web |
| App switched | Page hidden or frozen | Same as hide | Same |
| Another app, Android video PiP | Video keeps playing; the page is hidden and geolocation pauses | Not implemented | Do not treat video PiP as sharing |
| Another app, desktop Document PiP | PiP window stays visible and can keep fixes while the opener is hidden; closing or covering it stops | Not implemented | Desktop-only best effort; never offered as mobile sharing |
| Another app, web notification | Notification is shown, but no code runs; location stops | Not implemented | Never present a notification as proof of sharing |
| Low battery or power saver | Wake lock may be ignored; timers throttled | Banner may say wake lock unsupported | Warn; do not promise |
| Process killed or tab discarded | No JS; in-memory trip lost | Trip lost; server times out | Restart required; no resurrection |
| Permission revoked | Stream errors or stops | Supervisory end | End with guidance |
| Network loss | No pings; offline saver | Offline saver, probes | Recover when online; no background claim |
| Viewer after 120 s without fix | Vehicle hidden | Viewer hides | No stale "live" marker |
| Native Android, screen off | Foreground service continues | Works with notification | Supported path |
| Native iOS, screen off | Core Location background mode | Not in this app | Separate product decision |

Two failure modes deserve explicit tests:

- **Silent revival after timeout.** If the client's `gone` revive path
  recreates a trip after the server timed out, the user may see a trip that
  looks continuous but has a new start time and a stale first position. Test
  it and decide whether the revive path should be limited to server-restart
  cases, or whether the UI should always show an ended state after a long
  gap.
- **Stale wake-lock state.** If the wake lock is not reacquired after a
  hide/show cycle, the screen can sleep during a supposedly foreground trip.
  The banner says the screen stays on, so this would be a visible contract
  violation. Test it on Android Chrome and iOS Safari/PWA.

## 7. Device test protocol

This protocol complements `docs/field-tests/gps-acceptance.md`. It uses the
same privacy rules: no coordinates in logs or notes, no raw GPS traces, and
no production personal data. Use a staging server or a test receiver that
discards request bodies and records only timestamps and status codes.

### 7.1 Goals

1. Confirm the foreground baseline: wake lock, cadence, and pings while the
   trip screen is visible and the screen is on.
2. Confirm the platform boundary: what happens on screen off, app switch,
   lock screen, low power, and long hidden periods.
3. Measure post-return recovery: time to first accepted fix and first ping.
4. Confirm the product is honest: no false "live" state, no silent revival,
   no stale fix published.
5. Compare Android Chrome tab, Android installed PWA, iOS Safari, and iOS
   home-screen web app.

### 7.2 Pass criteria

The background scenarios are expected to stop delivering fixes. A test passes
when the app handles that correctly, not when it defeats the platform.

- Foreground baseline: at least 90 percent of the expected pings arrive at the
  server interval; the wake lock is held; the banner is visible.
- Hidden or screen off: no crash, no false "sharing" claim, no coordinates in
  logs, and no ping with a stale fix after return.
- Resume: first accepted fix within 15 s and first ping within 20 s after the
  page becomes visible. These are proposed targets for the gap-recovery work;
  record misses rather than relaxing them silently.
- Timeout: after more than 10 minutes hidden, the UI shows an ended trip or an
  explicit restart. A silent new trip is a failure.
- Wake lock: held again after returning from a hide/show cycle. If the
  browser refuses, the banner must say so.
- PWA parity: installed PWA behavior matches the browser tab, or the
  difference is recorded with the OS and browser version.

If a background scenario delivers a few fixes by accident, record the
duration and do not turn it into a product guarantee.

### 7.3 Devices and builds

Minimum useful matrix:

| Target | Why |
| --- | --- |
| Android, Chrome stable, browser tab | Reference Android web behavior |
| Android, installed PWA (WebAPK) | Confirms install does not change privileges |
| Android, second OEM skin if available (Samsung or Xiaomi) | Background restrictions vary |
| iPhone, Safari tab | Reference iOS web behavior |
| iPhone, home-screen web app | Standalone PWA behavior |
| Second phone or desktop, viewer | Independent observation of last update |

Use a release web build served over HTTPS with the staging API origin. Grant
precise location. Start with the phone unplugged and battery saver off. Repeat
the low-power scenario with battery saver on. Record the exact OS, browser,
and PWA install method. Do not use a debug build with extra logging that
changes timing.

### 7.4 Scenario matrix

Run S0 first on every target. Run the background scenarios in order, with a
fresh trip for each cell. Repeat each cell twice; one run is not enough for a
mobile browser.

| ID | Scenario | Duration | Expected platform result | Product check |
| --- | --- | --- | --- | --- |
| S0 | Visible, screen on, no interaction | 5 min | Pings at server cadence | Wake lock, banner, no pause |
| S1 | App switch to another app | 30 s | Updates stop or become sparse | Return resumes; gap measured |
| S2 | App switch | 61 s | No updates while hidden | Pause threshold observed |
| S3 | App switch | 2 min | No updates while hidden | Resume; first fix/ping measured |
| S4 | Screen lock (power button) | 2 min | Wake lock released; no updates | Return resumes; lock reacquired |
| S5 | Screen lock | 9 min | No updates; trip still within timeout | Resume before timeout |
| S6 | Screen lock | 11 min | Server timeout | UI ends or explicitly restarts |
| S7 | Installed PWA, repeat S0, S2, S4, S6 | as above | Same limits as tab | No extra privilege |
| S8 | Battery saver or low power mode, visible and locked | 2 min | Wake lock may fail; timers throttled | Banner honest; no crash |
| S9 | Wi-Fi to cellular while visible | 1 min | Network transition | Reconnect; no duplicate trip |
| S10 | Swipe away or force-stop the app | immediate | No JS; trip lost | Restart required; server timeout |
| S11 | Revoke location or switch to approximate | immediate | Stream stops or fixes fail gate | Trip ends with guidance |
| S12 | iOS Safari vs home-screen app | S0, S2, S4, S6 | Version-dependent | Record differences |

### 7.5 Procedure

1. Prepare the test receiver or staging server. It must record only request
   timestamp, route, status, and a random test-run id. It must discard the
   body and never log coordinates, tokens, or device identifiers.
2. Open the viewer on the second device and keep it awake.
3. On the sharer, clear app data, grant precise location, start a trip on the
   test line, and confirm the viewer shows the vehicle.
4. Record `t0` and the last server ping timestamp. Do not interact with the
   sharer during the hidden period.
5. Apply the scenario exactly: switch apps, press power, enable battery
   saver, or force-stop. Note the wall-clock time.
6. At the checkpoints for the scenario (30 s, 60 s, 2 min, 5 min, 9 min,
   11 min), record the viewer's last-update age and the server's last ping
   timestamp. Do not wake the sharer just to inspect it.
7. Return to the app, unlock the screen, and start a stopwatch. Record the
   first accepted fix, the first new ping, the banner state, and the wake-lock
   state.
8. If the trip ended, record the end reason shown. If a new trip appeared,
   record its start time and first position age.
9. End the trip and clean up the test record. Delete any test data that is not
   needed.
10. Repeat the cell twice. If the two runs differ, run a third time and record
    the range.

### 7.6 Measurements

Record only what is needed:

- Server ping timestamps and status codes, no bodies.
- Time to first accepted fix after visible.
- Time to first new ping after visible.
- Wake-lock state on return.
- Trip state: active, paused, ended, or revived.
- Battery percentage change over the scenario, from system settings.
- Network type transition, if tested.
- Screen recording or screenshots of the UI state, with no real location
  visible.

Do not record coordinates, raw GPS traces, tokens, device ids, or IP
addresses. Client logs should contain event names and reasons only; the `Log`
wrapper already has no coordinate API. If browser remote debugging is used,
filter to lifecycle and wake-lock events.

### 7.7 Result template

| Field | Value |
| --- | --- |
| Date | |
| Device, OS, browser | |
| Install mode (tab / PWA) | |
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

### 8.1 Adopt

Keep the foreground-only product contract. The web banner already states it,
and the Android native app already covers screen-off sharing. This is the only
configuration that is both reliable and honest on the web.

Add gap recovery as a small, pure-web improvement:

- one-shot position on visible, fed through the existing filter;
- immediate stream restart or kick when the stream is dead or silent;
- one paced ping when a fresh fix is accepted;
- explicit wake-lock reacquisition and release handling;
- an honest "retomando" or age display;
- an explicit ended state after a server timeout, with no silent revival.

No server change, new permission, new dependency, or new data field is needed.
The change should be covered by unit tests for the visible transition and by
the S1-S6 field cells above.

### 8.2 Do not adopt

- Silent audio or video keepalive. It does not override the geolocation gate
  and creates battery, policy, and trust problems.
- Service worker, Background Sync, Periodic Sync, or push as a location
  mechanism. They cannot acquire location.
- Document Picture-in-Picture as a mobile workaround. It is desktop Chromium
  only, needs a second location loop inside the PiP document, and stops when
  the window is closed, covered, or the screen locks.
- Web notifications as a keepalive or as an "ongoing sharing" indicator. They
  display only and cannot acquire location.
- Android video picture-in-picture as a sharing mode. It keeps video playing
  but not geolocation.
- Last-fix dead reckoning as if it were live. Keep it as a stale marker only.
- A TWA or Capacitor wrapper. It is a native app, not a web workaround, and it
  duplicates the existing Android app.
- A longer server timeout. It creates ghost trips and weakens retention.
- Browser flags or undocumented behavior. Not shippable.

### 8.3 If the owner wants more

If screen-off sharing on iOS is a hard requirement, evaluate a native iOS app
with Core Location background updates and Always authorization. That is a
separate product with its own review, battery, privacy, and App Store work. It
is not a PWA feature.

If the owner wants a web-UI shell with native location on Android, treat it as
a new native app, not a TWA side project. The existing Android app already
implements the service, token, retry, and notification path.

## 9. Open questions for the owner

1. Is foreground-only web sharing acceptable for the alpha, given that Android
   users can install the native app?
2. Should gap recovery be implemented now, or only after the device tests
   confirm the current recovery latency?
3. Is iOS screen-off sharing a real requirement? If yes, is a native iOS app
   funded and reviewed?
4. After a server timeout, should the web app always show an ended trip, or
   may it offer an explicit "continue sharing" action? The current revive path
   is ambiguous.
5. Is a 15 s first-fix and 20 s first-ping target after return acceptable, or
   should the product show a longer "reconnecting" state?
6. Should the trip screen show the age of the last position on web, in
   addition to the banner?
7. Is desktop web sharing in scope at all? If it is, is a desktop-only
   Document PiP prototype worth the second location loop, knowing that it
   still stops when the screen locks or the PiP window closes?

No decision should be recorded in `DECISIONS.md` until the owner answers
these. This document is evidence and a proposal, not an ADR.

## 10. Sources

All web sources accessed 2026-10-19.

- W3C, Geolocation, Candidate Recommendation Snapshot, 26 March 2026.
  https://www.w3.org/TR/geolocation/
- Chrome for Developers, "One-time permissions in Chrome".
  https://developer.chrome.com/blog/one-time-permissions
- MDN, Document Picture-in-Picture API.
  https://developer.mozilla.org/en-US/docs/Web/API/Document_Picture-in-Picture_API
- WICG, Document Picture-in-Picture specification.
  https://wicg.github.io/document-picture-in-picture/
- Chrome for Developers, "Picture-in-Picture for any Element, not just
  video".
  https://developer.chrome.com/docs/web-platform/document-picture-in-picture
- Can I use, DocumentPictureInPicture API.
  https://caniuse.com/mdn-api_documentpictureinpicture
- MDN, Notifications API.
  https://developer.mozilla.org/en-US/docs/Web/API/Notifications_API
- Chrome for Developers, "Page Lifecycle API".
  https://developer.chrome.com/docs/web-platform/page-lifecycle-api
- W3C, Screen Wake Lock.
  https://w3c.github.io/screen-wake-lock/
- Chrome for Developers, "Richer offline experiences with the Periodic
  Background Sync API".
  https://developer.chrome.com/docs/capabilities/periodic-background-sync
- MDN, Service Worker API.
  https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API
- Chrome for Developers, "Trusted Web Activity overview".
  https://developer.chrome.com/docs/android/trusted-web-activity/overview
- Chrome for Developers, "PostMessage for TWA".
  https://developer.chrome.com/docs/android/post-message-twa
- Capacitor, Geolocation plugin.
  https://capacitorjs.com/docs/apis/geolocation
- Android Developers, "Foreground service types", Location.
  https://developer.android.com/develop/background-work/services/fgs/service-types
- Apple Developer, "Handling location updates in the background".
  https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background
- Apple Developer, "allowsBackgroundLocationUpdates".
  https://developer.apple.com/documentation/corelocation/cllocationmanager/allowsbackgroundlocationupdates
- WebKit, "WebKit Features in Safari 16.4" (wake lock and PWA context).
  https://webkit.org/blog/13966/webkit-features-in-safari-16-4/

Project references:

- `PLAN.md` 8.12, 13.2, 13.4, RF04, PRV03.
- `DECISIONS.md` D11, D-U24, D59, D63-D69.
- `app/lib/platform/web/visibility.dart`
- `app/lib/platform/web/wake_lock.dart`
- `app/lib/platform/web/web_banner.dart`
- `app/lib/ui/features/trip/trip_screen.dart`
- `app/lib/features/trip/location_service.dart`
- `app/lib/features/trip/trip_controller.dart`
- `server/src/domain/types.ts` (`tripTimeoutS`)
- `docs/field-tests/gps-acceptance.md`
