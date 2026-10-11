// Banner: inline strip for offline, maintenance and permission info. Never
// blocks input, appears and disappears with a height and fade transition.
// See docs/ui/UI_SPEC.md 5 and 10.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/motion.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/design/tokens/text.dart';

/// Tone of a banner.
enum BannerTone {
  /// Neutral information.
  info,

  /// Warning, for stale data or a GPS problem.
  warning,

  /// Danger, for something that stopped working.
  danger,
}

/// Inline strip with an icon, a message and an optional action.
class Banner extends StatelessWidget {
  /// Creates a banner.
  const Banner({
    required this.message,
    this.tone = BannerTone.info,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.semanticLabel,
    super.key,
  });

  /// Message in pt-BR.
  final String message;

  /// Tone, which sets the colours.
  final BannerTone tone;

  /// Leading icon.
  final IconData? icon;

  /// Optional trailing action label.
  final String? actionLabel;

  /// Called when the trailing action is tapped.
  final VoidCallback? onAction;

  /// Screen-reader label, defaults to [message].
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Color accent = switch (tone) {
      BannerTone.info => colors.ink,
      BannerTone.warning => colors.warningText,
      BannerTone.danger => colors.dangerText,
    };
    return Semantics(
      label: semanticLabel ?? message,
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: Space.x5,
          vertical: Space.x3,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceSunken,
          border: Border(bottom: BorderSide(color: colors.line)),
        ),
        child: Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: Space.x2),
            ],
            Expanded(
              child: Text(
                message,
                style: PontualText.caption.copyWith(color: colors.ink),
              ),
            ),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(width: Space.x2),
              GestureDetector(
                onTap: onAction,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.x2,
                    vertical: Space.x1,
                  ),
                  child: Text(
                    actionLabel!,
                    style: PontualText.label.copyWith(color: colors.primary),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Animated banner slot: grows into place with a 140 ms height and fade.
class BannerSlot extends StatelessWidget {
  /// Creates the slot.
  const BannerSlot({required this.banner, super.key});

  /// Banner to show, or null to keep the slot collapsed.
  final Widget? banner;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: Motion.fast,
      curve: MotionCurves.move,
      alignment: Alignment.topCenter,
      child: banner ?? const SizedBox(width: double.infinity),
    );
  }
}
