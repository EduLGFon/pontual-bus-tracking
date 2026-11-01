// Privacy actions. Mirrors app/lib/features/settings/privacy_actions.dart.
// Offline delete reports honestly and keeps local data.
import { busApi } from "../../data/api/busApi";
import * as tokenStore from "../../data/prefs/tokenStore";
import { consentStore } from "../../data/prefs/consentStore";
import AsyncStorage from "@react-native-async-storage/async-storage";

export type DeleteOutcome = "deleted" | "offline";

export async function deleteMyData(): Promise<DeleteOutcome> {
  const token = await tokenStore.readToken();
  if (token) {
    const res = await busApi.deleteMe(token);
    if (!res.ok) return "offline";
  }
  await AsyncStorage.clear();
  await tokenStore.clearToken().catch(() => {});
  return "deleted";
}

export async function revokeConsent(): Promise<void> {
  const token = await tokenStore.readToken();
  if (token) {
    try {
      await busApi.endTrip(token);
    } catch {}
    try {
      await busApi.revokeConsent(token);
    } catch {}
  }
  await consentStore.clear();
}
