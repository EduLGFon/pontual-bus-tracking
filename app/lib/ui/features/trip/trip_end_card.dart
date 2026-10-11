// End card of a finished trip: the checkmark draws once over 400 ms and is
// skipped under reduced motion, the reason line comes only from the
// strings file, and the single action returns to the app.
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pontual/features/trip/trip_controller.dart';
import 'package:pontual/ui/design/components/buttons.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/motion.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// End card shown after a trip ends, with the reason for automatic ends.
class TripEndCard extends StatelessWidget {
  /// Creates the end card.
  const TripEndCard({
    required this.kind,
    this.detail,
    this.helpedTrips,
    super.key,
  });

  /// How the trip ended.
  final TripEndKind kind;

  /// Server detail for automatic ends, for example "idle".
  final String? detail;

  /// Device-only helped-trips count (D30 extra). Null hides the line.
  final int? helpedTrips;

  /// Reason line in pt-BR, taken only from the strings file.
  String get message {
    switch (kind) {
      case TripEndKind.user:
        return UiStrings.endTitle;
      case TripEndKind.automatic:
        return switch (detail) {
          'idle' => UiStrings.endIdle,
          'walking' => UiStrings.endWalking,
          _ => UiStrings.endMax,
        };
      case TripEndKind.permission:
        return detail == 'gps' ? UiStrings.endGps : UiStrings.endPermission;
      case TripEndKind.abuse:
        return UiStrings.endAbuse;
      case TripEndKind.server:
        return UiStrings.endServer;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.x6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _CheckMark(animate: !reduce),
              const SizedBox(height: Space.x6),
              Text(
                message,
                style: context.text.title,
                textAlign: TextAlign.center,
              ),
              if (helpedTrips != null && helpedTrips! > 0) ...<Widget>[
                const SizedBox(height: Space.x3),
                Text(
                  '${UiStrings.kudosPrefix} ${helpedTrips!} ${UiStrings.kudosSuffix}',
                  style: context.text.body,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: Space.x8),
              PrimaryButton(
                label: UiStrings.endBack,
                onPressed: () => context.go('/'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Duration of the end-card checkmark stroke.
const Duration _drawDuration = Duration(milliseconds: 400);

/// Checkmark that draws itself once over [_drawDuration]. Under reduced
/// motion the stroke is already complete, so nothing animates.
class _CheckMark extends StatelessWidget {
  /// Creates the checkmark, animated only when [animate] is true.
  const _CheckMark({required this.animate});

  /// Whether the stroke draws over time.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: animate ? _drawDuration : Duration.zero,
        curve: MotionCurves.enter,
        builder: (BuildContext context, double t, Widget? child) {
          return SizedBox(
            width: 96,
            height: 96,
            child: CustomPaint(
              painter: _CheckPainter(
                progress: t,
                color: context.colors.liveText,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Draws the end-card checkmark as a single stroke.
class _CheckPainter extends CustomPainter {
  /// Creates a painter for [progress] between 0 and 1.
  const _CheckPainter({required this.progress, required this.color});

  /// Fraction of the stroke already drawn.
  final double progress;

  /// Stroke colour.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final Path check = Path()
      ..moveTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.68)
      ..lineTo(size.width * 0.72, size.height * 0.36);
    final PathMetric metric = check.computeMetrics().first;
    canvas.drawPath(metric.extractPath(0, metric.length * progress), stroke);
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
