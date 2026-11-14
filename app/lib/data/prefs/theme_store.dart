// Persisted theme mode. System default; the settings screen writes
// through this store and updates themeModeProvider. See ARCHITECTURE.md S10.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Prefs key for the theme mode.
const String themeModeKey = 'theme_mode';

/// Reads and writes the theme mode.
class ThemeStore {
  /// Creates the store.
  const ThemeStore();

  /// Reads the saved mode, defaulting to system.
  Future<ThemeMode> read() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    switch (prefs.getString(themeModeKey)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  /// Persists [mode].
  Future<void> write(ThemeMode mode) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(themeModeKey, mode.name);
  }
}
