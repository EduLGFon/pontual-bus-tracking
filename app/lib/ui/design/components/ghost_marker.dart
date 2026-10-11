// GhostMarker: the predicted position of a vehicle. Dashed ring, 25 %
// fill, `~` chip, spark icon, never a pulse. The real marker stays solid
// at the last known fix with its age; the ghost moves along the route at
// the predicted pace from the shared marker ticker and snaps to the real
// fix (200 ms) when one arrives. After ~2 min without a fix the prediction
// fades and the vehicle reads stale instead. Flagged off with predictions.
// See docs/ui/UI_SPEC.md 13.1.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/components/certainty_badge.dart';
import 'package:pontual/ui/design/components/vehicle_marker.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/models/vehicle_vm.dart';

/// Predicted-position marker with its `~` chip.
class GhostMarker extends StatelessWidget {
  /// Creates the ghost marker.
  const GhostMarker({
    required this.vehicle,
    required this.lineKey,
    this.onTap,
    super.key,
  });

  /// Predicted vehicle. Certainty is read from the marker style table,
  /// so callers pass through whatever the seam produced.
  final VehicleVM vehicle;

  /// Stable line key used to pick the colour.
  final String lineKey;

  /// Called when the marker is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Previsão: ônibus se movendo, não é uma posição ao vivo.',
      button: onTap != null,
      child: SizedBox(
        width: markerHitDp,
        height: markerHitDp + 22,
        child: Stack(
          alignment: Alignment.topCenter,
          children: <Widget>[
            Positioned(
              top: 22,
              child: VehicleMarker(
                vehicle: vehicle,
                lineKey: lineKey,
                onTap: onTap,
              ),
            ),
            const Positioned(
              top: 0,
              child: CertaintyBadge(
                certainty: Certainty.predicted,
                compact: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
