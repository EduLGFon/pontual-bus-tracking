// EtaText: the hero number. Uses formatEta, tabular figures, and a width
// reserved so the digits never jitter. Digits stay in the ink colour;
// certainty is carried by the badge next to them.
// See docs/ui/UI_SPEC.md 5.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/motion.dart';
import 'package:pontual/ui/models/arrival_vm.dart';
import 'package:pontual/ui/util/format_eta.dart';

/// The big arrival number with its supporting line.
class EtaText extends StatelessWidget {
  /// Creates an ETA from pre-formatted strings.
  const EtaText({
    required this.primary,
    this.secondary,
    this.hero = false,
    this.dimmed = false,
    this.semanticLabel,
    super.key,
  });

  /// Builds an ETA from an arrival and the current instant.
  factory EtaText.ofArrival(
    ArrivalVM arrival,
    DateTime now, {
    bool hero = false,
    bool dimmed = false,
    String? semanticLabel,
  }) {
    final EtaFormat format = formatEta(arrival, now);
    return EtaText(
      primary: format.primary,
      secondary: format.secondary,
      hero: hero,
      dimmed: dimmed,
      semanticLabel: semanticLabel ?? format.a11y,
    );
  }

  /// The hero text, for example `4 min`.
  final String primary;

  /// Supporting text, for example `em 12 min`.
  final String? secondary;

  /// Uses the 56 dp hero size instead of 34 dp.
  final bool hero;

  /// Dims the text by colour alpha instead of an Opacity layer, used for
  /// past scheduled arrivals. See docs/ui/UI_SPEC.md 7.6 and 11.2.
  final bool dimmed;

  /// Screen-reader sentence.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final TextStyle primaryStyle =
        (hero ? context.text.etaHero : context.text.etaLarge).copyWith(
          color: dimmed ? context.colors.ink.withValues(alpha: 0.55) : null,
        );
    final TextStyle secondaryStyle = context.text.caption.copyWith(
      color: dimmed ? context.colors.inkSubtle.withValues(alpha: 0.55) : null,
    );
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ConstrainedBox(
            // Tabular figures keep the width stable; the constraint keeps
            // the row from moving when "4 min" becomes "1 h 05".
            constraints: BoxConstraints(minWidth: _widthFor(hero, primary)),
            child: AnimatedSwitcher(
              duration: Motion.fast,
              switchInCurve: MotionCurves.enter,
              switchOutCurve: MotionCurves.exit,
              transitionBuilder: (Widget child, Animation<double> animation) {
                final Animation<double> curved = CurvedAnimation(
                  parent: animation,
                  curve: MotionCurves.enter,
                );
                return FadeTransition(
                  opacity: curved,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.1),
                      end: Offset.zero,
                    ).animate(curved),
                    child: child,
                  ),
                );
              },
              child: Text(
                primary,
                key: ValueKey<String>(primary),
                style: primaryStyle,
                maxLines: 1,
              ),
            ),
          ),
          if (secondary != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              secondary!,
              style: secondaryStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// Approximate width needed by a value, so short strings do not shift the
/// layout when they grow. Characters are measured per style weight.
double _widthFor(bool hero, String value) {
  final double perChar = hero ? 30 : 18;
  return perChar * value.length.clamp(1, 7);
}
