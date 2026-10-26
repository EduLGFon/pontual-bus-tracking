// De-identified public place used for place search. Pure Dart, no Flutter
// imports. Coordinates are public landmarks, never user data.
import 'package:pontual/core/geo/geo.dart';

/// A public place (landmark or neighbourhood) used to find lines whose
/// learned route passes through it.
class Place {
  /// Creates a place.
  const Place({
    required this.id,
    required this.name,
    required this.aliases,
    required this.lat,
    required this.lng,
  });

  /// Stable id.
  final String id;

  /// Display name.
  final String name;

  /// Alternative names used for matching.
  final List<String> aliases;

  /// Latitude in degrees.
  final double lat;

  /// Longitude in degrees.
  final double lng;

  /// Coordinate pair.
  LatLng get point => LatLng(lat, lng);

  /// Parses a place from JSON.
  factory Place.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawAliases =
        (json['aliases'] as List<dynamic>?) ?? const <dynamic>[];
    return Place(
      id: json['id'] as String,
      name: json['name'] as String,
      aliases: rawAliases.map((dynamic e) => e as String).toList(),
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}
