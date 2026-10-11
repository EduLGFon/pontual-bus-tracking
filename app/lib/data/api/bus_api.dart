// BusApi base: typed HTTP over the shared client with the bearer token.
// Registration happens on demand only when sharing starts: at most one
// registration per install. No request fires at startup or first paint.
// See PLAN.md 8.4 and 6.5.
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pontual/core/errors/failures.dart';
import 'package:pontual/data/api/dto.dart';
import 'package:pontual/data/net/http_client.dart';

/// Base URL provider, injectable for tests.
typedef BaseUrlProvider = String Function();

/// Minimal API surface for T20: registration on demand.
class BusApi {
  /// Creates an API client. Performs no network calls.
  BusApi({
    required this.client,
    required this.baseUrl,
    required this.readToken,
    required this.writeToken,
  });

  /// Shared keep-alive HTTP client.
  final http.Client client;

  /// API base URL provider.
  final BaseUrlProvider baseUrl;

  /// Reads the stored device token.
  final Future<String?> Function() readToken;

  /// Persists the device token.
  final Future<void> Function(String token) writeToken;

  String? _cachedToken;

  /// Last ETag per line for conditional snapshot reads.
  final Map<int, String> _vehiclesEtags = <int, String>{};

  /// Last snapshot body per line, served on 304.
  final Map<int, VehiclesSnapshot> _vehiclesCache = <int, VehiclesSnapshot>{};

  /// Case-insensitive response header lookup. Servers may send ETag
  /// capitalized while mocks and CDNs vary.
  static String? _header(Map<String, String> headers, String name) {
    for (final MapEntry<String, String> e in headers.entries) {
      if (e.key.toLowerCase() == name) {
        return e.value;
      }
    }
    return null;
  }

  /// Returns the device token, registering once per install when needed.
  /// Callers outside trip sharing never invoke this.
  Future<Result<String>> ensureRegistered() async {
    final String? cached = _cachedToken ?? await readToken();
    if (cached != null && cached.isNotEmpty) {
      _cachedToken = cached;
      return Ok<String>(cached);
    }
    try {
      final http.Response res = await client
          .post(
            Uri.parse('${baseUrl()}/v1/devices'),
            headers: <String, String>{'content-type': 'application/json'},
            body: '{}',
          )
          .timeout(requestTimeout);
      if (res.statusCode != 201) {
        return const Err<String>(ServerFailure('register failed', 'register'));
      }
      final Map<String, dynamic> body =
          jsonDecode(res.body) as Map<String, dynamic>;
      final String? token = body['token'] as String?;
      if (token == null || token.isEmpty) {
        return const Err<String>(ServerFailure('bad token', 'register'));
      }
      await writeToken(token);
      _cachedToken = token;
      return Ok<String>(token);
    } on TimeoutException {
      return const Err<String>(NetworkFailure('register timed out'));
    } on http.ClientException catch (e) {
      return Err<String>(NetworkFailure(e.message));
    }
  }

  /// Records consent for the current version.
  Future<Result<bool>> postConsents(String token, int version) async {
    final Result<Map<String, dynamic>> res = await _authed(
      token,
      'POST',
      '/v1/consents',
      <String, dynamic>{'version': version},
    );
    return res is Ok<Map<String, dynamic>>
        ? const Ok<bool>(true)
        : Err<bool>((res as Err<Map<String, dynamic>>).failure);
  }

  /// Starts a trip on [lineId] with the first fix.
  Future<Result<TripInstruction>> startTrip(
    String token, {
    required int lineId,
    required double lat,
    required double lng,
    required double accuracyM,
    required int batteryPct,
    required bool charging,
    bool resume = false,
  }) async {
    final Result<Map<String, dynamic>> res = await _authed(
      token,
      'POST',
      '/v1/trip',
      <String, dynamic>{
        'line': lineId,
        'lat': lat,
        'lng': lng,
        'acc': accuracyM,
        'bat': batteryPct,
        'chg': charging,
        'resume': resume,
      },
    );
    return _instruction(res);
  }

  /// Sends one fix. [role] is the last known role for hand-over ack only.
  Future<Result<TripInstruction>> pingTrip(
    String token, {
    required int seq,
    required double lat,
    required double lng,
    required double speedMps,
    required double? heading,
    required double accuracyM,
    required int batteryPct,
    required bool charging,
    required String role,
  }) async {
    final Result<Map<String, dynamic>> res = await _authed(
      token,
      'POST',
      '/v1/trip/ping',
      <String, dynamic>{
        'seq': seq,
        'lat': lat,
        'lng': lng,
        'spd': speedMps,
        'hdg': heading,
        'acc': accuracyM,
        'bat': batteryPct,
        'chg': charging,
        'role': role,
      },
    );
    return _instruction(res);
  }

  /// Ends the active trip. Idempotent.
  Future<Result<bool>> endTrip(String token) async {
    final Result<void> res = await _authedVoid(token, 'DELETE', '/v1/trip');
    return res is Ok<void>
        ? const Ok<bool>(true)
        : Err<bool>((res as Err<void>).failure);
  }

  /// Deletes the device and all its data. Ends the trip first server-side.
  Future<Result<bool>> deleteMe(String token) async {
    final Result<void> res = await _authedVoid(token, 'DELETE', '/v1/me');
    return res is Ok<void>
        ? const Ok<bool>(true)
        : Err<bool>((res as Err<void>).failure);
  }

  /// Fetches the public vehicle snapshot for [lineId]. Uses a
  /// conditional GET once an ETag is known; 304 answers serve the
  /// cached snapshot without re-downloading it.
  Future<Result<VehiclesSnapshot>> getVehicles(int lineId) async {
    try {
      final Map<String, String> headers = <String, String>{};
      final String? etag = _vehiclesEtags[lineId];
      if (etag != null) {
        headers['if-none-match'] = etag;
      }
      final http.Response res = await client
          .get(
            Uri.parse('${baseUrl()}/v1/lines/$lineId/vehicles'),
            headers: headers,
          )
          .timeout(requestTimeout);
      if (res.statusCode == 304) {
        final VehiclesSnapshot? cached = _vehiclesCache[lineId];
        if (cached != null) {
          return Ok<VehiclesSnapshot>(cached);
        }
        return const Err<VehiclesSnapshot>(
          NetworkFailure('vehicles not cached'),
        );
      }
      if (res.statusCode != 200) {
        return Err<VehiclesSnapshot>(_failure(res));
      }
      final Map<String, dynamic> body =
          jsonDecode(res.body) as Map<String, dynamic>;
      final List<dynamic> rows = body['v'] as List<dynamic>;
      final VehiclesSnapshot snap = VehiclesSnapshot(
        epochS: body['t'] as int,
        vehicles: rows
            .map((dynamic r) => (r as List<dynamic>).cast<num?>())
            .toList(),
      );
      final String? newEtag = _header(res.headers, 'etag');
      if (newEtag != null) {
        _vehiclesEtags[lineId] = newEtag;
        _vehiclesCache[lineId] = snap;
      }
      return Ok<VehiclesSnapshot>(snap);
    } on TimeoutException {
      return const Err<VehiclesSnapshot>(NetworkFailure('vehicles timed out'));
    } on http.ClientException catch (e) {
      return Err<VehiclesSnapshot>(NetworkFailure(e.message));
    }
  }

  /// Fetches the live-lines indicator.
  Future<Result<LiveLines>> getLive() async {
    try {
      final http.Response res = await client
          .get(Uri.parse('${baseUrl()}/v1/live'))
          .timeout(requestTimeout);
      if (res.statusCode != 200) {
        return Err<LiveLines>(_failure(res));
      }
      final List<dynamic> rows = jsonDecode(res.body) as List<dynamic>;
      return Ok<LiveLines>(
        LiveLines(
          rows
              .map(
                (dynamic r) =>
                    (r as List<dynamic>).map((dynamic n) => n as int).toList(),
              )
              .toList(),
        ),
      );
    } on TimeoutException {
      return const Err<LiveLines>(NetworkFailure('live timed out'));
    } on http.ClientException catch (e) {
      return Err<LiveLines>(NetworkFailure(e.message));
    }
  }

  /// Fetches anonymous recent arrivals for [lineId] (D30). Timestamps
  /// only, no positions and no ids. Returns an empty payload on any
  /// shape mismatch so history cards hide instead of breaking.
  Future<Result<ArrivalsPayload>> getArrivals(int lineId) async {
    try {
      final http.Response res = await client
          .get(Uri.parse('${baseUrl()}/v1/lines/$lineId/arrivals'))
          .timeout(requestTimeout);
      if (res.statusCode != 200) {
        return Err<ArrivalsPayload>(_failure(res));
      }
      final Map<String, dynamic> body =
          jsonDecode(res.body) as Map<String, dynamic>;
      return Ok<ArrivalsPayload>(ArrivalsPayload.fromJson(body));
    } on TimeoutException {
      return const Err<ArrivalsPayload>(
        NetworkFailure('arrivals timed out'),
      );
    } on http.ClientException catch (e) {
      return Err<ArrivalsPayload>(NetworkFailure(e.message));
    }
  }

  Result<TripInstruction> _instruction(Result<Map<String, dynamic>> res) {
    if (res is Err<Map<String, dynamic>>) {
      return Err<TripInstruction>(res.failure);
    }
    final Map<String, dynamic> body = (res as Ok<Map<String, dynamic>>).value;
    return Ok<TripInstruction>(
      TripInstruction(
        role: body['r'] as String,
        intervalS: body['n'] as int,
        end: body['e'] as String?,
      ),
    );
  }

  Future<Result<Map<String, dynamic>>> _authed(
    String token,
    String method,
    String path,
    Map<String, dynamic>? body,
  ) async {
    try {
      final Uri uri = Uri.parse('${baseUrl()}$path');
      final Map<String, String> headers = <String, String>{
        'content-type': 'application/json',
        'authorization': 'Bearer $token',
      };
      final Future<http.Response> call;
      if (method == 'POST') {
        call = client.post(uri, headers: headers, body: jsonEncode(body));
      } else if (method == 'DELETE') {
        call = client.delete(uri, headers: headers);
      } else {
        call = client.get(uri, headers: headers);
      }
      final http.Response res = await call.timeout(requestTimeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        if (res.statusCode == 204 || res.body.isEmpty) {
          return const Ok<Map<String, dynamic>>(<String, dynamic>{});
        }
        return Ok<Map<String, dynamic>>(
          jsonDecode(res.body) as Map<String, dynamic>,
        );
      }
      return Err<Map<String, dynamic>>(_failure(res));
    } on TimeoutException {
      return const Err<Map<String, dynamic>>(NetworkFailure('timed out'));
    } on http.ClientException catch (e) {
      return Err<Map<String, dynamic>>(NetworkFailure(e.message));
    }
  }

  Future<Result<void>> _authedVoid(
    String token,
    String method,
    String path,
  ) async {
    final Result<Map<String, dynamic>> res = await _authed(
      token,
      method,
      path,
      null,
    );
    return res is Ok<Map<String, dynamic>>
        ? const Ok<void>(null)
        : Err<void>((res as Err<Map<String, dynamic>>).failure);
  }

  ServerFailure _failure(http.Response res) {
    String? code;
    try {
      final Map<String, dynamic> body =
          jsonDecode(res.body) as Map<String, dynamic>;
      code = body['e'] as String? ?? body['code'] as String?;
    } catch (_) {
      code = null;
    }
    return mapError(res.statusCode, code);
  }
}
