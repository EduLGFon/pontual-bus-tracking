// Theme store (minimal). Mirrors app/lib/data/prefs/theme_store.dart.
import * as storage from "./storage";
const KEY = "theme_mode";
export const themeStore = {
  async read(): Promise<string | null> {
    return storage.getItem(KEY);
  },
  async write(mode: string): Promise<void> {
    await storage.setItem(KEY, mode);
  },
};
