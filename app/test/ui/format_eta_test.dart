// Tests for the pure ETA formatter. Every branch of UI_SPEC 5.1.
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/ui/models/arrival_vm.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/util/format_eta.dart';

/// Reference instant: 14:23 São Mateus wall clock held as UTC.
final DateTime now = DateTime.utc(2026, 10, 14, 14, 23);

ArrivalVM arrival(Certainty certainty, DateTime at, {DateTime? asOf}) {
  return ArrivalVM(
    lineKey: '60-litoraneo-aviacao',
    at: at,
    certainty: certainty,
    asOf: asOf ?? now,
  );
}

void main() {
  test('live under a minute shows Agora', () {
    final EtaFormat f = formatEta(
      arrival(Certainty.live, now.add(const Duration(seconds: 30))),
      now,
    );
    expect(f.primary, 'Agora');
    expect(f.secondary, 'Chegando');
    expect(f.a11y, contains('ao vivo'));
  });

  test('predicted under a minute carries the tilde prefix', () {
    final EtaFormat f = formatEta(
      arrival(Certainty.predicted, now.add(const Duration(seconds: 30))),
      now,
    );
    expect(f.primary, '~Agora');
    expect(f.a11y, contains('Não é uma posição ao vivo'));
  });

  test('live under a minute is Agora, never zero minutes', () {
    final EtaFormat f = formatEta(
      arrival(Certainty.live, now.add(const Duration(seconds: 1))),
      now,
    );
    expect(f.primary, 'Agora');
    expect(f.primary.contains('0 min'), isFalse);
  });

  test('live minutes round up so a partial minute counts', () {
    final EtaFormat f = formatEta(
      arrival(Certainty.live, now.add(const Duration(seconds: 61))),
      now,
    );
    expect(f.primary, '2 min');
  });

  test('live one minute uses the singular', () {
    final EtaFormat f = formatEta(
      arrival(Certainty.live, now.add(const Duration(minutes: 1))),
      now,
    );
    expect(f.primary, '1 min');
    expect(f.secondary, '14:24');
  });

  test('live many minutes uses the plural', () {
    final EtaFormat f = formatEta(
      arrival(Certainty.live, now.add(const Duration(minutes: 4))),
      now,
    );
    expect(f.primary, '4 min');
    expect(f.a11y, contains('4 minutos'));
  });

  test('live over an hour uses the compact hour form', () {
    final EtaFormat f = formatEta(
      arrival(Certainty.live, now.add(const Duration(minutes: 65))),
      now,
    );
    expect(f.primary, '1 h 05');
    expect(f.secondary, '15:28');
  });

  test('predicted over an hour keeps the tilde', () {
    final EtaFormat f = formatEta(
      arrival(Certainty.predicted, now.add(const Duration(minutes: 60))),
      now,
    );
    expect(f.primary, '~1 h 00');
  });

  test('scheduled shows the clock time and a countdown', () {
    final EtaFormat f = formatEta(
      arrival(Certainty.scheduled, now.add(const Duration(minutes: 12))),
      now,
    );
    expect(f.primary, '14:35');
    expect(f.secondary, 'em 12 min');
    expect(f.a11y, contains('Horário previsto pela tabela'));
  });

  test('scheduled over an hour formats the countdown in hours', () {
    final EtaFormat f = formatEta(
      arrival(Certainty.scheduled, now.add(const Duration(minutes: 95))),
      now,
    );
    expect(f.secondary, 'em 1 h 35');
  });

  test('scheduled in the past says já saiu', () {
    final EtaFormat f = formatEta(
      arrival(Certainty.scheduled, now.subtract(const Duration(minutes: 5))),
      now,
    );
    expect(f.primary, '14:18');
    expect(f.secondary, 'já saiu');
    expect(f.a11y, contains('já saiu'));
  });

  test('scheduled at the current minute says agora', () {
    final EtaFormat f = formatEta(
      arrival(Certainty.scheduled, now),
      now.add(const Duration(seconds: 30)),
    );
    expect(f.primary, '14:23');
    expect(f.secondary, 'agora');
    expect(f.a11y, contains('agora'));
  });

  test('stale shows the age', () {
    final EtaFormat f = formatEta(
      arrival(
        Certainty.stale,
        now,
        asOf: now.subtract(const Duration(seconds: 200)),
      ),
      now,
    );
    expect(f.primary, 'há 4 min');
    expect(f.secondary, 'Última posição');
  });

  test('stale under a minute uses seconds', () {
    final EtaFormat f = formatEta(
      arrival(
        Certainty.stale,
        now,
        asOf: now.subtract(const Duration(seconds: 20)),
      ),
      now,
    );
    expect(f.primary, 'há 20 s');
  });

  test('clock time reads as hour and minutes for screen readers', () {
    final EtaFormat f = formatEta(
      arrival(Certainty.scheduled, DateTime.utc(2026, 10, 14, 14, 35)),
      now,
    );
    expect(f.a11y, contains('14 e 35'));
  });

  test('negative seconds never appear', () {
    final EtaFormat f = formatEta(
      arrival(Certainty.live, now.subtract(const Duration(minutes: 30))),
      now,
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
      now.add(const Duration(minutes: 1)),
    );
    final ArrivalVM old = ArrivalVM(
      lineKey: 'x',
      at: now,
      certainty: Certainty.live,
      asOf: now.subtract(const Duration(seconds: 90)),
    );
    expect(isStaleArrival(fresh, now), isFalse);
    expect(isStaleArrival(old, now), isTrue);
  });

  test('arrival helpers never return negative seconds', () {
    expect(arrival(Certainty.live, now).secondsUntil(now), 0);
    expect(
      arrival(
        Certainty.live,
        now.add(const Duration(seconds: 5)),
      ).secondsUntil(now),
      5,
    );
  });
}
