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
    primaryContainer: colors.surfaceSunken,
    onPrimaryContainer: colors.ink,
    secondary: colors.primary,
    onSecondary: colors.onPrimary,
    secondaryContainer: colors.surfaceSunken,
    onSecondaryContainer: colors.ink,
    tertiary: colors.live,
    onTertiary: colors.surface,
    tertiaryContainer: colors.surfaceSunken,
    onTertiaryContainer: colors.ink,
    error: colors.danger,
    onError: colors.surface,
    errorContainer: colors.surfaceSunken,
    onErrorContainer: colors.dangerText,
    surface: colors.surface,
    onSurface: colors.ink,
    surfaceDim: colors.bg,
    surfaceBright: colors.surfaceRaised,
    surfaceContainerLowest: colors.bg,
    surfaceContainerLow: colors.surfaceSunken,
    surfaceContainer: colors.surface,
    surfaceContainerHigh: colors.surface,
    surfaceContainerHighest: colors.surfaceRaised,
    onSurfaceVariant: colors.inkMuted,
    outline: colors.line,
    outlineVariant: colors.line,
    shadow: Colors.transparent,
    scrim: colors.scrim,
    inverseSurface: colors.ink,
    onInverseSurface: colors.surface,
    inversePrimary: colors.primary,
    surfaceTint: Colors.transparent,
  );
  final ThemeData base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    brightness: brightness,
    splashFactory: NoSplash.splashFactory,
    fontFamily: pontualFontFamily,
    applyElevationOverlayColor: false,
  );
  final TextTheme textTheme = _pontualTextTheme(colors);
  return base.copyWith(
    extensions: <ThemeExtension<Object?>>[colors],
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    scaffoldBackgroundColor: colors.bg,
    canvasColor: colors.bg,
    dividerColor: colors.line,
    dividerTheme: DividerThemeData(color: colors.line, thickness: 1, space: 1),
    iconTheme: IconThemeData(color: colors.ink),
    primaryIconTheme: IconThemeData(color: colors.ink),
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
      modalBackgroundColor: colors.surface,
      modalBarrierColor: colors.scrim,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: colors.line,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surfaceRaised,
      barrierColor: colors.scrim,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: PontualText.title.copyWith(color: colors.ink),
      contentTextStyle: PontualText.body.copyWith(color: colors.inkMuted),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    cardTheme: CardThemeData(
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: colors.inkMuted,
      textColor: colors.ink,
      titleTextStyle: PontualText.bodyStrong.copyWith(color: colors.ink),
      subtitleTextStyle: PontualText.caption.copyWith(color: colors.inkMuted),
    ),
    expansionTileTheme: ExpansionTileThemeData(
      iconColor: colors.inkMuted,
      collapsedIconColor: colors.inkMuted,
      textColor: colors.ink,
      collapsedTextColor: colors.ink,
      backgroundColor: Colors.transparent,
      collapsedBackgroundColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.surfaceRaised,
      contentTextStyle: PontualText.body.copyWith(color: colors.ink),
      actionTextColor: colors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.primary),
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: PontualText.body.copyWith(color: colors.inkSubtle),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) => states.contains(WidgetState.selected)
            ? colors.onPrimary
            : colors.inkMuted,
      ),
      thumbIcon: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) => states.contains(WidgetState.selected)
            ? Icon(Icons.check_rounded, size: 16, color: colors.primary)
            : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) => states.contains(WidgetState.selected)
            ? colors.primary
            : Colors.transparent,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) => states.contains(WidgetState.selected)
            ? Colors.transparent
            : colors.line,
      ),
      trackOutlineWidth: const WidgetStatePropertyAll<double>(2),
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
/// agree. Every style carries the token colour for [colors], so legacy
/// `Theme.of(context).textTheme` readers and bare `Text` widgets resolve to
/// ink in both brightnesses instead of the colourless default that rendered
/// as black on the dark surfaces.
TextTheme _pontualTextTheme(PontualColors colors) {
  return TextTheme(
    displayLarge: PontualText.etaHero.copyWith(color: colors.ink),
    displayMedium: PontualText.etaLarge.copyWith(color: colors.ink),
    displaySmall: PontualText.display.copyWith(color: colors.ink),
    headlineLarge: PontualText.title.copyWith(color: colors.ink),
    headlineMedium: PontualText.headline.copyWith(color: colors.ink),
    headlineSmall: PontualText.headline.copyWith(color: colors.ink),
    titleLarge: PontualText.title.copyWith(color: colors.ink),
    titleMedium: PontualText.headline.copyWith(color: colors.ink),
    titleSmall: PontualText.headline.copyWith(color: colors.ink),
    bodyLarge: PontualText.body.copyWith(color: colors.ink),
    bodyMedium: PontualText.body.copyWith(color: colors.ink),
    bodySmall: PontualText.caption.copyWith(color: colors.inkMuted),
    labelLarge: PontualText.label.copyWith(color: colors.ink),
    labelMedium: PontualText.label.copyWith(color: colors.ink),
    labelSmall: PontualText.caption.copyWith(color: colors.inkMuted),
  );
}
