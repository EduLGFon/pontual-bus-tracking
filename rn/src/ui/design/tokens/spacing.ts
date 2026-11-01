// Spacing tokens. Port of app/lib/ui/design/tokens/spacing.dart.
export const Space = {
  x1: 4,
  x2: 8,
  x3: 12,
  x4: 16,
  x5: 20,
  x6: 24,
  x8: 32,
  x12: 48,
} as const;

export type Breakpoint = "compact" | "medium" | "expanded";

export function breakpointOf(width: number): Breakpoint {
  if (width >= 840) return "expanded";
  if (width >= 600) return "medium";
  return "compact";
}

export function marginForWidth(width: number): number {
  switch (breakpointOf(width)) {
    case "compact":
      return Space.x5;
    case "medium":
      return Space.x6;
    case "expanded":
      return Space.x8;
  }
}

export const Radii = {
  s: 8,
  m: 12,
  l: 16,
  sheet: 24,
  pill: 999,
} as const;

export const hitTarget = 48;

export const dockClearance = 56 + 12 + 16;

export const Sizes = {
  navBar: 64,
  dock: 56,
  button: 56,
  buttonCompact: 48,
  chip: 36,
  search: 52,
  shortcutWidth: 156,
  shortcutHeight: 112,
  marker: 36,
  markerHit: 44,
  badgeS: 24,
  badgeM: 28,
  badgeL: 40,
} as const;