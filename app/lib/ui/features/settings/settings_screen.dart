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
import 'package:pontual/ui/adapters/local_stores.dart';
import 'package:pontual/ui/design/adapters/theme_bridge.dart';
import 'package:pontual/ui/design/components/pontual_sheet.dart';
import 'package:pontual/ui/design/components/pressable.dart';
import 'package:pontual/ui/design/components/section_header.dart';
import 'package:pontual/ui/design/components/segmented.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
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
          padding: const EdgeInsets.fromLTRB(
            Space.x5,
            Space.x4,
            Space.x5,
            dockClearance,
          ),
          children: <Widget>[
            Text(UiStrings.settingsTitle, style: context.text.display),
            const SectionHeader(
              title: UiStrings.sectionAppearance,
              topSpacing: Space.x4,
            ),
            Padding(
              padding: const EdgeInsets.only(left: Space.x1),
              child: Text(UiStrings.theme, style: context.text.label),
            ),
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
            const SizedBox(height: Space.x4),
            _SwitchRow(
              label: UiStrings.dataSaver,
              hint: UiStrings.dataSaverHint,
              value: settings.dataSaver,
              onChanged: (bool value) =>
                  ref.read(settingsProvider.notifier).setDataSaver(value),
            ),
            const SizedBox(height: Space.x2),
            _SwitchRow(
              label: UiStrings.reduceMotion,
              value: settings.reduceMotion,
              onChanged: (bool value) =>
                  ref.read(settingsProvider.notifier).setReduceMotion(value),
            ),
            const SectionHeader(title: UiStrings.sectionSharing),
            _Row(
              icon: Icons.help_outline_rounded,
              label: UiStrings.howSharing,
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
              _Row(
                icon: Icons.battery_saver_rounded,
                label: UiStrings.batteryTips,
                onTap: () => _infoSheet(
                  context,
                  title: UiStrings.batteryTips,
                  lines: const <String>[UiStrings.batteryTip],
                ),
              ),
            _Row(
              icon: Icons.privacy_tip_outlined,
              label: UiStrings.privacyData,
              onTap: () => context.push('/privacy'),
            ),
            _Row(
              icon: Icons.info_outline_rounded,
              label: UiStrings.about,
              onTap: () => context.push('/about'),
            ),
            const InstallHintSlot(),
            const SizedBox(height: Space.x4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.x1),
              child: Text(
                '${UiStrings.versionPrefix} $appVersion'
                ' · ${UiStrings.timetablesPrefix}${date.value ?? '-'}',
                style: context.text.caption,
              ),
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

/// Navigation row: icon, label, chevron, 48 dp hit area, pt-BR label.
class _Row extends StatelessWidget {
  /// Creates the row for [label].
  const _Row({required this.icon, required this.label, required this.onTap});

  /// Leading icon.
  final IconData icon;

  /// Row label in pt-BR.
  final String label;

  /// Called on tap.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      borderRadius: Radii.l,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.x3),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: context.colors.inkMuted),
            const SizedBox(width: Space.x3),
            Expanded(child: Text(label, style: context.text.body)),
            const SizedBox(width: Space.x2),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: context.colors.inkSubtle,
            ),
          ],
        ),
      ),
    );
  }
}

/// Switch row with a label, an optional hint, and a 48 dp target.
class _SwitchRow extends StatelessWidget {
  /// Creates the row for [label].
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  /// Row label in pt-BR.
  final String label;

  /// Current value.
  final bool value;

  /// Called with the new value.
  final ValueChanged<bool> onChanged;

  /// Optional explanation under the label.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: context.text.body),
              if (hint != null) ...<Widget>[
                const SizedBox(height: Space.x1),
                Text(hint!, style: context.text.caption),
              ],
            ],
          ),
        ),
        Semantics(
          label: label,
          child: Switch(value: value, onChanged: onChanged),
        ),
      ],
    );
  }
}
