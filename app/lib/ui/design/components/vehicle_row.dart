// VehicleRow: "Ônibus 1" numbered by display order, never by internal id.
// Shows the age, the speed, the certainty badge and an optional follow
// action. See docs/ui/UI_SPEC.md 5.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/components/certainty_badge.dart';
import 'package:pontual/ui/design/components/ghost_link.dart';
import 'package:pontual/ui/design/components/live_dot.dart';
import 'package:pontual/ui/design/components/surface_card.dart';
import 'package:pontual/ui/models/certainty.dart';
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

  @override
  Widget build(BuildContext context) {
    final int ordinal = vehicle.ordinal ?? 1;
    final String label = 'Ônibus $ordinal';
    final String age = _ageText(vehicle.ageSeconds);
    final String speed = vehicle.speedKmh == null
        ? ''
        : '${vehicle.speedKmh!.round()} km/h';
    final String a11y =
        '$label, atualizado há ${_ageWords(vehicle.ageSeconds)}, '
        '${vehicle.speedKmh?.round() ?? 0} quilômetros por hora.';
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
          const LiveDot(certainty: Certainty.live),
          const SizedBox(width: Space.x2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(label, style: context.text.headline),
                const SizedBox(height: Space.x1),
                Text('$age · $speed', style: context.text.caption),
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
