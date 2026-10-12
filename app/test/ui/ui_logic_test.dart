// Pure logic tests for the UI layer: colour contrast, ETA formatting,
// home helpers, line status, live arrivals, pace prediction and line
// categories. No widgets, no prefs, no network. Merged into one file so
// the suite pays a single test-process startup instead of seven.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/core/geo/geo.dart';
import 'package:pontual/data/realtime/vehicle_repository.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/domain/line_category.dart';
import 'package:pontual/domain/schedule.dart';
import 'package:pontual/ui/adapters/alerts_store.dart';
import 'package:pontual/ui/adapters/arrivals_adapter.dart';
import 'package:pontual/ui/adapters/vehicles_adapter.dart';
import 'package:pontual/ui/design/tokens/colors.dart';
import 'package:pontual/ui/design/tokens/line_colors.dart';
import 'package:pontual/ui/features/home/home_logic.dart';
import 'package:pontual/ui/features/lines/lines_logic.dart';
import 'package:pontual/ui/models/alert_rule.dart';
import 'package:pontual/ui/models/arrival_vm.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/models/line_status.dart';
import 'package:pontual/ui/models/line_vm.dart';
import 'package:pontual/ui/models/reliability.dart';
import 'package:pontual/ui/models/vehicle_vm.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:pontual/ui/util/contrast.dart';
import 'package:pontual/ui/util/format_eta.dart';

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

/// Reference instant for the ETA tests: 14:23 wall clock held as UTC.
final DateTime etaNow = DateTime.utc(2026, 10, 14, 14, 23);

ArrivalVM arrival(Certainty certainty, DateTime at, {DateTime? asOf}) {
  return ArrivalVM(
    lineKey: '60-litoraneo-aviacao',
    at: at,
    certainty: certainty,
    asOf: asOf ?? etaNow,
  );
}

/// Reference instant for the home tests: Wednesday 10:00 held as UTC.
final DateTime homeNow = DateTime.utc(2026, 10, 14, 10, 0);

ArrivalVM scheduledAt(DateTime at, {String? origin}) {
  return ArrivalVM(
    lineKey: '60-test',
    at: at,
    certainty: Certainty.scheduled,
    asOf: homeNow,
    originLabel: origin,
  );
}

StaticLine testLine({
  required List<Map<String, dynamic>> schedules,
  List<String> terminals = const <String>['Litorâneo', 'Aviação'],
}) {
  return StaticLine(
    id: 60,
    code: '60-test',
    short: '60',
    name: 'Litorâneo / Aviação',
    pilot: true,
    schedules: schedules,
    terminals: terminals,
  );
}

Map<String, dynamic> dayRow(String origin, List<String> times) {
  return <String, dynamic>{
    'day_type': 'weekday',
    'origin': origin,
    'times': times,
  };
}

/// Reference instant for the live-logic tests: 14:23 held as UTC.
final DateTime liveNow = DateTime.utc(2026, 10, 14, 14, 23);

VehicleVM vehicle(int ageS, Certainty certainty) {
  return VehicleVM(
    key: ageS,
    lineKey: '60',
    lat: -18.72,
    lng: -39.85,
    headingDeg: 90,
    speedKmh: 29,
    ageSeconds: ageS,
    certainty: certainty,
  );
}

void main() {
  group('contrast', () {
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
      for (final Color fill in <Color>[
        ...linePaletteLight,
        ...linePaletteDark,
      ]) {
        final Color text = lineBadgeTextOf(fill);
        final double ratio = contrastRatio(fill, text);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: 'badge text on $fill is ${ratio.toStringAsFixed(2)}',
        );
      }
    });

    test('category badge text reaches 4.5:1 in both themes', () {
      for (final Map<LineCategory, Color> palette in <Map<LineCategory, Color>>[
        lineCategoryLight,
        lineCategoryDark,
      ]) {
        for (final MapEntry<LineCategory, Color> entry in palette.entries) {
          final Color text = lineBadgeTextOf(entry.value);
          final double ratio = contrastRatio(entry.value, text);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                'category ${entry.key} text on ${entry.value} '
                'is ${ratio.toStringAsFixed(2)}',
          );
        }
      }
    });

    test(
      'line colours exclude pure green and the reserved predicted indigo',
      () {
        for (final Color fill in linePaletteLight) {
          expect(
            fill.g > fill.r && fill.g > fill.b && fill.g > 120,
            isFalse,
            reason: 'green is reserved for live: $fill',
          );
        }
      },
    );

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
  });

  group('format_eta', () {
    test('live under a minute shows Agora', () {
      final EtaFormat f = formatEta(
        arrival(Certainty.live, etaNow.add(const Duration(seconds: 30))),
        etaNow,
      );
      expect(f.primary, 'Agora');
      expect(f.secondary, 'Chegando');
      expect(f.a11y, contains('ao vivo'));
    });

    test('predicted under a minute carries the tilde prefix', () {
      final EtaFormat f = formatEta(
        arrival(Certainty.predicted, etaNow.add(const Duration(seconds: 30))),
        etaNow,
      );
      expect(f.primary, '~Agora');
      expect(f.a11y, contains('Não é uma posição ao vivo'));
    });

    test('live under a minute is Agora, never zero minutes', () {
      final EtaFormat f = formatEta(
        arrival(Certainty.live, etaNow.add(const Duration(seconds: 1))),
        etaNow,
      );
      expect(f.primary, 'Agora');
      expect(f.primary.contains('0 min'), isFalse);
    });

    test('live minutes round up so a partial minute counts', () {
      final EtaFormat f = formatEta(
        arrival(Certainty.live, etaNow.add(const Duration(seconds: 61))),
        etaNow,
      );
      expect(f.primary, '2 min');
    });

    test('live one minute uses the singular', () {
      final EtaFormat f = formatEta(
        arrival(Certainty.live, etaNow.add(const Duration(minutes: 1))),
        etaNow,
      );
      expect(f.primary, '1 min');
      expect(f.secondary, '14:24');
    });

    test('live many minutes uses the plural', () {
      final EtaFormat f = formatEta(
        arrival(Certainty.live, etaNow.add(const Duration(minutes: 4))),
        etaNow,
      );
      expect(f.primary, '4 min');
      expect(f.a11y, contains('4 minutos'));
    });

    test('live over an hour uses the compact hour form', () {
      final EtaFormat f = formatEta(
        arrival(Certainty.live, etaNow.add(const Duration(minutes: 65))),
        etaNow,
      );
      expect(f.primary, '1 h 05');
      expect(f.secondary, '15:28');
    });

    test('predicted over an hour keeps the tilde', () {
      final EtaFormat f = formatEta(
        arrival(Certainty.predicted, etaNow.add(const Duration(minutes: 60))),
        etaNow,
      );
      expect(f.primary, '~1 h 00');
    });

    test('scheduled shows the clock time and a countdown', () {
      final EtaFormat f = formatEta(
        arrival(Certainty.scheduled, etaNow.add(const Duration(minutes: 12))),
        etaNow,
      );
      expect(f.primary, '14:35');
      expect(f.secondary, 'em 12 min');
      expect(f.a11y, contains('Horário previsto pela tabela'));
    });

    test('scheduled over an hour formats the countdown in hours', () {
      final EtaFormat f = formatEta(
        arrival(Certainty.scheduled, etaNow.add(const Duration(minutes: 95))),
        etaNow,
      );
      expect(f.secondary, 'em 1 h 35');
    });

    test('scheduled in the past says já saiu', () {
      final EtaFormat f = formatEta(
        arrival(
          Certainty.scheduled,
          etaNow.subtract(const Duration(minutes: 5)),
        ),
        etaNow,
      );
      expect(f.primary, '14:18');
      expect(f.secondary, 'já saiu');
      expect(f.a11y, contains('já saiu'));
    });

    test('scheduled at the current minute says agora', () {
      final EtaFormat f = formatEta(
        arrival(Certainty.scheduled, etaNow),
        etaNow.add(const Duration(seconds: 30)),
      );
      expect(f.primary, '14:23');
      expect(f.secondary, 'agora');
      expect(f.a11y, contains('agora'));
    });

    test('stale shows the age', () {
      final EtaFormat f = formatEta(
        arrival(
          Certainty.stale,
          etaNow,
          asOf: etaNow.subtract(const Duration(seconds: 200)),
        ),
        etaNow,
      );
      expect(f.primary, 'há 4 min');
      expect(f.secondary, 'Última posição');
    });

    test('stale under a minute uses seconds', () {
      final EtaFormat f = formatEta(
        arrival(
          Certainty.stale,
          etaNow,
          asOf: etaNow.subtract(const Duration(seconds: 20)),
        ),
        etaNow,
      );
      expect(f.primary, 'há 20 s');
    });

    test('clock time reads as hour and minutes for screen readers', () {
      final EtaFormat f = formatEta(
        arrival(Certainty.scheduled, DateTime.utc(2026, 10, 14, 14, 35)),
        etaNow,
      );
      expect(f.a11y, contains('14 e 35'));
    });

    test('negative seconds never appear', () {
      final EtaFormat f = formatEta(
        arrival(Certainty.live, etaNow.subtract(const Duration(minutes: 30))),
        etaNow,
      );
      expect(f.primary, 'Agora');
      expect(f.primary.contains('-'), isFalse);
    });

    test('formatHours pads minutes', () {
      expect(formatHours(65), '1 h 05');
      expect(formatHours(605), '10 h 05');
    });

    test('isStaleArrival detects an old as-of', () {
      final ArrivalVM fresh = arrival(
        Certainty.live,
        etaNow.add(const Duration(minutes: 1)),
      );
      final ArrivalVM old = ArrivalVM(
        lineKey: 'x',
        at: etaNow,
        certainty: Certainty.live,
        asOf: etaNow.subtract(const Duration(seconds: 90)),
      );
      expect(isStaleArrival(fresh, etaNow), isFalse);
      expect(isStaleArrival(old, etaNow), isTrue);
    });

    test('arrival helpers never return negative seconds', () {
      expect(arrival(Certainty.live, etaNow).secondsUntil(etaNow), 0);
      expect(
        arrival(
          Certainty.live,
          etaNow.add(const Duration(seconds: 5)),
        ).secondsUntil(etaNow),
        5,
      );
    });
  });

  group('home_logic', () {
    test('subtitle dedupe collapses a repeated origin', () {
      expect(
        joinSubtitle(<String>['Litorâneo · Aviação', 'Aviação']),
        'Litorâneo · Aviação',
      );
    });

    test('subtitle dedupe drops empties and keeps order', () {
      expect(joinSubtitle(<String>['', '  ', 'B', 'A', 'B']), 'B · A');
      expect(joinSubtitle(<String>['', '']), isEmpty);
    });

    test('section title switches at the 15 minute boundary', () {
      expect(proximasSectionTitle(null, homeNow), UiStrings.nextDepartures);
      expect(
        proximasSectionTitle(homeNow.add(const Duration(minutes: 63)), homeNow),
        UiStrings.nextDepartures,
      );
      expect(
        proximasSectionTitle(homeNow.add(const Duration(minutes: 15)), homeNow),
        UiStrings.saindoAgora,
      );
      expect(
        proximasSectionTitle(
          homeNow.add(const Duration(minutes: 15, seconds: 1)),
          homeNow,
        ),
        UiStrings.nextDepartures,
      );
      expect(
        proximasSectionTitle(homeNow.add(const Duration(minutes: 6)), homeNow),
        UiStrings.saindoAgora,
      );
    });

    test('departure dedupe drops shown rows and keeps order', () {
      final DateTime first = homeNow.add(const Duration(minutes: 20));
      final DateTime second = homeNow.add(const Duration(minutes: 40));
      final List<String> rows = <String>[
        departureKey('a', null, first),
        departureKey('b', 'Aviação', second),
      ];
      final List<String> fresh = dropShownDepartures(rows, <String>{
        departureKey('a', null, first),
      }, (String row) => row);
      expect(fresh, <String>[departureKey('b', 'Aviação', second)]);
      expect(liveKey('a', null) == departureKey('a', null, first), isFalse);
    });

    test('shortcut state resolves live first', () {
      expect(
        resolveShortcutState(
          isLive: true,
          next: null,
          now: homeNow,
          hasTimetable: true,
        ),
        ShortcutCardState.live,
      );
    });

    test('shortcut state splits imminent from upcoming at 10 minutes', () {
      expect(
        resolveShortcutState(
          isLive: false,
          next: scheduledAt(homeNow.add(const Duration(minutes: 6))),
          now: homeNow,
          hasTimetable: true,
        ),
        ShortcutCardState.imminent,
      );
      expect(
        resolveShortcutState(
          isLive: false,
          next: scheduledAt(homeNow.add(const Duration(minutes: 63))),
          now: homeNow,
          hasTimetable: true,
        ),
        ShortcutCardState.upcoming,
      );
    });

    test('shortcut state without a next departure is explicit', () {
      expect(
        resolveShortcutState(
          isLive: false,
          next: null,
          now: homeNow,
          hasTimetable: true,
        ),
        ShortcutCardState.noneToday,
      );
      expect(
        resolveShortcutState(
          isLive: false,
          next: null,
          now: null,
          hasTimetable: false,
        ),
        ShortcutCardState.noData,
      );
    });

    test('direction label prefers the destination terminal', () {
      expect(
        directionLabel(
          terminals: const <String>['Litorâneo', 'Aviação'],
          originLabel: 'Aviação',
        ),
        'sentido Litorâneo',
      );
      expect(
        directionLabel(terminals: const <String>[], originLabel: 'Aviação'),
        'Aviação',
      );
      expect(
        directionLabel(
          terminals: const <String>['Litorâneo', 'Aviação'],
          originLabel: null,
        ),
        'Litorâneo · Aviação',
      );
      expect(
        directionLabel(terminals: const <String>[], originLabel: null),
        isNull,
      );
    });

    test('tomorrow lookup returns the first departure of the next day', () {
      final StaticLine line = testLine(
        schedules: <Map<String, dynamic>>[
          dayRow('Litorâneo', <String>['05:40', '10:20']),
          dayRow('Aviação', <String>['06:00', '11:00']),
        ],
      );
      // Thursday is a weekday in the fixture, so the first Litorâneo time.
      expect(firstDepartureTomorrow(line, 'Litorâneo', homeNow), '05:40');
      // Unknown origin falls back to the merged timetable.
      expect(firstDepartureTomorrow(line, 'Xyz', homeNow), '05:40');
      expect(
        firstDepartureTomorrow(
          testLine(schedules: const <Map<String, dynamic>>[]),
          null,
          homeNow,
        ),
        isNull,
      );
    });
  });

  group('line_status', () {
    test('live wins over every timetable state', () {
      expect(
        resolveLineStatus(
          isLive: true,
          hasTimetable: false,
          next: null,
          nowMinutes: 600,
        ).kind,
        LineStatusKind.live,
      );
    });

    test('missing timetable is an honest state', () {
      expect(
        resolveLineStatus(
          isLive: false,
          hasTimetable: false,
          next: null,
          nowMinutes: 600,
        ).kind,
        LineStatusKind.noTimetable,
      );
    });

    test('current minute is now, under ten is imminent', () {
      expect(
        resolveLineStatus(
          isLive: false,
          hasTimetable: true,
          next: const NextDeparture(time: '10:00', isTomorrow: false),
          nowMinutes: 600,
        ).kind,
        LineStatusKind.now,
      );
      final LineStatus imminent = resolveLineStatus(
        isLive: false,
        hasTimetable: true,
        next: const NextDeparture(time: '10:06', isTomorrow: false),
        nowMinutes: 600,
      );
      expect(imminent.kind, LineStatusKind.imminent);
      expect(imminent.minutes, 6);
    });

    test('further departures stay upcoming with minutes', () {
      final LineStatus status = resolveLineStatus(
        isLive: false,
        hasTimetable: true,
        next: const NextDeparture(time: '11:03', isTomorrow: false),
        nowMinutes: 600,
      );
      expect(status.kind, LineStatusKind.upcoming);
      expect(status.minutes, 63);
    });

    test('tomorrow and none-today states are explicit', () {
      expect(
        resolveLineStatus(
          isLive: false,
          hasTimetable: true,
          next: const NextDeparture(time: '05:40', isTomorrow: true),
          nowMinutes: 1400,
        ).kind,
        LineStatusKind.tomorrow,
      );
      expect(
        resolveLineStatus(
          isLive: false,
          hasTimetable: true,
          next: null,
          nowMinutes: 1400,
        ).kind,
        LineStatusKind.noneToday,
      );
    });

    test('subtitle hides when every terminal is already in the title', () {
      expect(
        shouldShowTerminals('Centro / IFES / UFES', const <String>[
          'Centro',
          'IFES / UFES',
        ]),
        isFalse,
      );
      expect(
        shouldShowTerminals('Guriri via Beira Mar', const <String>[
          'Guriri',
          'Beira Mar',
        ]),
        isFalse,
      );
      expect(shouldShowTerminals('Bosque', const <String>['Bosque']), isFalse);
      expect(
        shouldShowTerminals('Linha especial', const <String>['Centro']),
        isTrue,
      );
    });
  });

  group('live_logic', () {
    test('live hero prefers the freshest live vehicle', () {
      final ArrivalVM? hero = liveHeroOf('60', <VehicleVM>[
        vehicle(30, Certainty.live),
        vehicle(4, Certainty.live),
      ], liveNow);
      expect(hero, isNotNull);
      expect(hero!.certainty, Certainty.live);
      expect(hero.at, liveNow);
    });

    test('predicted hero applies when nothing is live', () {
      final ArrivalVM? hero = liveHeroOf('60', <VehicleVM>[
        vehicle(90, Certainty.predicted),
      ], liveNow);
      expect(hero, isNotNull);
      expect(hero!.certainty, Certainty.predicted);
    });

    test('no hero without live or predicted vehicles', () {
      expect(
        liveHeroOf('60', <VehicleVM>[vehicle(400, Certainty.stale)], liveNow),
        isNull,
      );
      expect(liveHeroOf('60', const <VehicleVM>[], liveNow), isNull);
    });

    test('alerts fire only for active rules on live lines', () {
      final List<AlertRuleVM> rules = <AlertRuleVM>[
        const AlertRuleVM(lineKey: '60', minutesBefore: 5),
        const AlertRuleVM(lineKey: '61', minutesBefore: 5, active: false),
        const AlertRuleVM(lineKey: '62', minutesBefore: 5),
      ];
      final List<AlertRuleVM> fired = triggeredAlerts(
        rules: rules,
        liveLineKeys: <String>{'60', '61'},
        now: liveNow,
      );
      expect(fired.map((AlertRuleVM r) => r.lineKey), <String>['60']);
    });

    test('alert weekday filter respects repeat days', () {
      // 2026-10-14 is a Wednesday (weekday 3).
      const AlertRuleVM rule = AlertRuleVM(
        lineKey: '60',
        minutesBefore: 5,
        days: <int>[1],
      );
      expect(
        triggeredAlerts(
          rules: const <AlertRuleVM>[rule],
          liveLineKeys: <String>{'60'},
          now: liveNow,
        ),
        isEmpty,
      );
    });

    test('reliability hides below two sightings', () {
      expect(
        reliabilityOf(
          passages: const <int>[100],
          headwayMin: null,
          scheduledHeadwayMin: 10,
        ),
        isNull,
      );
    });

    test('reliability delay is actual minus scheduled, floored', () {
      final ReliabilityVM? r = reliabilityOf(
        passages: const <int>[0, 900, 2100],
        headwayMin: 17.5,
        scheduledHeadwayMin: 15,
      );
      expect(r, isNotNull);
      expect(r!.typicalDelayMin, 3);
      expect(r.sampleSize, 3);
      expect(r.bars.length, 2);
      const ReliabilityVM? early = null;
      expect(
        reliabilityOf(
          passages: const <int>[0, 600],
          headwayMin: 10,
          scheduledHeadwayMin: 15,
        )?.typicalDelayMin,
        0,
      );
      expect(early, isNull);
    });

    test('scheduled headway is the median timetable gap', () {
      expect(scheduledHeadwayOf(const <String>['05:30', '06:00', '06:30']), 30);
      expect(scheduledHeadwayOf(const <String>['05:30']), isNull);
    });
  });

  group('pace_prediction', () {
    test('7-field rows parse with null pace', () {
      final ClientVehicle v = ClientVehicle.fromRow(<dynamic>[
        3,
        -18.72,
        -39.85,
        90,
        29.0,
        1,
        4,
      ]);
      expect(v.paceKmh, isNull);
      expect(v.kmh, 29.0);
    });

    test('8-field rows parse the pace', () {
      final ClientVehicle v = ClientVehicle.fromRow(<dynamic>[
        3,
        -18.72,
        -39.85,
        90,
        29.0,
        1,
        4,
        25.5,
      ]);
      expect(v.paceKmh, 25.5);
    });

    test('fresh vehicles stay live at the real fix', () {
      final ClientVehicle v = ClientVehicle.fromRow(<dynamic>[
        3,
        -18.72,
        -39.85,
        90,
        29.0,
        1,
        4,
        25.5,
      ]);
      final vm = vehicleVmOf(v, lineKey: '60');
      expect(vm.certainty, Certainty.live);
      expect(vm.lat, -18.72);
      expect(vm.paceKmh, 25.5);
    });

    test('stale moving vehicles predict forward and are labeled', () {
      final ClientVehicle v = ClientVehicle.fromRow(<dynamic>[
        3,
        -18.72,
        -39.85,
        90,
        29.0,
        1,
        90,
        28.8,
      ]);
      final vm = vehicleVmOf(v, lineKey: '60');
      expect(vm.certainty, Certainty.predicted);
      // Eastward heading moves longitude forward, latitude stays.
      expect(vm.lng > -39.85, isTrue);
      expect((vm.lat - -18.72).abs() < 0.001, isTrue);
    });

    test('stopped buses never predict', () {
      final ClientVehicle v = ClientVehicle.fromRow(<dynamic>[
        3,
        -18.72,
        -39.85,
        90,
        0.0,
        1,
        90,
        0.0,
      ]);
      final vm = vehicleVmOf(v, lineKey: '60');
      expect(vm.certainty, Certainty.stale);
      expect(vm.lat, -18.72);
    });

    test('very old vehicles go stale, not predicted', () {
      final ClientVehicle v = ClientVehicle.fromRow(<dynamic>[
        3,
        -18.72,
        -39.85,
        90,
        29.0,
        1,
        400,
        28.8,
      ]);
      final vm = vehicleVmOf(v, lineKey: '60');
      expect(vm.certainty, Certainty.stale);
    });

    test('predictPosition mirrors the server dead reckoning', () {
      final LatLng p = predictPosition(-18.72, -39.85, 90, 8, 60);
      expect((p.lat - -18.72).abs() < 0.0005, isTrue);
      expect(p.lng > -39.85, isTrue);
      final LatLng still = predictPosition(-18.72, -39.85, null, 8, 60);
      expect(still.lat, -18.72);
      expect(still.lng, -39.85);
    });
  });

  group('line_category', () {
    test('explicit map wins over text mentions', () {
      expect(
        categoryFor(
          short: '62',
          name: 'Guriri / IFES / UFES',
          terminals: const <String>['Guriri', 'IFES / UFES'],
        ),
        LineCategory.ufes,
      );
      expect(
        categoryFor(
          short: '60',
          name: 'Litorâneo / Aviação',
          terminals: const <String>['Litorâneo', 'Aviação'],
        ),
        LineCategory.ufes,
      );
      expect(
        categoryFor(
          short: '64',
          name: 'Villages / Roberto Silvares',
          terminals: const <String>['Villages', 'Roberto Silvares'],
        ),
        LineCategory.ufes,
      );
    });

    test('guriri lines are yellow, including the 23 assumption', () {
      for (final String short in <String>['701', '70', '23']) {
        expect(
          categoryFor(
            short: short,
            name: 'Guriri',
            terminals: const <String>['Guriri'],
          ),
          LineCategory.guriri,
          reason: 'short $short',
        );
      }
    });

    test('text fallback is accent-insensitive', () {
      expect(
        categoryFor(
          short: '999',
          name: 'Centro / Ifes / Ufes',
          terminals: const <String>['Centro'],
        ),
        LineCategory.ufes,
      );
      expect(
        categoryFor(
          short: '999',
          name: 'Aroeira / Cohab',
          terminals: const <String>['Aroeira', 'Cohab'],
        ),
        LineCategory.aroeira,
      );
      expect(
        categoryFor(
          short: '12',
          name: 'Aroeira / Roberto Silvares',
          terminals: const <String>['Aroeira', 'Roberto Silvares'],
        ),
        LineCategory.aroeira,
      );
    });

    test('unknown lines are other and never throw', () {
      expect(
        categoryFor(
          short: '71',
          name: 'Norte Sul',
          terminals: const <String>['Norte', 'Sul'],
        ),
        LineCategory.other,
      );
      expect(
        categoryFor(short: '', name: '', terminals: const <String>[]),
        LineCategory.other,
      );
    });

    test('labels and order put UFES first and other last', () {
      expect(lineCategoryLabel(LineCategory.ufes), 'UFES / IFES');
      expect(lineCategoryLabel(LineCategory.guriri), 'Guriri');
      expect(lineCategoryLabel(LineCategory.other), 'Outras');
      expect(
        lineCategoryOrder(LineCategory.ufes) <
            lineCategoryOrder(LineCategory.guriri),
        isTrue,
      );
      expect(
        lineCategoryOrder(LineCategory.guriri) <
            lineCategoryOrder(LineCategory.other),
        isTrue,
      );
    });

    test('grouped lines emit headers with counts', () {
      LineVM vm(String short, String name) =>
          LineVM(key: short, name: name, short: short);
      final List<LinesListItem> items = groupedLines(<LineVM>[
        vm('66', 'Centro / IFES / UFES'),
        vm('70', 'Guriri via Praiano'),
        vm('71', 'Norte Sul'),
      ]);
      expect(items.length, 6);
      expect(items[0], isA<LinesHeaderItem>());
      expect((items[0] as LinesHeaderItem).category, LineCategory.ufes);
      expect((items[0] as LinesHeaderItem).count, 1);
      expect((items[1] as LinesLineItem).line.short, '66');
      expect((items[2] as LinesHeaderItem).category, LineCategory.guriri);
      expect((items[4] as LinesHeaderItem).category, LineCategory.other);
    });
  });
}
