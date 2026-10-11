// Spacing, size and shape tokens. 4 pt grid, screen margins per window
// class, radii from 8 to 999. See docs/ui/UI_SPEC.md 4.3.
import 'package:flutter/widgets.dart';

/// 4 pt grid steps used across the UI.
class Space {
  /// Private constructor: this class only holds spacing constants.
  const Space._();

  /// 4 dp.
  static const double x1 = 4;

  /// 8 dp.
  static const double x2 = 8;

  /// 12 dp.
  static const double x3 = 12;

  /// 16 dp.
  static const double x4 = 16;

  /// 20 dp.
  static const double x5 = 20;

  /// 24 dp.
  static const double x6 = 24;

  /// 32 dp.
  static const double x8 = 32;

  /// 48 dp.
  static const double x12 = 48;
}

/// Window size classes. See docs/ui/UI_SPEC.md 6.5.
enum Breakpoint {
  /// Narrower than 600 dp: bottom navigation and bottom sheet over map.
  compact,

  /// 600 to 839 dp: navigation rail plus content.
  medium,

  /// 840 dp and wider: rail plus 400 dp side panel plus map.
  expanded;

  /// Classifies a [width] in logical pixels.
  static Breakpoint of(double width) {
    if (width >= 840) {
      return Breakpoint.expanded;
    }
    if (width >= 600) {
      return Breakpoint.medium;
    }
    return Breakpoint.compact;
  }
}

/// Screen margin for a window class: 20 compact, 24 medium, 32 expanded.
double marginFor(BuildContext context) {
  final double width = MediaQuery.sizeOf(context).width;
  return switch (Breakpoint.of(width)) {
    Breakpoint.compact => Space.x5,
    Breakpoint.medium => Space.x6,
    Breakpoint.expanded => Space.x8,
  };
}

/// Corner radii.
class Radii {
  /// Private constructor: this class only holds radius constants.
  const Radii._();

  /// Small chips.
  static const double s = 8;

  /// Inputs and small cards.
  static const double m = 12;

  /// Cards and rows.
  static const double l = 16;

  /// Top of sheets.
  static const double sheet = 24;

  /// Pills and badges.
  static const double pill = 999;
}

/// Minimum touch target in dp. Never below 44.
const double hitTarget = 48;

/// Bottom clearance scrollable branch screens reserve so the floating dock
/// never covers the last row: dock height plus its bottom margin plus one
/// spacing step.
const double dockClearance = 56 + 12 + 16;

/// Size constants shared by components.
class Sizes {
  /// Private constructor: this class only holds size constants.
  const Sizes._();

  /// Bottom navigation height without the safe area.
  static const double navBar = 64;

  /// Trip dock height.
  static const double dock = 56;

  /// Primary button height.
  static const double button = 56;

  /// Compact button height.
  static const double buttonCompact = 48;

  /// Chip height.
  static const double chip = 36;

  /// Search field height.
  static const double search = 52;

  /// Shortcut card width.
  static const double shortcutWidth = 156;

  /// Shortcut card height.
  static const double shortcutHeight = 112;

  /// Vehicle marker body diameter.
  static const double marker = 36;

  /// Vehicle marker hit area.
  static const double markerHit = 44;

  /// Smaller line badge.
  static const double badgeS = 24;

  /// Medium line badge.
  static const double badgeM = 28;

  /// Large line badge.
  static const double badgeL = 40;
}
