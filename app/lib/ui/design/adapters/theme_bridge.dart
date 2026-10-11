// Theme bridge: applies the new ThemeData and the system overlay style for
// the current brightness. Nothing visible comes from Material defaults.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:pontual/ui/design/theme/theme.dart';
import 'package:pontual/data/prefs/theme_store.dart';
import 'package:pontual/ui/design/tokens/colors.dart';
import 'package:pontual/ui/shell/scroll_behavior.dart';

/// Builds the app widget with the new theme.
Widget pontualApp({required ThemeMode mode, required GoRouter router}) {
  return MaterialApp.router(
    title: 'Pontual',
    debugShowCheckedModeBanner: false,
    themeMode: mode,
    theme: _light(),
    darkTheme: _dark(),
    routerConfig: router,
    scrollBehavior: const PontualScrollBehavior(),
  );
}

ThemeData _light() {
  return _applyOverlays(pontualLightTheme(), Brightness.light);
}

ThemeData _dark() {
  return _applyOverlays(pontualDarkTheme(), Brightness.dark);
}

/// Sets edge-to-edge transparent system bars with the right icon brightness.
ThemeData _applyOverlays(ThemeData theme, Brightness brightness) {
  return theme.copyWith(
    extensions: <ThemeExtension<Object?>>[
      brightness == Brightness.dark ? PontualColors.dark : PontualColors.light,
    ],
    appBarTheme: theme.appBarTheme.copyWith(
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: brightness == Brightness.dark
            ? Brightness.dark
            : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
    ),
  );
}

/// Theme mode notifier wired to the existing ThemeStore.
class ThemeHost extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  /// Applies [mode] and persists it.
  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      await const ThemeStore().write(mode);
    } on Object {
      // The mode still applies for this run.
    }
  }
}

/// Provides the theme mode.
final NotifierProvider<ThemeHost, ThemeMode> themeHostProvider =
    NotifierProvider<ThemeHost, ThemeMode>(ThemeHost.new);
