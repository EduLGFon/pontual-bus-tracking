# Search by place (lines that pass through a searched location)

Status: implemented in 0.3.x. Client search extension plus one server read endpoint (`GET /v1/learned-routes?bbox=`), built on top of the learning subsystem (learned routes and stops). Trip sharing, location handling and the privacy contract are unchanged.

Companions: PLAN.md, docs/data-learning.md, docs/ui/UI_SPEC.md section 7.3, DECISIONS.md (D20).

## 1. Goal

Extend the Busca screen so typing a place name (for example "Ufes") returns every line whose learned path passes through or near that place, including lines that do not name it in code/terminals. Example: "Ufes" should list 66 (Centro), 62 (Guriri), 64 (Villages), 60 (Litoraneo), and any other line whose learned route comes within the match radius of UFES.

Search stays instant and offline on the client. Learning subsystem is source of truth for "where each bus passes through" (docs/data-learning.md); search only consumes published aggregates.

## 2. Non-goals

- No turn-by-turn routing or point-to-point navigation (PLAN.md 1.2).
- No geocoding of arbitrary addresses. Place resolution uses a curated, bundled gazetteer of public landmarks and neighbourhoods only.
- No per-user location. User types a name; no device position used or sent.
- No change to existing line-name/code/terminal search; new kind is an additional group.

## 3. Data sources

1. Learned routes and stops (docs/data-learning.md 8.1, 8.2): encoded polyline plus stop centroids per line/direction, de-identified aggregates with minimum sample count.
2. Gazetteer: bundled JSON list of public places in Sao Mateus (landmarks, institutions, neighbourhoods, terminals) with name, aliases, lat, lng. Curated by owner; no personal data.

Client never sends the query to the server. Place resolution is local against the gazetteer; only public landmark coordinates are used for matching.

## 4. Matching rule

A line is a result for a place when, for at least one direction:
- minimum distance from place coordinate to any segment of the learned polyline <= `placeMatchRadiusM` (default 500 m), or
- at least one learned stop centroid within `placeStopRadiusM` (default 300 m) of the place coordinate.

Defaults are client fallback constants, not server config in v1 (matching is client-side presentation). If later tuning needed remotely, add keys to `app_config` and treat client values as fallbacks (PLAN.md 7).

Lines without learned data for any direction do not appear in place results, even if static terminals mention the place.

## 5. Server changes

5.1 Consumer methods (server/src/learning/consumer.ts): `allLearnedRoutes(): LearnedRoute[]` (active learned route for every line, both directions); `allLearnedStops(): Map<number, LearnedStop[]>` keyed by line id. Read from in-process cache/DB via existing repositories, never per-row PostgreSQL on request path. If subsystem disabled, return empty collections.

5.2 Bulk read endpoint `GET /v1/learned-routes` (server/src/http/readRoutes.ts):

```json
{
  "v": 1,
  "routes": [
    { "line": 66, "code": "66-centro-ifes-ufes", "dir": 0, "polyline": "_p~iF~ps|U...", "stops": [ { "id": "uuid", "i": 0, "lat": -18.72, "lng": -39.85, "r": 30, "n": 41 } ] }
  ]
}
```

Rules:
- Public read, no auth, consistent with vehicle reads (PLAN.md 6.5).
- Optional `bbox=latMin,lngMin,latMax,lngMax` query: returns only lines whose learned route intersects the box (segment or stop within box). Absent returns all. Keeps payload small on larger deployments; small-city default unaffected.
- 404 `{ "e": "not_found" }` when learning subsystem disabled, so client treats "no data" uniformly.
- Rate limit 60/min/IP (reuse existing `learningPerIp` limiter or dedicated).
- `Cache-Control: public, max-age=300` and `ETag` based on max learned-route version and latest `updated_at`.
- Returns only line ids, codes, polylines, stop centroids. No device, trip, session, or rider data; no coordinates other than published aggregates.
- Size: if payload exceeds ~256 KB, split into existing per-line endpoints only; for alpha dataset single endpoint expected small.

5.3 Tests: server/test read+security: 404 when disabled; rate limit; ETag; no personal fields; only active lines; empty array when no aggregates. Extend `no_location_at_rest` to assert bulk payload contains no coordinate outside published stop centroids and polylines.

## 6. Client changes

6.1 Gazetteer asset: add `data/places.json` (source of truth) and ship as `app/assets/data/places.json` via data build tool, with schema `data/schema/places.schema.json`. Entry shape:

```json
{ "id": "ufes", "name": "UFES", "aliases": ["universidade federal do espirito santo", "campus goiabeiras"], "lat": -20.27, "lng": -40.30 }
```

Data tool validates and copies into bundle, mirroring lines/stops. Small (tens of entries), versioned with data bundle.

6.2 Domain model: `app/lib/domain/learning/place.dart` (pure Dart): `Place` with `id`, `name`, `aliases`, `lat`, `lng`; `Place.fromJson`.

6.3 Repository: extend `LearningRepository` (`app/lib/data/learning/learning_repository.dart`): `fetchLearnedRoutesIndex()` returning `Result<LearnedRoutesIndex>` where `LearnedRoutesIndex` is `Map<int, LearnedRouteEntry>` with decoded polyline points and stops per line. Reuse existing HTTP client/base URL, 8 s timeout. On 404 or failure, return empty index (not error), so place search degrades to "no results" instead of surfacing failure.

6.4 Index provider: `app/lib/app/providers.dart`: `learnedRoutesIndexProvider` as `FutureProvider<LearnedRoutesIndex>` calling `fetchLearnedRoutesIndex()` once, kept for app lifetime (not auto-dispose), so search screen and line map share one fetch.

6.5 Gazetteer provider: `app/lib/data/static_data/places.dart` (or adapter) loading `assets/data/places.json` into `List<Place>`, exposed as `placesProvider`. Empty list on any failure, mirroring `stopsProvider`.

6.6 Proximity helper: `app/lib/core/geo/route_proximity.dart` (pure, unit-testable): `minDistanceM(LatLng point, List<LatLng> polyline)` returning minimum distance in meters from point to any segment, or infinity for polyline with fewer than two points; `linePassesNear(place, entry, radiusM, stopRadiusM)` implementing section 4 rule.

6.7 Place search provider: `app/lib/ui/features/search/place_search.dart`: `PlaceSearchProvider implements SearchProvider`, constructed with gazetteer and loaded index (or empty index while loading). `search(query)`: normalise query; find gazetteer entries whose name or any alias contains query (tokenised AND match, reusing `matchesAllTokens`); for each matched place find lines passing near; deduplicate by line key keeping smallest distance; sort by distance then line name; return `_PlaceHit` carrying line and matched place name. `row` renders existing line row plus caption "Passa por <place>" (pt-BR). Because `SearchProvider.search` is synchronous, provider holds already-loaded index; while loading, place search returns empty list and UI shows line group only.

6.8 Search screen wiring: `app/lib/ui/features/search/search_screen.dart`: `_searchGroupsProvider` watches `placesProvider` and `learnedRoutesIndexProvider`; when index data available, append `_PlaceSearchProvider` to providers list; group header only when more than one kind (already handled).

6.9 Strings: `app/lib/ui/strings/ui_strings.dart`: `searchPlaces` = "Linhas que passam por"; `searchPlacePassesBy` = "Passa por {place}" (or helper); `searchHint` remains "Buscar linha ou bairro" (optionally "Buscar linha, bairro ou lugar"); update `searchTip` to mention places.

6.10 Tests: unit `minDistanceM` and `linePassesNear` on synthetic polylines; unit `PlaceSearchProvider.search` with fake index and gazetteer (dedup, ranking, empty index); widget search screen shows place group when index available and tapping result opens line screen; golden/strings new strings present in pt-BR.

## 7. Privacy and security

- User query never sent to server; place resolution local.
- Bulk endpoint serves only published aggregates (line id, code, polyline, stop centroids). No device, trip, session, or rider data.
- Endpoint is public read with rate limiting, consistent with vehicle reads. No auth required.
- Gazetteer coordinates are public landmarks, not user data.
- No new logging of coordinates: `Log` wrapper has no coordinate API; CI grep covers new files.
- `no_location_at_rest` extended to allow only published aggregate columns already permitted (`learned_routes`, `learned_stops`); bulk endpoint adds no new stored data.

## 8. Performance

- One bulk fetch per app session, cached in memory. ~20 lines, each with simplified polyline and handful of stops: expected under 100 KB.
- Proximity matching O(lines * polyline points) per keystroke. ~20 lines and ~100 points each: sub-millisecond, no debounce, matching existing search behaviour.
- Bulk endpoint cached 5 min server-side and revalidated by ETag client-side.

## 9. Status

Shipped: bulk `GET /v1/learned-routes` with optional `bbox`, bundled `data/places.json` gazetteer, client place model and provider, proximity matching, search-screen wiring, strings and tests.

## 10. Acceptance criteria

- Typing "Ufes" on a build with learned routes available lists every line whose learned path comes within 500 m of UFES, including lines that do not name UFES.
- Each result row shows which place matched ("Passa por UFES").
- Tapping a result opens the line screen.
- With learning subsystem disabled, place search returns no results and UI shows only line group, no error.
- With empty or loading index, place search returns no results without blocking line search.
- `deno test` (including security and `no_location_at_rest`) passes.
- `flutter analyze` and `flutter test` pass, including new unit and widget tests.

## 11. Decisions

- Gazetteer: bundled `data/places.json`, reviewed like lines, grown from field feedback.
- Match radius: starts at 500 m / 300 m; tune from missed-line and false-positive field reports.
- Exposure: full search screen plus a home shortcut ("Buscar por lugar").
- Scaling: bulk endpoint accepts optional `bbox`; unfiltered form remains for small deployments and session cache.
- Open: none for alpha.