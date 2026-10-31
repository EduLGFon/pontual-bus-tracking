// Android permission gateway. Mirrors app/lib/platform/android/permission_gateway.dart.
// Uses expo-location foreground APIs only. No background location.
import * as Location from "expo-location";

export type LocationPermissionState =
  | "granted"
  | "denied"
  | "permanentlyDenied";

export interface PermissionGateway {
  check(): Promise<LocationPermissionState>;
  request(): Promise<LocationPermissionState>;
  servicesOn(): Promise<boolean>;
  preciseAccuracy(): Promise<boolean>;
  openSettings(): Promise<void>;
}

function mapStatus(status: string): LocationPermissionState {
  if (status === "granted") return "granted";
  return "denied";
}

export const geolocatorPermissionGateway: PermissionGateway = {
  async check(): Promise<LocationPermissionState> {
    try {
      const res = await Location.getForegroundPermissionsAsync();
      return mapStatus(res.status);
    } catch {
      return "denied";
    }
  },
  async request(): Promise<LocationPermissionState> {
    try {
      const res = await Location.requestForegroundPermissionsAsync();
      return mapStatus(res.status);
    } catch {
      return "denied";
    }
  },
  async servicesOn(): Promise<boolean> {
    try {
      return await Location.hasServicesEnabledAsync();
    } catch {
      return true;
    }
  },
  async preciseAccuracy(): Promise<boolean> {
    try {
      const fg = await Location.getForegroundPermissionsAsync();
      const scope = (fg as { ios?: { scope?: string }; android?: { accuracy?: string } }).ios?.scope
        ?? (fg as { android?: { accuracy?: string } }).android?.accuracy;
      void scope;
      return true;
    } catch {
      return true;
    }
  },
  async openSettings(): Promise<void> {
    const { Linking, Platform } = await import("react-native");
    void Platform;
    try {
      await Linking.openSettings();
    } catch {}
  },
};
