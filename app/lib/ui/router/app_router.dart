// Router of the new UI. Top-level destinations live in a
// StatefulShellRoute so each tab keeps its own state and the trip dock and
// navigation stay mounted. Detail routes are pushed on top of the shell.
// See docs/ui/UI_SPEC.md 6.6.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pontual/features/trip/trip_controller.dart';
import 'package:pontual/ui/design/gallery/gallery_screen.dart';
import 'package:pontual/ui/features/home/home_screen.dart';
import 'package:pontual/ui/features/line/line_screen.dart';
import 'package:pontual/ui/features/lines/lines_screen.dart';
import 'package:pontual/ui/features/search/search_screen.dart';
import 'package:pontual/ui/features/settings/about_screen.dart';
import 'package:pontual/ui/features/settings/privacy_screen.dart';
import 'package:pontual/ui/features/settings/settings_screen.dart';
import 'package:pontual/ui/features/system/system_screen.dart';
import 'package:pontual/ui/features/trip/trip_screen.dart';
import 'package:pontual/ui/router/page_transition.dart';
import 'package:pontual/ui/router/route_observer.dart';
import 'package:pontual/ui/shell/app_shell.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Builds the router of the new UI.
GoRouter buildUiRouter() {
  return GoRouter(
    initialLocation: '/',
    // Before the routes: the line screen closes its viewer stream while a
    // full page covers it. See DECISIONS.md#D77.
    observers: <NavigatorObserver>[appPageRouteObserver],
    errorBuilder: (BuildContext context, GoRouterState state) =>
        const SystemScreen(kind: SystemKind.notFound),
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder:
            (
              BuildContext context,
              GoRouterState state,
              StatefulNavigationShell navigationShell,
            ) {
              return AppShell(navigationShell: navigationShell);
            },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/',
                pageBuilder: (BuildContext context, GoRouterState state) =>
                    _page(key: 'home', child: const HomeScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/lines',
                pageBuilder: (BuildContext context, GoRouterState state) =>
                    _page(key: 'lines', child: const LinesScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/settings',
                pageBuilder: (BuildContext context, GoRouterState state) =>
                    _page(key: 'settings', child: const SettingsScreen()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/search',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _page(key: 'search', child: const SearchScreen()),
      ),
      GoRoute(
        path: '/line/:key',
        pageBuilder: (BuildContext context, GoRouterState state) => _page(
          key: 'line',
          child: LineScreen(
            lineKey: state.pathParameters['key'] ?? '',
            tab: state.uri.queryParameters['tab'],
          ),
        ),
      ),
      GoRoute(
        path: '/trip',
        pageBuilder: (BuildContext context, GoRouterState state) {
          final Object? extra = state.extra;
          final TripController? controller = extra is TripController
              ? extra
              : null;
          return _page(
            key: 'trip',
            child: controller == null
                ? const SystemScreen(kind: SystemKind.notFound)
                : TripRoute(controller: controller),
          );
        },
      ),
      GoRoute(
        path: '/privacy',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _page(key: 'privacy', child: const PrivacyScreen()),
        routes: <RouteBase>[
          GoRoute(
            path: 'policy',
            pageBuilder: (BuildContext context, GoRouterState state) => _page(
              key: 'policy',
              child: const PolicyTextScreen(kind: 'policy'),
            ),
          ),
          GoRoute(
            path: 'terms',
            pageBuilder: (BuildContext context, GoRouterState state) => _page(
              key: 'terms',
              child: const PolicyTextScreen(kind: 'terms'),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/about',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _page(key: 'about', child: const AboutScreen()),
      ),
      GoRoute(
        path: '/system/:kind',
        pageBuilder: (BuildContext context, GoRouterState state) {
          final SystemKind kind = systemKindOf(
            state.pathParameters['kind'] ?? 'maintenance',
          );
          return _page(
            key: 'system',
            child: SystemScreen(
              kind: kind,
              message: state.uri.queryParameters['message'] ?? '',
            ),
          );
        },
      ),
      if (_galleryEnabled)
        GoRoute(
          path: '/_gallery',
          pageBuilder: (BuildContext context, GoRouterState state) =>
              _page(key: 'gallery', child: const GalleryScreen()),
        ),
    ],
  );
}

/// Gallery route is compiled out of release builds.
bool get _galleryEnabled => kDebugMode;

/// Builds a transition page with the shared fade-through.
Page<void> _page({required String key, required Widget child}) {
  return CustomTransitionPage<void>(
    key: ValueKey<String>(key),
    child: child,
    transitionDuration: MotionDurationToken.base,
    reverseTransitionDuration: MotionDurationToken.fast,
    transitionsBuilder: fadeThroughTransition,
  );
}

/// Token indirection so the router does not import motion directly.
abstract class MotionDurationToken {
  /// Private constructor.
  const MotionDurationToken._();

  /// Enter duration.
  static const Duration base = Duration(milliseconds: 200);

  /// Exit duration.
  static const Duration fast = Duration(milliseconds: 140);
}

/// Provides the app title, used by the web document title.
String appTitle(String route) {
  return switch (route) {
    '/' => UiStrings.navHome,
    '/lines' => UiStrings.navLines,
    '/settings' => UiStrings.navSettings,
    '/search' => 'Buscar',
    _ => 'Pontual',
  };
}
