# Pontual RN/Expo agent rules

This is an Expo/React Native app (working dir `rn/`). Prioritize mobile-first patterns, performance, cross-platform compatibility. Source of truth: root `ARCHITECTURE.md`, `DECISIONS.md`, root `AGENTS.md`; companion plan `docs/ui/UI_SPEC.md`.

## Expo has changed - do not trust training data

Expo ships breaking changes every SDK release. Before writing code touching an Expo, EAS, or React Native API:
1. Read the `expo` major version in `package.json`.
2. Fetch matching docs: `https://docs.expo.dev/versions/v<major>.0.0/`
3. For anything else fetch `https://docs.expo.dev/llms.txt` and follow its links. Never answer from memory.

## Commands (Bun; `bun.lock` present)

```bash
bunx expo install <package>   # ALWAYS (SDK-compatible versions)
bunx expo start               # dev server
bunx expo lint                # lint
bunx tsc --noEmit             # typecheck
bunx expo-doctor              # diagnose deps/config
bunx expo install --fix       # fix incompatible versions
```

Run lint + typecheck before declaring any task done.

## Navigation and routing

- Expo Router for all navigation. Routes in `src/app/`; every file there is a screen, `_layout.tsx` defines navigators. Keep non-route code outside `src/app/`.
- Import `Link`, `router`, `useLocalSearchParams` from `expo-router`.
- Docs: `https://docs.expo.dev/router/introduction.md`

## Building with EAS

EAS for cloud build/sign/submit and OTA updates (`eas build`, `eas submit`, `eas update`); no local Xcode/Android Studio. Run as `bunx eas-cli <command>` (or `npx eas-cli@latest`). Docs: `https://docs.expo.dev/eas/index.md`

## Rules

- If `ios/` and `android/` do not exist, they are generated (CNG). Never create or edit by hand; configure native behavior in `app.json` and config plugins.
- Expo Go includes only bundled native modules. After adding a library with native code, use a dev build: `bunx expo run:ios|android` locally, or `eas build --profile development`.
- Prefer recommended Expo modules over third-party libraries; check available skills before adding dependencies. Docs: `https://docs.expo.dev/versions/latest/index.md`
- No analytics/crash reporting/ads/Firebase/local DB/codegen (root ARCHITECTURE.md 15). No `react-native-maps`, Mapbox, Google Maps.
- User-visible strings pt-BR; code/comments/docs English. No em dashes.
- One task per PR; acceptance criteria pass before next. Never weaken security, privacy, or budgets.
