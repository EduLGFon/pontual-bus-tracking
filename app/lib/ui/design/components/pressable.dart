// Pressable: the interaction base for every tappable element. Tints the
// background by 6 percent of the ink colour and scales to 0.98 with no ink
// splash. Hover (web) tints 4 percent. Focus shows a 2 px primary outline.
// See docs/ui/UI_SPEC.md 5.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/motion.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';

/// Press feedback without ripples.
class Pressable extends StatefulWidget {
  /// Creates a pressable area around [child].
  const Pressable({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onPrefetch,
    this.semanticLabel,
    this.semanticButton = true,
    this.minSize = hitTarget,
    this.borderRadius = Radii.m,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  /// Content of the pressable area.
  final Widget child;

  /// Called on a completed tap.
  final VoidCallback? onTap;

  /// Called on a long press.
  final VoidCallback? onLongPress;

  /// Called on pointer down, to warm the next screen before the tap ends.
  final VoidCallback? onPrefetch;

  /// Screen-reader label of the action.
  final String? semanticLabel;

  /// Whether the element is announced as a button.
  final bool semanticButton;

  /// Minimum hit area in dp.
  final double minSize;

  /// Radius of the pressed tint.
  final double borderRadius;

  /// When false the element is inert and shows no feedback.
  final bool enabled;

  /// Optional focus node so callers can move focus into overlays.
  final FocusNode? focusNode;

  /// Whether the element takes focus on mount (web keyboard flows).
  final bool autofocus;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;
  bool _hovered = false;

  bool get _interactive => widget.enabled && widget.onTap != null;

  void _setPressed(bool value) {
    if (!_interactive || _pressed == value) {
      return;
    }
    setState(() => _pressed = value);
  }

  void _setHovered(bool value) {
    if (!_interactive || _hovered == value) {
      return;
    }
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final Color ink = context.colors.ink;
    final Color tint = _pressed
        ? ink.withValues(alpha: 0.06)
        : _hovered
        ? ink.withValues(alpha: 0.04)
        : ink.withValues(alpha: 0);
    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: FocusableActionDetector(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        enabled: _interactive,
        child: Semantics(
          label: widget.semanticLabel,
          button: widget.semanticButton && _interactive,
          enabled: _interactive,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) {
              _setPressed(true);
              widget.onPrefetch?.call();
            },
            onTapUp: (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            onTap: _interactive ? widget.onTap : null,
            onLongPress: widget.onLongPress,
            child: AnimatedScale(
              scale: _pressed ? 0.98 : 1,
              duration: Motion.instant,
              curve: MotionCurves.enter,
              child: AnimatedContainer(
                duration: Motion.instant,
                constraints: BoxConstraints(
                  minWidth: widget.minSize,
                  minHeight: widget.minSize,
                ),
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
