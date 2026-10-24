// First-party diagnostics upload. Redacted bundles only; opt-in gated.
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pontual/core/config/env.dart';
import 'package:pontual/core/logging/log.dart';
import 'package:pontual/data/prefs/token_store.dart';

/// Uploads persisted diagnostic records to our first-party server.
class DiagnosticsUploader {
  /// Creates an uploader.
  const DiagnosticsUploader();

  /// Uploads pending records if the user opted in. Clears on success.
  Future<void> uploadIfOptedIn(bool optIn) async {
    if (!optIn) return;
    final List<Map<String, dynamic>> records = await Log.readPersisted();
    if (records.isEmpty) return;
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
      'build': '0.1.0',
      'platform': 'flutter',
      'os': 'unknown',
      'records': mapped,
      'optIn': true,
    };
    try {
      final http.Response res = await http
          .post(
            Uri.parse('$apiBaseUrl/v1/diagnostics'),
            headers: <String, String>{
              'content-type': 'application/json',
              if (token != null) 'authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 204 || res.statusCode == 200) {
        await Log.clearPersisted();
      }
    } on Object {
      // Keep persisted logs for next attempt.
    }
  }
}
