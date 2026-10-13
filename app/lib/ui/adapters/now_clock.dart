// Now clock adapter: exposes the wall clock the UI formats against. The
// UI never calls DateTime.now() itself.
// See docs/ui/UI_SPEC.md 5.2.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/domain/schedule.dart';

/// Current São Mateus wall clock. Re-evaluates when [nowTickProvider] emits.
final Provider<DateTime> currentNowProvider = Provider<DateTime>((Ref ref) {
  ref.watch(nowTickProvider);
  return saoMateusTime(DateTime.now());
});

/// Emits once per minute so every countdown re-renders together.
final StreamProvider<int> nowTickProvider = StreamProvider<int>((Ref ref) {
  return Stream<int>.periodic(const Duration(minutes: 1), (int i) => i);
});
