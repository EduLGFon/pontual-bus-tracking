// Local alert rules store. Tiny versioned JSON in shared_preferences,
// the storage the project already uses. Flagged off with the alerts UI.
// See docs/ui/UI_SPEC.md 6.3 and 13.2.
//
// D30: rules fire locally and in-app only. A rule triggers when its line
// has a live bus now (fresh vehicle on the line screen or live flag on
// home). No push channel, no server call, nothing leaves the device.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Pure alert matching. Returns the rules that fire now: active, weekday
/// matches (empty days means today only, always matches), and the line
/// is live. Callers pass the live line keys they already have; no data
/// is fetched here and nothing is sent anywhere.
List<AlertRuleVM> triggeredAlerts({
  required List<AlertRuleVM> rules,
  required Set<String> liveLineKeys,
  required DateTime now,
}) {
  final List<AlertRuleVM> out = <AlertRuleVM>[];
  for (final AlertRuleVM rule in rules) {
    if (!rule.active || rule.lineKey.isEmpty) {
      continue;
    }
    if (rule.days.isNotEmpty && !rule.days.contains(now.weekday)) {
      continue;
    }
    if (liveLineKeys.contains(rule.lineKey)) {
      out.add(rule);
    }
  }
  return out;
}

/// Alert rules state, loaded once and updated optimistically.
class AlertsNotifier extends Notifier<List<AlertRuleVM>> {
  @override
  List<AlertRuleVM> build() {
    unawaited(_load());
    return const <AlertRuleVM>[];
  }

  Future<void> _load() async {
    try {
      state = await const AlertsStore().read();
    } on Object {
      // Defaults (empty) stand when prefs are unavailable.
    }
  }

  /// Adds a rule.
  Future<void> add(AlertRuleVM rule) async {
    state = <AlertRuleVM>[...state, rule];
    await const AlertsStore().write(state);
  }

  /// Removes a rule.
  Future<void> remove(AlertRuleVM rule) async {
    state = state
        .where(
          (AlertRuleVM r) =>
              r.lineKey != rule.lineKey ||
              r.stopKey != rule.stopKey ||
              r.minutesBefore != rule.minutesBefore,
        )
        .toList();
    await const AlertsStore().write(state);
  }

  /// Forgets every rule.
  Future<void> clear() async {
    state = const <AlertRuleVM>[];
    await const AlertsStore().clear();
  }
}

/// Provides the alert rules.
final NotifierProvider<AlertsNotifier, List<AlertRuleVM>> alertsProvider =
    NotifierProvider<AlertsNotifier, List<AlertRuleVM>>(AlertsNotifier.new);
