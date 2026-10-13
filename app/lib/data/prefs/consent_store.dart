// Local consent versioning. The accepted version is stored on device and
// posted to the server; offline acceptance is retried before starting.
// See PLAN.md S06 and RF14.
// PRIVACY: only the version number is stored, never location or identity.
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences key for the accepted consent version.
const String consentVersionKey = 'consent_version_accepted';

/// SharedPreferences key for the consent version last confirmed by the
/// server. A version can be accepted locally while its POST is still
/// failing (offline); only this key means the server recorded it.
const String consentPostedKey = 'consent_version_posted';

/// Tracks which consent text version the user accepted.
class ConsentStore {
  /// Creates a consent store.
  const ConsentStore();

  /// Returns the accepted version, or null when never accepted.
  Future<int?> read() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt(consentVersionKey);
  }

  /// Records local acceptance of [version].
  Future<void> write(int version) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(consentVersionKey, version);
  }

  /// True when the stored acceptance covers [currentVersion].
  Future<bool> covers(int currentVersion) async {
    return await read() == currentVersion;
  }

  /// Returns the version the server confirmed, or null when never posted.
  Future<int?> readPosted() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt(consentPostedKey);
  }

  /// Records that the server confirmed [version].
  Future<void> markPosted(int version) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(consentPostedKey, version);
  }

  /// Forgets the server confirmation so the next start reposts.
  /// Used when the server rejects a trip for missing consent.
  Future<void> clearPosted() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(consentPostedKey);
  }

  /// Clears acceptance for consent revocation.
  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(consentVersionKey);
  }
}
