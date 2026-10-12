// Widget tests for the new search and lines screens. Deterministic: lines
// come from an overridden linesProvider, the live endpoint answers from a
// MockClient, prefs are mocked, and no network is hit.
// See docs/ui/UI_SPEC.md 7.3 and 7.4.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/ui/adapters/now_clock.dart';
import 'package:pontual/ui/design/components/toast.dart';
import 'package:pontual/ui/design/theme/theme.dart';
import 'package:pontual/ui/features/lines/favorites_store_bridge.dart';
import 'package:pontual/ui/features/lines/lines_screen.dart';
import 'package:pontual/ui/features/search/search_screen.dart';
import 'package:pontual/ui/shell/toast_host.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Two lines: a shareable one with a timetable and a plain one.
const String linesJson =
    '[{"id":60,"code":"60-litoraneo-aviacao","short":"60",'
    '"name":"Litorâneo / Aviação","pilot":true,'
    '"terminals":["Litorâneo","Aviação"],"area_tags":["aviation"],'
    '"schedules":[{"day_type":"weekday","origin":"Litorâneo",'
    '"times":["05:40","10:20","14:30"]}]},'
    '{"id":62,"code":"62-guriri","short":"62","name":"Guriri",'
    '"pilot":false,"terminals":["Guriri"],"area_tags":[],'
    '"schedules":[]}]';

/// Fixed São Mateus wall clock: Wednesday 10:00.
final DateTime fixedNow = DateTime.utc(2026, 10, 14, 10, 0);

/// Provider scope with deterministic lines and live answers.
Widget wrapTest(Widget app, {required String liveBody}) {
  final MockClient client = MockClient((http.Request req) async {
    if (req.url.path == '/v1/live') {
      return http.Response(liveBody, 200);
    }
    return http.Response('[]', 200);
  });
  return ProviderScope(
    overrides: [
      httpClientProvider.overrideWithValue(client),
      linesProvider.overrideWith(
        (Ref ref) async => StaticDataRepository(
          client: client,
          staticBaseUrl: () => 'https://x.example',
          bundleManifestJson: '{}',
          bundleLinesJson: linesJson,
          prefs: SharedPreferences.getInstance,
          nowMs: () => 0,
        ).lines(),
      ),
      currentNowProvider.overrideWith((Ref ref) => fixedNow),
    ],
    child: MaterialApp(theme: pontualLightTheme(), home: app),
  );
}

/// Router wrapper so the filter query parameter and row taps resolve.
Widget wrapRouter(String location, {String liveBody = '[[60,1]]'}) {
  final GoRouter router = GoRouter(
    initialLocation: location,
    routes: <GoRoute>[
      GoRoute(
        path: '/lines',
        builder: (BuildContext context, GoRouterState state) =>
            const LinesScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (BuildContext context, GoRouterState state) =>
            const SearchScreen(),
      ),
      GoRoute(
        path: '/line/:key',
        builder: (BuildContext context, GoRouterState state) => Scaffold(
          body: Center(child: Text('line:${state.pathParameters['key']}')),
        ),
      ),
    ],
  );
  return wrapTest(_RouterApp(router: router), liveBody: liveBody);
}

/// MaterialApp.router for the router wrapper.
class _RouterApp extends StatelessWidget {
  /// Creates the wrapper.
  const _RouterApp({required this.router});

  /// Router under test.
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(theme: pontualLightTheme(), routerConfig: router);
  }
}

/// One pump that flushes async providers and short animations. Fake time,
/// so the duration costs no wall time. Used instead of pumpAndSettle.
Future<void> settleOnce(WidgetTester tester) {
  return tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('SearchScreen', () {
    testWidgets('empty query, filtering and empty state', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'ui_recents_v1': <String>['62-guriri'],
      });
      await tester.pumpWidget(wrapTest(const SearchScreen(), liveBody: '[]'));
      await settleOnce(tester);
      expect(find.text(UiStrings.searchRecents), findsOneWidget);
      expect(find.text(UiStrings.searchSuggestions), findsOneWidget);
      expect(find.text('Guriri'), findsWidgets);
      // Accent-insensitive filtering with no network.
      await tester.enterText(find.byType(TextField), 'litoraneo');
      await settleOnce(tester);
      expect(find.text('Litorâneo / Aviação'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'gur');
      await settleOnce(tester);
      expect(find.text('Guriri'), findsWidgets);
      expect(find.text('Litorâneo / Aviação'), findsNothing);
      // No results show the empty state.
      await tester.enterText(find.byType(TextField), 'zzz');
      await settleOnce(tester);
      expect(find.text(UiStrings.searchEmptyTitle), findsOneWidget);
      expect(find.text(UiStrings.searchEmptyTip), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty query without recents shows only suggestions', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapTest(const SearchScreen(), liveBody: '[]'));
      await settleOnce(tester);
      expect(find.text(UiStrings.searchRecents), findsNothing);
      expect(find.text(UiStrings.searchSuggestions), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a row opens the line', (WidgetTester tester) async {
      await tester.pumpWidget(wrapRouter('/search'));
      await settleOnce(tester);
      await tester.enterText(find.byType(TextField), 'gur');
      await settleOnce(tester);
      await tester.tap(find.text('Guriri').first);
      await settleOnce(tester);
      expect(find.text('line:62-guriri'), findsOneWidget);
    });
  });

  group('LinesScreen', () {
    testWidgets('lists every line with counts and category headers', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapRouter('/lines'));
      await settleOnce(tester);
      expect(find.text(UiStrings.linesTitle), findsOneWidget);
      expect(
        find.text('2 ${UiStrings.linesCount} · 1 ${UiStrings.linesWithTimes}'),
        findsOneWidget,
      );
      expect(find.textContaining(UiStrings.linesWithTimes), findsOneWidget);
      expect(find.text('Litorâneo / Aviação'), findsOneWidget);
      // The timetable-less line shows the honest muted state.
      expect(find.text('Guriri'), findsOneWidget);
      expect(find.text(UiStrings.linesNoTimetable), findsOneWidget);
      expect(find.textContaining('UFES / IFES'), findsOneWidget);
      expect(find.text('${UiStrings.filterLive} (1)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('live filter shows only live lines, then the empty state', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapRouter('/lines?filter=live'));
      await settleOnce(tester);
      expect(find.text('Litorâneo / Aviação'), findsOneWidget);
      expect(find.text('Guriri'), findsNothing);
      await tester.pumpWidget(wrapRouter('/lines', liveBody: '[]'));
      await settleOnce(tester);
      await tester.tap(find.text(UiStrings.filterLive));
      await settleOnce(tester);
      expect(find.text(UiStrings.homeNoLive), findsOneWidget);
      expect(find.text(UiStrings.linesNoLiveBody), findsOneWidget);
    });

    testWidgets('star toggle persists and offers undo', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapRouter('/lines'));
      await settleOnce(tester);
      final BuildContext context = tester.element(find.byType(LinesScreen));
      final ProviderContainer container = ProviderScope.containerOf(context);
      expect(container.read(favoritesProvider), isEmpty);
      // Rows sort by category then number, so the first star is Litorâneo.
      await tester.tap(
        find.bySemanticsLabel(UiStrings.favoriteLine('60')).first,
      );
      await settleOnce(tester);
      expect(
        container.read(favoritesProvider).contains('60-litoraneo-aviacao'),
        isTrue,
      );
      // No shell toast slot in this harness, so assert the controller state.
      final ToastData? toast = container.read(toastControllerProvider).current;
      expect(toast?.message, UiStrings.linesFavAdded);
      expect(toast?.actionLabel, UiStrings.undo);
      toast?.onAction?.call();
      await settleOnce(tester);
      expect(container.read(favoritesProvider), isEmpty);
      await tester.tap(find.textContaining(UiStrings.filterFavorites));
      await settleOnce(tester);
      expect(find.text('Litorâneo / Aviação'), findsNothing);
      // Flush the favorites toast timer before teardown (fake time).
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('row tap opens the line', (WidgetTester tester) async {
      await tester.pumpWidget(wrapRouter('/lines'));
      await settleOnce(tester);
      await tester.tap(find.text('Guriri').first);
      await settleOnce(tester);
      expect(find.text('line:62-guriri'), findsOneWidget);
    });
  });
}
