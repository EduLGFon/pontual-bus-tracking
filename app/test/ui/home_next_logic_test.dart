// Pure tests for the timetable helpers shared by the Início shortcut cards
// and the "Sua próxima saída" hero. No widgets, no I/O.
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/ui/features/home/home_logic.dart';
import 'package:pontual/ui/models/arrival_vm.dart';
import 'package:pontual/ui/models/shortcut_vm.dart';

const String _line10 = '10-centro';
const String _line20 = '20-praia';

const List<StaticLine> _lines = <StaticLine>[
  StaticLine(
    id: 10,
    code: _line10,
    short: '10',
    name: 'Centro',
    pilot: true,
    terminals: <String>['Centro', 'Praia'],
    schedules: <Map<String, dynamic>>[
      <String, dynamic>{
        'day_type': 'weekday',
        'origin': 'Centro',
        'times': <String>['10:10', '12:00'],
      },
      <String, dynamic>{
        'day_type': 'weekday',
        'origin': 'Praia',
        'times': <String>['11:30'],
      },
    ],
  ),
  StaticLine(
    id: 20,
    code: _line20,
    short: '20',
    name: 'Praia',
    pilot: false,
    terminals: <String>['Praia'],
    schedules: <Map<String, dynamic>>[
      <String, dynamic>{
        'day_type': 'weekday',
        'origin': 'Praia',
        'times': <String>['10:05', '13:00'],
      },
    ],
  ),
];

final DateTime _morning = DateTime.utc(2026, 10, 14, 10, 0);
final DateTime _night = DateTime.utc(2026, 10, 14, 23, 0);

void main() {
  group('nextArrivalFor', () {
    test('honours the origin and falls back to the merged timetable', () {
      final StaticLine line = _lines.first;
      final ArrivalVM? praia = nextArrivalFor(line, 'Praia', _morning);
      expect(praia?.at, DateTime.utc(2026, 10, 14, 11, 30));
      expect(praia?.originLabel, 'Praia');

      final ArrivalVM? unknown = nextArrivalFor(line, 'Xyz', _morning);
      expect(unknown?.at, DateTime.utc(2026, 10, 14, 10, 10));
    });

    test('returns null when no departure remains today', () {
      expect(
        nextArrivalFor(
          _lines.first,
          'Centro',
          DateTime.utc(2026, 10, 14, 12, 1),
        ),
        isNull,
      );
    });
  });

  group('nextDepartureChoice', () {
    test('picks the earliest departure across favourites and shortcuts', () {
      final NextDepartureChoice? choice = nextDepartureChoice(
        favoriteKeys: const <String>{_line10},
        shortcuts: const <ShortcutVM>[
          ShortcutVM(
            kind: ShortcutKind.work,
            label: 'Trabalho',
            lineKey: _line20,
          ),
        ],
        statics: _lines,
        now: _morning,
      );
      expect(choice?.lineKey, _line20);
      expect(choice?.today?.at, DateTime.utc(2026, 10, 14, 10, 5));
    });

    test('dedupes a line and prefers the shortcut origin', () {
      final NextDepartureChoice? choice = nextDepartureChoice(
        favoriteKeys: const <String>{_line10},
        shortcuts: const <ShortcutVM>[
          ShortcutVM(
            kind: ShortcutKind.home,
            label: 'Casa',
            lineKey: _line10,
            originLabel: 'Praia',
          ),
        ],
        statics: _lines,
        now: _morning,
      );
      expect(choice?.lineKey, _line10);
      expect(choice?.originLabel, 'Praia');
      expect(choice?.today?.at, DateTime.utc(2026, 10, 14, 11, 30));
    });

    test('falls back to the earliest departure tomorrow', () {
      final NextDepartureChoice? choice = nextDepartureChoice(
        favoriteKeys: const <String>{_line10},
        shortcuts: const <ShortcutVM>[],
        statics: _lines,
        now: _night,
      );
      expect(choice?.isTomorrow, isTrue);
      expect(choice?.tomorrowAt, DateTime.utc(2026, 10, 15, 10, 10));
      expect(choice?.today, isNull);
    });

    test('returns null without candidates or known timetables', () {
      expect(
        nextDepartureChoice(
          favoriteKeys: const <String>{},
          shortcuts: const <ShortcutVM>[],
          statics: _lines,
          now: _morning,
        ),
        isNull,
      );
      expect(
        nextDepartureChoice(
          favoriteKeys: const <String>{'missing-line'},
          shortcuts: const <ShortcutVM>[],
          statics: _lines,
          now: _morning,
        ),
        isNull,
      );
    });
  });
}
