// Token store. Mirrors app/lib/data/prefs/token_store.dart.
import * as storage from "./storage";

const TOKEN_KEY = "device_token";

export async function readToken(): Promise<string | null> {
  return storage.getItem(TOKEN_KEY);
}
export async function writeToken(token: string): Promise<void> {
  await storage.setItem(TOKEN_KEY, token);
}
export async function clearToken(): Promise<void> {
  await storage.removeItem(TOKEN_KEY);
}
