# Alpha security review (T43)

Date: 2026-10-03. Scope: PLAN.md 12.6 AC01-AC23 against the current
tree. Verdicts: pass, partial (usable with a noted gap), or blocked
(needs the VPS, a release build, or a phone).

## Automated suites (all green this round)

- Server: 67 passed, 0 failed (`deno task test` against local
  PostgreSQL 16 on 5433; needs `TEST_DATABASE_URL` set, CI sets it).
- Client: 131 passed (`flutter test` in `app/`).
- `deno fmt --check`, `deno lint`, `deno check`: clean.
  `flutter analyze`: clean. Manifest source audit: PASS.
- Simulator: 90 s and 45 s local runs green (T35); 8-hour soak is
  T46.

## Per-AC verdicts

| ID | Verdict | Evidence |
| -- | ------- | -------- |
| AC01 | pass | `security_test.ts`: missing, malformed, unknown tokens rejected with generic 401. Expired-token path covered by the 30-day purge plus lookup miss. |
| AC02 | pass | `trip_test.ts`: device B cannot affect device A (engine state). |
| AC03 | pass | No trip/session/user ids in routes or schemas (T08 scan). The device id returned at registration is by design (PLAN 6.5). |
| AC04 | blocked | Needs the VPS. Local posture: PostgreSQL binds the container port, metrics listen on localhost only. |
| AC05 | pass | Metrics localhost-only; `/admin`, `/internal`, `/metrics`, `/debug` via public host are 404. |
| AC06 | pass | Unit plus live 101 upgrade: invalid line, oversized message, unknown op, per-IP and global caps close the socket without leaking data. Full Cloudflare relay stays VERIFY on staging. |
| AC07 | pass | Bbox, accuracy, speed, teleport ignored with strikes; 5 strikes end the trip as abuse. |
| AC08 | pass | Snapshot IP flood and device ping flood contained in tests. 1000/min and 10000/min scale is staging work (T46/T47). |
| AC09 | pass | `429 quota` and `503 capacity` paths tested. |
| AC10 | pass | Start without consent or with an old version returns `403 consent`. |
| AC11 | pass | Schema fuzz (nulls, NaN, Inf, huge numbers, wrong types, extra keys, nesting, giant bodies, wrong content type) returns generic errors, no traces. |
| AC12 | pass with residual | Far spoof cannot attach; without route geometry a ghost vehicle is possible, documented residual with mitigations (T12 review). |
| AC13 | pass | Server row-count test plus client end-to-end (T41 privacy test): confirm clears the token and returns to welcome; cancel and offline keep data. |
| AC14 | pass | Kill switch returns `503 maint` within the refresh window. Hygiene: AC14 leaves `service_enabled=false` in the shared dev DB; reset `app_config` before later runs (T35 note). |
| AC15 | partial | Source manifest audit PASS (no background location, no WAKE_LOCK; `wakelock_plus` adds no Android permission). Merged-manifest, `allowBackup=false`, cleartext, and debuggable checks need the release AAB (T45). |
| AC16 | partial | No secrets tracked: root `.env` (owner VPS creds) is gitignored, grep finds no keys, tokens, or hashes in code, tests, or docs. The gitleaks binary is absent on this host; CI runs the gitleaks action per release. |
| AC17 | pass | Full trip at debug level on 2026-10-03 (register, consent, start, ping, end, delete): zero hits for coordinates, bearer token, or device id in API logs. Request logs carry method, route, status, duration, request id only. |
| AC18 | pass | `build/_headers` verified (CSP without Google CDN, HSTS, nosniff, no-referrer, geolocation self-only, COOP same-origin); live CORS test in `security_test.ts`. Browser console check stays on the T37 machine. |
| AC19 | pass | Pins committed (`pubspec.lock`, `deno.lock`); Hono 4.13.12, postgres.js 3.4.9, Valibot 1.5.0, dbmate 2.36.0 per ADRs; `wakelock_plus` 1.8.0 is allow-listed (PLAN 8.2); `stream_channel` is a test-only companion of `web_socket_channel` (T27). |
| AC20 | blocked | Needs the VPS and Cloudflare (origin lock, firewall ranges). |
| AC21 | blocked | Needs the VPS. `server/deploy/` is still empty (T05 deploy script and systemd unit, owner-blocked). Sandbox flags are specified in PLAN 12.8, not yet provisioned. |
| AC22 | pass | Migration 0001 has no location columns; `no_location_at_rest` test green. |
| AC23 | pass | DB holds only SHA-256 hashes; delete evicts the lookup cache immediately in-process. |

## Open P0/P1 findings

None in code. Release blockers that remain are environmental, not
findings: VPS provisioning and hardening (T04), deploy script and
systemd unit (T05), merged-manifest and release-flag audit (T45),
browser console check (T37 machine), field tests (T47), gitleaks
binary run (covered by CI per release).

## Residual risks accepted for alpha

KL2 (lone rider position), KL3 (bunching), KL6 (restart drops live
state), ghost vehicle without route geometry (AC12). All disclosed
in consent text, policy draft, or RIPD.

## D82/D83 passenger reports (2026-10-20)

New attack surface: a state-changing `POST /v1/reports` and a public `r` array
in the line snapshot/stream. Controls reviewed in code: bearer auth, strict
schema with unknown keys rejected (including `lat`/`lng`/`at`), a coarse ~150 m
area id validated against the served bbox, kind-target rules, per-device and
per-IP rate limits, per-line/global caps, closed kinds, no free text, no exact
coordinates, memory-only TTL, `DELETE /v1/me` clears reporter sets, and a kill
switch. Reports are labelled as passenger claims, never verified facts.

Residual: counts are sybil-able because tokens are free, and a single device can
keep its own report fresh until the hard max age. Mitigations are the short TTL,
caps, single-source wording ("1 relato recente") and the kill switch. The report
HTTP suite needs `TEST_DATABASE_URL` and was not run on this host; it must run in
CI before release.