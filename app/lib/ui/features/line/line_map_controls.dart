// Controls drawn over the line map: the back button, the recenter button
// and the always visible OSM attribution chip. Kept apart from the map layer
// so both stay small. See docs/ui/UI_SPEC.md 7.5.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/design/tokens/text.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:url_launcher/url_launcher.dart';

/// OSM copyright page opened from the attribution chip.
const String osmCopyrightUrl = 'https://www.openstreetmap.org/copyright';

/// 44 dp circular back control over the map, top-left.
class MapBackButton extends StatelessWidget {
  /// Creates the button.
  const MapBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return MapCircleButton(
      icon: Icons.arrow_back_rounded,
      semanticLabel: UiStrings.back,
      fill: colors.surface,
      border: colors.line,
      onTap: () => Navigator.of(context).maybePop(),
    );
  }
}

/// Attribution chip, always visible, top-right, 12 sp on a surface pill.
class MapAttributionChip extends StatelessWidget {
  /// Creates the chip.
  const MapAttributionChip({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Positioned(
      top: Space.x3,
      right: Space.x3,
      child: Semantics(
        link: true,
        label: UiStrings.attribution,
        child: GestureDetector(
          onTap: _openCopyright,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: Space.x3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              // Token colour, never a literal: surface at 85 percent alpha.
              color: colors.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(Radii.pill),
              border: Border.all(color: colors.line),
            ),
            child: Text(
              UiStrings.attribution,
              style: PontualText.caption.copyWith(
                fontSize: 12,
                color: colors.inkMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Opens the OSM copyright page in the system browser.
  Future<void> _openCopyright() async {
    final Uri uri = Uri.parse(osmCopyrightUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Recenter control, shown only after the user pans away.
class MapRecenterButton extends StatelessWidget {
  /// Creates the button.
  const MapRecenterButton({required this.onTap, super.key});

  /// Called when the control is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Positioned(
      right: Space.x3,
      bottom: Space.x3,
      child: MapCircleButton(
        icon: Icons.my_location_rounded,
        semanticLabel: UiStrings.recenter,
        fill: colors.surface,
        border: colors.line,
        onTap: onTap,
        iconSize: 20,
      ),
    );
  }
}

/// Circular map control with a hairline border and a token fill.
class MapCircleButton extends StatelessWidget {
  /// Creates the button.
  const MapCircleButton({
    required this.icon,
    required this.semanticLabel,
    required this.fill,
    required this.border,
    required this.onTap,
    this.iconSize = 22,
    super.key,
  });

  /// Icon drawn in the middle.
  final IconData icon;

  /// Screen-reader label, also used as the web tooltip.
  final String semanticLabel;

  /// Fill colour, from the token set.
  final Color fill;

  /// Hairline colour, from the token set.
  final Color border;

  /// Called on tap.
  final VoidCallback onTap;

  /// Icon size in dp.
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: Space.x3,
      left: Space.x3,
      child: Tooltip(
        message: semanticLabel,
        child: Semantics(
          label: semanticLabel,
          button: true,
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fill,
                shape: BoxShape.circle,
                border: Border.all(color: border),
              ),
              child: Icon(icon, size: iconSize, color: context.colors.ink),
            ),
          ),
        ),
      ),
    );
  }
}
