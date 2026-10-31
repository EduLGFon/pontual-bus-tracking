// Theme context and provider. Port of app/lib/ui/design/theme/context.dart + theme.dart.
import React, { createContext, useContext, useEffect, useMemo, useState } from "react";
import { useColorScheme } from "react-native";
import { colorsLight, colorsDark, type PontualColors } from "../tokens/colors";
import { PontualText } from "../tokens/text";
import { themeStore } from "../../../data/prefs/themeStore";

export type ThemeMode = "system" | "light" | "dark";

export interface ThemeTextStyles {
  etaHero: any;
  etaLarge: any;
  metric: any;
  display: any;
  title: any;
  headline: any;
  body: any;
  bodyStrong: any;
  label: any;
  caption: any;
  clock: any;
}

export interface ThemeValue {
  mode: ThemeMode;
  setMode: (m: ThemeMode) => void;
  resolved: "light" | "dark";
  colors: PontualColors;
  text: ThemeTextStyles;
}

const ThemeContext = createContext<ThemeValue | null>(null);

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const system = useColorScheme();
  const [mode, setModeState] = useState<ThemeMode>("system");
  useEffect(() => {
    themeStore.read().then((v) => {
      if (v === "light" || v === "dark" || v === "system") setModeState(v);
    }).catch(() => {});
  }, []);
  const resolved: "light" | "dark" =
    mode === "system" ? (system === "dark" ? "dark" : "light") : mode;
  const colors = resolved === "dark" ? colorsDark : colorsLight;
  const text: ThemeTextStyles = useMemo(() => {
    const ink = colors.ink;
    const inkMuted = colors.inkMuted;
    return {
      etaHero: { ...PontualText.etaHero, color: ink },
      etaLarge: { ...PontualText.etaLarge, color: ink },
      metric: { ...PontualText.metric, color: ink },
      display: { ...PontualText.display, color: ink },
      title: { ...PontualText.title, color: ink },
      headline: { ...PontualText.headline, color: ink },
      body: { ...PontualText.body, color: ink },
      bodyStrong: { ...PontualText.bodyStrong, color: ink },
      label: { ...PontualText.label, color: ink },
      caption: { ...PontualText.caption, color: inkMuted },
      clock: { ...PontualText.clock, color: ink },
    };
  }, [colors]);
  const setMode = (m: ThemeMode) => {
    setModeState(m);
    themeStore.write(m).catch(() => {});
  };
  const value: ThemeValue = { mode, setMode, resolved, colors, text };
  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme(): ThemeValue {
  const v = useContext(ThemeContext);
  if (!v) throw new Error("ThemeProvider missing");
  return v;
}