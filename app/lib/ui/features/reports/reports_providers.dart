// Local "mine" tracking for reports. The server keeps no per-device view,
// so the app remembers which reports this session sent. Losing the set on
// restart only removes the retract shortcut; the public report stays until
// its TTL. See DECISIONS.md#D82.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/domain/reporting/report_kind.dart';

/// Stable key of one report target.
String reportKeyOf(int lineId, ReportKind kind, String? stop) {
  return '$lineId:${kind.wire}:${stop ?? '-'}';
}

/// In-memory set of report keys this device sent in this app session.
class MyReportsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  /// Marks a report as sent by this device.
  void mark(String key) {
    state = <String>{...state, key};
  }

  /// Forgets a report after a retract.
  void remove(String key) {
    if (!state.contains(key)) return;
    state = <String>{...state}..remove(key);
  }
}

/// Provides the local "mine" set.
final NotifierProvider<MyReportsNotifier, Set<String>> myReportsProvider =
    NotifierProvider<MyReportsNotifier, Set<String>>(MyReportsNotifier.new);
