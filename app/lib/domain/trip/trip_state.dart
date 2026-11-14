// Pure trip state machine. Sealed states, pure transitions, effects as
// data executed by TripController. Only one trip at a time. Illegal
// events are ignored. See ARCHITECTURE.md 8.5.

/// Sampling roles inside an active trip.
enum TripRole {
  /// Not yet attached to a moving vehicle.
  waiting,

  /// High-frequency reporter for the vehicle.
  leader,

  /// Low-frequency redundancy reporter.
  follower,

  /// Connectivity lost; probes only.
  offlineSaver,
}

/// Trip states.
sealed class TripState {
  /// Creates a state.
  const TripState();
}

/// No active trip.
class TripIdle extends TripState {
  /// Creates the idle state.
  const TripIdle();
}

/// Consent disclosure on screen.
class TripConsent extends TripState {
  /// Creates the consent state.
  const TripConsent();
}

/// Permission request flow.
class TripPermissions extends TripState {
  /// Creates the permissions state.
  const TripPermissions();
}

/// Trip creation in flight.
class TripStarting extends TripState {
  /// Creates the starting state.
  const TripStarting();
}

/// Trip active with a sampling role.
class TripActive extends TripState {
  /// Creates the active state.
  const TripActive(this.role);

  /// Current sampling role.
  final TripRole role;
}

/// Trip ending in flight.
class TripEnding extends TripState {
  /// Creates the ending state.
  const TripEnding();
}

/// Events driving the machine.
enum TripEvent {
  /// User taps "Estou no ônibus".
  tapStart,

  /// User accepts consent.
  consentAccepted,

  /// User declines consent.
  consentDeclined,

  /// Permissions granted.
  permissionsGranted,

  /// Permissions denied.
  permissionsDenied,

  /// Server confirmed the trip start.
  startConfirmed,

  /// Start call failed.
  startFailed,

  /// Server assigned the leader role.
  roleLeader,

  /// Server assigned the follower role.
  roleFollower,

  /// Connectivity lost.
  wentOffline,

  /// Connectivity back.
  wentOnline,

  /// User taps "Desci" or an auto-end fired.
  tapEnd,

  /// End call finished or best effort done.
  endConfirmed,
}

/// Transition result: the next state.
TripState tripReduce(TripState state, TripEvent event) {
  return switch (state) {
    TripIdle() => switch (event) {
      TripEvent.tapStart => const TripConsent(),
      _ => state,
    },
    TripConsent() => switch (event) {
      TripEvent.consentAccepted => const TripPermissions(),
      TripEvent.consentDeclined => const TripIdle(),
      _ => state,
    },
    TripPermissions() => switch (event) {
      TripEvent.permissionsGranted => const TripStarting(),
      TripEvent.permissionsDenied => const TripIdle(),
      _ => state,
    },
    TripStarting() => switch (event) {
      TripEvent.startConfirmed => const TripActive(TripRole.waiting),
      TripEvent.startFailed => const TripIdle(),
      _ => state,
    },
    TripActive(role: _) => switch (event) {
      TripEvent.roleLeader => const TripActive(TripRole.leader),
      TripEvent.roleFollower => const TripActive(TripRole.follower),
      TripEvent.wentOffline => const TripActive(TripRole.offlineSaver),
      TripEvent.wentOnline => const TripActive(TripRole.waiting),
      TripEvent.tapEnd => const TripEnding(),
      _ => state,
    },
    TripEnding() => switch (event) {
      TripEvent.endConfirmed => const TripIdle(),
      _ => state,
    },
  };
}

/// True while a trip occupies the device (sharing or winding down).
bool tripInProgress(TripState state) {
  return state is TripStarting || state is TripActive || state is TripEnding;
}

/// Role of an active trip, or null otherwise.
TripRole? activeRole(TripState state) {
  if (state is TripActive) {
    return state.role;
  }
  return null;
}
