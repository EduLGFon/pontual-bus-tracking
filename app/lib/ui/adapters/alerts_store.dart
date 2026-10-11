// Local alert rules store. Tiny versioned JSON in shared_preferences,
// the storage the project already uses. Flagged off with the alerts UI.
// See docs/ui/UI_SPEC.md 6.3 and 13.2.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:pontual/ui/models/alert_rule.dart';

/// Storage key for the alert rules.
const String alertsKey = 'ui_alerts_v1';

/// Reads and writes alert rules. Corrupt JSON returns an empty list.
class AlertsStore {
  /// Creates the store.
  const AlertsStore();

  /// Reads the rules, oldest first.
  Future<List<AlertRuleVM>> read() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String raw = prefs.getString(alertsKey) ?? '';
    if (raw.isEmpty) {
      return const <AlertRuleVM>[];
    }
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(
            (dynamic e) => AlertRuleVM.fromJson(
              (e as Map<dynamic, dynamic>).cast<String, dynamic>(),
            ),
          )
          .toList();
    } on FormatException {
      return const <AlertRuleVM>[];
    }
  }

  /// Writes the rules.
  Future<void> write(List<AlertRuleVM> rules) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String raw = jsonEncode(
      rules.map((AlertRuleVM r) => r.toJson()).toList(),
    );
    await prefs.setString(alertsKey, raw);
  }

  /// Forgets every rule.
  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(alertsKey);
  }
}
