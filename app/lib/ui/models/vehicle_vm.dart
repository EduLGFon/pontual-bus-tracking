// Vehicle view-model. key is the internal id and is never shown to users;
// ordinal is the 1,2,3 position the UI uses instead.
// See docs/ui/UI_SPEC.md 6.2.
import 'package:flutter/foundation.dart';
import 'package:pontual/ui/models/certainty.dart';

/// One vehicle on the map and in the list.
@immutable
class VehicleVM {
  /// Creates a vehicle view-model.
  const VehicleVM({
    required this.key,
    required this.lineKey,
    required this.lat,
    required this.lng,
    this.headingDeg,
    this.speedKmh,
    required this.ageSeconds,
    required this.certainty,
    this.ordinal,
    this.paceFactor,
  });

  /// Internal id. Never displayed.
  final int key;

  /// Line the vehicle belongs to.
  final String lineKey;

  /// Latitude in degrees.
  final double lat;

  /// Longitude in degrees.
  final double lng;

  /// Heading in degrees, null when unknown.
  final double? headingDeg;

  /// Speed in km/h.
  final double? speedKmh;

  /// Age of the position in seconds.
  final int ageSeconds;

  /// Certainty implied by the age.
  final Certainty certainty;

  /// Display position: 1, 2, 3 by recency. Null before assignment.
  final int? ordinal;

  /// Recent pace along the route divided by the usual pace, kept in memory
  /// for the life of the vehicle only (UI_SPEC 13.1). Null when unknown.
  final double? paceFactor;

  /// True when the heading triangle should be drawn.
  bool get showsHeading =>
      certainty == Certainty.live &&
      headingDeg != null &&
      (speedKmh ?? 0) >= 1.5;

  /// Returns a copy with a different ordinal.
  VehicleVM withOrdinal(int value) {
    return VehicleVM(
      key: key,
      lineKey: lineKey,
      lat: lat,
      lng: lng,
      headingDeg: headingDeg,
      speedKmh: speedKmh,
      ageSeconds: ageSeconds,
      certainty: certainty,
      ordinal: value,
      paceFactor: paceFactor,
    );
  }
}
