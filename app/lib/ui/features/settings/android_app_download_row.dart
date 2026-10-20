// Permanent Android download link for the web build. The one-time prompt
// covers Android browsers; this row keeps the APK reachable from Settings
// afterwards and on desktop. See D81.
import 'package:flutter/material.dart';
import 'package:pontual/platform/web/android_app_download.dart';
import 'package:pontual/ui/features/settings/settings_section.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Settings row that downloads the latest Android APK. Shown on web only:
/// inside the native Android app the link would be meaningless.
class AndroidAppDownloadRow extends StatelessWidget {
  /// Creates the row. [openUrl] is injectable for tests.
  const AndroidAppDownloadRow({this.openUrl, super.key});

  /// Opens the download URL. Defaults to the system browser.
  final Future<void> Function(Uri uri)? openUrl;

  @override
  Widget build(BuildContext context) {
    return SettingsTile.chevron(
      icon: Icons.android_rounded,
      title: UiStrings.androidAppDownloadRow,
      description: UiStrings.androidAppDownloadRowHint,
      onTap: () => openAndroidAppDownload(openUrl: openUrl),
    );
  }
}
