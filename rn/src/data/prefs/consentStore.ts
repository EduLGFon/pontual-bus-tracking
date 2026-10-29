// Consent store. Mirrors app/lib/data/prefs/consent_store.dart.
import * as storage from "./storage";

const ACCEPTED_KEY = "consent_version_accepted";
const POSTED_KEY = "consent_version_posted";

export const consentStore = {
  async read(): Promise<number | null> {
    const v = await storage.getItem(ACCEPTED_KEY);
    return v ? Number(v) : null;
  },
  async write(version: number): Promise<void> {
    await storage.setItem(ACCEPTED_KEY, String(version));
  },
  async covers(currentVersion: number): Promise<boolean> {
    return (await this.read()) === currentVersion;
  },
  async readPosted(): Promise<number | null> {
    const v = await storage.getItem(POSTED_KEY);
    return v ? Number(v) : null;
  },
  async markPosted(version: number): Promise<void> {
    await storage.setItem(POSTED_KEY, String(version));
  },
  async clearPosted(): Promise<void> {
    await storage.removeItem(POSTED_KEY);
  },
  async clear(): Promise<void> {
    await storage.removeItem(ACCEPTED_KEY);
  },
};
