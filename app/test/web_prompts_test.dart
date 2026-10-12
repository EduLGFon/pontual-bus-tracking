// Platform-gated web prompts: the iOS install hint (T39) and the
// Android app download card. Both show once, only on their unseen
// platform, and stay hidden on the test platform. Merged into one file
// so the suite pays a single test-process startup instead of two.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/platform/web/android_app_download.dart';
import 'package:pontual/platform/web/install_hint.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('shouldShowInstallHint', () {
    test('only unseen iOS web', () {
      expect(
        shouldShowInstallHint(isWeb: true, isIos: true, seen: false),
        isTrue,
      );
      expect(
        shouldShowInstallHint(isWeb: true, isIos: true, seen: true),
        isFalse,
      );
      expect(
        shouldShowInstallHint(isWeb: true, isIos: false, seen: false),
        isFalse,
      );
      expect(
        shouldShowInstallHint(isWeb: false, isIos: true, seen: false),
        isFalse,
      );
    });
  });

  group('InstallHintStore', () {
    test('round-trips the dismissal', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const InstallHintStore store = InstallHintStore();
      expect(await store.seen(), isFalse);
      await store.markSeen();
      expect(await store.seen(), isTrue);
    });
  });

  group('InstallHintCard', () {
    testWidgets('shows Safari steps and dismisses', (
      WidgetTester tester,
    ) async {
      bool dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InstallHintCard(onDismiss: () => dismissed = true),
          ),
        ),
      );
      expect(find.textContaining('Adicionar à Tela de Início'), findsOneWidget);
      await tester.tap(find.text('Entendi'));
      expect(dismissed, isTrue);
    });
  });

  group('InstallHintSlot', () {
    testWidgets('stays hidden off iOS web test platform', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: InstallHintSlot())),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(InstallHintCard), findsNothing);
    });
  });

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
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AndroidAppDownloadCard), findsNothing);
    });
  });
}
