// Contrast test for every colour token pair the UI uses. Fails below
// WCAG 2.2 AA: 4.5:1 for text, 3:1 for graphics. See UI_SPEC 4.1 and 12.6.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/ui/design/tokens/colors.dart';
import 'package:pontual/ui/design/tokens/line_colors.dart';
import 'package:pontual/ui/util/contrast.dart';

/// Foreground/background pairs that must reach 4.5:1.
const List<List<String>> textPairs = <List<String>>[
  <String>['ink', 'bg'],
  <String>['ink', 'surface'],
  <String>['ink', 'surfaceSunken'],
  <String>['inkMuted', 'bg'],
  <String>['inkMuted', 'surface'],
  <String>['inkMuted', 'surfaceSunken'],
  <String>['inkSubtle', 'bg'],
  <String>['inkSubtle', 'surface'],
  <String>['inkSubtle', 'surfaceSunken'],
  <String>['liveText', 'bg'],
  <String>['liveText', 'surface'],
  <String>['liveText', 'surfaceSunken'],
  <String>['predictedText', 'bg'],
  <String>['predictedText', 'surface'],
  <String>['predictedText', 'surfaceSunken'],
  <String>['warningText', 'bg'],
  <String>['warningText', 'surface'],
  <String>['warningText', 'surfaceSunken'],
  <String>['dangerText', 'bg'],
  <String>['dangerText', 'surface'],
  <String>['dangerText', 'surfaceSunken'],
  <String>['scheduled', 'bg'],
  <String>['scheduled', 'surface'],
  <String>['scheduled', 'surfaceSunken'],
  <String>['onPrimary', 'primary'],
];

/// Pairs that must reach 3:1 because they are graphics, not text.
const List<List<String>> graphicPairs = <List<String>>[
  <String>['live', 'bg'],
  <String>['live', 'surface'],
  <String>['live', 'surfaceSunken'],
  <String>['predicted', 'bg'],
  <String>['predicted', 'surface'],
  <String>['warning', 'bg'],
  <String>['warning', 'surface'],
  <String>['danger', 'bg'],
  <String>['danger', 'surface'],
  <String>['primary', 'bg'],
];

void main() {
  Color fieldOf(PontualColors colors, String name) {
    return switch (name) {
      'bg' => colors.bg,
      'surface' => colors.surface,
      'surfaceSunken' => colors.surfaceSunken,
      'surfaceRaised' => colors.surfaceRaised,
      'line' => colors.line,
      'ink' => colors.ink,
      'inkMuted' => colors.inkMuted,
      'inkSubtle' => colors.inkSubtle,
      'primary' => colors.primary,
      'onPrimary' => colors.onPrimary,
      'live' => colors.live,
      'liveText' => colors.liveText,
      'predicted' => colors.predicted,
      'predictedText' => colors.predictedText,
      'scheduled' => colors.scheduled,
      'warning' => colors.warning,
      'warningText' => colors.warningText,
      'danger' => colors.danger,
      'dangerText' => colors.dangerText,
      _ => throw ArgumentError('unknown token: $name'),
    };
  }

  for (final String theme in <String>['light', 'dark']) {
    final PontualColors colors = theme == 'light'
        ? PontualColors.light
        : PontualColors.dark;

    test('$theme text contrast reaches 4.5:1', () {
      for (final List<String> pair in textPairs) {
        final Color fg = fieldOf(colors, pair[0]);
        final Color bg = fieldOf(colors, pair[1]);
        final double ratio = contrastRatio(fg, bg);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason:
              '$theme ${pair[0]} on ${pair[1]} is ${ratio.toStringAsFixed(2)}',
        );
      }
    });

    test('$theme graphic contrast reaches 3:1', () {
      for (final List<String> pair in graphicPairs) {
        final Color fg = fieldOf(colors, pair[0]);
        final Color bg = fieldOf(colors, pair[1]);
        final double ratio = contrastRatio(fg, bg);
        expect(
          ratio,
          greaterThanOrEqualTo(3),
          reason:
              '$theme ${pair[0]} on ${pair[1]} is ${ratio.toStringAsFixed(2)}',
        );
      }
    });
  }

  test('line badge text reaches 4.5:1 on every palette fill', () {
    for (final Color fill in <Color>[...linePaletteLight, ...linePaletteDark]) {
      final Color text = lineBadgeTextOf(fill);
      final double ratio = contrastRatio(fill, text);
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason: 'badge text on $fill is ${ratio.toStringAsFixed(2)}',
      );
    }
  });

  test('line colours exclude pure green and the reserved predicted indigo', () {
    for (final Color fill in linePaletteLight) {
      expect(
        fill.g > fill.r && fill.g > fill.b && fill.g > 120,
        isFalse,
        reason: 'green is reserved for live: $fill',
      );
    }
  });

  test('line colours are deterministic per key', () {
    for (final String key in <String>[
      '60-litoraneo-aviacao',
      '62-guriri-ifes-ufes',
      'unknown-line',
    ]) {
      final Color first = lineColorOf(key, brightness: Brightness.light);
      final Color second = lineColorOf(key, brightness: Brightness.light);
      expect(first, second);
      expect(linePaletteLight.contains(first), isTrue);
    }
  });

  test('ensureContrast darkens a failing fill', () {
    final Color fixed = ensureContrast(
      const Color(0xFF7DD3FC),
      const Color(0xFF000000),
    );
    expect(
      contrastRatio(fixed, const Color(0xFF000000)),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('relative luminance matches the known black and white values', () {
    expect(relativeLuminance(const Color(0xFF000000)), closeTo(0, 1e-9));
    expect(relativeLuminance(const Color(0xFFFFFFFF)), closeTo(1, 1e-9));
  });
}
