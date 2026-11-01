// Theme context and provider. Port of app/lib/ui/design/theme/context.dart + theme.dart.
import React, { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";
import { useColorScheme } from "react-native";
import { colorsLight, colorsDark, type PontualColors } from "../tokens/colors";
import { PontualText } from "../tokens/text";
import { themeStore } from "../../../data/prefs/themeStore";

export type ThemeMode = "system" | "light" | "dark";
export type ResolvedTheme = "light" | "dark";

export interface ThemeTextStyles {
  etaHero: typeof PontualText.etaHero & { color: string };
  etaLarge: typeof PontualText.etaLarge & { color: string };
  metric: typeof PontualText.metric & { color: string };
  display: typeof PontualText.display & { color: string };
  title: typeof PontualText.title & { color: string };
  headline: typeof PontualText.headline & { color: string };
  body: typeof PontualText.body & { color: string };
  bodyStrong: typeof PontualText.bodyStrong & { color: string };
  label: typeof PontualText.label & { color: string };
  caption: typeof PontualText.caption & { color: string };
  clock: typeof PontualText.clock & { color: string };
}

export interface ThemeValue {
  mode: ThemeMode;
  setMode: (m: ThemeMode) => void;
  resolved: ResolvedTheme;
  colors: PontualColors;
  text: ThemeTextStyles;
}

const ThemeContext = createContext<ThemeValue | null>(null);

function isMode(v: string | null): v is ThemeMode {
  return v === "light" || v === "dark" || v === "system";
}

export function ThemeProvider({ children, initial = "system" }: { children: React.ReactNode; initial?: ThemeMode }) {
  const system = useColorScheme();
  const [mode, setModeState] = useState<ThemeMode>(initial);
  useEffect(() => {
    let live = true;
    themeStore
      .read()
      .then((v) => {
        if (live && isMode(v)) setModeState(v);
      })
      .catch(() => {});
    return () => {
      live = false;
    };
  }, []);
  const resolved: ResolvedTheme = mode === "system" ? (system === "dark" ? "dark" : "light") : mode;
  const colors = resolved === "dark" ? colorsDark : colorsLight;
  const text: ThemeTextStyles = useMemo(() => {
    const ink = colors.ink;
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
      caption: { ...PontualText.caption, color: colors.inkMuted },
      clock: { ...PontualText.clock, color: ink },
    };
  }, [colors]);
  const setMode = useCallback((m: ThemeMode) => {
    setModeState(m);
    themeStore.write(m).catch(() => {});
  }, []);
  const value = useMemo<ThemeValue>(() => ({ mode, setMode, resolved, colors, text }), [mode, setMode, resolved, colors, text]);
  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useThemeOptional(): ThemeValue | null {
  return useContext(ThemeContext);
}

export function useTheme(): ThemeValue {
  const v = useContext(ThemeContext);
  if (v == null) throw new Error("ThemeProvider missing");
  return v;
}
