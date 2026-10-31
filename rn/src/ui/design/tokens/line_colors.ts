// Deterministic line colours. Port of app/lib/ui/design/tokens/line_colors.dart.
import type { LineCategory } from "../../../domain/lineCategory";
import { bestTextOn, ensureContrast, parseHexColor as parseHexColorUtil } from "../../util/contrast";

export type Brightness = "light" | "dark";

export const linePaletteLight: string[] = [
  "#2563EB", "#027CBB", "#07819E", "#0F766E", "#C026D3",
  "#DB2777", "#CC4D0A", "#92400E", "#475569", "#9F1239",
];

export const linePaletteDark: string[] = [
  "#2B73FF", "#0282C4", "#0787A6", "#128A81", "#CD29E2",
  "#E6297D", "#D6510A", "#CB5913", "#687D9A", "#F01B56",
];

export function paletteOf(brightness: Brightness): string[] {
  return brightness === "dark" ? linePaletteDark : linePaletteLight;
}

export function stableHash(key: string): number {
  let hash = 0x811c9dc5;
  for (let i = 0; i < key.length; i++) {
    hash ^= key.charCodeAt(i);
    hash = (hash * 0x01000193) >>> 0;
  }
  return hash;
}

export function lineColorOf(
  lineKey: string,
  brightness: Brightness,
  colorValue?: string | null,
): string {
  const palette = paletteOf(brightness);
  if (colorValue) {
    const parsed = parseHexColorUtil(colorValue);
    if (parsed) {
      return ensureContrast(parsed, bestTextOn(parsed));
    }
  }
  return palette[stableHash(lineKey) % palette.length];
}

export function lineBadgeTextOf(fill: string): string {
  return bestTextOn(fill);
}

const lineCategoryLight: Record<LineCategory, string> = {
  ufes: "#2563EB",
  guriri: "#EAB308",
  aroeira: "#7C3AED",
  other: "#475569",
};

const lineCategoryDark: Record<LineCategory, string> = {
  ufes: "#2B73FF",
  guriri: "#FACC15",
  aroeira: "#A78BFA",
  other: "#687D9A",
};

export function categoryColorOf(category: LineCategory, brightness: Brightness): string {
  return brightness === "dark" ? lineCategoryDark[category] : lineCategoryLight[category];
}

export function parseHexColor(value: string): string | null {
  return parseHexColorUtil(value);
}