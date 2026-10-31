// LivePulse host. Port of app/lib/ui/design/components/live_pulse.dart.
// RN has no shared AnimationController; this host is a no-op scope so the
// tree shape matches Flutter. Animated dots use a static ring instead.
import React, { createContext, useContext } from "react";
import { AccessibilityInfo } from "react-native";

const PulseContext = createContext<boolean>(true);

export function LivePulse({ children }: { children: React.ReactNode }) {
  return <PulseContext.Provider value={true}>{children}</PulseContext.Provider>;
}

export function useLivePulse(): boolean {
  const enabled = useContext(PulseContext);
  void AccessibilityInfo;
  return enabled;
}
