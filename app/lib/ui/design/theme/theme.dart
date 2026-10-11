// ThemeData built once per brightness from the token extensions. Material 3
// is the base only: nothing visible comes from Material defaults. No
// splash factory, no ink ripples, transparent system overlays.
// See docs/ui/UI_SPEC.md 4.7.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/tokens/colors.dart';
import 'package:pontual/ui/design/tokens/text.dart';

/// Light theme with the Pontual token extensions attached.
ThemeData pontualLightTheme() {
  return _base(Brightness.light, PontualColors.light);
}

/// Dark theme with the Pontual token extensions attached.
ThemeData pontualDarkTheme() {
  return _base(Brightness.dark, PontualColors.dark);
}

ThemeData _base(Brightness brightness, PontualColors colors) {
  final ColorScheme scheme = ColorScheme(
    brightness: brightness,
    primary: colors.primary,
    onPrimary: colors.onPrimary,
    secondary: colors.primary,
    onSecondary: colors.onPrimary,
    error: colors.danger,
    onError: colors.surface,
    surface: colors.surface,
    onSurface: colors.ink,
  );
  final ThemeData base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    brightness: brightness,
    splashFactory: NoSplash.splashFactory,
    fontFamily: pontualFontFamily,
  );
  return base.copyWith(
    extensions: <ThemeExtension<Object?>>[colors],
    textTheme: _pontualTextTheme(),
    scaffoldBackgroundColor: colors.bg,
    canvasColor: colors.bg,
    dividerColor: colors.line,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: colors.primary,
      selectionColor: colors.primary.withValues(alpha: 0.2),
      selectionHandleColor: colors.primary,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: PontualText.title.copyWith(color: colors.ink),
      iconTheme: IconThemeData(color: colors.ink),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: colors.line,
      modalBackgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: PontualText.title.copyWith(color: colors.ink),
      contentTextStyle: PontualText.body.copyWith(color: colors.inkMuted),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: PontualText.caption.copyWith(color: colors.ink),
    ),
  );
}

/// Text theme built from [PontualText] so widget tests and the base theme
/// agree. Individual widgets still read styles from the context extension.
TextTheme _pontualTextTheme() {
  return const TextTheme(
    displayLarge: PontualText.etaHero,
    displayMedium: PontualText.etaLarge,
    displaySmall: PontualText.display,
    headlineLarge: PontualText.title,
    headlineMedium: PontualText.headline,
    titleLarge: PontualText.title,
    titleMedium: PontualText.headline,
    bodyLarge: PontualText.body,
    bodyMedium: PontualText.body,
    bodySmall: PontualText.caption,
    labelLarge: PontualText.label,
    labelMedium: PontualText.label,
    labelSmall: PontualText.caption,
  );
}
