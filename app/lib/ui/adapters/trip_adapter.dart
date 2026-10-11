// Trip adapter: shapes the existing TripController into the TripVM the
// shell draws. The controller keeps every side effect and every state
// transition; this file only reads it.
// See docs/ui/UI_SPEC.md 6.1.
import 'package:pontual/domain/trip/trip_state.dart';
import 'package:pontual/features/trip/trip_controller.dart';
import 'package:pontual/ui/models/trip_vm.dart';

/// Converts controller state into the dock view-model.
TripVM tripVmOf(TripController controller) {
  final TripState state = controller.state;
  final bool active = state is TripActive;
  final TripPhase phase;
  if (state is TripIdle) {
    phase = TripPhase.idle;
  } else if (controller.isPaused) {
    phase = TripPhase.paused;
  } else if (controller.isOffline) {
    phase = TripPhase.reconnecting;
  } else if (active) {
    phase = TripPhase.active;
  } else {
    phase = TripPhase.starting;
  }
  return TripVM(
    phase: phase,
    lineKey: controller.lineId?.toString(),
    lineLabel: controller.lineLabel,
    elapsedS: _elapsedS(controller),
    gpsOff: controller.isPaused,
    webHidden: controller.isWebHidden,
    role: _roleOf(state),
  );
}

/// Elapsed seconds since the start, zero before a trip exists.
int _elapsedS(TripController controller) {
  final int? start = controller.startedAtMs;
  if (start == null) {
    return 0;
  }
  final int delta = DateTime.now().millisecondsSinceEpoch - start;
  return delta < 0 ? 0 : delta ~/ 1000;
}

/// Role name of an active trip, "waiting" otherwise.
String _roleOf(TripState state) {
  final TripRole? role = activeRole(state);
  return role?.name ?? 'waiting';
}

/// Formats mm:ss for the trip elapsed timer.
String formatElapsed(int elapsedS) {
  final String hh = (elapsedS ~/ 3600).toString().padLeft(2, '0');
  final String mm = ((elapsedS ~/ 60) % 60).toString().padLeft(2, '0');
  final String ss = (elapsedS % 60).toString().padLeft(2, '0');
  return '$hh:$mm:$ss';
}
