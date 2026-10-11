// Toast host: one global toast queue, shown above the dock.
// See docs/ui/UI_SPEC.md 7.1.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/ui/design/components/toast.dart';

/// Provides the single toast controller of the app.
final NotifierProvider<ToastNotifier, ToastController> toastControllerProvider =
    NotifierProvider<ToastNotifier, ToastController>(ToastNotifier.new);

/// Owns the toast controller for the app lifetime.
class ToastNotifier extends Notifier<ToastController> {
  @override
  ToastController build() => ToastController();

  @override
  bool updateShouldNotify(ToastController previous, ToastController next) {
    return false;
  }

  /// Shows a message with an optional action.
  void show(String message, {String? actionLabel, VoidCallback? onAction}) {
    state.show(message, actionLabel: actionLabel, onAction: onAction);
  }
}
