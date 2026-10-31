// Viewer location. Port of app/lib/ui/features/line/viewer_location.dart.
// One-shot device position for "my location" and report distance hints.
// Never stored, never logged.
import { useCallback, useState } from "react";
import * as Location from "expo-location";

export interface ViewerFix {
  lat: number;
  lng: number;
  accuracyM: number;
}

export function useViewerLocation(): {
  fix: ViewerFix | null;
  loading: boolean;
  locate: () => Promise<void>;
} {
  const [fix, setFix] = useState<ViewerFix | null>(null);
  const [loading, setLoading] = useState(false);
  const locate = useCallback(async () => {
    setLoading(true);
    try {
      const perm = await Location.requestForegroundPermissionsAsync();
      if (perm.status !== "granted") return;
      const pos = await Location.getCurrentPositionAsync({ accuracy: Location.Accuracy.Balanced });
      setFix({ lat: pos.coords.latitude, lng: pos.coords.longitude, accuracyM: pos.coords.accuracy ?? 999 });
    } catch {
      // Leave previous fix (or null) in place.
    } finally {
      setLoading(false);
    }
  }, []);
  return { fix, loading, locate };
}
