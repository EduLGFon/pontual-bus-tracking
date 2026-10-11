// Haptics and platform helpers. Haptics are no-op on web and respect the
// in-app setting. See docs/ui/UI_SPEC.md 4.6 and 8.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Tiny wrapper around [HapticFeedback] that ignores web and honours the
/// reduce-motion setting.
class Haptics {
  /// Creates the wrapper.
  const Haptics({this.enabled = true});

  /// When false every call is a no-op.
  final bool enabled;

  /// Selection change: segments, tabs, chips, sheet snap.
  void selection() {
    if (!enabled || kIsWeb) {
      return;
    }
    HapticFeedback.selectionClick();
  }

  /// Light impact: primary button press, trip end.
  void light() {
    if (!enabled || kIsWeb) {
      return;
    }
    HapticFeedback.lightImpact();
  }

  /// Medium impact: a trip started successfully.
  void medium() {
    if (!enabled || kIsWeb) {
      return;
    }
    HapticFeedback.mediumImpact();
  }
}

/// Platform questions in one place. No `dart:io` in shared code.
abstract class PlatformInfo {
  /// Private constructor: this class only exposes statics.
  const PlatformInfo._();

  /// True on the web build.
  static bool get isWeb => kIsWeb;

  /// True on Android.
  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// True on iOS.
  static bool get isIos =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
}

/// Browser family for the permission "how to unblock" copy.
enum BrowserFamily {
  /// Chrome or Edge.
  chromium,

  /// Safari on iPhone or macOS.
  safari,

  /// Firefox.
  firefox,

  /// Anything else.
  unknown,
}

/// Detects the browser family from a user-agent string.
BrowserFamily browserFamilyOf(String userAgent) {
  final String ua = userAgent.toLowerCase();
  if (ua.contains('firefox')) {
    return BrowserFamily.firefox;
  }
  if (ua.contains('safari') && !ua.contains('chrome')) {
    return BrowserFamily.safari;
  }
  if (ua.contains('chrome') || ua.contains('edg')) {
    return BrowserFamily.chromium;
  }
  return BrowserFamily.unknown;
}
