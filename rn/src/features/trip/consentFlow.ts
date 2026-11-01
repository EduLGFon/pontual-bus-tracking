// Consent flow. Mirrors app/lib/features/trip/consent_flow.dart.
// A trip never starts without covering consent.
import type { consentStore } from "../../data/prefs/consentStore";

export type ConsentResult = "granted" | "declined" | "offlinePending";

export async function ensureConsent(opts: {
  currentVersion: number;
  store: typeof consentStore;
  showSheet: () => Promise<boolean>;
  postConsents: () => Promise<{ ok: boolean }>;
}): Promise<ConsentResult> {
  const { currentVersion, store, showSheet, postConsents } = opts;
  if (!(await store.covers(currentVersion))) {
    const accepted = await showSheet();
    if (!accepted) return "declined";
    await store.write(currentVersion);
  }
  if ((await store.readPosted()) === currentVersion) return "granted";
  const posted = await postConsents();
  if (posted.ok) {
    await store.markPosted(currentVersion);
    return "granted";
  }
  return "offlinePending";
}
