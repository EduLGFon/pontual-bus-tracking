// Remote flags from config.json. Bundled copy first, cached copy next,
// remote refresh at most daily. Maintenance and forced-update screens never
// block timetables: cached data stays usable. See PLAN.md S13 and T23.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pontual/core/errors/failures.dart';
import 'package:pontual/data/net/http_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage key for the cached flags.
const String remoteConfigKey = 'remote_config';

/// Storage key for the last flags check timestamp.
const String remoteConfigCheckKey = 'remote_config_check_ms';

/// Minimum interval between remote flag checks.
const Duration remoteCheckInterval = Duration(hours: 24);

/// Current app version. Compared against min_app_version.
/// Overridable via the APP_VERSION dart-define (env file).
const String appVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '0.1.0',
);

/// Remote flags controlling maintenance and forced update.
class RemoteConfig {
  /// Creates remote flags.
  const RemoteConfig({
    required this.minAppVersion,
    required this.maintenance,
    required this.messagePt,
    required this.consentVersion,
    required this.tileUrl,
  });

  /// Minimum supported app version.
  final String minAppVersion;

  /// When true the app shows the maintenance screen.
  final bool maintenance;

  /// Optional pt-BR message shown on system screens.
  final String messagePt;

  /// Current consent text version.
  final int consentVersion;

  /// Tile URL template.
  final String tileUrl;

  /// Parses flags. Throws [FormatException] on bad shapes.
  factory RemoteConfig.fromJson(Map<String, dynamic> json) {
    return RemoteConfig(
      minAppVersion: json['min_app_version'] as String,
      maintenance: json['maintenance'] as bool,
      messagePt: json['message_pt'] as String,
      consentVersion: json['consent_version'] as int,
      tileUrl: json['tile_url'] as String,
    );
  }

  /// Bundled defaults used before any fetch.
  factory RemoteConfig.bundled(String text) {
    return RemoteConfig.fromJson(jsonDecode(text) as Map<String, dynamic>);
  }

  /// True when [version] is older than [min].
  static bool updateRequired(String version, String min) {
    List<int> parts(String v) =>
        v.split('.').map((String e) => int.tryParse(e) ?? 0).toList();
    final List<int> have = parts(version);
    final List<int> need = parts(min);
    for (int i = 0; i < 3; i++) {
      final int h = i < have.length ? have[i] : 0;
      final int n = i < need.length ? need[i] : 0;
      if (h != n) {
        return h < n;
      }
    }
    return false;
  }
}

/// Repository for remote flags with offline-first semantics.
class RemoteConfigRepository {
  /// Creates a repository. No network calls happen until [refresh].
  const RemoteConfigRepository({
    required this.client,
    required this.staticBaseUrl,
    required this.bundleConfigJson,
    required this.prefs,
    required this.nowMs,
  });

  /// Shared HTTP client.
  final http.Client client;

  /// Static host base URL provider.
  final String Function() staticBaseUrl;

  /// Bundled config.json from assets.
  final String bundleConfigJson;

  /// Preferences accessor.
  final Future<SharedPreferences> Function() prefs;

  /// Clock in milliseconds.
  final int Function() nowMs;

  /// Returns cached flags, falling back to the bundle. Never throws.
  Future<RemoteConfig> current() async {
    final SharedPreferences sp = await prefs();
    final String? cached = sp.getString(remoteConfigKey);
    if (cached != null) {
      try {
        return RemoteConfig.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
        );
      } catch (_) {
        // Fall through to the bundle.
      }
    }
    return RemoteConfig.bundled(bundleConfigJson);
  }

  /// Refreshes flags at most once per day. Failures keep old flags.
  Future<Result<bool>> refresh() async {
    final SharedPreferences sp = await prefs();
    final int last = sp.getInt(remoteConfigCheckKey) ?? 0;
    if (nowMs() - last < remoteCheckInterval.inMilliseconds) {
      return const Ok<bool>(false);
    }
    await sp.setInt(remoteConfigCheckKey, nowMs());
    try {
      final http.Response res = await client
          .get(Uri.parse('${staticBaseUrl()}/config.json'))
          .timeout(requestTimeout);
      if (res.statusCode != 200) {
        return const Err<bool>(ServerFailure('config fetch failed', 'static'));
      }
      final RemoteConfig parsed = RemoteConfig.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
      await sp.setString(remoteConfigKey, res.body);
      return Ok<bool>(parsed.maintenance);
    } on FormatException {
      return const Err<bool>(ServerFailure('corrupt config', 'static'));
    } catch (_) {
      return const Err<bool>(NetworkFailure('config refresh failed'));
    }
  }
}
