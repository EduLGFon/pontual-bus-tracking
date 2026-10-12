// Local stores for the new UI: shortcuts, recents, favourites, and the
// two settings toggles. All are tiny versioned JSON in shared_preferences,
// the storage the project already uses. No new persistence layer.
// See docs/ui/UI_SPEC.md 6.3.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pontual/ui/models/shortcut_vm.dart';

/// Storage key for the shortcut list.
const String shortcutsKey = 'ui_shortcuts_v1';

/// Storage key for the recent line keys.
const String recentsKey = 'ui_recents_v1';

/// Storage key for the favourite line keys.
const String favoritesKey = 'ui_favorites_v1';

/// Storage key for the data saver setting.
const String dataSaverKey = 'ui_data_saver_v1';

/// Storage key for the reduce animations setting.
const String reduceMotionKey = 'ui_reduce_motion_v1';

/// Storage key for the device-only helped-trips counter.
const String kudosKey = 'ui_kudos_v1';

/// Reads and writes the device-only helped-trips counter. Local only,
/// never sent anywhere. Shown on the trip end card (D30 extra).
class KudosStore {
  /// Creates the store.
  const KudosStore();

  /// Reads the counter, defaulting to zero.
  Future<int> read() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt(kudosKey) ?? 0;
  }

  /// Adds one helped trip.
  Future<void> addOne() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kudosKey, (prefs.getInt(kudosKey) ?? 0) + 1);
  }
}

/// Provides the helped-trips count.
final FutureProvider<int> kudosProvider = FutureProvider<int>((Ref ref) async {
  try {
    return await const KudosStore().read();
  } on Object {
    return 0;
  }
});

/// Reads and writes the shortcut list.
class ShortcutsStore {
  /// Creates the store.
  const ShortcutsStore();

  /// Reads the list, oldest first. Corrupt JSON returns an empty list.
  Future<List<ShortcutVM>> read() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String raw = prefs.getString(shortcutsKey) ?? '';
    if (raw.isEmpty) {
      return const <ShortcutVM>[];
    }
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(
            (dynamic e) => ShortcutVM.fromJson(
              (e as Map<dynamic, dynamic>).cast<String, dynamic>(),
            ),
          )
          .toList();
    } on FormatException {
      return const <ShortcutVM>[];
    }
  }

  /// Writes the list. Never stores more than [maxShortcuts] entries.
  Future<void> write(List<ShortcutVM> shortcuts) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<ShortcutVM> trimmed = shortcuts.length <= maxShortcuts
        ? shortcuts
        : shortcuts.sublist(0, maxShortcuts);
    final String raw = jsonEncode(
      trimmed.map((ShortcutVM s) => s.toJson()).toList(),
    );
    await prefs.setString(shortcutsKey, raw);
  }
}

/// Maximum number of shortcuts the home screen shows.
const int maxShortcuts = 8;

/// Reads and writes the recent line keys, newest first.
class RecentsStore {
  /// Creates the store.
  const RecentsStore();

  /// Reads the list.
  Future<List<String>> read() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> raw =
        prefs.getStringList(recentsKey) ?? const <String>[];
    return raw.where((String key) => key.isNotEmpty).toList();
  }

  /// Records [key] as the most recent opening.
  Future<void> add(String key) async {
    final List<String> current = await read();
    current.removeWhere((String e) => e == key);
    current.insert(0, key);
    if (current.length > maxRecents) {
      current.removeRange(maxRecents, current.length);
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(recentsKey, current);
  }

  /// Clears the list.
  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(recentsKey);
  }

  /// Overwrites the list, newest first, trimmed to [maxRecents].
  Future<void> write(List<String> keys) async {
    final List<String> trimmed = keys
        .where((String key) => key.isNotEmpty)
        .toList();
    if (trimmed.length > maxRecents) {
      trimmed.removeRange(maxRecents, trimmed.length);
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(recentsKey, trimmed);
  }
}

/// Maximum number of recent lines kept.
const int maxRecents = 8;

/// Reads and writes the favourite line keys.
class FavoritesStore {
  /// Creates the store.
  const FavoritesStore();

  /// Reads the list.
  Future<Set<String>> read() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> raw =
        prefs.getStringList(favoritesKey) ?? const <String>[];
    return raw.where((String key) => key.isNotEmpty).toSet();
  }

  /// Adds or removes [key].
  Future<void> toggle(String key) async {
    final Set<String> current = await read();
    if (!current.add(key)) {
      current.remove(key);
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(favoritesKey, current.toList());
  }

  /// Writes the whole set.
  Future<void> write(Set<String> keys) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(favoritesKey, keys.toList());
  }
}

/// Reads and writes the data saver setting.
class SettingsStore {
  /// Creates the store.
  const SettingsStore();

  /// Reads data saver, defaulting to false.
  Future<bool> readDataSaver() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(dataSaverKey) ?? false;
  }

  /// Writes data saver.
  Future<void> writeDataSaver(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(dataSaverKey, value);
  }

  /// Reads the reduce animations setting, defaulting to false.
  Future<bool> readReduceMotion() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(reduceMotionKey) ?? false;
  }

  /// Writes the reduce animations setting.
  Future<void> writeReduceMotion(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(reduceMotionKey, value);
  }
}

/// Local settings state, loaded once and updated optimistically.
class SettingsNotifier extends Notifier<UiSettings> {
  @override
  UiSettings build() {
    const SettingsStore store = SettingsStore();
    unawaited(_load(store));
    return const UiSettings();
  }

  Future<void> _load(SettingsStore store) async {
    bool dataSaver = false;
    bool reduceMotion = false;
    try {
      dataSaver = await store.readDataSaver();
      reduceMotion = await store.readReduceMotion();
    } on Object {
      // Defaults stand when prefs are unavailable.
    }
    state = UiSettings(dataSaver: dataSaver, reduceMotion: reduceMotion);
  }

  /// Sets data saver.
  Future<void> setDataSaver(bool value) async {
    state = state.copyWith(dataSaver: value);
    const SettingsStore store = SettingsStore();
    await store.writeDataSaver(value);
  }

  /// Sets reduce animations.
  Future<void> setReduceMotion(bool value) async {
    state = state.copyWith(reduceMotion: value);
    const SettingsStore store = SettingsStore();
    await store.writeReduceMotion(value);
  }
}

/// Local settings of the new UI.
class UiSettings {
  /// Creates the settings.
  const UiSettings({this.dataSaver = false, this.reduceMotion = false});

  /// Map and images stay on the cheap side.
  final bool dataSaver;

  /// Overrides the OS setting towards no motion.
  final bool reduceMotion;

  /// Returns a copy with the given overrides.
  UiSettings copyWith({bool? dataSaver, bool? reduceMotion}) {
    return UiSettings(
      dataSaver: dataSaver ?? this.dataSaver,
      reduceMotion: reduceMotion ?? this.reduceMotion,
    );
  }
}

/// Provides the local settings.
final NotifierProvider<SettingsNotifier, UiSettings> settingsProvider =
    NotifierProvider<SettingsNotifier, UiSettings>(SettingsNotifier.new);
