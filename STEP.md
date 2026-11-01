# STEP

Current step: Full client recreation complete and verified (all 15 phases).

Status: verified, pending field test
Branch: rn
Working dir: rn/

Verified (this iteration):
- npx tsc --noEmit: clean
- npx expo lint: clean (0 errors, 0 warnings)
- npx jest --ci --coverage=false: 12 suites, 39 tests, all pass
- npx expo export --platform web: success

Done since Phase 1:
- Design system: tokens, theme, 36 components, 4 icons, shell, strings
- Screens S01-S15 with Expo Router routes (welcome, home, lines, search,
  line/[id] with Agora/Horarios tabs, trip, settings, privacy + policy/terms,
  about, system)
- Trip runtime: location filter, ping client (latest-wins + backoff),
  supervisor, consent flow, share flow, trip service with server pacing
  and revive-once
- Vehicle repository: snapshot-first, sub protocol, watchdog, polling fallback
- Reports UI wiring (strip, sheet with coarse 150 m cell, detail, retract)
- Arrivals predictions in Agora tab; learned-route overlay on map (native + web)
- EAS profiles (eas.json) + RN CI workflow (.github/workflows/rn.yml)
- Test runner (jest-expo) with domain and trip unit tests

Remaining (needs device or owner):
- Field test against local server (two phones, one bus)
- EAS build run (eas build) and Play submission
- Merged Android manifest audit + size check on capable machine
