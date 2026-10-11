// Geometry of the draggable line sheet. Snap fractions and the pixel
// conversions live here so the screen stays readable and the rules are
// testable on their own. See docs/ui/UI_SPEC.md 7.5.

/// Peek snap point as a screen-height fraction.
const double sheetPeek = 0.30;

/// Half-open snap point as a screen-height fraction.
const double sheetHalf = 0.55;

/// Almost-full snap point as a screen-height fraction.
const double sheetFull = 0.92;

/// Minimum sheet height in logical pixels.
const double sheetMinHeightDp = 220;

/// Fallback height used before the first layout pass, so the sheet is
/// never built with an infinite fraction.
const double sheetFallbackHeightDp = 640;

/// Peek fraction: [sheetPeek], never below [sheetMinHeightDp]. On a short
/// screen the fraction grows so the peek always shows 220 dp. The fraction
/// never exceeds [sheetHalf], otherwise the sheet has no drag range.
double sheetPeekFraction(double screenHeight) {
  final double height = screenHeight > 0 ? screenHeight : sheetFallbackHeightDp;
  final double floor = sheetMinHeightDp / height;
  final double raw = floor > sheetPeek ? floor : sheetPeek;
  return raw > sheetHalf ? sheetHalf : raw;
}

/// Snap sizes of the sheet, ascending and inside the valid range.
List<double> sheetSnapSizes(double screenHeight) {
  final double peek = sheetPeekFraction(screenHeight);
  return <double>[
    peek,
    if (sheetHalf > peek) sheetHalf,
    if (sheetFull > sheetHalf) sheetFull,
  ];
}

/// Nearest snap point of [size], or null while the sheet is in between.
/// Used to fit the map camera only when the sheet settles on a snap.
double? nearestSnapOf(double size, List<double> snaps) {
  for (final double snap in snaps) {
    if ((size - snap).abs() <= 0.02) {
      return snap;
    }
  }
  return null;
}

/// Pixels of a sheet fraction on a screen of [screenHeight].
double sheetPixels(double screenHeight, double fraction) {
  return screenHeight * fraction;
}
