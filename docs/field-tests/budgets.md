# Budget measurements (T44)

Date: 2026-10-03. Reference budgets: PLAN.md 10.1. Items marked
TODO need a reference device or the Android SDK, neither of which
exists on this host (no phones, no usable browser, no Android SDK).

## Measured on this host

| Metric | Budget | Measured | Verdict |
| ------ | ------ | -------- | ------- |
| Ping wire size | <= ~0.6 KB | 0.62 KB (215 B headers + 103 B body up; ~0.3 KB response) via curl trace against the local server | at target; through Cloudflare with TLS expect 0.6-0.8 KB |
| Leader data | <= ~0.15 MB/h | ~0.15 MB/h (240 pings x 0.62 KB) | at budget |
| Follower data | <= ~0.03 MB/h | ~0.025 MB/h (40 pings x 0.62 KB) | inside |
| Web first load (gz) | <= 3 MB | JS path 2.95 MB; wasm path 3.08 MB | JS inside; wasm ~3 % over (canvaskit.wasm 2.06 MB gz dominates) |
| Web repeat load | <= 0.2 MB | hashed assets immutable + manifest/config no-cache (`build/_headers` verified) | by construction, browser check TODO |
| Tile first view | <= ~1.5 MB | OSM cache capped 50 MB, browser HTTP cache on web | browser check TODO |
| Server soak | no errors | 90 s and 45 s sim runs green; 8 h soak is T46 | TODO |

## TODO on a capable machine or device

- [ ] Android AAB size (<= 15 MB arm64) and universal APK (<= 25 MB).
- [ ] First Flutter frame (<= 2 s mid-range, <= 3.5 s low-end).
- [ ] RAM: <= 150 MB PSS map visible, <= 80 MB trip screen off.
- [ ] CPU: trip screen off average < 2 %; map pan >= 55 fps on low-end.
- [ ] Battery: leader extra drain <= ~4 %/h, follower <= ~2 %/h.
- [ ] Fix-to-map p95 latency <= 10 s on real phones (local sim: p50 4-7 ms, p95 ~5 s snapshot cadence).
- [ ] Viewer WebSocket <= ~0.05 MB per 10 min on a real network.
- [ ] Merged-manifest audit and release flags (T45).

Method: ping bodies measured with `curl -w size_upload/size_download` plus
a `--trace-ascii` header capture; Dart client headers are comparable in
size. TLS and Cloudflare add overhead amortized over the keep-alive
connection; re-measure on staging.