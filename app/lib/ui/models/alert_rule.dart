// Alert rule for a future arrival notification. Data only, flagged off:
// the UI builds the sheet and the list, the backend push channel lands
// later. See docs/ui/UI_SPEC.md 13.2.
import 'package:flutter/foundation.dart';

/// One saved alert rule. Local only, never sent anywhere in alpha.
@immutable
class AlertRuleVM {
  /// Creates a rule.
  const AlertRuleVM({
    required this.lineKey,
    this.stopKey,
    required this.minutesBefore,
    this.days = const <int>[],
    this.active = true,
  });

  /// Stable line key the rule watches.
  final String lineKey;

  /// Stop or terminal key, null for the whole line.
  final String? stopKey;

  /// Minutes before the arrival to notify (2, 5 or 10 in the sheet).
  final int minutesBefore;

  /// Weekdays the rule repeats on, empty for today only.
  final List<int> days;

  /// False pauses the rule without deleting it.
  final bool active;

  /// Reads a rule. Unknown or wrong-typed values fall back to defaults,
  /// so a new field never breaks the app.
  factory AlertRuleVM.fromJson(Map<String, dynamic> json) {
    return AlertRuleVM(
      lineKey: json['line_key'] is String ? json['line_key'] as String : '',
      stopKey: json['stop_key'] is String ? json['stop_key'] as String : null,
      minutesBefore: json['minutes_before'] is int
          ? json['minutes_before'] as int
          : 5,
      days: json['days'] is List
          ? (json['days'] as List).whereType<int>().toList()
          : const <int>[],
      active: json['active'] is bool ? json['active'] as bool : true,
    );
  }

  /// Writes a rule.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'line_key': lineKey,
      'stop_key': stopKey,
      'minutes_before': minutesBefore,
      'days': days,
      'active': active,
    };
  }
}
