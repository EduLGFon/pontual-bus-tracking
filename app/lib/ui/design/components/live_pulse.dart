// LivePulse: the single shared pulse controller. Live dots and vehicle
// markers animate from it so no widget owns its own ticker. Paused when
// reduced motion is on or when the subtree is hidden (TickerMode).
// See docs/ui/UI_SPEC.md 5 (LiveDot) and 9.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/tokens/motion.dart';

/// Hosts the shared live-pulse controller for its subtree.
class LivePulse extends StatefulWidget {
  /// Creates the host.
  const LivePulse({required this.child, super.key});

  /// Subtree that can read the controller through [LivePulseScope].
  final Widget child;

  @override
  State<LivePulse> createState() => _LivePulseState();
}

class _LivePulseState extends State<LivePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.pulse,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(LivePulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  /// Starts or stops the loop to match the current context.
  void _sync() {
    if (!mounted) {
      return;
    }
    final bool reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final bool tickerOn = TickerMode.valuesOf(context).enabled;
    if (reduce || !tickerOn) {
      _controller.stop();
      return;
    }
    if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LivePulseScope(controller: _controller, child: widget.child);
  }
}

/// Makes the shared controller reachable without rebuilding the host.
class LivePulseScope extends InheritedWidget {
  /// Creates the scope.
  const LivePulseScope({
    required this.controller,
    required super.child,
    super.key,
  });

  /// Shared pulse controller.
  final AnimationController controller;

  /// Returns the shared controller, or null when no host is mounted.
  static AnimationController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<LivePulseScope>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(LivePulseScope oldWidget) {
    return oldWidget.controller != controller;
  }
}
