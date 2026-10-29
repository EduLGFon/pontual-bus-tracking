// Environment config. Values come from EXPO_PUBLIC_* at build time.
// Mirrors app/lib/core/config/env.dart.
export const API_BASE_URL =
  process.env.EXPO_PUBLIC_API_BASE_URL ?? "http://127.0.0.1:8080";
export const STATIC_BASE_URL =
  process.env.EXPO_PUBLIC_STATIC_BASE_URL ?? "http://127.0.0.1:8080/data";
export const APP_VERSION = process.env.EXPO_PUBLIC_APP_VERSION ?? "0.1.0";
export const MAPTILER_KEY = process.env.EXPO_PUBLIC_MAPTILER_KEY ?? "";
export const FIX_ACCURACY_MAX_M = Number(
  process.env.EXPO_PUBLIC_FIX_ACCURACY_MAX_M ?? "60",
);
export const FORCE_PING_BUTTON =
  process.env.EXPO_PUBLIC_FORCE_PING_BUTTON === "true";
