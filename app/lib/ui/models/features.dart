// Feature flags. Compile-time defaults, optionally overridden by the remote
// config the app already fetches. A disabled feature renders nothing.
// See docs/ui/UI_SPEC.md 6.4.
import 'package:flutter/foundation.dart';

/// Flags gating parts of the new UI.
@immutable
class Features {
  /// Creates the flag set. D30 defaults: momentum features are on.
  const Features({
    this.shortcuts = true,
    this.recents = true,
    this.favorites = true,
    this.dataSaver = true,
    this.predictions = true,
    this.eta = true,
    this.arrivalAlerts = true,
    this.reliability = true,
    this.followVehicle = true,
    this.routeLine = false,
    this.localKudos = true,
    this.reports = true,
  });

  /// Home shortcut cards.
  final bool shortcuts;

  /// Home recents chips.
  final bool recents;

  /// Star toggles on line rows.
  final bool favorites;

  /// Data saver setting and map behaviour.
  final bool dataSaver;

  /// Prediction styling, ghost markers and confidence meters.
  final bool predictions;

  /// Live and predicted arrival times.
  final bool eta;

  /// Arrival alerts.
  final bool arrivalAlerts;

  /// Reliability history in the line screen.
  final bool reliability;

  /// Follow-a-bus camera mode.
  final bool followVehicle;

  /// Route polyline on the line map. Off until route data exists.
  final bool routeLine;

  /// Device-only "you helped N trips" counter on the end card.
  final bool localKudos;

  /// Passenger reports on the line sheet and trip screen.
  final bool reports;

  /// Returns a copy with overrides applied. Unknown JSON keys are ignored.
  Features copyWith({
    bool? shortcuts,
    bool? recents,
    bool? favorites,
    bool? dataSaver,
    bool? predictions,
    bool? eta,
    bool? arrivalAlerts,
    bool? reliability,
    bool? followVehicle,
    bool? routeLine,
    bool? localKudos,
    bool? reports,
  }) {
    return Features(
      shortcuts: shortcuts ?? this.shortcuts,
      recents: recents ?? this.recents,
      favorites: favorites ?? this.favorites,
      dataSaver: dataSaver ?? this.dataSaver,
      predictions: predictions ?? this.predictions,
      eta: eta ?? this.eta,
      arrivalAlerts: arrivalAlerts ?? this.arrivalAlerts,
      reliability: reliability ?? this.reliability,
      followVehicle: followVehicle ?? this.followVehicle,
      routeLine: routeLine ?? this.routeLine,
      localKudos: localKudos ?? this.localKudos,
      reports: reports ?? this.reports,
    );
  }

  /// Applies overrides from a decoded JSON map. Non-boolean or unknown
  /// values are ignored so a new server flag never breaks the app.
  static Features fromJson(Map<String, dynamic> json) {
    const Features base = Features();
    return base.copyWith(
      shortcuts: _flag(json, 'shortcuts') ?? base.shortcuts,
      recents: _flag(json, 'recents') ?? base.recents,
      favorites: _flag(json, 'favorites') ?? base.favorites,
      dataSaver: _flag(json, 'data_saver') ?? base.dataSaver,
      predictions: _flag(json, 'predictions') ?? base.predictions,
      eta: _flag(json, 'eta') ?? base.eta,
      arrivalAlerts: _flag(json, 'arrival_alerts') ?? base.arrivalAlerts,
      reliability: _flag(json, 'reliability') ?? base.reliability,
      followVehicle: _flag(json, 'follow_vehicle') ?? base.followVehicle,
      routeLine: _flag(json, 'route_line') ?? base.routeLine,
      localKudos: _flag(json, 'local_kudos') ?? base.localKudos,
      reports: _flag(json, 'reports') ?? base.reports,
    );
  }

  static bool? _flag(Map<String, dynamic> json, String key) {
    final Object? value = json[key];
    return value is bool ? value : null;
  }
}
