// Repository for the de-identified learning endpoints. HTTP only; no
// Flutter imports beyond the shared http client. See PLAN.md 6.5.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pontual/core/errors/failures.dart';
import 'package:pontual/domain/learning/learned_route.dart';
import 'package:pontual/domain/learning/learned_route_index.dart';
import 'package:pontual/domain/learning/learned_stop.dart';
import 'package:pontual/domain/learning/eta_estimate.dart';

/// Base URL provider, injectable for tests.
typedef LearningBaseUrlProvider = String Function();

/// Repository for learned routes, stops, and ETA.
class LearningRepository {
  /// Creates a learning repository.
  LearningRepository({required this.client, required this.baseUrl});

  /// Shared HTTP client.
  final http.Client client;

  /// Base URL provider.
  final LearningBaseUrlProvider baseUrl;

  /// Fetches the learned route for [lineId].
  Future<Result<LearnedRoute?>> fetchLearnedRoute(int lineId) async {
    try {
      final http.Response res = await client
          .get(Uri.parse('${baseUrl()}/v1/lines/$lineId/learned-route'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 404) {
        return const Ok<LearnedRoute?>(null);
      }
      if (res.statusCode != 200) {
        return const Err<LearnedRoute?>(
          ServerFailure('learned route failed', 'learned_route'),
        );
      }
      final Map<String, dynamic> body =
          jsonDecode(res.body) as Map<String, dynamic>;
      return Ok<LearnedRoute?>(LearnedRoute.fromJson(body));
    } on Exception catch (e) {
      return Err<LearnedRoute?>(NetworkFailure(e.toString()));
    }
  }

  /// Fetches learned stops for [lineId].
  Future<Result<LearnedStopsResult?>> fetchStops(int lineId) async {
    try {
      final http.Response res = await client
          .get(Uri.parse('${baseUrl()}/v1/lines/$lineId/stops'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 404) {
        return const Ok<LearnedStopsResult?>(null);
      }
      if (res.statusCode != 200) {
        return const Err<LearnedStopsResult?>(
          ServerFailure('learned stops failed', 'learned_stops'),
        );
      }
      final Map<String, dynamic> body =
          jsonDecode(res.body) as Map<String, dynamic>;
      return Ok<LearnedStopsResult?>(LearnedStopsResult.fromJson(body));
    } on Exception catch (e) {
      return Err<LearnedStopsResult?>(NetworkFailure(e.toString()));
    }
  }

  /// Fetches the bulk learned-routes index. Returns an empty index on 404
  /// or failure so place search degrades to "no results".
  Future<Result<LearnedRoutesIndex>> fetchLearnedRoutesIndex() async {
    try {
      final http.Response res = await client
          .get(Uri.parse('${baseUrl()}/v1/learned-routes'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 404) {
        return const Ok<LearnedRoutesIndex>(LearnedRoutesIndex.empty);
      }
      if (res.statusCode != 200) {
        return const Ok<LearnedRoutesIndex>(LearnedRoutesIndex.empty);
      }
      final Map<String, dynamic> body =
          jsonDecode(res.body) as Map<String, dynamic>;
      return Ok<LearnedRoutesIndex>(LearnedRoutesIndex.fromJson(body));
    } on Exception catch (e) {
      return Err<LearnedRoutesIndex>(NetworkFailure(e.toString()));
    }
  }

  Future<Result<EtaResult?>> fetchEta(int lineId, String stopId) async {
    try {
      final http.Response res = await client
          .get(Uri.parse('${baseUrl()}/v1/lines/$lineId/eta?stop=$stopId'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 404) {
        return const Ok<EtaResult?>(null);
      }
      if (res.statusCode != 200) {
        return const Err<EtaResult?>(ServerFailure('eta failed', 'eta'));
      }
      final Map<String, dynamic> body =
          jsonDecode(res.body) as Map<String, dynamic>;
      return Ok<EtaResult?>(EtaResult.fromJson(body));
    } on Exception catch (e) {
      return Err<EtaResult?>(NetworkFailure(e.toString()));
    }
  }
}
