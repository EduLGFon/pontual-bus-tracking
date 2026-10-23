// Log wrapper. Debug builds are verbose; release builds keep warnings and
// errors in an in-memory ring buffer and a persisted append-only list that
// is uploaded to our first-party server when the user opts in.
// PRIVACY: never log coordinates, tokens, session or user ids.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Log severity levels.
enum LogLevel {
  /// Verbose tracing for debug builds.
  debug,

  /// Noteworthy events for debug builds.
  info,

  /// Kept in the ring buffer.
  warning,

  /// Kept in the ring buffer.
  error,
}

/// Bounded in-memory record of one log line.
class LogRecord {
  /// Creates a log record.
  const LogRecord(this.level, this.message, this.context);

  /// Severity of the record.
  final LogLevel level;

  /// Short static message with no personal data.
  final String message;

  /// Optional safe context (route names, status codes, durations only).
  final String context;
}

/// Application logger with a redaction-by-construction API.
class Log {
  Log._();

  static const int _ringCap = 200;
  static final List<LogRecord> _ring = <LogRecord>[];
  static const String _persistKey = 'diag_logs_v1';
  static const int _persistCap = 500;

  /// Recent warnings and errors, newest last. For on-device debugging only.
  static List<LogRecord> get recent => List<LogRecord>.unmodifiable(_ring);

  /// Appends a record to the persisted list (best effort, never throws).
  static void _persist(LogRecord record) {
    unawaited(() async {
      try {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final List<String> raw =
            prefs.getStringList(_persistKey) ?? const <String>[];
        final List<String> next = List<String>.from(raw);
        next.add(jsonEncode(<String, dynamic>{
          'l': record.level == LogLevel.warning ? 'w' : 'e',
          'm': record.message,
          'c': record.context,
          't': DateTime.now().millisecondsSinceEpoch,
        }));
        while (next.length > _persistCap) {
          next.removeAt(0);
        }
        await prefs.setStringList(_persistKey, next);
      } on Object {
        // Never fail logging.
      }
    }());
  }

  /// Reads persisted records.
  static Future<List<Map<String, dynamic>>> readPersisted() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> raw =
          prefs.getStringList(_persistKey) ?? const <String>[];
      return raw
          .map((String s) => jsonDecode(s) as Map<String, dynamic>)
          .toList();
    } on Object {
      return const <Map<String, dynamic>>[];
    }
  }

  /// Clears persisted records after a successful upload.
  static Future<void> clearPersisted() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_persistKey);
    } on Object {
      // Ignore.
    }
  }

  /// Clears the ring buffer. Used by tests.
  @visibleForTesting
  static void clearForTest() => _ring.clear();

  /// Logs a debug line (debug builds only).
  static void d(String message, [String context = '']) {
    if (kDebugMode) {
      debugPrint('D $message $context');
    }
  }

  /// Logs an informational line (debug builds only).
  static void i(String message, [String context = '']) {
    if (kDebugMode) {
      debugPrint('I $message $context');
    }
  }

  /// Logs a warning, kept in the ring buffer.
  static void w(String message, [String context = '']) {
    _push(LogRecord(LogLevel.warning, message, context));
    if (kDebugMode) {
      debugPrint('W $message $context');
    }
  }

  /// Logs an error, kept in the ring buffer.
  static void e(String message, [String context = '']) {
    _push(LogRecord(LogLevel.error, message, context));
    if (kDebugMode) {
      debugPrint('E $message $context');
    }
  }

  static void _push(LogRecord record) {
    _ring.add(record);
    while (_ring.length > _ringCap) {
      _ring.removeAt(0);
    }
    if (record.level == LogLevel.warning || record.level == LogLevel.error) {
      _persist(record);
    }
  }
}
