// WCAG contrast maths. Port of app/lib/ui/util/contrast.dart.
export type ColorHex = string;

function parseHex(hex: string): { r: number; g: number; b: number } {
  const h = hex.startsWith("#") ? hex.slice(1) : hex;
  const n = parseInt(h, 16);
  return { r: (n >> 16) & 0xff, g: (n >> 8) & 0xff, b: n & 0xff };
}

function channel(v: number): number {
  const c = v / 255;
  return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
}

export function relativeLuminance(hex: string): number {
  const { r, g, b } = parseHex(hex);
  return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b);
}

export function contrastRatio(a: string, b: string): number {
  const la = relativeLuminance(a);
  const lb = relativeLuminance(b);
  const hi = Math.max(la, lb);
  const lo = Math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

export const NEAR_BLACK_ON_FILL = "#08111A";
export const WHITE_ON_FILL = "#FFFFFF";

export function bestTextOn(fill: string): string {
  return contrastRatio(fill, WHITE_ON_FILL) >= contrastRatio(fill, NEAR_BLACK_ON_FILL)
    ? WHITE_ON_FILL
    : NEAR_BLACK_ON_FILL;
}

function lerpColor(a: string, b: string, t: number): string {
  const ca = parseHex(a);
  const cb = parseHex(b);
  const r = Math.round(ca.r + (cb.r - ca.r) * t);
  const g = Math.round(ca.g + (cb.g - ca.g) * t);
  const bl = Math.round(ca.b + (cb.b - ca.b) * t);
  return `#${r.toString(16).padStart(2, "0")}${g.toString(16).padStart(2, "0")}${bl.toString(16).padStart(2, "0")}`.toUpperCase();
}

export function ensureContrast(fill: string, text: string): string {
  if (contrastRatio(fill, text) >= 4.5) return fill;
  for (let f = 0.98; f >= 0.7; f -= 0.01) {
    const candidate = lerpColor(fill, "#000000", 1 - f);
    if (contrastRatio(candidate, text) >= 4.5) return candidate;
  }
  return lerpColor(fill, "#000000", 0.3);
}

export function parseHexColor(value: string): string | null {
  const hex = value.startsWith("#") ? value.slice(1) : value;
  if (hex.length !== 6) return null;
  if (!/^[0-9a-fA-F]{6}$/.test(hex)) return null;
  return `#${hex.toUpperCase()}`;
}