// Android app download hint. Shown on Android web browsers so sharers
// get the native app (screen-off trips) instead of the foreground-only
// web trip. Tap downloads the latest release APK from GitHub releases.
// See PLAN.md 8.12 and T48.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Prefs key recording that the Android download hint was dismissed.
const String androidAppSeenKey = 'android_app_seen';

/// Latest release APK download. The release workflow uploads
/// app-release.apk alongside the AAB, so this stable name resolves.
const String androidApkUrl =
    '${UiStrings.repoUrl}/releases/latest/download/app-release.apk';

/// Returns true when the hint should show: Android web browser, not seen.
bool shouldShowAndroidAppDownload({
  required bool isWeb,
  required bool isAndroid,
  required bool seen,
}) {
  return isWeb && isAndroid && !seen;
}

/// Persists the Android hint dismissal.
class AndroidAppDownloadStore {
  /// Creates the store.
  const AndroidAppDownloadStore();

  /// True after the user dismissed the hint once.
  Future<bool> seen() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(androidAppSeenKey) ?? false;
  }

  /// Records the dismissal. Shown only once by design.
  Future<void> markSeen() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(androidAppSeenKey, true);
  }
}

/// Card with the native-app pitch and the APK download action.
class AndroidAppDownloadCard extends StatelessWidget {
  /// Creates the card. [onDismiss] records the dismissal.
  /// [openUrl] is injectable for tests; production opens the APK URL.
  const AndroidAppDownloadCard({
    required this.onDismiss,
    this.openUrl,
    super.key,
  });

  /// Called when the user dismisses the card.
  final VoidCallback onDismiss;

  /// Opens the download URL. Defaults to the system browser.
  final Future<void> Function(Uri uri)? openUrl;

  /// Downloads the latest release APK in the system browser.
  Future<void> download() async {
    final Uri uri = Uri.parse(androidApkUrl);
    if (openUrl != null) {
      await openUrl!(uri);
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: UiStrings.androidAppTitle,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Space.x3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Row(
                children: <Widget>[
                  Icon(Icons.android_rounded),
                  SizedBox(width: Space.x2),
                  Expanded(child: Text(UiStrings.androidAppTitle)),
                ],
              ),
              const SizedBox(height: Space.x1),
              const Text(UiStrings.androidAppBody),
              const SizedBox(height: Space.x2),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: onDismiss,
                    child: const Text(UiStrings.installHintDismiss),
                  ),
                  const SizedBox(width: Space.x2),
                  FilledButton(
                    onPressed: download,
                    child: const Text(UiStrings.androidAppDownload),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Slot placed at the top of Home and in Settings on web. Loads the
/// dismissal flag once and shows the card only to unseen Android browsers.
class AndroidAppDownloadSlot extends StatefulWidget {
  /// Creates the slot.
  const AndroidAppDownloadSlot({
    this.store = const AndroidAppDownloadStore(),
    super.key,
  });

  /// Store for tests.
  final AndroidAppDownloadStore store;

  @override
  State<AndroidAppDownloadSlot> createState() => _AndroidAppDownloadSlotState();
}

class _AndroidAppDownloadSlotState extends State<AndroidAppDownloadSlot> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    bool seen = true;
    try {
      seen = await widget.store.seen();
    } catch (_) {
      // Prefs unavailable: stay hidden rather than nagging.
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _show = shouldShowAndroidAppDownload(
        isWeb: kIsWeb,
        isAndroid: defaultTargetPlatform == TargetPlatform.android,
        seen: seen,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) {
      return const SizedBox.shrink();
    }
    return AndroidAppDownloadCard(
      onDismiss: () async {
        try {
          await widget.store.markSeen();
        } catch (_) {
          // Best effort only.
        }
        if (mounted) {
          setState(() {
            _show = false;
          });
        }
      },
    );
  }
}
