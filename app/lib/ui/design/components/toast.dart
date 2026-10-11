// Toast: a transient message above the dock. One at a time, 3 seconds,
// optional action, no SnackBar styling. See docs/ui/UI_SPEC.md 5.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/motion.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';

/// Controller that shows one toast at a time.
class ToastController extends ChangeNotifier {
  /// Creates the controller.
  ToastController({this.duration = const Duration(seconds: 3)});

  /// How long a toast stays.
  final Duration duration;

  ToastData? _current;
  Timer? _timer;

  /// The message currently shown, or null.
  ToastData? get current => _current;

  /// Shows [message] with an optional action. Replaces any visible toast.
  void show(String message, {String? actionLabel, VoidCallback? onAction}) {
    _timer?.cancel();
    _current = ToastData(
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
    notifyListeners();
    _timer = Timer(duration, hide);
  }

  /// Hides the toast immediately.
  void hide() {
    _timer?.cancel();
    _timer = null;
    if (_current == null) {
      return;
    }
    _current = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _current = null;
    super.dispose();
  }
}

/// Data of one toast.
@immutable
class ToastData {
  /// Creates the toast data.
  const ToastData({required this.message, this.actionLabel, this.onAction});

  /// Message in pt-BR.
  final String message;

  /// Optional action label.
  final String? actionLabel;

  /// Called when the action is tapped.
  final VoidCallback? onAction;
}

/// Widget that renders the current toast of [controller].
class ToastSlot extends StatelessWidget {
  /// Creates the slot.
  const ToastSlot({required this.controller, super.key});

  /// Controller holding the queue.
  final ToastController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        final ToastData? data = controller.current;
        return AnimatedSwitcher(
          duration: Motion.fast,
          child: data == null
              ? const SizedBox.shrink()
              : Padding(
                  key: ValueKey<ToastData>(data),
                  padding: const EdgeInsets.symmetric(horizontal: Space.x5),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.x4,
                      vertical: Space.x3,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceRaised,
                      borderRadius: BorderRadius.circular(Radii.m),
                      border: Border.all(color: colors.line),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            data.message,
                            style: context.text.body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (data.actionLabel != null &&
                            data.onAction != null) ...<Widget>[
                          const SizedBox(width: Space.x2),
                          GestureDetector(
                            onTap: data.onAction,
                            behavior: HitTestBehavior.opaque,
                            child: Text(
                              data.actionLabel!,
                              style: context.text.label.copyWith(
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}
