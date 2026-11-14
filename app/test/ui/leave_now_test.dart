// Pure unit tests for the leave-now verdict. No widgets, no providers,
// no clock: only the walking estimate and the plan boundaries.
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/ui/features/line/leave_now.dart';

void main() {
  group('walkMinutesFor', () {
    test('zero distance needs no walk', () {
      expect(walkMinutesFor(0), 0);
    });

    test('exact multiples of the walking pace', () {
      expect(walkMinutesFor(80), 1);
      expect(walkMinutesFor(160), 2);
      expect(walkMinutesFor(240), 3);
    });

    test('a positive distance rounds up to at least one minute', () {
      expect(walkMinutesFor(1), 1);
      expect(walkMinutesFor(81), 2);
    });
  });

  group('planLeaveNow', () {
    test('at the stop wins over arriving', () {
      final LeaveNowPlan plan = planLeaveNow(
        etaMinutes: 0,
        walkMinutes: 2,
        arriving: true,
        atStop: true,
      );
      expect(plan.kind, LeaveNowKind.atStop);
      expect(plan.etaMinutes, 0);
      expect(plan.walkMinutes, 2);
      expect(plan.leaveInMin, isNull);
      expect(plan.spareMin, isNull);
    });

    test('arriving wins over the walking comparison', () {
      final LeaveNowPlan plan = planLeaveNow(
        etaMinutes: 1,
        walkMinutes: 8,
        arriving: true,
      );
      expect(plan.kind, LeaveNowKind.arriving);
      expect(plan.leaveInMin, isNull);
      expect(plan.spareMin, isNull);
    });

    test('eta equal to the walk means leave now', () {
      final LeaveNowPlan plan = planLeaveNow(etaMinutes: 4, walkMinutes: 4);
      expect(plan.kind, LeaveNowKind.leaveNow);
    });

    test('eta shorter than the walk means leave now', () {
      final LeaveNowPlan plan = planLeaveNow(etaMinutes: 2, walkMinutes: 5);
      expect(plan.kind, LeaveNowKind.leaveNow);
    });

    test('one minute of spare means leave soon', () {
      final LeaveNowPlan plan = planLeaveNow(etaMinutes: 5, walkMinutes: 4);
      expect(plan.kind, LeaveNowKind.leaveSoon);
      expect(plan.leaveInMin, 1);
      expect(plan.spareMin, isNull);
    });

    test('three minutes of spare is still leave soon', () {
      final LeaveNowPlan plan = planLeaveNow(etaMinutes: 7, walkMinutes: 4);
      expect(plan.kind, LeaveNowKind.leaveSoon);
      expect(plan.leaveInMin, 3);
      expect(plan.spareMin, isNull);
    });

    test('four minutes of spare becomes still time', () {
      final LeaveNowPlan plan = planLeaveNow(etaMinutes: 8, walkMinutes: 4);
      expect(plan.kind, LeaveNowKind.stillTime);
      expect(plan.leaveInMin, isNull);
      expect(plan.spareMin, 4);
    });

    test('plan keeps the eta and walk inputs', () {
      final LeaveNowPlan plan = planLeaveNow(etaMinutes: 12, walkMinutes: 3);
      expect(plan.etaMinutes, 12);
      expect(plan.walkMinutes, 3);
    });
  });
}
