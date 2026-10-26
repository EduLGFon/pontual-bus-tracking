# Search by place (lines that pass through a searched location)

Status: design plan. Scope: client search extension plus one server read
endpoint, built on top of the learning subsystem (learned routes and stops).
Nothing here changes trip sharing, location handling, or the privacy contract.

Companion documents: `PLAN.md`, `docs/data-learning.md`, `docs/ui/UI_SPEC.md`
section 7.3, `DECISIONS.md` (D20).

---

## 1. Goal

Extend the Busca screen so that typing a place name (for example "Ufes")
returns every line whose learned path passes through or near that place,
including lines that do not have the place in their name or terminals.
Example: typing "Ufes" should list 66 (Centro), 62 (Guriri), 64 (Villages),
60 (Litoraneo), and any other line whose learned route comes within the
match radius of UFES.

The search must stay instant and offline on the client. The learning
subsystem is the source of truth for "where each bus passes through"
(`docs/data-learning.md`); the search only consumes its published
aggregates.

## 2. Non-goals

- No turn-by-turn routing or point-to-point navigation (`PLAN.md` 1.2).
- No geocoding of arbitrary addresses. Place resolution uses a curated,
  bundled gazetteer of public landmarks and neighbourhoods only.
- No per-user location. The user types a name; no device position is used
  or sent.
- No change to the existing line-name/code/terminal search. The new kind
  is an additional group.

## 3. Data sources

1. **Learned routes and stops** (`docs/data-learning.md` 8.1 and 8.2):
   encoded polyline plus stop centroids per line and direction. These are
   de-identified aggregates with a minimum sample count.
2. **Gazetteer**: a bundled JSON list of public places in Sao Mateus
   (landmarks, institutions, neighbourhoods, terminals) with a name,
   aliases, latitude and longitude. Curated by the owner; no personal data.

The client never sends the user query to the server. Place resolution
happens locally against the gazetteer; only public landmark coordinates
are used for matching, and those are already public.

## 4. Matching rule

A line is a result for a place when, for at least one of its directions:

- the minimum distance from the place coordinate to any segment of the
  learned polyline is at most `placeMatchRadiusM` (default 500 m), or
- at least one learned stop centroid is within `placeStopRadiusM`
  (default 300 m) of the place coordinate.

Defaults are client fallback constants; they are not server config in v1
because matching is a client-side presentation concern. If a later review
shows a need to tune them remotely, add keys to `app_config` and treat
the client values as fallbacks (`PLAN.md` 7).

Lines without learned data for any direction do not appear in place
results, even if their static terminals mention the place. This keeps the
feature honest about what the learning subsystem actually knows.

## 5. Server changes

### 5.1 Consumer methods

Add to `LearningConsumer` (`server/src/learning/consumer.ts`):

- `allLearnedRoutes(): LearnedRoute[]` returning the active learned route
  for every line that has one, across both directions.
- `allLearnedStops(): Map<number, LearnedStop[]>` keyed by line id.

These read from the in-process cache / database through the existing
repositories, never from a request path that hits PostgreSQL per row. If
the subsystem is disabled, return empty collections.

### 5.2 Bulk read endpoint

Add `GET /v1/learned-routes` to `server/src/http/readRoutes.ts`:

Response:

```json
{
  "v": 1,
  "routes": [
    {
      "line": 66,
      "code": "66-centro-ifes-ufes",
      "dir": 0,
      "polyline": "_p~iF~ps|U...",
      "stops": [
        { "id": "uuid", "i": 0, "lat": -18.72, "lng": -39.85, "r": 30, "n": 41 }
      ]
    }
  ]
}
```

Rules:

- Public read, no auth, consistent with vehicle reads (`PLAN.md` 6.5).
- Accepts an optional `bbox=latMin,lngMin,latMax,lngMax` query parameter.
  When present, returns only lines whose learned route intersects the box
  (segment or stop within the box). When absent, returns all lines. This
  keeps the payload small on larger deployments without breaking the
  small-city default.
- Returns 404 with `{ "e": "not_found" }` when the learning subsystem is
  disabled, so the client treats "no data" uniformly.
- Rate limit 60 requests per minute per IP (reuse the existing
  `learningPerIp` limiter or a dedicated one).
- `Cache-Control: public, max-age=300` and an `ETag` based on the maximum
  learned-route version and the latest `updated_at`.
- Returns only line ids, codes, polylines and stop centroids. No device,
  trip, session, or rider data. No coordinates other than published
  aggregates.
- Size: if the payload exceeds a reasonable bound (about 256 KB), split
  into the existing per-line endpoints only; for the alpha dataset the
  single endpoint is expected to stay small.

### 5.3 Tests

- `server/test/` (read + security): endpoint returns 404 when disabled;
  rate limit; ETag; no personal fields; only active lines; empty array
  when no aggregates exist.
- Extend `no_location_at_rest` to assert the bulk payload contains no
  coordinate outside the published stop centroids and polylines.

## 6. Client changes

### 6.1 Gazetteer asset

Add `data/places.json` (source of truth) and ship it as
`app/assets/data/places.json` through the data build tool, with a schema
in `data/schema/places.schema.json`. Each entry:

```json
{
  "id": "ufes",
  "name": "UFES",
  "aliases": ["universidade federal do espirito santo", "campus goiabeiras"],
  "lat": -20.27,
  "lng": -40.30
}
```

The data tool validates and copies it into the bundle, mirroring lines
and stops. The gazetteer is small (tens of entries) and versioned with
the data bundle.

### 6.2 Domain model

Add `app/lib/domain/learning/place.dart` (pure Dart, no Flutter imports):

- `Place` with `id`, `name`, `aliases`, `lat`, `lng`.
- `Place.fromJson`.

### 6.3 Repository method

Extend `LearningRepository` (`app/lib/data/learning/learning_repository.dart`):

- `fetchLearnedRoutesIndex()` returning
  `Result<LearnedRoutesIndex>` where `LearnedRoutesIndex` is
  `Map<int, LearnedRouteEntry>` with the decoded polyline points and stops
  per line.
- Reuse the existing HTTP client and base URL. 8 s timeout. On 404 or
  failure, return an empty index rather than an error, so place search
  degrades to "no results" instead of surfacing a failure.

### 6.4 Index provider

Add to `app/lib/app/providers.dart`:

- `learnedRoutesIndexProvider` as a `FutureProvider<LearnedRoutesIndex>`
  that calls `fetchLearnedRoutesIndex()` once and keeps the result for the
  app lifetime (not auto-dispose), so the search screen and the line map
  share one fetch.

### 6.5 Gazetteer provider

Add `app/lib/data/static_data/places.dart` (or an adapter) loading
`assets/data/places.json` into `List<Place>`, exposed as
`placesProvider`. Empty list on any failure, mirroring `stopsProvider`.

### 6.6 Proximity helper

Add `app/lib/core/geo/route_proximity.dart` (pure, unit-testable):

- `minDistanceM(LatLng point, List<LatLng> polyline)` returning the
  minimum distance in meters from the point to any segment, or infinity
  for a polyline with fewer than two points.
- `linePassesNear(place, entry, radiusM, stopRadiusM)` implementing the
  rule in section 4.

### 6.7 Place search provider

Add `app/lib/ui/features/search/place_search.dart`:

- `PlaceSearchProvider implements SearchProvider`, constructed with the
  gazetteer and the loaded index (or an empty index while loading).
- `search(query)`:
  1. Normalise the query.
  2. Find gazetteer entries whose name or any alias contains the query
     (tokenised AND match, reusing `matchesAllTokens`).
  3. For each matched place, find lines passing near it.
  4. Deduplicate by line key, keeping the smallest distance.
  5. Sort by distance then line name.
  6. Return `_PlaceHit` instances carrying the line and the matched place
     name.
- `row` renders the existing line row plus a caption
  "Passa por <place>" (pt-BR), so the reason for the match is visible.

Because `SearchProvider.search` is synchronous, the provider holds the
already-loaded index. While the index is loading, place search returns
an empty list; the UI shows the line group only.

### 6.8 Search screen wiring

In `app/lib/ui/features/search/search_screen.dart`:

- `_searchGroupsProvider` watches `placesProvider` and
  `learnedRoutesIndexProvider`.
- When the index data is available, append a `_PlaceSearchProvider` to
  the providers list.
- Group header only when more than one kind exists (already handled).

### 6.9 Strings

Add to `app/lib/ui/strings/ui_strings.dart`:

- `searchPlaces` = "Linhas que passam por"
- `searchPlacePassesBy` = "Passa por {place}" (or a helper)
- Update `searchHint` remains "Buscar linha ou bairro"; optionally
  "Buscar linha, bairro ou lugar".
- Update `searchTip` to mention places.

### 6.10 Tests

- Unit: `minDistanceM` and `linePassesNear` on synthetic polylines.
- Unit: `PlaceSearchProvider.search` with a fake index and gazetteer,
  including deduplication, ranking, and empty index.
- Widget: search screen shows a place group when the index is available;
  tapping a result opens the line screen.
- Golden/strings: new strings present in pt-BR.

## 7. Privacy and security

- The user query is never sent to the server. Place resolution is local.
- The bulk endpoint serves only published aggregates (line id, code,
  polyline, stop centroids). No device, trip, session, or rider data.
- The endpoint is a public read with rate limiting, consistent with
  vehicle reads. No auth required.
- Coordinates in the gazetteer are public landmarks, not user data.
- No new logging of coordinates: the `Log` wrapper has no coordinate API,
  and the CI grep check covers the new files.
- `no_location_at_rest` is extended to allow only the published aggregate
  columns already permitted (`learned_routes`, `learned_stops`); the bulk
  endpoint adds no new stored data.

## 8. Performance

- One bulk fetch per app session, cached in memory. About 20 lines, each
  with a simplified polyline and a handful of stops: expected under
  100 KB.
- Proximity matching is O(lines * polyline points) per keystroke. With
  ~20 lines and ~100 points each, this is sub-millisecond and needs no
  debounce, matching the existing search behaviour.
- The bulk endpoint is cached for 5 minutes server-side and revalidated
  by ETag client-side.

## 9. Rollout and milestones

1. Server: add consumer methods and bulk endpoint; tests.
2. Data tool: places schema and build step; seed a small gazetteer.
3. Client: domain model, repository method, providers, proximity helper.
4. Client: PlaceSearchProvider and search screen wiring.
5. Strings and tests.
6. Documentation: update `docs/ui/UI_SPEC.md` 7.3 to mention the place
   kind; add the new kind to the SearchProvider list.

Each step is one change set with its own acceptance criteria. Do not
start step N+1 until step N passes.

## 10. Acceptance criteria

- Typing "Ufes" on a build with learned routes available lists every line
  whose learned path comes within 500 m of UFES, including lines that do
  not name UFES.
- Each result row shows which place matched ("Passa por UFES").
- Tapping a result opens the line screen.
- With the learning subsystem disabled, place search returns no results
  and the UI shows only the line group, with no error.
- With an empty or loading index, place search returns no results
  without blocking the line search.
- `deno test` (including security and no_location_at_rest) passes.
- `flutter analyze` and `flutter test` pass, including the new unit and
  widget tests.

## 11. Prompts and recommended actions

The following items need an owner decision before or during implementation.
Each is written as a prompt with a recommended action. Defaults below are
used if no answer is given, so implementation is never blocked.

### Prompt 1 - Gazetteer scope and ownership

Prompt: Which landmarks and neighbourhoods should the initial gazetteer
contain, and who maintains it?

Recommended action: seed it with the same places already used as line
terminals and area tags (Centro, IFES / UFES, Guriri, Villages, Roberto
Silvares, Jacuipe, Santo Antonio, Cohab, Aroeira, etc.), plus the major
institutions (UFES, IFES, terminal Centro). Maintain it as a data/ file
reviewed like lines, with source_ids and verified_at, so it follows the
existing data governance. Start small (about 20-40 entries) and grow from
field feedback.

### Prompt 2 - Match radius tuning

Prompt: Are 500 m for the route and 300 m for stops the right thresholds?

Recommended action: start with 500 m / 300 m as conservative defaults and
add a field-test note in docs/field-tests/ recording false positives and
missed lines. If a field test shows too many loose matches, lower to
300 m / 200 m; if it misses lines that locals consider "passing
through", raise to 700 m. Keep the values as named constants with a
comment pointing to this document so they are easy to find.

### Prompt 3 - Home screen exposure

Prompt: Should place search also appear in the home shortcut flow, or only
on the full search screen?

Recommended action (owner override): expose place search on the full search
screen and also in the home shortcut flow. The home shortcut sheet gains a
"Buscar por lugar" entry that opens /search with the field focused, reusing
the existing shortcut store. This differs from the original
recommendation of search-screen-only in v1.

### Prompt 4 - Bulk endpoint scaling

Prompt: Does the single bulk endpoint need pagination or a bounding box
filter for larger cities?

Owner decision: add the bounding-box filter now. The endpoint accepts an
optional `bbox` parameter (see section 5.2). Keep the unfiltered form for
small deployments and for the app's session-wide cache.
