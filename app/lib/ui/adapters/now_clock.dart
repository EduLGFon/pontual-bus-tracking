// Now clock adapter: exposes the wall clock the UI formats against. The
// UI never calls DateTime.now() itself.
// See docs/ui/UI_SPEC.md 5.2.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/domain/schedule.dart';
import 'package:pontual/ui/util/lifecycle_ticks.dart';

/// Current São Mateus wall clock. Re-evaluates when [nowTickProvider] emits.
/// Auto-disposed with its watchers so the minute tick stops when no
/// countdown is visible.
final Provider<DateTime> currentNowProvider = Provider.autoDispose<DateTime>((
  Ref ref,
) {
  ref.watch(nowTickProvider);
  return saoMateusTime(DateTime.now());
});

/// Emits once per minute so every countdown re-renders together. Paused
/// while the app is not resumed: no countdown is visible then. Disposed
/// with the last watcher so the minute timer never wakes the isolate
/// for invisible screens.
final StreamProvider<int> nowTickProvider = StreamProvider.autoDispose<int>((
  Ref ref,
) {
  return lifecycleTicks(const Duration(minutes: 1));
});
