// Privacy center of the new UI: the bundled policy and terms, what the app
// collects, revoking consent, and deleting the data this device left on
// the server. All server work goes through the existing PrivacyActions:
// this screen only presents the state and reports failures honestly.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/core/config/contact.dart';
import 'package:pontual/features/settings/privacy_actions.dart';
import 'package:pontual/features/settings/privacy_texts.dart';
import 'package:pontual/ui/design/adapters/theme_bridge.dart';
import 'package:pontual/ui/design/components/icon_btn.dart';
import 'package:pontual/ui/design/components/section_header.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/shell/toast_host.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:url_launcher/url_launcher.dart';

import 'settings_row.dart';

/// Privacy center. Reads rows from the strings file and the shared
/// collection summary; performs no work of its own beyond dialogs.
class PrivacyScreen extends ConsumerWidget {
  /// Creates the privacy center.
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.x5,
            vertical: Space.x4,
          ),
          children: <Widget>[
            Row(
              children: <Widget>[
                IconBtn(
                  icon: Icons.arrow_back_rounded,
                  semanticLabel: UiStrings.back,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: Space.x2),
                Expanded(
                  child: Text(
                    UiStrings.privacyData,
                    style: context.text.display,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.x4),
            SettingsRow(
              icon: Icons.policy_outlined,
              label: UiStrings.privacyPolicy,
              onTap: () => context.push('/privacy/policy'),
            ),
            SettingsRow(
              icon: Icons.description_outlined,
              label: UiStrings.privacyTerms,
              onTap: () => context.push('/privacy/terms'),
            ),
            const SectionHeader(title: UiStrings.privacyCollectsTitle),
            for (final String line in UiStrings.collectsSummary)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.x2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: context.colors.liveText,
                    ),
                    const SizedBox(width: Space.x2),
                    Expanded(child: Text(line, style: context.text.body)),
                  ],
                ),
              ),
            const SizedBox(height: Space.x4),
            SettingsRow(
              icon: Icons.restart_alt_rounded,
              label: UiStrings.privacyRevoke,
              onTap: () => unawaited(_revoke(context, ref)),
            ),
            SettingsRow(
              icon: Icons.delete_outline_rounded,
              label: UiStrings.privacyDelete,
              onTap: () => _delete(context, ref),
            ),
            if (supportEmail.isNotEmpty)
              SettingsRow(
                icon: Icons.mail_outline_rounded,
                label: UiStrings.contactUs,
                subtitle: supportEmail,
                onTap: () => unawaited(_mail(supportEmail)),
              ),
          ],
        ),
      ),
    );
  }

  /// Revokes consent through the existing actions and says so. Offline is
  /// not a failure here: the revocation is local and the next trip asks
  /// again.
  Future<void> _revoke(BuildContext context, WidgetRef ref) async {
    await PrivacyActions(api: ref.read(busApiProvider)).revokeConsent();
    if (!context.mounted) {
      return;
    }
    ref.read(toastControllerProvider.notifier).show(UiStrings.privacyRevoked);
  }

  /// Deletes the data this device left on the server. Offline reports the
  /// failure and leaves everything untouched: no fake success.
  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text(UiStrings.privacyDeleteTitle, style: context.text.title),
        content: Text(UiStrings.privacyDeleteBody, style: context.text.body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(UiStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(UiStrings.privacyConfirmDelete),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) {
      return;
    }
    final DeleteOutcome outcome = await PrivacyActions(
      api: ref.read(busApiProvider),
    ).deleteMyData();
    if (!context.mounted) {
      return;
    }
    if (outcome == DeleteOutcome.offline) {
      ref.read(toastControllerProvider.notifier).show(UiStrings.privacyOffline);
      return;
    }
    // Local storage is gone: start from the system theme again.
    unawaited(ref.read(themeHostProvider.notifier).set(ThemeMode.system));
    context.go('/');
  }

  /// Opens the system mail client for [email]. A failure keeps the address
  /// visible to copy.
  Future<void> _mail(String email) async {
    try {
      await launchUrl(Uri(scheme: 'mailto', path: email));
    } on Object {
      // No mail client: the address stays on screen.
    }
  }
}

/// Bundled policy or terms text. Works offline; the canonical web link is
/// added once the owner publishes the static domain.
// TODO(#infra-23): add the canonical link once policyUrl or termsUrl land.
class PolicyTextScreen extends StatelessWidget {
  /// Creates the text screen for [kind] (`policy` or `terms`).
  const PolicyTextScreen({required this.kind, super.key});

  /// Which text to show.
  final String kind;

  @override
  Widget build(BuildContext context) {
    final bool policy = kind == 'policy';
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.x5,
            vertical: Space.x4,
          ),
          children: <Widget>[
            Row(
              children: <Widget>[
                IconBtn(
                  icon: Icons.arrow_back_rounded,
                  semanticLabel: UiStrings.back,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: Space.x2),
                Expanded(
                  child: Text(
                    policy ? UiStrings.privacyPolicy : UiStrings.privacyTerms,
                    style: context.text.display,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.x4),
            Text(
              policy ? bundledPolicy : bundledTerms,
              style: context.text.body,
            ),
          ],
        ),
      ),
    );
  }
}
