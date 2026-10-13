// Static data repository: bundled data first, then cache, then conditional
// GET, with atomic swap. The first frame never waits on the network.
// Every line list the UI shows comes from here. See PLAN.md 7.1.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pontual/core/errors/failures.dart';
import 'package:pontual/data/net/http_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage key prefix for versioned cached line bundles.
const String linesKeyPrefix = 'static_lines_';

/// Storage key prefix for cached stop sets, keyed by stops file name.
const String stopsKeyPrefix = 'static_stops_';

/// Storage key for the cached manifest.
const String manifestKey = 'static_manifest';

/// Storage key for the cached manifest ETag.
const String manifestEtagKey = 'static_manifest_etag';

/// Storage key for the last remote check timestamp.
const String lastCheckKey = 'static_last_check_ms';

/// Case-insensitive response header lookup. Servers and CDNs vary
/// the ETag capitalization.
String? headerOf(Map<String, String> headers, String name) {
  for (final MapEntry<String, String> e in headers.entries) {
    if (e.key.toLowerCase() == name) {
      return e.value;
    }
  }
  return null;
}

/// Minimum interval between remote manifest checks.
const Duration checkInterval = Duration(hours: 24);

/// One transit line with its timetables.
class StaticLine {
  /// Creates a line from decoded JSON.
  const StaticLine({
    required this.id,
    required this.code,
    required this.short,
    required this.name,
    required this.pilot,
    required this.schedules,
    this.terminals = const <String>[],
    this.areaTags = const <String>[],
    this.isActive = true,
  });

  /// Stable numeric id.
  final int id;

  /// Immutable slug.
  final String code;

  /// Badge text of up to 3 chars.
  final String short;

  /// Display name in pt-BR.
  final String name;

  /// Whether live tracking is enabled.
  final bool pilot;

  /// Raw schedule entries.
  final List<Map<String, dynamic>> schedules;

  /// Endpoint names, empty when the data has none.
  final List<String> terminals;

  /// Neighbourhood tags used by the search index.
  final List<String> areaTags;

  /// False hides the line from the UI without reusing the id.
  final bool isActive;

  /// Parses a line object. Throws [FormatException] on bad shapes.
  factory StaticLine.fromJson(Map<String, dynamic> json) {
    return StaticLine(
      id: json['id'] as int,
      code: json['code'] as String,
      short: json['short'] as String,
      name: json['name'] as String,
      pilot: json['pilot'] as bool,
      schedules: ((json['schedules'] as List<dynamic>?) ?? <dynamic>[])
          .map(
            (dynamic e) => (e as Map<dynamic, dynamic>).cast<String, dynamic>(),
          )
          .toList(),
      terminals: _stringsOf(json['terminals']),
      areaTags: _stringsOf(json['area_tags']),
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

/// Reads a list of strings, dropping unknown value types.
List<String> _stringsOf(Object? raw) {
  if (raw is! List<dynamic>) {
    return const <String>[];
  }
  return raw.whereType<String>().toList(growable: false);
}

/// One city bus stop: public infrastructure, never a person.
class StopPoint {
  /// Creates a stop from decoded fields.
  const StopPoint({
    required this.id,
    required this.lat,
    required this.lng,
    this.name,
  });

  /// Stable id, never reused.
  final String id;

  /// Latitude in degrees.
  final double lat;

  /// Longitude in degrees.
  final double lng;

  /// Posted name, null when unmapped.
  final String? name;

  /// Parses a stop object. Throws [FormatException] on bad shapes.
  factory StopPoint.fromJson(Map<String, dynamic> json) {
    return StopPoint(
      id: json['id'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      name: json['name'] as String?,
    );
  }
}

/// Repository for lines and timetables with offline-first semantics.
class StaticDataRepository {
  /// Creates a repository. No network calls happen until [refresh].
  const StaticDataRepository({
    required this.client,
    required this.staticBaseUrl,
    required this.bundleManifestJson,
    required this.bundleLinesJson,
    required this.prefs,
    required this.nowMs,
    this.bundleStopsJson = '[]',
  });

  /// Shared HTTP client.
  final http.Client client;

  /// Static host base URL provider.
  final String Function() staticBaseUrl;

  /// Bundled manifest JSON from assets.
  final String bundleManifestJson;

  /// Bundled lines JSON from assets.
  final String bundleLinesJson;

  /// Bundled stops JSON from assets. Empty until stops are mapped.
  final String bundleStopsJson;

  /// Preferences accessor.
  final Future<SharedPreferences> Function() prefs;

  /// Clock in milliseconds.
  final int Function() nowMs;

  /// Returns lines immediately: cache first, bundled fallback. Never throws;
  /// corrupt cache falls back to the bundle.
  Future<List<StaticLine>> lines() async {
    final SharedPreferences sp = await prefs();
    final String? manifestStr = sp.getString(manifestKey);
    if (manifestStr != null) {
      try {
        final Map<String, dynamic> manifest =
            jsonDecode(manifestStr) as Map<String, dynamic>;
        final String version = manifest['data_version'] as String;
        final String? linesStr = sp.getString('$linesKeyPrefix$version');
        if (linesStr != null) {
          return _parseLines(linesStr);
        }
      } catch (_) {
        // Fall through to the bundle.
      }
    }
    return _parseLines(bundleLinesJson);
  }

  /// Returns bus stops: cached set first, bundled fallback. Never throws;
  /// unknown shapes yield an empty list, never a broken map.
  Future<List<StopPoint>> stops() async {
    final SharedPreferences sp = await prefs();
    final String? manifestStr = sp.getString(manifestKey);
    if (manifestStr != null) {
      try {
        final Map<String, dynamic> manifest =
            jsonDecode(manifestStr) as Map<String, dynamic>;
        final String? name = manifest['stops'] as String?;
        if (name != null) {
          final String? stopsStr = sp.getString('$stopsKeyPrefix$name');
          if (stopsStr != null) {
            return _parseStops(stopsStr);
          }
        }
      } catch (_) {
        // Fall through to the bundle.
      }
    }
    try {
      return _parseStops(bundleStopsJson);
    } catch (_) {
      return const <StopPoint>[];
    }
  }

  /// Checks the remote manifest at most once per day and atomically swaps
  /// in a newer bundle. Corrupt or unreachable remotes keep the old data.
  Future<Result<bool>> refresh() async {
    final SharedPreferences sp = await prefs();
    final int last = sp.getInt(lastCheckKey) ?? 0;
    if (nowMs() - last < checkInterval.inMilliseconds) {
      return const Ok<bool>(false);
    }
    await sp.setInt(lastCheckKey, nowMs());
    try {
      final String? etag = sp.getString(manifestEtagKey);
      final Map<String, String> headers = <String, String>{};
      if (etag != null) {
        headers['if-none-match'] = etag;
      }
      final http.Response res = await client
          .get(Uri.parse('${staticBaseUrl()}/manifest.json'), headers: headers)
          .timeout(requestTimeout);
      if (res.statusCode == 304) {
        return const Ok<bool>(false);
      }
      if (res.statusCode != 200) {
        return const Err<bool>(
          ServerFailure('manifest fetch failed', 'static'),
        );
      }
      final Map<String, dynamic> remote =
          jsonDecode(res.body) as Map<String, dynamic>;
      final String version = remote['data_version'] as String;
      final String linesName = remote['lines'] as String;
      final String current = _versionOf(sp);
      if (version == current) {
        return const Ok<bool>(false);
      }
      final http.Response linesRes = await client
          .get(Uri.parse('${staticBaseUrl()}/$linesName'))
          .timeout(requestTimeout);
      if (linesRes.statusCode != 200) {
        return const Err<bool>(ServerFailure('lines fetch failed', 'static'));
      }
      final List<StaticLine> parsed = _parseLines(linesRes.body);
      if (parsed.isEmpty) {
        return const Err<bool>(ServerFailure('empty bundle', 'static'));
      }
      // Stops ride the same manifest but never block it: a stops failure
      // keeps the previous set while lines still swap below.
      String? stopsName;
      String? stopsBody;
      try {
        final String? remoteStops = remote['stops'] as String?;
        if (remoteStops != null) {
          final http.Response stopsRes = await client
              .get(Uri.parse('${staticBaseUrl()}/$remoteStops'))
              .timeout(requestTimeout);
          if (stopsRes.statusCode == 200) {
            _parseStops(stopsRes.body);
            stopsName = remoteStops;
            stopsBody = stopsRes.body;
          }
        }
      } catch (_) {
        // Keep the previous stops; lines still swap below.
      }
      // Atomic swap: versioned lines first, manifest pointer last.
      await sp.setString('$linesKeyPrefix$version', linesRes.body);
      if (stopsName != null && stopsBody != null) {
        await sp.setString('$stopsKeyPrefix$stopsName', stopsBody);
      }
      await sp.setString(manifestKey, res.body);
      final String? newEtag = headerOf(res.headers, 'etag');
      if (newEtag != null) {
        await sp.setString(manifestEtagKey, newEtag);
      }
      // Evict superseded bundles; keep storage flat across versions.
      // Runs after the pointer swap so a crash can never delete live
      // data: at worst an orphaned bundle waits for the next refresh.
      final Set<String> keys = sp.getKeys();
      for (final String k in keys) {
        if (k.startsWith(linesKeyPrefix) && k != '$linesKeyPrefix$version') {
          await sp.remove(k);
        }
        if (stopsName != null &&
            k.startsWith(stopsKeyPrefix) &&
            k != '$stopsKeyPrefix$stopsName') {
          await sp.remove(k);
        }
      }
      return const Ok<bool>(true);
    } on FormatException {
      return const Err<bool>(ServerFailure('corrupt bundle', 'static'));
    } catch (_) {
      return const Err<bool>(NetworkFailure('static refresh failed'));
    }
  }

  String _versionOf(SharedPreferences prefs) {
    final String? manifestStr = prefs.getString(manifestKey);
    if (manifestStr == null) {
      try {
        final Map<String, dynamic> bundle =
            jsonDecode(bundleManifestJson) as Map<String, dynamic>;
        return bundle['data_version'] as String? ?? '';
      } catch (_) {
        return '';
      }
    }
    try {
      return (jsonDecode(manifestStr) as Map<String, dynamic>)['data_version']
          as String;
    } catch (_) {
      return '';
    }
  }

  List<StaticLine> _parseLines(String text) {
    final List<dynamic> raw = jsonDecode(text) as List<dynamic>;
    return raw
        .map((dynamic e) => StaticLine.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  List<StopPoint> _parseStops(String text) {
    final List<dynamic> raw = jsonDecode(text) as List<dynamic>;
    return raw
        .map((dynamic e) => StopPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
