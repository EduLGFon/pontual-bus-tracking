// Colour tokens. Port of app/lib/ui/design/tokens/colors.dart.
export type CertaintyTone = "live" | "predicted" | "scheduled" | "stale";

export interface PontualColors {
  bg: string;
  surface: string;
  surfaceSunken: string;
  surfaceRaised: string;
  line: string;
  ink: string;
  inkMuted: string;
  inkSubtle: string;
  primary: string;
  onPrimary: string;
  live: string;
  liveText: string;
  predicted: string;
  predictedText: string;
  scheduled: string;
  warning: string;
  warningText: string;
  danger: string;
  dangerText: string;
  scrim: string;
  mapScrim: string;
  graphicOf: (tone: CertaintyTone) => string;
  textOf: (tone: CertaintyTone) => string;
}

function make(colors: Omit<PontualColors, "graphicOf" | "textOf">): PontualColors {
  const graphicOf = (tone: CertaintyTone): string => {
    switch (tone) {
      case "live":
        return colors.live;
      case "predicted":
        return colors.predicted;
      case "scheduled":
        return colors.scheduled;
      case "stale":
        return colors.warning;
    }
  };
  const textOf = (tone: CertaintyTone): string => {
    switch (tone) {
      case "live":
        return colors.liveText;
      case "predicted":
        return colors.predictedText;
      case "scheduled":
        return colors.scheduled;
      case "stale":
        return colors.warningText;
    }
  };
  return { ...colors, graphicOf, textOf };
}

export const colorsLight: PontualColors = make({
  bg: "#F6F5F1",
  surface: "#FFFFFF",
  surfaceSunken: "#EDECE6",
  surfaceRaised: "#FFFFFF",
  line: "#E3E1D9",
  ink: "#0F1B18",
  inkMuted: "#44544F",
  inkSubtle: "#5E6E69",
  primary: "#0B3D36",
  onPrimary: "#FFFFFF",
  live: "#149B5C",
  liveText: "#087443",
  predicted: "#5B4BDB",
  predictedText: "#4A3BC4",
  scheduled: "#576964",
  warning: "#CC7006",
  warningText: "#9F4B07",
  danger: "#C2362B",
  dangerText: "#B42318",
  scrim: "#660F1B18",
  mapScrim: "#2EF6F5F1",
});

export const colorsDark: PontualColors = make({
  bg: "#0A1110",
  surface: "#121B19",
  surfaceSunken: "#0E1614",
  surfaceRaised: "#1A2623",
  line: "#26332F",
  ink: "#EAF2EE",
  inkMuted: "#A9B8B2",
  inkSubtle: "#8A9A94",
  primary: "#62E8B0",
  onPrimary: "#07140F",
  live: "#3DDC97",
  liveText: "#6EE7B7",
  predicted: "#A9A0FF",
  predictedText: "#C4BEFF",
  scheduled: "#8A9A94",
  warning: "#FBBF24",
  warningText: "#FBBF24",
  danger: "#FF8A80",
  dangerText: "#FF8A80",
  scrim: "#99000000",
  mapScrim: "#590A1110",
});