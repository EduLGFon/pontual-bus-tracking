// T30 tests: consent flow gating, versioning, and permission sheets.
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/core/errors/failures.dart';
import 'package:pontual/data/prefs/consent_store.dart';
import 'package:pontual/features/trip/consent_flow.dart';
import 'package:pontual/features/trip/consent_sheet.dart';
import 'package:pontual/features/trip/permission_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('declined consent posts nothing', () async {
    int posts = 0;
    final ConsentResult result = await ensureConsent(
      currentVersion: 1,
      store: const ConsentStore(),
      showSheet: () async => false,
      postConsents: () async {
        posts += 1;
        return const Ok<bool>(true);
      },
    );
    expect(result, ConsentResult.declined);
    expect(posts, 0);
    expect(await const ConsentStore().read(), isNull);
  });

  test('accepted consent posts and stores the version', () async {
    int posts = 0;
    final ConsentResult result = await ensureConsent(
      currentVersion: 1,
      store: const ConsentStore(),
      showSheet: () async => true,
      postConsents: () async {
        posts += 1;
        return const Ok<bool>(true);
      },
    );
    expect(result, ConsentResult.granted);
    expect(posts, 1);
    expect(await const ConsentStore().read(), 1);
  });

  test('offline acceptance stays pending with local record', () async {
    final ConsentResult result = await ensureConsent(
      currentVersion: 1,
      store: const ConsentStore(),
      showSheet: () async => true,
      postConsents: () async => const Err<bool>(NetworkFailure('offline')),
    );
    expect(result, ConsentResult.offlinePending);
    expect(await const ConsentStore().read(), 1);
  });

  test('covering unconfirmed version skips sheet but posts once', () async {
    await const ConsentStore().write(1);
    int posts = 0;
    int sheets = 0;
    final ConsentResult result = await ensureConsent(
      currentVersion: 1,
      store: const ConsentStore(),
      showSheet: () async {
        sheets += 1;
        return true;
      },
      postConsents: () async {
        posts += 1;
        return const Ok<bool>(true);
      },
    );
    expect(result, ConsentResult.granted);
    expect(sheets, 0);
    expect(posts, 1);
  });

  test('confirmed version skips sheet and post', () async {
    await const ConsentStore().write(1);
    await const ConsentStore().markPosted(1);
    int posts = 0;
    int sheets = 0;
    final ConsentResult result = await ensureConsent(
      currentVersion: 1,
      store: const ConsentStore(),
      showSheet: () async {
        sheets += 1;
        return true;
      },
      postConsents: () async {
        posts += 1;
        return const Ok<bool>(true);
      },
    );
    expect(result, ConsentResult.granted);
    expect(sheets, 0);
    expect(posts, 0);
  });

  test('covering version with failed reconcile stays pending', () async {
    await const ConsentStore().write(1);
    final ConsentResult result = await ensureConsent(
      currentVersion: 1,
      store: const ConsentStore(),
      showSheet: () async => true,
      postConsents: () async => const Err<bool>(NetworkFailure('offline')),
    );
    expect(result, ConsentResult.offlinePending);
    expect(await const ConsentStore().read(), 1);
  });

  test('version bump requires consent again', () async {
    await const ConsentStore().write(1);
    expect(await const ConsentStore().covers(2), isFalse);
  });

  testWidgets('consent sheet accepts and declines', (
    WidgetTester tester,
  ) async {
    bool? choice;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return ElevatedButton(
              onPressed: () async {
                choice =
                    await ConsentSheet.show(context) == ConsentChoice.accepted;
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Aceitar e continuar'), findsOneWidget);
    await tester.ensureVisible(find.text('Agora não'));
    await tester.tap(find.text('Agora não'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(choice, isFalse);
  });

  testWidgets('denied and blocked sheets expose their actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PermissionDeniedSheet()));
    expect(find.text('Tentar de novo'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: PermissionBlockedSheet()));
    expect(find.text('Abrir ajustes'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: PermissionInfoSheet()));
    expect(find.text('Continuar'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: LocationOffSheet()));
    expect(find.textContaining('Ative a localização'), findsOneWidget);
  });
}
