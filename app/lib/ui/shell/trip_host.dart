// Trip host: holds the TripController created by the share flow and exposes
// the TripVM the dock and the trip screen draw. Only the dock starts or
// stops a trip, through the existing share flow and controller.
// See docs/ui/UI_SPEC.md 7.1.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/domain/trip/trip_state.dart';
import 'package:pontual/features/trip/trip_controller.dart';

/// Holds the active controller. Null when no trip is running.
class TripHost extends Notifier<TripController?> {
  @override
  TripController? build() => null;

  /// Attaches a started controller. Disposes a different previous one:
  /// a superseded share flow must never keep pinging behind the new trip.
  /// Callers must end the previous trip before starting a new one; with
  /// the entry guard in the share flow the previous instance is always
  /// idle here, so this dispose carries no native subscription and can
  /// never kill the new foreground service.
  void attach(TripController controller) {
    final TripController? current = state;
    state = controller;
    if (current != null && current != controller) {
      current.dispose();
    }
  }

  /// True while a trip occupies the device (sharing or winding down).
  /// The share flow checks this before subscribing: only one trip at a
  /// time, so a new start never races the previous foreground-service
  /// teardown.
  bool get hasLiveTrip {
    final TripController? current = state;
    if (current == null) {
      return false;
    }
    return tripInProgress(current.state);
  }

  /// Detaches and disposes the controller.
  void detach() {
    final TripController? current = state;
    state = null;
    current?.dispose();
  }

  /// Detaches [controller] once its screen is gone and no trip runs. A
  /// live trip keeps its host, so minimising the screen leaves the dock
  /// working and the controller alive. Reads only its own state, so it is
  /// safe to call from a widget dispose through a captured notifier.
  void detachIfIdle(TripController controller) {
    if (state != controller) {
      return;
    }
    if (tripInProgress(controller.state)) {
      return;
    }
    detach();
  }
}

/// Provides the trip controller.
final NotifierProvider<TripHost, TripController?> tripHostProvider =
    NotifierProvider<TripHost, TripController?>(TripHost.new);
