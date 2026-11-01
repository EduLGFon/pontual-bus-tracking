// Line sheet geometry. Port of app/lib/ui/features/line/line_sheet_geometry.dart.
// Snap fractions for the compact bottom sheet.
export const sheetSnaps: readonly number[] = [0.18, 0.5, 0.92];

export function nearestSnap(fraction: number): number {
  let best = sheetSnaps[0];
  for (const s of sheetSnaps) {
    if (Math.abs(s - fraction) < Math.abs(best - fraction)) best = s;
  }
  return best;
}
