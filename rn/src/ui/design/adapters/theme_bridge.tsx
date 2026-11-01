// Theme bridge. Port of app/lib/ui/design/adapters/theme_bridge.dart.
import React from "react";
import { ThemeProvider } from "../theme/context";
export function ThemeBridge({ children }: { children: React.ReactNode }) {
  return <ThemeProvider>{children}</ThemeProvider>;
}