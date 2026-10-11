// Colour tokens for the new UI. Deep pine brand with a mint signal colour.
// Contrast for every foreground/background pair is computed by
// test/ui/contrast_test.dart; the hex values here are the ones that pass
// WCAG 2.2 AA (4.5:1 text, 3:1 graphics). See docs/ui/UI_SPEC.md 4.1.
import 'package:flutter/material.dart';

/// Colour tokens consumed through Theme extensions. Widgets never hold a
/// raw colour: they read [PontualContext.colors].
@immutable
class PontualColors extends ThemeExtension<PontualColors> {
  /// Creates the light or dark token set.
  const PontualColors({
    required this.bg,
    required this.surface,
    required this.surfaceSunken,
    required this.surfaceRaised,
    required this.line,
    required this.ink,
    required this.inkMuted,
    required this.inkSubtle,
    required this.primary,
    required this.onPrimary,
    required this.live,
    required this.liveText,
    required this.predicted,
    required this.predictedText,
    required this.scheduled,
    required this.warning,
    required this.warningText,
    required this.danger,
    required this.dangerText,
    required this.scrim,
    required this.mapScrim,
  });

  /// Light theme tokens.
  static const PontualColors light = PontualColors(
    bg: Color(0xFFF6F5F1),
    surface: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFEDECE6),
    surfaceRaised: Color(0xFFFFFFFF),
    line: Color(0xFFE3E1D9),
    ink: Color(0xFF0F1B18),
    inkMuted: Color(0xFF44544F),
    inkSubtle: Color(0xFF5E6E69),
    primary: Color(0xFF0B3D36),
    onPrimary: Color(0xFFFFFFFF),
    live: Color(0xFF149B5C),
    liveText: Color(0xFF087443),
    predicted: Color(0xFF5B4BDB),
    predictedText: Color(0xFF4A3BC4),
    scheduled: Color(0xFF5E6E69),
    warning: Color(0xFFCC7006),
    warningText: Color(0xFFAD5009),
    danger: Color(0xFFC2362B),
    dangerText: Color(0xFFB42318),
    scrim: Color(0x660F1B18),
    mapScrim: Color(0x2EF6F5F1),
  );

  /// Dark theme tokens.
  static const PontualColors dark = PontualColors(
    bg: Color(0xFF0A1110),
    surface: Color(0xFF121B19),
    surfaceSunken: Color(0xFF0E1614),
    surfaceRaised: Color(0xFF1A2623),
    line: Color(0xFF26332F),
    ink: Color(0xFFEAF2EE),
    inkMuted: Color(0xFFA9B8B2),
    inkSubtle: Color(0xFF8A9A94),
    primary: Color(0xFF62E8B0),
    onPrimary: Color(0xFF07140F),
    live: Color(0xFF3DDC97),
    liveText: Color(0xFF6EE7B7),
    predicted: Color(0xFFA9A0FF),
    predictedText: Color(0xFFC4BEFF),
    scheduled: Color(0xFF8A9A94),
    warning: Color(0xFFFBBF24),
    warningText: Color(0xFFFBBF24),
    danger: Color(0xFFFF8A80),
    dangerText: Color(0xFFFF8A80),
    scrim: Color(0x99000000),
    mapScrim: Color(0x590A1110),
  );

  /// Screen background. Warm paper in light, near-black in dark.
  final Color bg;

  /// Cards, sheets, rows.
  final Color surface;

  /// Inputs, wells, chip backgrounds.
  final Color surfaceSunken;

  /// Dock, dialogs.
  final Color surfaceRaised;

  /// Hairline borders and dividers.
  final Color line;

  /// Primary text.
  final Color ink;

  /// Secondary text.
  final Color inkMuted;

  /// Tertiary text, still at 4.5:1 on every surface.
  final Color inkSubtle;

  /// Primary actions and key accents.
  final Color primary;

  /// Text on [primary].
  final Color onPrimary;

  /// Live dots, markers and rings.
  final Color live;

  /// Live text.
  final Color liveText;

  /// Predicted rings and dashed lines.
  final Color predicted;

  /// Predicted text.
  final Color predictedText;

  /// Timetable-only text and icons.
  final Color scheduled;

  /// Stale and notice graphics.
  final Color warning;

  /// Stale and notice text.
  final Color warningText;

  /// Destructive action and error graphics.
  final Color danger;

  /// Destructive action and error text.
  final Color dangerText;

  /// Modal scrim.
  final Color scrim;

  /// Subtle tint over map tiles.
  final Color mapScrim;

  @override
  PontualColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceSunken,
    Color? surfaceRaised,
    Color? line,
    Color? ink,
    Color? inkMuted,
    Color? inkSubtle,
    Color? primary,
    Color? onPrimary,
    Color? live,
    Color? liveText,
    Color? predicted,
    Color? predictedText,
    Color? scheduled,
    Color? warning,
    Color? warningText,
    Color? danger,
    Color? dangerText,
    Color? scrim,
    Color? mapScrim,
  }) {
    return PontualColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      line: line ?? this.line,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      inkSubtle: inkSubtle ?? this.inkSubtle,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      live: live ?? this.live,
      liveText: liveText ?? this.liveText,
      predicted: predicted ?? this.predicted,
      predictedText: predictedText ?? this.predictedText,
      scheduled: scheduled ?? this.scheduled,
      warning: warning ?? this.warning,
      warningText: warningText ?? this.warningText,
      danger: danger ?? this.danger,
      dangerText: dangerText ?? this.dangerText,
      scrim: scrim ?? this.scrim,
      mapScrim: mapScrim ?? this.mapScrim,
    );
  }

  @override
  PontualColors lerp(covariant PontualColors? other, double t) {
    if (other == null) {
      return this;
    }
    return PontualColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      line: Color.lerp(line, other.line, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      inkSubtle: Color.lerp(inkSubtle, other.inkSubtle, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      live: Color.lerp(live, other.live, t)!,
      liveText: Color.lerp(liveText, other.liveText, t)!,
      predicted: Color.lerp(predicted, other.predicted, t)!,
      predictedText: Color.lerp(predictedText, other.predictedText, t)!,
      scheduled: Color.lerp(scheduled, other.scheduled, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningText: Color.lerp(warningText, other.warningText, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerText: Color.lerp(dangerText, other.dangerText, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      mapScrim: Color.lerp(mapScrim, other.mapScrim, t)!,
    );
  }

  /// Graphic colour of a certainty, never the only signal for it.
  Color graphicOf(CertaintyTone tone) {
    return switch (tone) {
      CertaintyTone.live => live,
      CertaintyTone.predicted => predicted,
      CertaintyTone.scheduled => scheduled,
      CertaintyTone.stale => warning,
    };
  }

  /// Text colour of a certainty, always paired with a shape and a word.
  Color textOf(CertaintyTone tone) {
    return switch (tone) {
      CertaintyTone.live => liveText,
      CertaintyTone.predicted => predictedText,
      CertaintyTone.scheduled => scheduled,
      CertaintyTone.stale => warningText,
    };
  }
}

/// Certainty tones used by the colour table. Mirrors the Certainty enum in
/// the models without making tokens depend on them.
enum CertaintyTone {
  /// Measured by a rider phone in the last 45 s.
  live,

  /// Estimated, never presented as live.
  predicted,

  /// From the static timetable only.
  scheduled,

  /// Was live, no update for more than 45 s.
  stale,
}
