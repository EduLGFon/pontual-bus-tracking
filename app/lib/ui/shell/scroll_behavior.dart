// Scroll behaviour of the new UI. Desktop and web pointers drag scrollable
// content (click-and-drag), while touch, stylus and trackpad keep working.
// See docs/ui/UI_SPEC.md 8.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Scroll behaviour with drag support for every pointer kind.
class PontualScrollBehavior extends MaterialScrollBehavior {
  /// Creates the behaviour.
  const PontualScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.unknown,
  };
}
