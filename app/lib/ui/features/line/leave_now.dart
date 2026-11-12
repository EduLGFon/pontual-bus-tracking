// Pure leave-now verdict for the personal arrival card: given the bus ETA
// and the walking time to the stop, decide whether the rider must leave
// now, in a few minutes, or still has time. No widgets, no strings, no
// clock, so the rules stay unit-testable on their own.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Walking speed used by the straight-line estimate, in meters per minute.
///
/// A calm walking pace of 4.8 km/h. The card discloses that the estimate
/// comes from the straight-line distance to the stop.
const double walkMetersPerMinute = 80;

/// Walking minutes needed to cover [distanceM].
///
/// Zero distance means no walk. Any positive distance takes at least one
/// minute, so the card never says zero minutes for a real walk.
int walkMinutesFor(double distanceM) {
  if (distanceM <= 0) {
    return 0;
  }
  return math.max(1, (distanceM / walkMetersPerMinute).ceil());
}

/// The five verdicts of the leave-now block.
enum LeaveNowKind {
  /// The bus is at the stop right now.
  atStop,

  /// The bus is arriving at the stop.
  arriving,

  /// The rider must walk now to catch the bus.
  leaveNow,

  /// The rider should leave in a few minutes.
  leaveSoon,

  /// There is spare time before the rider needs to leave.
  stillTime,
}

/// Immutable result of [planLeaveNow].
@immutable
class LeaveNowPlan {
  /// Creates a leave-now plan.
  const LeaveNowPlan({
    required this.kind,
    required this.etaMinutes,
    required this.walkMinutes,
    this.leaveInMin,
    this.spareMin,
  });

  /// The verdict to render.
  final LeaveNowKind kind;

  /// Bus ETA to the stop, in minutes.
  final int etaMinutes;

  /// Walking time to the stop, in minutes.
  final int walkMinutes;

  /// Minutes until the rider should leave, for the leave-soon verdict.
  final int? leaveInMin;

  /// Minutes of spare time, for the still-time verdict.
  final int? spareMin;
}

/// Decides the leave-now verdict.
///
/// Order matters: at the stop wins over arriving, which wins over the
/// walking comparison. When the ETA is not longer than the walk, the rider
/// must leave immediately. Otherwise the difference is the delay before
/// leaving; up to three minutes it is still worth leaving soon, beyond
/// that there is real spare time.
LeaveNowPlan planLeaveNow({
  required int etaMinutes,
  required int walkMinutes,
  bool arriving = false,
  bool atStop = false,
}) {
  if (atStop) {
    return LeaveNowPlan(
      kind: LeaveNowKind.atStop,
      etaMinutes: etaMinutes,
      walkMinutes: walkMinutes,
    );
  }
  if (arriving) {
    return LeaveNowPlan(
      kind: LeaveNowKind.arriving,
      etaMinutes: etaMinutes,
      walkMinutes: walkMinutes,
    );
  }
  if (etaMinutes <= walkMinutes) {
    return LeaveNowPlan(
      kind: LeaveNowKind.leaveNow,
      etaMinutes: etaMinutes,
      walkMinutes: walkMinutes,
    );
  }
  final int leaveInMin = etaMinutes - walkMinutes;
  if (leaveInMin <= 3) {
    return LeaveNowPlan(
      kind: LeaveNowKind.leaveSoon,
      etaMinutes: etaMinutes,
      walkMinutes: walkMinutes,
      leaveInMin: leaveInMin,
    );
  }
  return LeaveNowPlan(
    kind: LeaveNowKind.stillTime,
    etaMinutes: etaMinutes,
    walkMinutes: walkMinutes,
    spareMin: leaveInMin,
  );
}
