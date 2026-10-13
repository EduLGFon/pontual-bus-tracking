// Opaque device token storage. The token carries no PII, is revocable,
// and is useless outside the app sandbox. See PLAN.md 12.3 and
// DECISIONS.md token rationale.
// SECURITY: the token lives only in app-private storage and is cleared
// on delete-my-data; it is never logged or put in URLs.
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences key for the device token.
const String tokenPrefsKey = 'device_token';

/// Loads and stores the opaque device token.
class TokenStore {
  /// Creates a token store.
  const TokenStore();

  /// Returns the stored token, or null on a fresh install.
  Future<String?> read() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(tokenPrefsKey);
  }

  /// Persists the token after registration.
  Future<void> write(String token) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenPrefsKey, token);
  }

  /// Discards the token for delete-my-data.
  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenPrefsKey);
  }
}
