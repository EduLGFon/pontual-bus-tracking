// Settings screen of the new UI: appearance (theme, data saver, reduce
// animations), the sharing and privacy entries, the quiet install item the
// browser offers, and the version footer. No network calls: the theme and
// the toggles are local, the timetable date comes from the bundle.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/data/config/remote_config.dart';
import 'package:pontual/platform/web/install_hint.dart';
import 'package:pontual/platform/web/android_app_download.dart';
import 'package:pontual/ui/adapters/local_stores.dart';
import 'package:pontual/ui/design/adapters/theme_bridge.dart';
import 'package:pontual/ui/design/components/pontual_sheet.dart';
import 'package:pontual/ui/design/components/segmented.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/features/settings/settings_section.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:pontual/ui/util/platform.dart';

/// Settings screen. Every visible label comes from the strings file.
class SettingsScreen extends ConsumerWidget {
  /// Creates the settings screen.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode mode = ref.watch(themeHostProvider);
    final UiSettings settings = ref.watch(settingsProvider);
    final AsyncValue<String> date = ref.watch(timetableDateProvider);
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            marginFor(context),
            Space.x4,
            marginFor(context),
            dockClearance,
          ),
          children: <Widget>[
            Text(UiStrings.settingsTitle, style: context.text.title),
            SettingsSection(
              title: UiStrings.sectionAppearance,
              topSpacing: Space.x4,
              children: <Widget>[
                Text(UiStrings.theme, style: context.text.label),
                const SizedBox(height: Space.x2),
                Segmented(
                  segments: const <Segment>[
                    Segment(value: 'system', label: UiStrings.themeSystem),
                    Segment(value: 'light', label: UiStrings.themeLight),
                    Segment(value: 'dark', label: UiStrings.themeDark),
                  ],
                  value: _themeValue(mode),
                  onChanged: (String value) =>
                      ref.read(themeHostProvider.notifier).set(_modeOf(value)),
                ),
                const SizedBox(height: Space.x2),
                SettingsTile.toggle(
                  title: UiStrings.dataSaver,
                  description: UiStrings.dataSaverHint,
                  value: settings.dataSaver,
                  onChanged: (bool value) =>
                      ref.read(settingsProvider.notifier).setDataSaver(value),
                ),
                SettingsTile.toggle(
                  title: UiStrings.reduceMotion,
                  value: settings.reduceMotion,
                  onChanged: (bool value) =>
                      ref.read(settingsProvider.notifier).setReduceMotion(value),
                ),
              ],
            ),
            SettingsSection(
              title: UiStrings.sectionSharing,
              children: <Widget>[
                SettingsTile.chevron(
                  icon: Icons.help_outline_rounded,
                  title: UiStrings.howSharing,
                  onTap: () => _infoSheet(
                    context,
                    title: UiStrings.howSharing,
                    lines: const <String>[
                      UiStrings.consentBulletPurpose,
                      UiStrings.consentBulletNoIdentity,
                      UiStrings.consentBulletDeleted,
                      UiStrings.consentBulletOthers,
                      UiStrings.consentBulletControl,
                    ],
                  ),
                ),
                if (PlatformInfo.isAndroid)
                  SettingsTile.chevron(
                    icon: Icons.battery_saver_rounded,
                    title: UiStrings.batteryTips,
                    onTap: () => _infoSheet(
                      context,
                      title: UiStrings.batteryTips,
                      lines: const <String>[UiStrings.batteryTip],
                    ),
                  ),
                SettingsTile.chevron(
                  icon: Icons.privacy_tip_outlined,
                  title: UiStrings.privacyData,
                  onTap: () => context.push('/privacy'),
                ),
                SettingsTile.chevron(
                  icon: Icons.info_outline_rounded,
                  title: UiStrings.about,
                  onTap: () => context.push('/about'),
                ),
              ],
            ),
            const InstallHintSlot(),
            const AndroidAppDownloadSlot(),
            const SizedBox(height: Space.x4),
            Text(
              'Pontual $appVersion'
              ' · ${UiStrings.timetablesUpdatedPrefix}${date.value ?? '-'}',
              style: context.text.caption,
            ),
            const SizedBox(height: Space.x6),
          ],
        ),
      ),
    );
  }

  /// Query value of a theme mode, matching the segment values above.
  String _themeValue(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => 'system',
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
    };
  }

  /// Theme mode of a segment value.
  ThemeMode _modeOf(String value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  /// Opens a short explanation sheet with one line per bullet.
  void _infoSheet(
    BuildContext context, {
    required String title,
    required List<String> lines,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // Root navigator so the sheet slides above the shell dock pill. D-U26.
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (BuildContext context) => PontualSheet(
        title: title,
        scrollable: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final String line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.x3),
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
          ],
        ),
      ),
    );
  }
}
