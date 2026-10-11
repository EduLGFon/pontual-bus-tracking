// Android app download hint: shows once, only to unseen Android web,
// and the download button opens the latest release APK URL.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/platform/web/android_app_download.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('shouldShowAndroidAppDownload', () {
    test('only unseen Android web', () {
      expect(
        shouldShowAndroidAppDownload(isWeb: true, isAndroid: true, seen: false),
        isTrue,
      );
      expect(
        shouldShowAndroidAppDownload(isWeb: true, isAndroid: true, seen: true),
        isFalse,
      );
      expect(
        shouldShowAndroidAppDownload(
          isWeb: true,
          isAndroid: false,
          seen: false,
        ),
        isFalse,
      );
      expect(
        shouldShowAndroidAppDownload(
          isWeb: false,
          isAndroid: true,
          seen: false,
        ),
        isFalse,
      );
    });
  });

  group('androidApkUrl', () {
    test('points at the latest release APK', () {
      expect(
        androidApkUrl,
        '${UiStrings.repoUrl}/releases/latest/download/app-release.apk',
      );
    });
  });

  group('AndroidAppDownloadStore', () {
    test('round-trips the dismissal', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const AndroidAppDownloadStore store = AndroidAppDownloadStore();
      expect(await store.seen(), isFalse);
      await store.markSeen();
      expect(await store.seen(), isTrue);
    });
  });

  group('AndroidAppDownloadCard', () {
    testWidgets('download opens the APK URL and dismiss hides', (
      WidgetTester tester,
    ) async {
      Uri? opened;
      bool dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AndroidAppDownloadCard(
              onDismiss: () => dismissed = true,
              openUrl: (Uri uri) async {
                opened = uri;
              },
            ),
          ),
        ),
      );
      expect(find.text(UiStrings.androidAppTitle), findsOneWidget);
      await tester.tap(find.text(UiStrings.androidAppDownload));
      expect(opened, Uri.parse(androidApkUrl));
      await tester.tap(find.text(UiStrings.installHintDismiss));
      expect(dismissed, isTrue);
    });
  });

  group('AndroidAppDownloadSlot', () {
    testWidgets('stays hidden off Android web test platform', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AndroidAppDownloadSlot())),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AndroidAppDownloadCard), findsNothing);
    });
  });
}
