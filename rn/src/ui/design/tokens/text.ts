// Text tokens. Port of app/lib/ui/design/tokens/text.dart.
// System font only.
import type { TextStyle } from "react-native";

export const PontualText = {
  etaHero: { fontSize: 56, lineHeight: 56, fontWeight: "800", letterSpacing: -1.5 } as TextStyle,
  etaLarge: { fontSize: 34, lineHeight: 36, fontWeight: "800", letterSpacing: -0.8 } as TextStyle,
  metric: { fontSize: 26, lineHeight: 30, fontWeight: "800", letterSpacing: -0.5 } as TextStyle,
  display: { fontSize: 32, lineHeight: 38, fontWeight: "700", letterSpacing: -0.6 } as TextStyle,
  title: { fontSize: 22, lineHeight: 28, fontWeight: "700", letterSpacing: -0.3 } as TextStyle,
  headline: { fontSize: 18, lineHeight: 24, fontWeight: "600", letterSpacing: -0.1 } as TextStyle,
  body: { fontSize: 16, lineHeight: 24, fontWeight: "400" } as TextStyle,
  bodyStrong: { fontSize: 16, lineHeight: 24, fontWeight: "600" } as TextStyle,
  label: { fontSize: 14, lineHeight: 20, fontWeight: "600", letterSpacing: 0.1 } as TextStyle,
  caption: { fontSize: 12, lineHeight: 16, fontWeight: "500", letterSpacing: 0.2 } as TextStyle,
  clock: { fontSize: 18, lineHeight: 24, fontWeight: "700" } as TextStyle,
} as const;