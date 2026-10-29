# React Native + Expo alternative: parity plan

> Companion to `PLAN.md` (Flutter) and `DECISIONS.md`. This document is the
> build contract for a **second client** that talks to the **unchanged**
> Pontual backend. Backend, database, static data, and WebSocket protocol are
> out of scope for change. Only the client is reimplemented.
>
> Status: draft v0.1 - planning only. No code has been written yet.
> Owner decision required before Phase 0 (see section 22).

---

## 0. Purpose and scope

### 0.1 Goal

Reimplement the Pontual mobile/web client in **React Native + Expo** so that it
can be evaluated against the existing Flutter client without recreating the
entire product. The new client must:

- run on **Android** (dev build, not Expo Go) and on **Web/PWA** from one
  codebase;
- talk to the **existing Deno API** and **existing static data bundle** with no
  backend, migration, or protocol changes;
- reproduce **all app logic**: device registration, consent versioning,
  sharing trips (start/ping/end), leader/follower election via server, public
  vehicle snapshots, WebSocket stream subscription, passenger reports, place
  search, learned routes/stops/eta, arrivals, remote config, maintenance and
  forced-update gates, delete-my-data, learning opt-out, offline timetables;
- use **MapLibre** for maps on both native and web (no Google dependencies, no
  `react-native-maps`);
- keep the **UI intentionally simple** (functional screens, no design-system
  parity with the Flutter app).

### 0.2 Non-goals

- No backend changes. No new endpoints. No schema changes.
- No iOS store release in this phase (Android + Web only; iOS may follow once
  validated).
- No pixel-perfect UI parity. No theme/typography parity. No accessibility
  audit parity (basic a11y only).
- No analytics, crash reporting, local database, or new third-party SDKs
  beyond the allow-list in section 6.
- No background location sharing beyond what the platform permits in a dev
  build (see section 8.3); foreground service parity is **best-effort** and
  flagged as a risk.

### 0.3 Relationship to PLAN.md

`PLAN.md` remains the design contract for the product. This plan inherits every
MUST rule from `PLAN.md` sections 12 (security), 13 (LGPD), 10 (budgets), 11
(unstable connections), 7 (architecture), and 15 (hard limits). Where this plan
and `PLAN.md` conflict, the stricter rule wins and the conflict is recorded in
`DECISIONS.md` as an ADR.

### 0.4 Definition of done (parity)

A build is "parity-ready" when all of these hold:

1. Android dev build + Web export both build clean.
2. Device registration, consent, trip start/ping/end, delete-me work against
   the local server (`http://127.0.0.1:8080`) and the staging server.
3. Map renders vehicles for a chosen line on both platforms, with the same
   WebSocket stream updates the Flutter client receives.
4. Timetables and line list render offline from the bundled static data.
5. Passenger reports create/retract and refresh the snapshot.
6. Place search, learned route overlay, stops, and ETA call the learning
   endpoints and render without crashing when disabled (404).
7. Maintenance and forced-update gates work from `config.json`.
8. No coordinates, tokens, session ids, or device ids in logs, URLs, or
   error messages.
9. Budgets in `PLAN.md` 10.1 not regressed knowingly (measured where possible;
   documented where not).

---

## 1. Decisions and constraints (locked)

| # | Decision | Rationale |
|---|----------|-----------|
| D-RN-1 | Expo SDK **58** (RN 0.88, React 19.3, Node 22+) | Current stable line as of 2026-10; matches the research date. Verify before scaffolding (VERIFY). |
| D-RN-2 | **Development builds** (`expo-dev-client`), not Expo Go | `@maplibre/maplibre-react-native` is not in Expo Go; foreground location service needs native config. |
| D-RN-3 | Maps: `@maplibre/maplibre-react-native` on native, `maplibre-gl` + `react-map-gl` on web, behind one component using `.native.tsx` / `.web.tsx` file suffixes | User requirement; no Google deps; no `react-native-maps` (no web support). |
| D-RN-4 | Tile/style source: MapTiler style URL or a self-hosted style; OSM raster fallback acceptable for dev | Avoids Google; respect OSM tile usage policy (no bulk prefetch). |
| D-RN-5 | Storage: `expo-secure-store` on native, `localStorage` fallback on web, behind one module | SecureStore has no web impl (confirmed). |
| D-RN-6 | HTTP: `fetch` (built-in) + a thin typed client; no `axios` | Smaller surface; matches "prefer native runtime". |
| D-RN-7 | Navigation: `expo-router` (file-based) | Standard for Expo; deep links for place search results. |
| D-RN-8 | State: `zustand` for client state; React hooks + `fetch` for server state; no Redux/RTK | Smallest maintainable; avoids heavy boilerplate. ADR required if changed. |
| D-RN-9 | Forms/validation: `zod` at the boundary only (parsing server payloads) | One schema library on the client; mirrors server valibot discipline. |
| D-RN-10 | No TypeScript `any` escape hatches at boundaries; strict mode on | Matches `PLAN.md` 14.2 spirit. |
| D-RN-11 | Location: `expo-location` (foreground) + `expo-task-manager` only if background sharing is validated | See section 8.3 risk. |
| D-RN-12 | WebSocket: native `WebSocket` (browser/RN global) | No extra dep; matches backend `/v1/stream`. |
| D-RN-13 | Offline static data: bundled JSON under `assets/` + AsyncStorage cache + conditional GET via ETag | Mirrors Flutter `StaticData`. |
| D-RN-14 | No background location on web (browsers cannot share while backgrounded) | Documented limitation; web is a viewer + opt-in foreground share. |

---

## 2. Architecture mapping (Flutter -> RN/Expo)

```
Flutter (app/lib)              RN/Expo (rn/)
-----------------------------------------------
core/config/env.dart           src/core/config/env.ts (EXPO_PUBLIC_*)
core/geo/*                     src/core/geo/* (pure TS, no platform)
core/errors/failures.dart      src/core/errors/failures.ts
core/net/backoff.dart          src/core/net/backoff.ts
core/time/clock.dart           src/core/time/clock.ts (injectable)
core/logging/log.ts            src/core/logging/log.ts (no coords API)

data/api/bus_api.dart          src/data/api/busApi.ts
data/api/dto.dart              src/data/api/dto.ts (zod schemas)
data/config/remote_config.dart src/data/config/remoteConfig.ts
data/prefs/*                   src/data/prefs/* (storage wrapper)
data/static_data/*             src/data/static/* (offline-first)
data/realtime/vehicle_repository src/data/realtime/vehicleRepository.ts
data/net/http_client*.dart     src/data/net/httpClient.ts

domain/*                       src/domain/* (pure TS, no I/O, no clock)
features/trip/*                src/features/trip/* (controller + service)
features/map/*                 src/features/map/* (tile source, offline)
platform/*                     src/platform/* (web/android branches)
ui/*                           src/ui/* (simple screens)

app/providers.dart (riverpod)  src/app/providers.ts (zustand stores)
ui/router/app_router.dart      app/ (expo-router file routes)
```

Dependency direction (must hold): `features -> data -> core`; `features` and
`data -> domain`; `domain` imports nothing from RN, Expo, networking, or
storage. Enforced by lint/import rules in `eslint` config (to be added).

### 2.1 State management mapping

| Flutter (riverpod) | RN (zustand) |
|--------------------|--------------|
| `TripController` (singleton) | `useTripStore` (zustand) + `TripService` class |
| `ConsentStore` | `useConsentStore` |
| `TokenStore` | `useTokenStore` (backed by storage wrapper) |
| `RemoteConfigRepository` | `useRemoteConfigStore` |
| `StaticDataRepository` | `useStaticDataStore` |
| `VehicleRepository` (WS) | `useVehicleStore` |
| `LearningRepository` | `useLearningStore` |

One rule: **stores hold state only; services hold logic.** Stores never call
`fetch` directly; services do and then call store setters. This mirrors
`TripController` being the only place that starts/stops the foreground service
and sends pings (PLAN.md 7): in RN, `TripService` is the only place that
starts/stops location tracking and sends pings.

---

## 3. Parity matrix (feature -> module -> priority)

Priority: P0 = must for parity-ready; P1 = should; P2 = nice-to-have.

| Feature | Flutter module | RN module | P |
|---------|----------------|-----------|---|
| Env config (API_BASE_URL, STATIC_BASE_URL) | core/config/env.dart | core/config/env.ts | P0 |
| HTTP client (keep-alive, timeout) | data/net/http_client*.dart | data/net/httpClient.ts | P0 |
| Typed failures | core/errors/failures.dart | core/errors/failures.ts | P0 |
| Device registration (POST /v1/devices) | data/api/bus_api.dart | data/api/busApi.ts | P0 |
| Token storage | data/prefs/token_store.dart | data/prefs/tokenStore.ts | P0 |
| Consent local versioning | data/prefs/consent_store.dart | data/prefs/consentStore.ts | P0 |
| Consent flow (sheet + server record) | features/trip/consent_flow.dart | features/trip/consentFlow.ts | P0 |
| POST/DELETE /v1/consents | data/api/bus_api.dart | data/api/busApi.ts | P0 |
| DELETE /v1/me (delete my data) | BusApi.deleteMe | busApi.deleteMe | P0 |
| DELETE /v1/me/learning | BusApi | busApi | P1 |
| Static lines manifest + conditional GET | data/static_data/static_data.dart | data/static/staticData.ts | P0 |
| Timetables offline | StaticLine.schedules | static/staticData.ts | P0 |
| Line list UI | ui/features/lines | ui/screens/Lines | P0 |
| Line detail + map | ui/features/line | ui/screens/LineDetail | P0 |
| Live lines indicator | getLive | busApi.getLive | P1 |
| Start trip | TripController + BusApi.startTrip | features/trip/tripService.ts | P0 |
| Ping loop with server interval | TripController | tripService.ts | P0 |
| End trip | BusApi.endTrip | busApi.endTrip | P0 |
| Auto-end (idle/timeout) | domain/trip/auto_end.dart | domain/trip/autoEnd.ts | P1 |
| GPS sampling policy | domain/trip/sampling_policy.dart | domain/trip/samplingPolicy.ts | P1 |
| Foreground service (Android) | platform + TripController | see 8.3 | P1 (risk) |
| Permissions (location) | permission_handler | expo-location | P0 |
| Permission sheet UI | features/trip/permission_sheet.dart | ui/components/PermissionSheet.tsx | P0 |
| Map (vehicles) native | flutter_map | MapLibre native | P0 |
| Map (vehicles) web | flutter_map | MapLibre GL JS | P0 |
| Vehicle snapshot (GET /v1/lines/:id/vehicles) | BusApi.getVehicles | busApi.getVehicles | P0 |
| ETag conditional GET + cache | BusApi | busApi | P0 |
| WebSocket stream (/v1/stream) | vehicle_repository | data/realtime/vehicleRepository.ts | P0 |
| Reports (POST /v1/reports) | report_actions | features/reports/reportActions.ts | P1 |
| Reports in snapshot | parseReports | dto parseReports | P1 |
| Arrivals (GET /v1/lines/:id/arrivals) | getArrivals | busApi.getArrivals | P1 |
| Place search | search/* | features/search/* | P1 |
| Learned route (GET .../learned-route) | learning_repository | data/learning/learningRepository.ts | P1 |
| Learned stops | learning_repository | learningRepository.ts | P1 |
| ETA | learning_repository | learningRepository.ts | P1 |
| Learned routes bulk (place search) | learning_repository | learningRepository.ts | P1 |
| Remote config (config.json) | RemoteConfigRepository | data/config/remoteConfig.ts | P0 |
| Maintenance/forced-update gates | home providers | app gates | P0 |
| Diagnostics upload | diagnostics_uploader | data/diagnostics/diagnosticsUploader.ts | P2 |
| Theme store | data/prefs/theme_store.dart | data/prefs/themeStore.ts | P2 |
| Settings/privacy screens | ui/features/settings | ui/screens/Settings | P1 |
| About screen | about_screen | ui/screens/About | P2 |
| Android app download row | platform/web/android_app_download | platform/web/androidAppDownload.ts | P2 |
| Wake lock (web) | platform/web/wake_lock.dart | platform/web/wakeLock.ts | P2 |
| Visibility handling (web) | platform/web/visibility.dart | platform/web/visibility.ts | P1 |
| Backoff | core/net/backoff.dart | core/net/backoff.ts | P0 |
| Clock injection | core/time/clock.dart | core/time/clock.ts | P0 |

---

## 4. Backend contract (unchanged)

The client MUST implement these endpoints exactly. No new endpoints. Source of
truth: `server/src/http/*.ts` and `PLAN.md` 6.5.

### 4.1 Base URLs

- `API_BASE_URL` (e.g. `http://127.0.0.1:8080` or `https://api-pontual.spotnik.space`).
- `STATIC_BASE_URL` (e.g. `http://127.0.0.1:8080/data` or
  `https://pontual.spotnik.space/data`).
- Both come from `EXPO_PUBLIC_API_BASE_URL` / `EXPO_PUBLIC_STATIC_BASE_URL`
  env vars baked at build time (Expo convention), with dev defaults pointing
  at localhost.

### 4.2 Endpoints

| Method | Path | Auth | Body/Query | Response |
|--------|------|------|------------|----------|
| GET | /v1/health | none | - | `{ok:true}` |
| POST | /v1/devices | none | `{}` | `{token, exp, id}` (201) |
| POST | /v1/consents | Bearer | `{version}` | `{ok:true}` or 403 `consent` |
| DELETE | /v1/consents | Bearer | - | 204 |
| DELETE | /v1/me | Bearer | - | 204 |
| DELETE | /v1/me/learning | Bearer | - | 204 |
| POST | /v1/trip | Bearer | `{line, lat, lng, acc, bat, chg, resume?}` | `{r, n}` (201) or 404/422/503 |
| POST | /v1/trip/ping | Bearer | `{seq, lat, lng, spd, hdg, acc, bat, chg, role}` | `{r, n}` or `{r, n, e}` |
| DELETE | /v1/trip | Bearer | - | 204 |
| GET | /v1/lines/:id/vehicles | none | If-None-Match | `{t, v, r}` or 304 |
| GET | /v1/live | none | - | `[[lineId, count], ...]` |
| GET | /v1/lines/:id/arrivals | none | - | `{t, line, passages, headwayMin, sampleSize}` |
| GET | /v1/stream | WS upgrade | first msg: line id (number) | `{l, t, v, r}` |
| POST | /v1/reports | Bearer | `{op, kind, line, area?}` | `{r: [...]}` |
| GET | /v1/lines/:id/learned-route | none | - | `{v, dir, polyline, points, trips, computed_at, fallback}` |
| GET | /v1/lines/:id/stops | none | - | `{dir, stops:[{id,i,lat,lng,r,n}], fallback}` |
| GET | /v1/lines/:id/eta | none | `?stop=&vehicle=` | `{stop, now, items:[{vehicle, eta_s, conf, n}], next_scheduled_s}` |
| GET | /v1/learned-routes | none | `?bbox=` | `{v, routes:[...]}` |
| POST | /v1/diagnostics | Bearer | redacted bundle | 204/4xx |

### 4.3 WebSocket protocol

- Endpoint `/v1/stream`, upgrade required, Origin must be in allowed list.
- Client sends one message: a JSON number (line id) or a number as text.
  (Hub expects a line id; see `server/src/ws/hub.ts` - VERIFY exact parse.)
- Server replies with `{l, t, v, r}` snapshots on subscribe and on broadcast.
- Client sends no further messages; server pushes. On close, reconnect with
  backoff.
- Rate/capacity: 503 with Retry-After on capacity; client honors Retry-After.

### 4.4 Static data contract

- `GET {STATIC_BASE_URL}/manifest.json` returns `{version, files:[...]}` with
  ETag. Conditional GET supported.
- Files: `lines/*.json`, `routes/*`, `stops.json`, `config.json`, `places.json`
  (VERIFY exact manifest schema by reading `tools/` data-build output).
- `config.json` fields: `min_app_version`, `maintenance`, `message_pt`,
  `consent_version`, `tile_url`.
- Bundled copy shipped in app assets so first frame never waits on network.

### 4.5 Error code mapping

Server returns `{e: code}` or `{code}`. Client maps:

| Code | Meaning | Client action |
|------|---------|---------------|
| `rate` / 429 | rate limited | honor Retry-After, back off |
| `maint` / 503 | service disabled | show maintenance screen |
| `blocked` / 403 | device blocked | show blocked message, stop sharing |
| `consent` / 403 | consent mismatch | clear posted, re-run consent flow |
| `line` / 404 | unknown/inactive line | drop line, refresh static data |
| `area` / 422 | outside service area | show area error |
| `capacity` / 503 | too many active trips | retry with backoff |
| `quota` / 429 | trip quota | retry later |
| `gone` / 404 (ping) | trip ended server-side | stop sharing, reset state |
| `end` (in ping body) | trip auto-ended | stop sharing, show reason |
| `media` / 415 | wrong content type | client bug |
| `bad_request` / 400 | validation failed | client bug |
| `auth` / 403 (stream) | origin not allowed | config error |
| `capacity` / 503 (stream) | WS capacity | retry with backoff |

---

## 5. Project skeleton

Create a new top-level directory `rn/` (or a separate repo). Recommended:
keep in same repo under `rn/` for shared CI, but it is an independent app.

```
rn/
  app.json                 # Expo config (plugins, permissions, bundle id)
  app.config.ts            # dynamic config (env)
  package.json
  tsconfig.json            # strict
  eslint.config.js
  metro.config.js          # asset extensions for json/geojson
  babel.config.js
  .env.example
  assets/
    data/                  # bundled static data (copy from app/assets/data)
    fonts/
  src/
    app/                   # expo-router routes
      _layout.tsx
      index.tsx            # home / line list
      line/[id].tsx
      trip.tsx
      settings.tsx
      privacy.tsx
    core/
      config/env.ts
      errors/failures.ts
      geo/geo.ts
      geo/routeProximity.ts
      logging/log.ts
      net/backoff.ts
      time/clock.ts
    data/
      api/busApi.ts
      api/dto.ts (zod)
      config/remoteConfig.ts
      net/httpClient.ts
      prefs/consentStore.ts
      prefs/tokenStore.ts
      prefs/themeStore.ts
      prefs/storage.ts     # platform-agnostic storage wrapper
      static/staticData.ts
      realtime/vehicleRepository.ts
      learning/learningRepository.ts
      diagnostics/diagnosticsUploader.ts
    domain/
      trip/tripState.ts
      trip/autoEnd.ts
      trip/samplingPolicy.ts
      trip/sharePhases.ts
      reporting/reportKind.ts
      reporting/reportArea.ts
      learning/*.ts
      schedule.ts
      lineCategory.ts
    features/
      trip/tripService.ts
      trip/consentFlow.ts
      trip/locationService.ts
      trip/pingClient.ts
      trip/permissionGateway.ts
      reports/reportActions.ts
      search/placeSearch.ts
      map/tileSource.ts
      map/offlineMap.ts
    platform/
      android/permissionGateway.ts
      web/visibility.ts
      web/wakeLock.ts
      web/androidAppDownload.ts
      web/userAgent.ts
    ui/
      components/Map.tsx          # platform dispatcher (see 7)
      components/Map.native.tsx    # MapLibre native
      components/Map.web.tsx      # MapLibre GL JS
      ... simple components
    app/providers.ts             # zustand stores
  plugins/                       # local expo config plugins if needed
  e2e/                           # detox/maestro later (P2)
```

Routing with expo-router: file names under `src/app/` (configure `app` dir in
`app.json` `expo.router.appDir`).

---

## 6. Dependency allow-list

All versions VERIFY against npm at scaffolding time. Use `npx expo install` to
align to SDK 58.

Core:
- `expo` ~58.0.0
- `react`, `react-dom`, `react-native`
- `expo-router`
- `expo-status-bar`, `expo-splash-screen`, `expo-constants`
- `expo-location` (foreground; background only if validated)
- `expo-secure-store`
- `expo-task-manager` (only if background sharing validated)
- `expo-asset`, `expo-file-system` (for bundled static data + cache)
- `expo-network` (connectivity state, optional)
- `@react-native-async-storage/async-storage`
- `zustand`
- `zod`
- `react-native-safe-area-context`, `react-native-screens`
- `react-native-gesture-handler`, `react-native-reanimated`
- `react-native-webview` (only if needed for privacy policy link; prefer Linking)

Maps:
- `@maplibre/maplibre-react-native` (peer: expo >=54, RN >=0.80)
- `maplibre-gl`
- `react-map-gl` (or `@vis.gl/react-maplibre`)

Utils:
- `date-fns`? Prefer native `Intl`/`Date`. Avoid unless needed.
- `pako`? Only if static data is gzipped (VERIFY).

Forbidden (PLAN.md 15 + parity): analytics, crash reporting, ads, Firebase,
local DB (SQLite/Realm/Watermelon), code generation, `react-native-maps`,
Mapbox SDK (paid/ToS), Google Maps.

---

## 7. Map component (the key platform split)

User requirement: `@maplibre/maplibre-react-native` on native, `maplibre-gl`
on web, behind a small shared component with `.native.tsx` / `.web.tsx`.

### 7.1 File layout

```
src/ui/components/
  Map.tsx            # shared props interface + platform-agnostic helpers
  Map.native.tsx     # imports @maplibre/maplibre-react-native ONLY
  Map.web.tsx        # imports maplibre-gl + react-map-gl ONLY
```

Metro/Expo resolves `.native.tsx` on iOS/Android and `.web.tsx` on web
automatically. **Never import a native-only module in `Map.tsx` or any shared
file**, or web breaks (confirmed by maplibre issue #414).

### 7.2 Shared props (minimal)

```ts
// Map.tsx
export interface MapMarker { id: string; lat: number; lng: number; }
export interface MapProps {
  styleUrl: string;
  initialCenter: { lat: number; lng: number };
  initialZoom: number;
  markers: MapMarker[];
  onMapReady?: () => void;
  onMarkerPress?: (id: string) => void;
  // camera control is internal per platform; expose a ref handle instead
}
```

### 7.3 Native implementation sketch

```tsx
// Map.native.tsx
import MapLibreGL from "@maplibre/maplibre-react-native";
import { MapView, Camera, PointAnnotation } from "@maplibre/maplibre-react-native";
// ...
export function Map(props: MapProps) {
  MapLibreGL.setAccessToken(null);
  return (
    <MapView style={{flex:1}} styleURL={props.styleUrl}>
      <Camera centerCoordinate={[props.initialCenter.lng, props.initialCenter.lat]}
              zoomLevel={props.initialZoom} animationDuration={0} />
      {props.markers.map(m => (
        <PointAnnotation key={m.id} id={m.id} coordinate={[m.lng, m.lat]} />
      ))}
    </MapView>
  );
}
```

### 7.4 Web implementation sketch

```tsx
// Map.web.tsx
import "maplibre-gl/dist/maplibre-gl.css";
import Map, { Marker } from "react-map-gl/maplibre";
import { setWorkerUrl } from "maplibre-gl";
// worker url setup (see 7.5)
export function Map(props: MapProps) {
  return (
    <Map initialViewState={{latitude: props.initialCenter.lat,
                            longitude: props.initialCenter.lng,
                            zoom: props.initialZoom}}
         style={{width:"100%", height:"100%"}}
         mapStyle={props.styleUrl}>
      {props.markers.map(m => (
        <Marker key={m.id} longitude={m.lng} latitude={m.lat} />
      ))}
    </Map>
  );
}
```

### 7.5 MapLibre web worker (critical)

MapLibre GL JS v6 ships its worker as a separate file and resolves it relative
to its own module, which breaks under Expo/Metro bundling (blank map, no
error). Fix:

```ts
// src/features/map/maplibreWorker.ts (web only)
import { setWorkerUrl } from "maplibre-gl";
import workerUrl from "maplibre-gl/dist/maplibre-gl-worker.mjs?worker&url";
setWorkerUrl(workerUrl);
```

Import this module once before any Map renders (e.g. in `src/app/_layout.tsx`
guarded by `Platform.OS === 'web'`). Additionally, a `postinstall` script
copies the worker and its transitive chunks into the served folder; if the
copy fails, install fails loudly.

### 7.6 Style URL

- Dev: MapLibre demo tiles (`https://demotiles.maplibre.org/style.json`) or a
  MapTiler key from `EXPO_PUBLIC_MAPTILER_KEY`.
- Prod: prefer a self-hosted style + OSM raster tiles served from the static
  bundle host, respecting OSM tile usage policy (no bulk prefetch, attribution
  visible). Tile URL may come from `config.json` `tile_url` (VERIFY whether
  the Flutter client uses it; `RemoteConfig.tileUrl` exists).

### 7.7 Vehicle markers

Render one marker per vehicle from the snapshot `v` array
`[id, lat, lng, heading, kmh, n, ageS, paceKmh?]`. Use a simple colored dot +
heading arrow. No clustering in v1 (marker cap from PLAN.md 10.1; degrade
gracefully if > cap by sampling).

---

## 8. Location, permissions, and sharing

### 8.1 Permissions

- Use `expo-location`: `requestForegroundPermissionsAsync` first, then
  `requestBackgroundPermissionsAsync` only if background sharing is validated.
- On Android 11+, background permission opens system settings; show rationale
  modal first (PLAN.md UX).
- On iOS, request "When In Use" first; "Always" only after explaining.
- Permission state persisted by OS; app re-checks on foreground via
  `AppState`.

### 8.2 Foreground location sampling

- `Location.watchPositionAsync` with `accuracy: Location.Accuracy.BestForNavigation`
  (or High), `timeInterval` and `distanceInterval` from sampling policy.
- Feed fixes into `TripService`, which calls `BusApi.pingTrip` at the server-
  instructed interval `n`.
- Client never sends timestamps; server stamps.

### 8.3 Background sharing (RISK)

Flutter uses a foreground service (Android) to keep sharing while the screen is
off. React Native options:

- `expo-location` background updates via `expo-task-manager` require
  `ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`,
  `RECEIVE_BOOT_COMPLETED`, `POST_NOTIFICATIONS` (added by config plugin when
  `isAndroidBackgroundLocationEnabled: true`).
- Background delivery on Android is throttled by the OS (a few times/hour when
  the app process has ended) - **this is materially worse** than a foreground
  service. This is the single biggest functional risk of the RN port.
- iOS background location works only with "Always" permission and a declared
  background mode; delivery continues while backgrounded.

Decision: Phase 1 ships **foreground-only sharing** (screen must stay on or
app in foreground). Phase 2 evaluates a **custom native module** or
`react-native-background-actions` / `expo-background-fetch` to restore
foreground-service parity. Record as ADR + known limitation (KL) if not
achieved. **Do not** request `ACCESS_BACKGROUND_LOCATION` in the first Play
build without a clear justification (PLAN.md 15 hard limit; Google Play review).

### 8.4 TripService (single owner of sharing)

Mirrors `TripController`:

- `start(lineId, firstFix)` -> ensure registered -> ensure consent -> POST
  /v1/trip -> store role/interval -> start location watch + ping loop.
- `ping(fix)` -> POST /v1/trip/ping -> update role/interval; handle `e`/`gone`.
- `end()` -> DELETE /v1/trip -> stop watch + loop -> reset state.
- Auto-end on idle/timeout/abuse per `domain/trip/autoEnd.ts`.
- On app background/foreground, adjust sampling (PLAN.md 10/11).
- On network failure, backoff and retry; never lose the "end" intent.

### 8.5 Consent flow

Port `ensureConsent` exactly:

1. If local accepted version != currentVersion, show sheet.
2. If declined, abort.
3. Write local acceptance.
4. If server-posted version != currentVersion, POST /v1/consents.
5. On success mark posted; on failure return `offlinePending` and retry before
   trip start.

Current version comes from `RemoteConfig.consentVersion` (from `config.json`),
with bundled fallback.

---

## 9. Auth and token storage

- Token is an opaque 256-bit string from `POST /v1/devices`, stored via
  `expo-secure-store` on native, `localStorage` on web (dev convenience only;
  production web should use HTTP-only cookie - but backend has no cookie
  support, so document as limitation).
- Storage wrapper (`src/data/prefs/storage.ts`):

```ts
export const storage = {
  async get(key): Promise<string | null> {
    if (Platform.OS === "web") return globalThis.localStorage?.getItem(key) ?? null;
    return SecureStore.getItemAsync(key);
  },
  async set(key, value) { ... },
  async remove(key) { ... },
};
```

- Token sent as `Authorization: Bearer <token>` only, never in URLs.
- `_cachedToken` in-memory cache; read from storage on first use.
- Registration happens on demand when sharing starts, never at startup
  (PLAN.md 8.4).

---

## 10. Static data (offline-first)

Port `StaticData` repository semantics:

1. Bundle `assets/data/*` into the app (Metro asset).
2. On first launch, load bundled manifest + files into AsyncStorage cache.
3. `current()` returns cached if present else bundled; never throws; never
   blocks first frame.
4. `refresh()` at most once per 24h: GET manifest with If-None-Match; on 200,
   download changed files, validate, atomically swap cache; on 304 do nothing;
   on failure keep old.
5. ETag case-insensitive lookup.
6. Lines with `is_active: false` hidden but kept (ids never reused).

Validation: parse with zod; on malformed file, keep previous (never crash).

---

## 11. Realtime (WebSocket + HTTP)

### 11.1 Vehicle repository

- Per-line WebSocket to `/v1/stream`. Subscribe by sending line id.
- On message, parse `{l, t, v, r}`, update `useVehicleStore`.
- Reconnect with exponential backoff + jitter; respect 503 Retry-After.
- Fall back to HTTP polling `GET /v1/lines/:id/vehicles` every 5s if WS fails
  repeatedly (PLAN.md 11 unstable connections).
- On app background, close WS to save battery; reopen on foreground.

### 11.2 HTTP polling (vehicles)

- ETag conditional GET; serve cached on 304.
- 5s cache-control max-age respected via client-side throttle.

---

## 12. Reports, learning, arrivals

- Reports: `POST /v1/reports` with `{op, kind, line, area?}`. area is a
  coarse ~150m grid cell string (port `reportArea.ts` hashing). Refresh line
  snapshot on success.
- Learning endpoints are optional: treat 404 as "disabled", hide UI.
- ETA requires a selected stop; render only when learned route exists.
- Place search: reuse `search_index` logic ported to TS; learned routes bulk
  endpoint for overlays.

---

## 13. UI (simple)

Screens (expo-router):

- `/` Home: line list (search + favorites), live indicator, maintenance gate.
- `/line/[id]`: map + timetable + arrivals + reports strip.
- `/trip`: sharing status, metrics, end button (forced ping button behind env).
- `/settings`: privacy actions (delete data, revoke consent, opt-out learning),
  about, download Android app row (web only).
- `/privacy`: privacy policy text.

Components: use React Native primitives + a minimal style. No design system
port. One `Map` component (platform split). Bottom sheets via a simple modal.

---

## 14. Theming, i18n

- Strings in pt-BR only for user-visible text; code/comments/logs in English.
- No em dashes in any string.
- Theme: light/dark via `useColorScheme`; minimal tokens.

---

## 15. Networking, errors, backoff

- Single `httpClient.ts` with keep-alive (`fetch` default), timeout 15s,
  retry on network errors with exponential backoff + jitter (port backoff.ts).
- Typed result: `Result<T> = {ok:true, value} | {ok:false, failure}`.
- Failure types: `NetworkFailure`, `ServerFailure(code)`, `ValidationFailure`.
- Never log request bodies, tokens, or coordinates. Log only method, route,
  status, duration, requestId.

---

## 16. Battery and budgets

Inherit PLAN.md 10.1 budgets. RN-specific notes:

- Hermes engine default (Expo) -> good startup/memory.
- Avoid re-renders: memoize vehicle markers; use `React.memo`.
- WS closed on background; location watch stopped on end.
- No wake lock on web except while sharing (port wake_lock, optional).
- Measure bundle size (`expo export` output) and Android APK/AAB size; document.

---

## 17. Security/privacy compliance

- No new fields, logs, metrics, or third-party calls with personal data.
- Token only in secure storage; never in URLs or logs.
- Coordinates never logged (Log wrapper has no coordinate API).
- Delete-my-data calls `DELETE /v1/me` and clears local storage + caches.
- Consent version from server (via config); never hardcode a higher version.
- No background location without explicit owner approval (ADR).
- Secret scan (gitleaks) on PRs; no `.env` committed.

---

## 18. Testing strategy

- Unit tests: `jest` + `@testing-library/react-native` for pure logic (geo,
  backoff, dto parsing, consent flow, sampling policy, report area).
- Integration: against local server (same as Flutter api_test) using
  `BUS_API_BASE` env.
- E2E: Maestro or Detox (P2).
- Security tests: manual checklist mirroring PLAN.md 12.6 (auth boundaries,
  malformed input, ownership, no location at rest).
- `no_location_at_rest` check: grep codebase for coordinate persistence in
  RN storage calls.

Commands:
- `npm test` (jest)
- `npx tsc --noEmit`
- `npx expo export --platform web`
- `npx expo run:android` (dev build)

---

## 19. Build, CI, EAS

- EAS Build for Android dev/preview/production profiles.
- Web export to GitHub Pages or Cloudflare Pages (separate from Flutter PWA
  initially).
- CI: typecheck + lint + unit tests + web export smoke.
- Env: `EXPO_PUBLIC_API_BASE_URL`, `EXPO_PUBLIC_STATIC_BASE_URL`,
  `EXPO_PUBLIC_MAPTILER_KEY`, `EXPO_PUBLIC_APP_VERSION`.

---

## 20. Phases and tasks (atomic)

### Phase 0 - Spike (1 task)
- S-RN-0: scaffold Expo SDK 58 project, install MapLibre native+web, render a
  map on both platforms with a marker. Verify Metro worker fix. Record versions
  in DECISIONS.md.

### Phase 1 - Core parity (P0) - 12 tasks
1. T-RN-1: env + http client + typed failures + backoff + clock + log.
2. T-RN-2: storage wrapper (secure store / localStorage) + token store.
3. T-RN-3: device registration + BusApi (start/ping/end/delete/revoke).
4. T-RN-4: consent store + consent flow + sheet.
5. T-RN-5: static data offline-first (manifest, lines, routes, config).
6. T-RN-6: remote config + maintenance/forced-update gates.
7. T-RN-7: location service + permission gateway + permission sheet.
8. T-RN-8: TripService (start/ping/end/auto-end).
9. T-RN-9: Map component platform split + vehicle markers.
10. T-RN-10: line list + line detail screens (simple UI).
11. T-RN-11: WebSocket vehicle repository + fallback polling.
12. T-RN-12: trip screen + sharing metrics + end control.

### Phase 2 - Extended parity (P1) - 8 tasks
13. T-RN-13: reports create/retract + snapshot refresh.
14. T-RN-14: arrivals + history card.
15. T-RN-15: place search + search screen.
16. T-RN-16: learning repository + learned route/stops/eta overlay.
17. T-RN-17: learned routes bulk + map overlay.
18. T-RN-18: settings/privacy screens + delete-my-data + opt-out.
19. T-RN-19: web visibility/wake-lock handling + background/foreground.
20. T-RN-20: live lines indicator.

### Phase 3 - Hardening (P2) - 4 tasks
21. T-RN-21: diagnostics uploader.
22. T-RN-22: Android app download row (web).
23. T-RN-23: EAS profiles + CI + secret scan.
24. T-RN-24: Maestro E2E smoke (Android + web).

### Phase 4 - Evaluation
25. T-RN-25: side-by-side field test vs Flutter; record findings in
    DECISIONS.md; decide whether to migrate.

Each task: one change set, acceptance criteria pass before next.

---

## 21. Risks and known limitations

1. **Background sharing degradation** (high): RN background location is
   throttled by OS; no true foreground service without native module. May
   require a custom native module or accepting foreground-only sharing.
2. **MapLibre web worker** (medium): blank map if worker URL not set; must
   follow section 7.5 exactly.
3. **Secure storage on web** (medium): `localStorage` is not secure; document
   as dev-only limitation. Production web tokens are exposed to XSS.
4. **Bundle size / startup** (medium): RN + MapLibre native increases app
   size; measure against PLAN.md 10.1.
5. **Expo SDK version drift** (low): versions move fast; pin and verify.
6. **No Expo Go** (low): requires dev builds; slower iteration.
7. **iOS not in scope** (low): can add later.
8. **Static data bundle sync** (low): must copy `app/assets/data` into
   `rn/assets/data` on each data build; automate in CI.

---

## 22. Owner decisions required before Phase 0

1. Repo layout: `rn/` inside this repo vs separate repo.
2. Android `applicationId` for the RN build (suggest `app.pontual.rn` or reuse
   `com.spotnik.pontual`? Reusing would conflict with Flutter installs - recommend
   distinct id for testing).
3. Map style provider (MapTiler key budget vs self-hosted OSM).
4. Background sharing scope: foreground-only acceptable for evaluation, or
   invest in native module?
5. Web production hosting (GitHub Pages vs Cloudflare Pages).
6. Whether to keep both clients long-term or migrate fully.

---

## 23. Verification checklist (per release)

- [ ] `npx tsc --noEmit` clean
- [ ] `npm test` green
- [ ] `npx expo export --platform web` succeeds
- [ ] Android dev build installs and launches
- [ ] Map renders on both platforms with vehicle markers
- [ ] Trip start/ping/end round-trips against local server
- [ ] Delete-my-data clears storage
- [ ] No coordinates/tokens in logs (grep)
- [ ] gitleaks clean
- [ ] Budgets measured or documented as not measured

---

## 24. References

- PLAN.md (design contract), DECISIONS.md (ADRs), AGENTS.md (agent rules).
- Expo docs: SDK 58, Location, SecureStore, TaskManager, Web.
- MapLibre React Native: expo setup, v11 migration.
- GreenAsh guide: MapLibre native + web in Expo.
- Expo OSM SDK web setup guide (worker handling).
- Flutter client modules listed in section 3 (source of truth for logic).

---

## Appendix A - zod DTO sketch (busApi)

```ts
import { z } from "zod";

export const TripInstructionSchema = z.object({
  r: z.string(),
  n: z.number().int(),
  e: z.string().optional(),
});

export const VehiclesSnapshotSchema = z.object({
  t: z.number().int(),
  v: z.array(z.array(z.number().nullable())),
  r: z.array(z.object({
    kind: z.string(),
    area: z.string().nullable().optional(),
    count: z.number().int(),
    created_age_s: z.number().int(),
    updated_age_s: z.number().int(),
    expires_in_s: z.number().int(),
  })).optional().default([]),
});

export const ArrivalsPayloadSchema = z.object({
  t: z.number().int().optional().default(0),
  line: z.number().int().optional().default(0),
  passages: z.array(z.number()).optional().default([]),
  headwayMin: z.number().nullable().optional().default(null),
  sampleSize: z.number().int().optional().default(0),
});

export const LiveLinesSchema = z.array(z.tuple([z.number().int(), z.number().int()]));

export const RemoteConfigSchema = z.object({
  min_app_version: z.string(),
  maintenance: z.boolean(),
  message_pt: z.string(),
  consent_version: z.number().int(),
  tile_url: z.string(),
});
```

## Appendix B - storage wrapper (full)

```ts
import * as SecureStore from "expo-secure-store";
import { Platform } from "react-native";

const isWeb = Platform.OS === "web";

export async function getItem(key: string): Promise<string | null> {
  if (isWeb) return globalThis.localStorage?.getItem(key) ?? null;
  return SecureStore.getItemAsync(key);
}
export async function setItem(key: string, value: string): Promise<void> {
  if (isWeb) { globalThis.localStorage?.setItem(key, value); return; }
  await SecureStore.setItemAsync(key, value);
}
export async function removeItem(key: string): Promise<void> {
  if (isWeb) { globalThis.localStorage?.removeItem(key); return; }
  await SecureStore.deleteItemAsync(key);
}
```

## Appendix C - backoff (port)

```ts
export function backoffMs(attempt: number, baseMs = 500, capMs = 30000): number {
  const exp = Math.min(capMs, baseMs * 2 ** attempt);
  const jitter = Math.random() * 0.3 * exp;
  return Math.round(exp + (Math.random() < 0.5 ? -jitter : jitter));
}
```

---

End of plan.
