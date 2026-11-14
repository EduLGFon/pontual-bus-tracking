// Shared favourite action for line rows. Linhas and Busca must announce,
// toast and offer undo identically, so both call this instead of keeping
// their own copy. See docs/ui/UI_SPEC.md 6.3 and 7.4.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/ui/features/lines/favorites_store_bridge.dart';
import 'package:pontual/ui/shell/toast_host.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Toggles [key] optimistically with a haptic and an undo toast.
void toggleFavoriteLine(WidgetRef ref, String key) {
  HapticFeedback.selectionClick();
  final bool wasFavorite = ref.read(favoritesProvider).contains(key);
  unawaited(ref.read(favoritesProvider.notifier).toggle(key));
  ref
      .read(toastControllerProvider.notifier)
      .show(
        wasFavorite ? UiStrings.linesFavRemoved : UiStrings.linesFavAdded,
        actionLabel: UiStrings.undo,
        onAction: () =>
            unawaited(ref.read(favoritesProvider.notifier).toggle(key)),
      );
}
