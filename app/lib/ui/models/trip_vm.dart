// Trip view-model: what the shell needs to render the dock and the trip
// screen. Built by an adapter from the existing TripController, which keeps
// owning every side effect. See docs/ui/UI_SPEC.md 6.2.
import 'package:flutter/foundation.dart';

/// Phase shown by the dock.
enum TripPhase {
  /// No trip, nothing to show but the CTA.
  idle,

  /// Trip is starting, the label changes and taps are ignored.
  starting,

  /// Sharing right now.
  active,

  /// Sends failing, retrying.
  reconnecting,

  /// Permission or GPS problem paused the trip.
  paused,
}

/// Trip state as the UI sees it.
@immutable
class TripVM {
  /// Creates the view-model.
  const TripVM({
    required this.phase,
    this.lineKey,
    this.lineLabel = '',
    this.elapsedS = 0,
    this.gpsOff = false,
    this.webHidden = false,
    this.role = 'waiting',
  });

  /// Current phase.
  final TripPhase phase;

  /// Line being shared, null when the flow has not chosen one yet.
  final String? lineKey;

  /// Line name for the dock and the trip screen.
  final String lineLabel;

  /// Seconds since the trip started.
  final int elapsedS;

  /// True while location services are off.
  final bool gpsOff;

  /// True on the web while the page is hidden.
  final bool webHidden;

  /// Sampling role: waiting, leader, follower or offlineSaver.
  final String role;

  /// True while a trip occupies the device.
  bool get inProgress =>
      phase == TripPhase.starting ||
      phase == TripPhase.active ||
      phase == TripPhase.reconnecting ||
      phase == TripPhase.paused;

  /// Whether the dock is in a state that needs attention.
  bool get needsAttention =>
      phase == TripPhase.reconnecting || phase == TripPhase.paused;
}
