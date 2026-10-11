// First-run affordances of Início: the one-time welcome card and the
// one-time dock coachmark bubble. Both dismiss into local prefs through
// the onboarding provider; the coachmark auto-dismisses after six seconds.
// See docs/ui/UI_SPEC.md 7.10.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pontual/ui/design/components/buttons.dart';
import 'package:pontual/ui/design/components/ghost_link.dart';
import 'package:pontual/ui/design/components/pressable.dart';
import 'package:pontual/ui/design/components/surface_card.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Seconds the coachmark stays before auto-dismissing.
const Duration _coachmarkDuration = Duration(seconds: 6);

/// One-time welcome card shown at the top of Início.
class WelcomeCard extends StatelessWidget {
  /// Creates the card. [onDismiss] acknowledges it for good.
  const WelcomeCard({required this.onDismiss, super.key});

  /// Called when the card is acknowledged.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.directions_bus_filled_rounded,
                color: context.colors.primary,
              ),
              const SizedBox(width: Space.x3),
              Expanded(
                child: Text(
                  UiStrings.welcomeTitle,
                  style: context.text.headline,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.x3),
          Text(
            UiStrings.welcomeBody,
            style: context.text.body.copyWith(color: context.colors.inkMuted),
          ),
          const SizedBox(height: Space.x2),
          Align(
            alignment: Alignment.centerLeft,
            child: GhostLink(
              label: UiStrings.welcomePrivacy,
              icon: Icons.privacy_tip_outlined,
              onTap: () => context.push('/privacy'),
            ),
          ),
          const SizedBox(height: Space.x2),
          PrimaryButton(label: UiStrings.ok, onPressed: onDismiss),
        ],
      ),
    );
  }
}

/// One-time coachmark bubble pointing at the dock, tap to dismiss.
class CoachmarkBubble extends StatefulWidget {
  /// Creates the coachmark. [onDismiss] fires on tap or auto-dismiss.
  const CoachmarkBubble({required this.onDismiss, super.key});

  /// Called on tap or after the auto-dismiss duration.
  final VoidCallback onDismiss;

  @override
  State<CoachmarkBubble> createState() => _CoachmarkBubbleState();
}

class _CoachmarkBubbleState extends State<CoachmarkBubble> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_coachmarkDuration, widget.onDismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: widget.onDismiss,
      semanticLabel: UiStrings.coachmark,
      borderRadius: Radii.m,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.x4,
                vertical: Space.x3,
              ),
              decoration: BoxDecoration(
                color: context.colors.surfaceRaised,
                borderRadius: BorderRadius.circular(Radii.m),
                border: Border.all(color: context.colors.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.touch_app_outlined,
                    size: 16,
                    color: context.colors.primary,
                  ),
                  const SizedBox(width: Space.x2),
                  Flexible(
                    child: Text(UiStrings.coachmark, style: context.text.label),
                  ),
                ],
              ),
            ),
          ),
          CustomPaint(
            size: const Size(16, 8),
            painter: _ArrowPainter(
              fill: context.colors.surfaceRaised,
              border: context.colors.line,
            ),
          ),
        ],
      ),
    );
  }
}

/// Downward-pointing triangle under the coachmark bubble.
class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({required this.fill, required this.border});

  /// Triangle fill, matching the bubble surface.
  final Color fill;

  /// Hairline colour of the bubble border.
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    final Path triangle = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(
      triangle,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawPath(triangle, Paint()..color = fill);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) {
    return oldDelegate.fill != fill || oldDelegate.border != border;
  }
}
