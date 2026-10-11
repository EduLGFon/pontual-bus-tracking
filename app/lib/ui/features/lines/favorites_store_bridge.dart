// Favourites bridge: the notifier behind the star toggle on every line row
// and behind the "Favoritas" filter. Updates are optimistic, so the row
// flips before the store write finishes. See docs/ui/UI_SPEC.md 6.3, 7.4.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/ui/adapters/local_stores.dart';

/// Favourite line keys. Holds the optimistic set while [FavoritesStore]
/// catches up, and survives a rebuild because the provider outlives screens.
class FavoritesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    const FavoritesStore store = FavoritesStore();
    unawaited(_load(store));
    return const <String>{};
  }

  Future<void> _load(FavoritesStore store) async {
    Set<String> keys = const <String>{};
    try {
      keys = await store.read();
    } on Object {
      // Defaults stand when preferences are unavailable.
    }
    state = keys;
  }

  /// True when [key] is a favourite.
  bool has(String key) => state.contains(key);

  /// Toggles [key] optimistically, then persists.
  Future<void> toggle(String key) async {
    final Set<String> next = Set<String>.of(state);
    if (!next.add(key)) {
      next.remove(key);
    }
    state = next;
    const FavoritesStore store = FavoritesStore();
    await store.toggle(key);
  }
}

/// Provides the favourite line keys.
final NotifierProvider<FavoritesNotifier, Set<String>> favoritesProvider =
    NotifierProvider<FavoritesNotifier, Set<String>>(FavoritesNotifier.new);
