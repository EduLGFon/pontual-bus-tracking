# Pontual (React Native / Expo)

Second client for Pontual, talking to the unchanged Deno backend. Working dir `rn/`. Source of truth: root `ARCHITECTURE.md`, `DECISIONS.md`, root `AGENTS.md`. Companion plan: `docs/ui/UI_SPEC.md`. Parity inventory: `RN_RECREATION_ARCHITECTURE.md`.

## Get started (Bun)

```bash
bun install
bunx expo start
```

Open in a development build (not Expo Go): `bunx expo run:android` or `bunx expo run:ios`.

## Commands

```bash
bunx expo install <package>   # resolves SDK-compatible versions
bunx expo lint                # lint
bunx tsc --noEmit             # typecheck
bunx expo-doctor              # diagnose deps/config
bunx expo install --fix       # fix incompatible versions
```

Run lint + typecheck before declaring any task done.

## Structure

- Routes: `src/app/` (Expo Router file-based). Every file is a screen; `_layout.tsx` defines navigators. Keep non-route code outside `src/app/`.
- Non-route code: `src/{core,data,domain,features,platform,ui,app}/`.
- Config: `app.json`, `app.config.ts`. Env via `EXPO_PUBLIC_*` baked at build time.

## Rules (rn/)

- Expo ships breaking changes each SDK. Read `expo` major in `package.json`, fetch matching docs at `https://docs.expo.dev/versions/v<major>.0.0/`, and `https://docs.expo.dev/llms.txt`. Never answer Expo/RN API questions from memory.
- Native dirs (`ios/`, `android/`) are generated (CNG). Never create/edit by hand; configure in `app.json` + config plugins.
- After adding a lib with native code, use a dev build (`bunx expo run:ios|android` or `eas build --profile development`); Expo Go lacks it.
- Prefer recommended Expo modules over third-party; check available skills before adding deps.
- EAS: `bunx eas-cli <command>` (or `npx eas-cli@latest`). Docs: `https://docs.expo.dev/eas/index.md`.
- Env: `EXPO_PUBLIC_API_BASE_URL`, `EXPO_PUBLIC_STATIC_BASE_URL`, `EXPO_PUBLIC_MAPTILER_KEY`, `EXPO_PUBLIC_APP_VERSION`.
- No analytics/crash reporting/ads/Firebase/local DB/codegen (ARCHITECTURE.md 15). No `react-native-maps`, Mapbox, Google Maps.
- Keep user-visible strings pt-BR; code/comments/docs English. No em dashes.

## Nav

Import `Link`, `router`, `useLocalSearchParams` from `expo-router`. Docs: `https://docs.expo.dev/router/introduction.md`.
