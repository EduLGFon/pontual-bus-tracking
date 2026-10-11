// ETA formatting in pure Dart, no Intl and no locale initialisation.
// Every branch returns the same three strings so no screen invents its own
// wording. Minutes are rounded up so "0 min" never appears.
// See docs/ui/UI_SPEC.md 5.1.
import 'package:pontual/domain/schedule.dart';
import 'package:pontual/ui/models/arrival_vm.dart';
import 'package:pontual/ui/models/certainty.dart';

/// The three strings an ETA is rendered with.
class EtaFormat {
  /// Creates the formatted ETA.
  const EtaFormat({
    required this.primary,
    required this.secondary,
    required this.a11y,
  });

  /// The hero text, for example `4 min`, `14:35` or `há 3 min`.
  final String primary;

  /// The supporting text, for example `em 12 min` or `Chegando`.
  final String secondary;

  /// The natural sentence a screen reader reads.
  final String a11y;
}

/// Formats an arrival for [now]. Both instants are São Mateus wall clock
/// held as UTC, the same convention as `saoMateusTime`.
EtaFormat formatEta(ArrivalVM arrival, DateTime now) {
  if (arrival.certainty == Certainty.stale) {
    return _staleFormat(arrival, now);
  }
  if (arrival.certainty == Certainty.scheduled) {
    return _scheduledFormat(arrival, now);
  }
  return _freshFormat(arrival, now);
}

EtaFormat _freshFormat(ArrivalVM arrival, DateTime now) {
  final bool predicted = arrival.certainty == Certainty.predicted;
  final int seconds = arrival.at.difference(now).inSeconds;
  final String prefix = predicted ? '~' : '';
  if (seconds < 60) {
    return EtaFormat(
      primary: '${prefix}Agora',
      secondary: 'Chegando',
      a11y: predicted
          ? 'Previsão: chega agora. Não é uma posição ao vivo.'
          : 'Chega agora, ao vivo.',
    );
  }
  if (seconds < 3600) {
    final int minutes = (seconds + 59) ~/ 60;
    final EtaFormat format = EtaFormat(
      primary: '$prefix$minutes min',
      secondary: formatClock(arrival.at),
      a11y: predicted
          ? 'Previsão: chega em cerca de $minutes ${_minutesWord(minutes)}. '
                'Não é uma posição ao vivo.'
          : 'Chega em $minutes ${_minutesWord(minutes)}, ao vivo.',
    );
    return format;
  }
  final int minutes = (seconds + 59) ~/ 60;
  final EtaFormat format = EtaFormat(
    primary: '$prefix${formatHours(minutes)}',
    secondary: formatClock(arrival.at),
    a11y: predicted
        ? 'Previsão: chega em ${_hoursPhrase(minutes)}. '
              'Não é uma posição ao vivo.'
        : 'Chega em ${_hoursPhrase(minutes)}, ao vivo.',
  );
  return format;
}

EtaFormat _scheduledFormat(ArrivalVM arrival, DateTime now) {
  final int minutes = minutesUntilClock(arrival.at, now);
  if (minutes <= 0) {
    return EtaFormat(
      primary: formatClock(arrival.at),
      secondary: 'já saiu',
      a11y: 'Saída às ${_clockPhrase(arrival.at)}, já saiu.',
    );
  }
  return EtaFormat(
    primary: formatClock(arrival.at),
    secondary: minutes < 60 ? 'em $minutes min' : 'em ${formatHours(minutes)}',
    a11y:
        'Próxima saída às ${_clockPhrase(arrival.at)}, '
        'em ${_minutesPhrase(minutes)}. Horário previsto pela tabela.',
  );
}

EtaFormat _staleFormat(ArrivalVM arrival, DateTime now) {
  final int ageS = now.difference(arrival.asOf).inSeconds.abs();
  if (ageS < 60) {
    return EtaFormat(
      primary: 'há $ageS s',
      secondary: 'Última posição',
      a11y: 'Última posição há $ageS segundos.',
    );
  }
  final int minutes = (ageS + 59) ~/ 60;
  final String word = minutes == 1 ? 'minuto' : 'minutos';
  return EtaFormat(
    primary: 'há $minutes min',
    secondary: 'Última posição',
    a11y: 'Última posição há $minutes $word.',
  );
}

/// Minutes from [now] to [at], negative when already gone.
int minutesUntilClock(DateTime at, DateTime now) {
  return at.difference(now).inMinutes;
}

/// `1 h 05`, the compact hour form used by every countdown.
String formatHours(int minutes) {
  final int h = minutes ~/ 60;
  final int m = minutes % 60;
  final String mm = m.toString().padLeft(2, '0');
  return '$h h $mm';
}

/// `14:35` from a São Mateus wall-clock instant.
String formatClock(DateTime instant) {
  final String hh = instant.hour.toString().padLeft(2, '0');
  final String mm = instant.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

/// "1 minuto" / "5 minutos".
String _minutesWord(int minutes) => minutes == 1 ? 'minuto' : 'minutos';

String _minutesPhrase(int minutes) => '$minutes ${_minutesWord(minutes)}';

String _hoursPhrase(int minutes) {
  final int h = minutes ~/ 60;
  final int m = minutes % 60;
  if (m == 0) {
    return '$h ${h == 1 ? 'hora' : 'horas'}';
  }
  final String word = _minutesWord(m);
  return '$h ${h == 1 ? 'hora' : 'horas'} e $m $word';
}

/// "14 e 35", how a screen reader should read a clock time.
String _clockPhrase(DateTime instant) {
  final String hh = instant.hour.toString();
  final String mm = instant.minute.toString();
  return '$hh e $mm';
}

/// True when an arrival is stale for [now].
bool isStaleArrival(ArrivalVM arrival, DateTime now) {
  return arrival.certainty == Certainty.stale ||
      (arrival.certainty != Certainty.scheduled &&
          now.difference(arrival.asOf).inSeconds > liveFreshS);
}

/// Grouping helper used by the timetable rail: hour label of an instant.
String hourLabelOf(DateTime instant) => instant.hour.toString().padLeft(2, '0');

/// Minute part of an HH:mm string, for the timetable rail.
int minuteOf(String hhmm) => minutesOf(hhmm) % 60;
