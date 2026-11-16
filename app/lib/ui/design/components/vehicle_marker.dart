// VehicleMarker: custom-painted 36 dp circle in the line colour with a
// surface ring, an optional heading triangle and the shared live pulse.
// One RepaintBoundary wraps the marker layer, not each marker.
// See docs/ui/UI_SPEC.md 7.5.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pontual/ui/design/icons/bus_icon.dart';
import 'package:pontual/ui/design/tokens/line_colors.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/models/vehicle_vm.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Marker body diameter in dp.
const double markerBodyDp = 36;

/// Marker hit area in dp.
const double markerHitDp = 60;

/// Heading arrow tip offset beyond the body radius, in dp.
const double headingArrowTipOffsetDp = 8;

/// Heading arrow half width at its base, in dp.
const double headingArrowHalfWidthDp = 4;

/// Heading arrow stroke width in dp.
const double headingArrowStrokeDp = 1.5;

/// Pulse ring start radius in dp.
const double markerPulseFromDp = 18;

/// Pulse ring end radius in dp.
const double markerPulseToDp = 30;

/// Marker for one vehicle.
class VehicleMarker extends StatelessWidget {
  /// Creates the marker.
  const VehicleMarker({
    required this.vehicle,
    required this.lineKey,
    this.selected = false,
    this.onTap,
    this.pulse,
    this.ringColor,
    this.glyphColor,
    super.key,
  });

  /// Vehicle to draw.
  final VehicleVM vehicle;

  /// Stable line key used to pick the colour.
  final String lineKey;

  /// Shows the larger scale and the stronger ring.
  final bool selected;

  /// Called when the marker is tapped.
  final VoidCallback? onTap;

  /// Shared pulse animation, from the same host as the dot.
  final Animation<double>? pulse;

  /// Ring colour, normally the surface token.
  final Color? ringColor;

  /// Bus glyph colour, computed for contrast by default.
  final Color? glyphColor;

  @override
  Widget build(BuildContext context) {
    final Color fill = lineColorOf(
      lineKey,
      brightness: Theme.of(context).brightness,
    );
    final Color ring = ringColor ?? Theme.of(context).colorScheme.surface;
    final Color glyph = glyphColor ?? lineBadgeTextOf(fill);
    final bool reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final bool pulseOn =
        vehicle.certainty == Certainty.live && pulse != null && !reduce;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        label: _label(),
        button: onTap != null,
        child: SizedBox(
          width: markerHitDp,
          height: markerHitDp,
          child: AnimatedBuilder(
            animation: pulseOn
                ? pulse!
                : const AlwaysStoppedAnimation<double>(0),
            builder: (BuildContext context, Widget? child) {
              return CustomPaint(
                painter: VehicleMarkerPainter(
                  fill: fill,
                  ring: ring,
                  glyph: glyph,
                  heading: vehicle.headingDeg,
                  showHeading: vehicle.showsHeading,
                  stale: vehicle.certainty == Certainty.stale,
                  dashed: vehicle.certainty == Certainty.predicted,
                  selected: selected,
                  pulse: pulseOn ? pulse!.value : 0,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _label() {
    final int ordinal = vehicle.ordinal ?? 1;
    final int ageS = vehicle.ageSeconds;
    final String age = ageS < 60 ? '$ageS s' : '${(ageS + 59) ~/ 60} min';
    return 'Ônibus $ordinal, há $age, ${UiStrings.aboard(vehicle.members)}';
  }
}

/// Paints the marker body, glyph, heading triangle and pulse ring.
class VehicleMarkerPainter extends CustomPainter {
  /// Creates the painter.
  const VehicleMarkerPainter({
    required this.fill,
    required this.ring,
    required this.glyph,
    required this.heading,
    required this.showHeading,
    required this.stale,
    required this.dashed,
    required this.selected,
    required this.pulse,
  });

  /// Body fill.
  final Color fill;

  /// Inner ring colour.
  final Color ring;

  /// Bus glyph colour.
  final Color glyph;

  /// Heading in degrees, null when unknown.
  final double? heading;

  /// Whether to draw the heading triangle.
  final bool showHeading;

  /// Grey, faded marker with no pulse.
  final bool stale;

  /// Dashed indigo ring for predicted positions.
  final bool dashed;

  /// Slightly larger with a stronger ring.
  final bool selected;

  /// Pulse phase, 0 to 1.
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = selected ? markerBodyDp * 0.56 : markerBodyDp * 0.5;
    final Color bodyFill = stale
        ? fill.withValues(alpha: 0.55)
        : dashed
        ? fill.withValues(alpha: 0.25)
        : fill;

    if (pulse > 0) {
      final double ringRadius =
          markerPulseFromDp + (markerPulseToDp - markerPulseFromDp) * pulse;
      canvas.drawCircle(
        center,
        ringRadius,
        Paint()..color = fill.withValues(alpha: 0.3 * (1 - pulse)),
      );
    }

    if (showHeading && heading != null) {
      final double rad = heading! * math.pi / 180;
      final Offset dir = Offset(math.sin(rad), -math.cos(rad));
      final Offset perp = Offset(-dir.dy, dir.dx);
      final Offset tip = center + dir * (radius + headingArrowTipOffsetDp);
      final Offset base = center + dir * (radius + 1);
      final Path arrow = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(
          base.dx - perp.dx * headingArrowHalfWidthDp,
          base.dy - perp.dy * headingArrowHalfWidthDp,
        )
        ..lineTo(
          base.dx + perp.dx * headingArrowHalfWidthDp,
          base.dy + perp.dy * headingArrowHalfWidthDp,
        )
        ..close();
      final Paint fillPaint = Paint()..color = fill;
      final Paint strokePaint = Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = headingArrowStrokeDp;
      canvas.drawPath(arrow, fillPaint);
      canvas.drawPath(arrow, strokePaint);
    }

    canvas.drawCircle(center, radius, Paint()..color = ring);
    canvas.drawCircle(center, radius - 2, Paint()..color = bodyFill);
    if (dashed) {
      _dashedRing(canvas, center, radius - 1);
    }

    final double glyphBox = selected ? 22 : 20;
    canvas.save();
    canvas.translate(center.dx - glyphBox / 2, center.dy - glyphBox / 2);
    BusIconPainter(
      color: glyph,
      filled: false,
    ).paint(canvas, Size.square(glyphBox));
    canvas.restore();
  }

  void _dashedRing(Canvas canvas, Offset center, double radius) {
    final Paint paint = Paint()
      ..color = fill
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final int segments = (2 * math.pi * radius / 7).floor();
    for (int i = 0; i < segments; i++) {
      final double start = (i / segments) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        0.45 * math.pi,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(VehicleMarkerPainter oldDelegate) {
    return oldDelegate.fill != fill ||
        oldDelegate.ring != ring ||
        oldDelegate.glyph != glyph ||
        oldDelegate.heading != heading ||
        oldDelegate.showHeading != showHeading ||
        oldDelegate.stale != stale ||
        oldDelegate.dashed != dashed ||
        oldDelegate.selected != selected ||
        oldDelegate.pulse != pulse;
  }
}
