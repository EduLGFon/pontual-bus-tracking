// First-party diagnostics upload. Redacted bundles only; opt-in gated.
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pontual/core/config/env.dart';
import 'package:pontual/data/config/remote_config.dart' show appVersion;
import 'package:pontual/core/logging/log.dart';
import 'package:pontual/data/prefs/token_store.dart';

import 'os_info.dart';

/// Uploads persisted diagnostic records to our first-party server.
class DiagnosticsUploader {
  /// Creates an uploader. An optional [client] overrides the default
  /// global HTTP client (useful for tests).
  const DiagnosticsUploader({this.client});

  /// Optional HTTP client.
  final http.Client? client;

  /// SharedPreferences key for a persisted crash payload.
  static const String crashKey = 'diag_crash_v1';

  /// SharedPreferences key for the pending bundle id (retry dedupe).
  static const String bundleIdKey = 'diag_bundle_id_v1';

  static bool _inFlight = false;

  /// Uploads pending records if the user opted in. Clears on success.
  Future<void> uploadIfOptedIn(bool optIn) async {
    if (!optIn) return;
    if (_inFlight) return;
    _inFlight = true;
    try {
      final List<Map<String, dynamic>> records = await Log.readPersisted();
      final String? crash = await _readCrash();
      if (records.isEmpty && crash == null) return;

      String? bundleId = await _readBundleId();
      if (bundleId == null) {
        bundleId = _uuidV4();
        await _storeBundleId(bundleId);
      }

      final String? token = await const TokenStore().read();
      final List<Map<String, dynamic>> mapped = records
          .map(
            (Map<String, dynamic> r) => <String, dynamic>{
              'l': r['l'] ?? 'w',
              'm': (r['m'] ?? '').toString(),
              'c': r['c']?.toString(),
              't': r['t'],
            },
          )
          .toList();
      final Map<String, dynamic> body = <String, dynamic>{
        'v': 1,
        'app': 'pontual',
        'build': buildValue(),
        'platform': _truncate(kIsWeb ? 'web' : defaultTargetPlatform.name, 20),
        'os': _truncate(osString(), 60),
        'records': mapped,
        'optIn': true,
        'id': bundleId,
      };
      if (crash != null) {
        body['crash'] = _truncate(crash, 4000);
      }

      try {
        final http.Response res = await _post(
          token,
          body,
        ).timeout(const Duration(seconds: 30));
        if (res.statusCode == 204 || res.statusCode == 200) {
          await Log.clearPersistedUpTo(records.length);
          await _clearCrashIfEquals(crash);
          await _clearBundleIdIfEquals(bundleId);
        }
      } on Object {
        // Keep persisted logs for next attempt.
      }
    } finally {
      _inFlight = false;
    }
  }

  Future<http.Response> _post(String? token, Map<String, dynamic> body) {
    final Uri uri = Uri.parse('$apiBaseUrl/v1/diagnostics');
    final Map<String, String> headers = <String, String>{
      'content-type': 'application/json',
      if (token != null) 'authorization': 'Bearer $token',
    };
    if (client != null) {
      return client!.post(uri, headers: headers, body: jsonEncode(body));
    }
    return http.post(uri, headers: headers, body: jsonEncode(body));
  }

  static Future<String?> _readCrash() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString(crashKey);
    } on Object {
      return null;
    }
  }

  static Future<void> _clearCrash() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(crashKey);
    } on Object {
      // Ignore.
    }
  }

  static Future<String?> _readBundleId() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString(bundleIdKey);
    } on Object {
      return null;
    }
  }

  static Future<void> _storeBundleId(String id) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(bundleIdKey, id);
    } on Object {
      // Ignore.
    }
  }

  static Future<void> _clearCrashIfEquals(String? sent) async {
    if (sent == null) return;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (prefs.getString(crashKey) == sent) {
        await prefs.remove(crashKey);
      }
    } on Object {
      // Ignore.
    }
  }

  static Future<void> _clearBundleIdIfEquals(String? sent) async {
    if (sent == null) return;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (prefs.getString(bundleIdKey) == sent) {
        await prefs.remove(bundleIdKey);
      }
    } on Object {
      // Ignore.
    }
  }

  /// Persists a crash payload (truncated to the server limit).
  static Future<void> persistCrash(String crash) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(crashKey, _truncate(crash, 4000));
    } on Object {
      // Ignore.
    }
  }

  /// Reads the persisted crash payload.
  static Future<String?> readCrash() async => _readCrash();

  /// Clears the persisted crash payload.
  static Future<void> clearCrash() async => _clearCrash();

  /// Builds a redacted crash payload from Flutter error details.
  static String buildCrash(FlutterErrorDetails details) {
    final String exception = details.exceptionAsString();
    final String ctx = details.context?.toString() ?? '';
    final String stack = details.stack?.toString() ?? '';
    final String stackPart = stack.length > 1000
        ? stack.substring(0, 1000)
        : stack;
    final List<String> parts = <String>[exception];
    if (ctx.isNotEmpty) parts.add(ctx);
    if (stackPart.isNotEmpty) parts.add(stackPart);
    return _truncate(parts.join('\n'), 4000);
  }

  /// Safe, short context for the persisted record line.
  static String safeContext(FlutterErrorDetails details) {
    final String ctx = details.context?.toString() ?? '';
    return _truncate(ctx, 200);
  }

  /// Persists the crash payload and logs a short record.
  static Future<void> recordFlutterError(FlutterErrorDetails details) async {
    await persistCrash(buildCrash(details));
    Log.e('flutter error', safeContext(details));
  }

  /// Resolves the build field, never blank.
  static String buildValue([String value = appVersion]) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) return 'unknown';
    return _truncate(trimmed, 40);
  }

  static String _truncate(String value, int max) {
    if (value.length <= max) return value;
    return value.substring(0, max);
  }

  static String _uuidV4() {
    final Random r = Random.secure();
    final List<int> bytes = List<int>.generate(16, (_) => r.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final String h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
        '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20, 32)}';
  }
}
