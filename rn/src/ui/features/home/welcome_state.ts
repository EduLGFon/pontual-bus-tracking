// First-run local state for the home screen. Port of
// app/lib/ui/features/home/welcome_state.dart. Uses the storage wrapper
// (SecureStore on native, localStorage on web). No personal data.
import { useCallback, useEffect, useState } from "react";
import * as storage from "../../../data/prefs/storage";

export const welcomeSeenKey = "ui_welcome_seen_v1";
export const coachmarkSeenKey = "ui_coachmark_seen_v1";

export interface HomeOnboarding {
  welcomeSeen: boolean;
  coachmarkSeen: boolean;
}

async function readFlag(key: string): Promise<boolean> {
  try {
    return (await storage.getItem(key)) === "1";
  } catch {
    return false;
  }
}

export function useHomeOnboarding(): HomeOnboarding & {
  dismissWelcome: () => void;
  dismissCoachmark: () => void;
} {
  const [state, setState] = useState<HomeOnboarding>({ welcomeSeen: true, coachmarkSeen: true });
  useEffect(() => {
    let live = true;
    (async () => {
      const [w, c] = await Promise.all([readFlag(welcomeSeenKey), readFlag(coachmarkSeenKey)]);
      if (live) setState({ welcomeSeen: w, coachmarkSeen: c });
    })();
    return () => {
      live = false;
    };
  }, []);
  const dismissWelcome = useCallback(() => {
    setState((s) => ({ ...s, welcomeSeen: true }));
    storage.setItem(welcomeSeenKey, "1").catch(() => {});
  }, []);
  const dismissCoachmark = useCallback(() => {
    setState((s) => ({ ...s, coachmarkSeen: true }));
    storage.setItem(coachmarkSeenKey, "1").catch(() => {});
  }, []);
  return { ...state, dismissWelcome, dismissCoachmark };
}
