// VehicleRow: "Ônibus 1" numbered by display order, never by internal id.
// Shows the age, the speed, an optional personal ETA to the rider's stop, the
// certainty badge and an optional follow action. See docs/ui/UI_SPEC.md 5.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/components/certainty_badge.dart';
import 'package:pontual/ui/design/components/ghost_link.dart';
import 'package:pontual/ui/design/components/live_dot.dart';
import 'package:pontual/ui/design/components/surface_card.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/models/vehicle_vm.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// One vehicle in the sheet list.
class VehicleRow extends StatelessWidget {
  /// Creates a row.
  const VehicleRow({
    required this.vehicle,
    this.onTap,
    this.onFollow,
    this.selected = false,
    this.personalEta,
    this.personalEtaSemantic,
    this.personalEtaMuted = false,
    super.key,
  });

  /// Vehicle to show.
  final VehicleVM vehicle;

  /// Called when the row is tapped, to focus the map.
  final VoidCallback? onTap;

  /// Called by the follow action, when the feature is on.
  final VoidCallback? onFollow;

  /// Highlights the row when the marker is selected.
  final bool selected;

  /// ETA to the rider's stop, for example "~6 min até você". Null or empty
  /// hides the line.
  final String? personalEta;

  /// Screen-reader sentence for [personalEta]. It is appended to the row
  /// sentence and never repeats the visible label.
  final String? personalEtaSemantic;

  /// Draws [personalEta] in the muted colour instead of primary.
  final bool personalEtaMuted;

  @override
  Widget build(BuildContext context) {
    final int ordinal = vehicle.ordinal ?? 1;
    final String label = 'Ônibus $ordinal';
    final String age = _ageText(vehicle.ageSeconds);
    final String speed = vehicle.speedKmh == null
        ? ''
        : '${vehicle.speedKmh!.round()} km/h';
    final List<String> bits = <String>[age];
    if (speed.isNotEmpty) {
      bits.add(speed);
    }
    bits.add(UiStrings.aboard(vehicle.members));
    final String? eta = _nonEmpty(personalEta);
    final String? etaSemantic = _nonEmpty(personalEtaSemantic);
    final String a11y =
        '$label, atualizado há ${_ageWords(vehicle.ageSeconds)}, '
        '${vehicle.speedKmh?.round() ?? 0} quilômetros por hora, '
        '${UiStrings.aboard(vehicle.members)}.'
        '${etaSemantic == null ? '' : ' $etaSemantic'}';
    return SurfaceCard(
      onTap: onTap,
      selected: selected,
      semanticLabel: a11y,
      padding: const EdgeInsets.symmetric(
        horizontal: Space.x4,
        vertical: Space.x3,
      ),
      child: Row(
        children: <Widget>[
          LiveDot(certainty: vehicle.certainty),
          const SizedBox(width: Space.x2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(label, style: context.text.headline),
                const SizedBox(height: Space.x1),
                Text(bits.join(' · '), style: context.text.caption),
                if (eta != null) ...<Widget>[
                  const SizedBox(height: Space.x1),
                  Text(
                    eta,
                    style: context.text.label.copyWith(
                      color: personalEtaMuted
                          ? context.colors.inkMuted
                          : context.colors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Space.x2),
          CertaintyBadge(certainty: vehicle.certainty),
          if (onFollow != null) ...<Widget>[
            const SizedBox(width: Space.x1),
            GhostLink(label: UiStrings.follow, onTap: onFollow),
          ],
        ],
      ),
    );
  }
}

/// Null for a null or empty string, so optional copy never draws a gap.
String? _nonEmpty(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

/// "há 8 s" or "há 3 min".
String _ageText(int ageSeconds) {
  if (ageSeconds < 60) {
    return 'há $ageSeconds s';
  }
  return 'há ${(ageSeconds + 59) ~/ 60} min';
}

/// Full words for the screen-reader sentence.
String _ageWords(int ageSeconds) {
  if (ageSeconds < 60) {
    return '$ageSeconds segundos';
  }
  final int minutes = (ageSeconds + 59) ~/ 60;
  return '$minutes ${minutes == 1 ? 'minuto' : 'minutos'}';
}
