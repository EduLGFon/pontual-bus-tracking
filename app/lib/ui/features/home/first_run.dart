// First-run affordances of Início: the welcome card that opens the line
// picker. It dismisses into local prefs through the onboarding provider.
// See docs/ui/UI_SPEC.md 7.10.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pontual/ui/design/components/buttons.dart';
import 'package:pontual/ui/design/components/ghost_link.dart';
import 'package:pontual/ui/design/components/surface_card.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// One-time welcome card shown at the top of Início.
class WelcomeCard extends StatelessWidget {
  /// Creates the card. [onChoose] opens the line picker and [onDismiss]
  /// acknowledges the card for good.
  const WelcomeCard({
    required this.onChoose,
    required this.onDismiss,
    super.key,
  });

  /// Opens the line picker.
  final VoidCallback onChoose;

  /// Called when the rider prefers to look around first.
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
                  UiStrings.homeWelcomeTitle,
                  style: context.text.headline,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.x3),
          Text(
            UiStrings.homeWelcomeBody,
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
          PrimaryButton(
            label: UiStrings.homeWelcomeChoose,
            onPressed: onChoose,
          ),
          const SizedBox(height: Space.x1),
          Align(
            alignment: Alignment.center,
            child: GhostLink(
              label: UiStrings.homeWelcomeLater,
              onTap: onDismiss,
            ),
          ),
        ],
      ),
    );
  }
}
