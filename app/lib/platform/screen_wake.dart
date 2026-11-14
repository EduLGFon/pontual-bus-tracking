// Platform screen wake lock. Keeps the display on during a trip when the
// rider opts in on Android, and while the web trip screen stays open.
// Backed by wakelock_plus, which uses FLAG_KEEP_SCREEN_ON on Android and
// adds no manifest permission. Failures are reported through `enabled`,
// never thrown, so sharing continues when the platform refuses.
import 'package:wakelock_plus/wakelock_plus.dart';

/// Controls the screen wake lock. Injectable for tests.
abstract class ScreenWake {
  /// Requests the wake lock.
  Future<void> enable();

  /// Releases the wake lock.
  Future<void> disable();

  /// True while the lock is held.
  Future<bool> get enabled;
}

/// Production screen wake lock backed by wakelock_plus.
class ProdScreenWake implements ScreenWake {
  /// Creates the production wake lock.
  const ProdScreenWake();

  @override
  Future<void> enable() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {
      // Unsupported platforms stay usable; the UI carries the message.
    }
  }

  @override
  Future<void> disable() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {
      // Best effort only.
    }
  }

  @override
  Future<bool> get enabled async {
    try {
      return await WakelockPlus.enabled;
    } catch (_) {
      return false;
    }
  }
}

/// Fake screen wake lock for tests.
class FakeScreenWake implements ScreenWake {
  /// Creates a fake. Set [failEnable] to simulate a platform that refuses
  /// the wake lock.
  FakeScreenWake({this.failEnable = false});

  /// When true, [enable] leaves the lock unheld.
  final bool failEnable;

  /// Whether enable was called without a matching disable.
  bool held = false;

  /// Number of enable calls.
  int enables = 0;

  /// Number of disable calls.
  int disables = 0;

  @override
  Future<void> enable() async {
    enables += 1;
    if (failEnable) {
      return;
    }
    held = true;
  }

  @override
  Future<void> disable() async {
    disables += 1;
    held = false;
  }

  @override
  Future<bool> get enabled async => held;
}
