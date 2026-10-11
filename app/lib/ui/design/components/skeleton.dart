// Skeleton: static rounded rectangles in the sunken surface. One shared
// opacity pulse, and only shown after 300 ms of loading.
// See docs/ui/UI_SPEC.md 5 and 10.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';

/// A single placeholder block.
class Skeleton extends StatelessWidget {
  /// Creates the block.
  const Skeleton({
    this.width,
    this.height = 16,
    this.radius = Radii.s,
    super.key,
  });

  /// Width, null fills the available width.
  final double? width;

  /// Height in dp.
  final double height;

  /// Corner radius.
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Hosts the shared 1.2 s opacity pulse.
class SkeletonHost extends StatefulWidget {
  /// Creates the host.
  const SkeletonHost({required this.child, super.key});

  /// Subtree that can read the controller through [SkeletonScope].
  final Widget child;

  @override
  State<SkeletonHost> createState() => _SkeletonHostState();
}

class _SkeletonHostState extends State<SkeletonHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SkeletonScope(
      controller: _controller,
      minOpacity: 0.45,
      child: widget.child,
    );
  }
}

/// Makes the shared skeleton controller reachable.
class SkeletonScope extends InheritedWidget {
  /// Creates the scope.
  const SkeletonScope({
    required this.controller,
    required this.minOpacity,
    required super.child,
    super.key,
  });

  /// Shared pulse controller.
  final AnimationController controller;

  /// Lowest opacity reached by the pulse.
  final double minOpacity;

  @override
  bool updateShouldNotify(SkeletonScope oldWidget) {
    return oldWidget.controller != controller ||
        oldWidget.minOpacity != minOpacity;
  }
}

/// A skeleton that pulses with the shared controller.
class PulsingSkeleton extends StatelessWidget {
  /// Creates the block.
  const PulsingSkeleton({
    this.width,
    this.height = 16,
    this.radius = Radii.s,
    super.key,
  });

  /// Width, null fills the available width.
  final double? width;

  /// Height in dp.
  final double height;

  /// Corner radius.
  final double radius;

  @override
  Widget build(BuildContext context) {
    final SkeletonScope? scope = context
        .dependOnInheritedWidgetOfExactType<SkeletonScope>();
    final Widget block = Skeleton(width: width, height: height, radius: radius);
    if (scope == null) {
      return block;
    }
    return FadeTransition(
      opacity: Tween<double>(begin: scope.minOpacity, end: 1).animate(
        CurvedAnimation(parent: scope.controller, curve: Curves.easeInOut),
      ),
      child: block,
    );
  }
}

/// Delays its child by [delay] before building it, used to honour the
/// 300 ms rule without any timer in the widget itself.
class Delayed extends StatelessWidget {
  /// Creates the delay.
  const Delayed({required this.delay, required this.child, super.key});

  /// How long to wait.
  final Duration delay;

  /// Widget shown once the delay elapsed.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: delay,
      builder: (BuildContext context, double value, Widget? w) {
        return value >= 1 ? child : const SizedBox.shrink();
      },
    );
  }
}

/// Builds a skeleton list with [count] rows.
class SkeletonList extends StatelessWidget {
  /// Creates the list.
  const SkeletonList({this.count = 4, super.key});

  /// Number of placeholder rows.
  final int count;

  @override
  Widget build(BuildContext context) {
    return SkeletonHost(
      child: Column(
        children: <Widget>[
          for (int i = 0; i < count; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: Space.x3),
              child: Row(
                children: <Widget>[
                  Skeleton(width: 40, height: 28, radius: Radii.pill),
                  SizedBox(width: Space.x3),
                  Expanded(child: Skeleton(height: 20)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
