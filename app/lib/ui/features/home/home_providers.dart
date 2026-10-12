// Providers shared by the Início feature files. The foundation exposes the
// feature-flag model and the local stores but not their providers, so these
// stand in and are overridable in tests.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/ui/adapters/local_stores.dart';
import 'package:pontual/ui/models/features.dart';
import 'package:pontual/ui/models/line_vm.dart';

/// Feature flags of the new UI. Replaceable once a foundation provider exists.
final Provider<Features> homeFeaturesProvider = Provider<Features>(
  (Ref ref) => const Features(),
);

/// Finds a line view-model by key in an already-available list.
LineVM? lineByKey(List<LineVM> lines, String key) {
  for (final LineVM line in lines) {
    if (line.key == key) {
      return line;
    }
  }
  return null;
}

/// Last opened line keys, newest first, loaded once and cleared optimistically.
class RecentsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    unawaited(_load());
    return const <String>[];
  }

  Future<void> _load() async {
    try {
      state = await const RecentsStore().read();
    } on Object {
      // Defaults (empty) stand when prefs are unavailable.
    }
  }

  /// Clears the recent list.
  void clear() {
    state = const <String>[];
    unawaited(const RecentsStore().clear());
  }

  /// Restores a previous list, used by the undo action after clearing.
  void restore(List<String> keys) {
    state = keys.toList();
    unawaited(const RecentsStore().write(keys));
  }
}

/// Provides the recent line keys of Início.
final NotifierProvider<RecentsNotifier, List<String>> homeRecentsProvider =
    NotifierProvider<RecentsNotifier, List<String>>(RecentsNotifier.new);
