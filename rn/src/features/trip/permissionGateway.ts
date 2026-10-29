// Permission gateway. Mirrors app/lib/platform permission checks (simplified).
import * as Location from "expo-location";

export async function ensureForegroundPermission(): Promise<boolean> {
  const { status } = await Location.requestForegroundPermissionsAsync();
  return status === "granted";
}

export async function getForegroundStatus(): Promise<string> {
  const { status } = await Location.getForegroundPermissionsAsync();
  return status;
}
