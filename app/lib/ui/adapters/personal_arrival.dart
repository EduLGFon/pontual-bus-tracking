// Pure view-model for "when does a bus reach my stop?" on the line screen.
// The UI feeds one viewer fix, the line's learned stops, the live vehicles
// and one ETA response; this module returns an immutable state to render.
// No widgets, no providers, no I/O, no logging: coordinates stay in memory
// and are never printed. Copy comes from UiStrings.
// See docs/ui and the personal arrival design contract.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:pontual/core/geo/geo.dart';
import 'package:pontual/domain/learning/eta_estimate.dart';
import 'package:pontual/domain/learning/learned_stop.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/models/vehicle_vm.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Search radius for snapping the rider to a learned stop, in meters.
const double personalStopRadiusM = 300;

/// Distance under which the stop counts as "Seu ponto", in meters.
const int personalStopNearM = 120;

/// Straight-line distance under which a bus counts as arriving, in meters.
const int personalArrivingDistanceM = 250;

/// ETA under which a bus counts as arriving, in seconds.
const int personalArrivingEtaS = 60;

/// Largest ETA the personal card shows, in seconds (90 minutes).
const int personalMaxEtaS = 5400;

/// Age after which a viewer fix is stale, in seconds.
const int personalFixFreshS = 300;

/// Suggested ETA refresh interval while the line screen is visible.
const int personalEtaRefreshS = 10;

/// State of the personal arrival card and its rows.
enum PersonalArrivalStatus {
  /// No usable fix yet: the card offers the opt-in prompt.
  needsLocation,

  /// A fix exists but the learned stops are still loading.
  loadingStops,

  /// The line has no learned stops.
  noStops,

  /// No learned stop within [personalStopRadiusM] of the rider.
  noStopNear,

  /// No live vehicle on the line right now.
  noLive,

  /// A live bus exists and the ETA request is in flight.
  etaLoading,

  /// A live bus has a usable ETA to the rider's stop.
  ready,

  /// Live buses exist but none is approaching the stop.
  noApproaching,

  /// The ETA request failed or returned nothing.
  etaError,
}

/// One vehicle's ETA to the rider's stop, ready to render in a row.
@immutable
class PersonalEtaVM {
  /// Creates a personal ETA row.
  const PersonalEtaVM({
    required this.vehicleKey,
    required this.etaSeconds,
    required this.minutes,
    required this.arriving,
    required this.passed,
    required this.approaching,
    required this.confidence,
    required this.sampleCount,
    required this.label,
    required this.semantic,
  });

  /// Internal vehicle key. Never displayed.
  final int vehicleKey;

  /// Raw ETA in seconds from the server.
  final int etaSeconds;

  /// Rounded minutes, minimum 1. Only used when not [arriving].
  final int minutes;

  /// True when the bus is at or next to the stop.
  final bool arriving;

  /// True when the bus is heading away and far from the stop.
  final bool passed;

  /// True when the bus heading points toward the stop, or is unknown.
  final bool approaching;

  /// Confidence level, 0 to 2.
  final int confidence;

  /// Number of trips backing the estimate.
  final int sampleCount;

  /// Row label, for example "~6 min ate voce".
  final String label;

  /// Row screen-reader sentence.
  final String semantic;
}

/// Immutable state of the personal arrival card.
@immutable
class PersonalArrivalVM {
  /// Creates a personal arrival state.
  const PersonalArrivalVM({
    required this.status,
    this.stopId,
    this.stopLat,
    this.stopLng,
    this.stopDistanceM,
    this.staleFix = false,
    this.lead,
    this.byVehicle = const <int, PersonalEtaVM>{},
  });

  /// Current state of the card.
  final PersonalArrivalStatus status;

  /// Learned stop id, when a nearest stop was chosen.
  final int? stopId;

  /// Learned stop latitude, when a nearest stop was chosen.
  final double? stopLat;

  /// Learned stop longitude, when a nearest stop was chosen.
  final double? stopLng;

  /// Rounded distance from the rider to the stop, in meters.
  final int? stopDistanceM;

  /// True when the viewer fix is older than [personalFixFreshS].
  final bool staleFix;

  /// Bus with the smallest ETA among approaching buses.
  final PersonalEtaVM? lead;

  /// Per-vehicle ETA rows, keyed by [VehicleVM.key].
  final Map<int, PersonalEtaVM> byVehicle;

  /// True when a live bus has a usable ETA.
  bool get isReady => status == PersonalArrivalStatus.ready;
}

/// Nearest learned stop to [viewer] within [maxM], or null.
LearnedStop? nearestStopOf(
  LatLng viewer,
  List<LearnedStop> stops, {
  double maxM = personalStopRadiusM,
}) {
  LearnedStop? best;
  double bestM = double.infinity;
  for (final LearnedStop stop in stops) {
    final double d = distM(viewer.lat, viewer.lng, stop.lat, stop.lng);
    if (d <= maxM && d < bestM) {
      best = stop;
      bestM = d;
    }
  }
  return best;
}

/// Rounded distance to the nearest learned stop within [maxM], or null.
int? nearestStopDistanceM(
  LatLng viewer,
  List<LearnedStop> stops, {
  double maxM = personalStopRadiusM,
}) {
  final LearnedStop? stop = nearestStopOf(viewer, stops, maxM: maxM);
  if (stop == null) {
    return null;
  }
  return distM(viewer.lat, viewer.lng, stop.lat, stop.lng).round();
}

/// True when [vehicle] points toward [stop], within 90 degrees.
///
/// Unknown heading and stopped vehicles count as approaching: they may
/// still be waiting at the stop and must not be hidden.
bool isApproaching(VehicleVM vehicle, LearnedStop stop) {
  final double? heading = vehicle.headingDeg;
  if (heading == null || (vehicle.speedKmh ?? 0) < 1.5) {
    return true;
  }
  final double bearing = _bearingDeg(
    vehicle.lat,
    vehicle.lng,
    stop.lat,
    stop.lng,
  );
  double diff = (bearing - heading) % 360;
  if (diff > 180) {
    diff = 360 - diff;
  }
  return diff <= 90;
}

/// Builds the personal arrival state from the UI inputs. Never throws.
PersonalArrivalVM buildPersonalArrival({
  required LatLng? viewer,
  required DateTime now,
  required DateTime? fixAt,
  required bool stopsLoading,
  required List<LearnedStop> stops,
  required List<VehicleVM> vehicles,
  required EtaResult? eta,
  required bool etaLoading,
  required bool etaFailed,
}) {
  if (viewer == null) {
    return const PersonalArrivalVM(status: PersonalArrivalStatus.needsLocation);
  }
  final bool staleFix =
      fixAt != null &&
      now.difference(fixAt) > const Duration(seconds: personalFixFreshS);
  if (staleFix) {
    return const PersonalArrivalVM(
      status: PersonalArrivalStatus.needsLocation,
      staleFix: true,
    );
  }
  if (stopsLoading) {
    return const PersonalArrivalVM(status: PersonalArrivalStatus.loadingStops);
  }
  if (stops.isEmpty) {
    return const PersonalArrivalVM(status: PersonalArrivalStatus.noStops);
  }
  final LearnedStop? stop = nearestStopOf(viewer, stops);
  if (stop == null) {
    return const PersonalArrivalVM(status: PersonalArrivalStatus.noStopNear);
  }
  final int stopDistanceM = distM(
    viewer.lat,
    viewer.lng,
    stop.lat,
    stop.lng,
  ).round();

  final List<VehicleVM> live = vehicles
      .where((VehicleVM v) => v.certainty == Certainty.live)
      .toList(growable: false);
  if (live.isEmpty) {
    return _withStop(PersonalArrivalStatus.noLive, stop, stopDistanceM);
  }
  if (etaLoading && eta == null) {
    return _withStop(PersonalArrivalStatus.etaLoading, stop, stopDistanceM);
  }
  if (etaFailed || eta == null) {
    return _withStop(PersonalArrivalStatus.etaError, stop, stopDistanceM);
  }

  final Map<int, EtaItem> items = <int, EtaItem>{
    for (final EtaItem item in eta.items) item.vehicleId: item,
  };
  final Map<int, PersonalEtaVM> byVehicle = <int, PersonalEtaVM>{};
  final Map<int, int> distances = <int, int>{};
  for (final VehicleVM vehicle in live) {
    final EtaItem? item = items[vehicle.key];
    if (item == null || item.etaS > personalMaxEtaS) {
      continue;
    }
    final double vehicleDistanceM = distM(
      vehicle.lat,
      vehicle.lng,
      stop.lat,
      stop.lng,
    );
    final bool approaching = isApproaching(vehicle, stop);
    final bool passed =
        !approaching && vehicleDistanceM > personalArrivingDistanceM;
    if (item.etaS == 0 &&
        vehicleDistanceM > personalArrivingDistanceM &&
        !passed) {
      continue;
    }
    final bool arriving =
        item.etaS <= personalArrivingEtaS ||
        vehicleDistanceM <= personalArrivingDistanceM;
    final int minutes = math.max(1, (item.etaS / 60).round());
    final int roundedVehicleDistanceM = vehicleDistanceM.round();
    final String label;
    final String semantic;
    if (arriving) {
      label = UiStrings.myStopArrivingUntilYou;
      semantic = UiStrings.myStopA11yArriving(roundedVehicleDistanceM);
    } else if (passed) {
      label = UiStrings.myStopPassedUntilYou;
      semantic = label;
    } else {
      label = UiStrings.myStopEtaUntilYou(minutes);
      semantic = UiStrings.myStopA11y(minutes, roundedVehicleDistanceM);
    }
    byVehicle[vehicle.key] = PersonalEtaVM(
      vehicleKey: vehicle.key,
      etaSeconds: item.etaS,
      minutes: minutes,
      arriving: arriving,
      passed: passed,
      approaching: approaching,
      confidence: _confidenceOf(item.confidence),
      sampleCount: item.sampleCount,
      label: label,
      semantic: semantic,
    );
    distances[vehicle.key] = roundedVehicleDistanceM;
  }

  PersonalEtaVM? lead;
  int leadDistanceM = 0;
  for (final PersonalEtaVM vm in byVehicle.values) {
    if (!vm.approaching || vm.passed) {
      continue;
    }
    final int distance = distances[vm.vehicleKey] ?? 0;
    if (lead == null ||
        vm.etaSeconds < lead.etaSeconds ||
        (vm.etaSeconds == lead.etaSeconds && distance < leadDistanceM)) {
      lead = vm;
      leadDistanceM = distance;
    }
  }
  return PersonalArrivalVM(
    status: lead == null
        ? PersonalArrivalStatus.noApproaching
        : PersonalArrivalStatus.ready,
    stopId: int.tryParse(stop.id),
    stopLat: stop.lat,
    stopLng: stop.lng,
    stopDistanceM: stopDistanceM,
    lead: lead,
    byVehicle: Map<int, PersonalEtaVM>.unmodifiable(byVehicle),
  );
}

PersonalArrivalVM _withStop(
  PersonalArrivalStatus status,
  LearnedStop stop,
  int stopDistanceM,
) {
  return PersonalArrivalVM(
    status: status,
    stopId: int.tryParse(stop.id),
    stopLat: stop.lat,
    stopLng: stop.lng,
    stopDistanceM: stopDistanceM,
  );
}

int _confidenceOf(String value) {
  return switch (value) {
    'high' => 2,
    'medium' => 1,
    _ => 0,
  };
}

double _bearingDeg(double lat, double lng, double stopLat, double stopLng) {
  const double rad = math.pi / 180;
  final double dLng = (stopLng - lng) * rad;
  final double y = math.sin(dLng) * math.cos(stopLat * rad);
  final double x =
      math.cos(lat * rad) * math.sin(stopLat * rad) -
      math.sin(lat * rad) * math.cos(stopLat * rad) * math.cos(dLng);
  final double deg = math.atan2(y, x) / rad;
  return (deg + 360) % 360;
}
