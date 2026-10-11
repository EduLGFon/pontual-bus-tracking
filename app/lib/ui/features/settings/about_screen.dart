// About screen of the new UI: the non-affiliation disclaimer, where the
// data comes from, the OpenStreetMap attribution, the open-source licences
// and the repository. Every external link opens in the system browser and
// every failure leaves the text on screen, so nothing is ever lost.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pontual/data/config/remote_config.dart';
import 'package:pontual/ui/design/components/section_header.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

import 'settings_row.dart';

/// About screen, in pt-BR, with no network calls of its own.
class AboutScreen extends ConsumerWidget {
  /// Creates the about screen.
  const AboutScreen({super.key});

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
            Text(UiStrings.about, style: context.text.display),
            Text(UiStrings.tagline, style: context.text.body),
            const SizedBox(height: Space.x4),
            Text(UiStrings.aboutDisclaimer, style: context.text.body),
            const SectionHeader(title: UiStrings.aboutSourcesTitle),
            Text(UiStrings.aboutSourceLines, style: context.text.body),
            const SizedBox(height: Space.x4),
            SettingsRow(
              icon: Icons.map_outlined,
              label: UiStrings.aboutOsm,
              onTap: () => _open(context, UiStrings.osmCopyrightUrl),
            ),
            SettingsRow(
              icon: Icons.description_outlined,
              label: UiStrings.aboutLicences,
              onTap: () => showLicensePage(
                context: context,
                applicationVersion: appVersion,
              ),
            ),
            SettingsRow(
              icon: Icons.code_rounded,
              label: UiStrings.aboutRepo,
              subtitle: UiStrings.repoUrl,
              onTap: () => _open(context, UiStrings.repoUrl),
            ),
            const SizedBox(height: Space.x4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.x1),
              child: Text(
                '${UiStrings.versionPrefix} $appVersion',
                style: context.text.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens [url] in the system browser. A failure keeps the row readable.
  Future<void> _open(BuildContext context, String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on Object {
      // Offline or no browser: the text and the URL stay on screen.
    }
  }
}
