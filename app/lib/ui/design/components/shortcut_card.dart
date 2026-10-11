// ShortcutCard: 156x112 card for a saved journey. Icon, label, line badge
// and the next arrival with its certainty. The empty variant is a ghost
// card with a dashed border that opens the add flow.
// See docs/ui/UI_SPEC.md 5 and 7.2.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/components/dashed_outline.dart';
import 'package:pontual/ui/design/components/eta_text.dart';
import 'package:pontual/ui/design/components/line_badge.dart';
import 'package:pontual/ui/design/components/pressable.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/models/arrival_vm.dart';
import 'package:pontual/ui/models/line_vm.dart';
import 'package:pontual/ui/models/shortcut_vm.dart';

/// A shortcut card.
class ShortcutCard extends StatelessWidget {
  /// Creates a card.
  const ShortcutCard({
    required this.label,
    required this.line,
    this.arrival,
    this.now,
    this.icon = Icons.place_outlined,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  /// Card label, for example "Casa".
  final String label;

  /// Line the shortcut points at.
  final LineVM line;

  /// Next arrival, when known.
  final ArrivalVM? arrival;

  /// Current instant, required with [arrival].
  final DateTime? now;

  /// Leading icon chosen by the shortcut kind.
  final IconData icon;

  /// Called on tap.
  final VoidCallback? onTap;

  /// Called on long press, for the edit and remove sheet.
  final VoidCallback? onLongPress;

  Widget _eta(BuildContext context) {
    final ArrivalVM? current = arrival;
    final DateTime? at = now;
    if (current == null || at == null) {
      return Text('--', style: context.text.etaLarge);
    }
    return EtaText.ofArrival(
      current,
      at,
      semanticLabel: '$label, linha ${line.name}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: label,
      borderRadius: Radii.l,
      child: Container(
        width: Sizes.shortcutWidth,
        constraints: const BoxConstraints(minHeight: Sizes.shortcutHeight),
        padding: const EdgeInsets.all(Space.x3),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(Radii.l),
          border: Border.all(color: context.colors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 18, color: context.colors.inkMuted),
                const SizedBox(width: Space.x1),
                Expanded(
                  child: Text(
                    label,
                    style: context.text.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.x3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                LineBadge.ofLine(line, size: BadgeSize.s),
                const Spacer(),
                Flexible(child: _eta(context)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Ghost card that opens the add flow with a kind preselected.
class AddShortcutCard extends StatelessWidget {
  /// Creates the card.
  const AddShortcutCard({
    required this.label,
    required this.onTap,
    this.icon = Icons.add_rounded,
    super.key,
  });

  /// Label in pt-BR, for example "Casa".
  final String label;

  /// Called on tap.
  final VoidCallback onTap;

  /// Leading icon.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      borderRadius: Radii.l,
      child: CustomPaint(
        painter: DashedOutline(
          color: colors.inkMuted,
          radius: Radii.l,
          strokeWidth: 1.5,
        ),
        child: Container(
          width: Sizes.shortcutWidth,
          constraints: const BoxConstraints(minHeight: Sizes.shortcutHeight),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(Space.x3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 22, color: colors.inkMuted),
              const SizedBox(height: Space.x1),
              Text(
                label,
                style: context.text.caption.copyWith(color: colors.inkMuted),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon of a shortcut kind.
IconData iconOfKind(ShortcutKind kind) {
  return switch (kind) {
    ShortcutKind.home => Icons.home_rounded,
    ShortcutKind.work => Icons.work_outline_rounded,
    ShortcutKind.school => Icons.school_outlined,
    ShortcutKind.university => Icons.menu_book_outlined,
    ShortcutKind.custom => Icons.place_outlined,
  };
}
