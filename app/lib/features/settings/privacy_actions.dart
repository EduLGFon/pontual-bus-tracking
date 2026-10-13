// Delete-my-data and revoke-consent actions. Pure orchestration over
// the typed API and local stores; the screen handles dialogs and
// navigation. Offline delete reports honestly and keeps local data.
// See PLAN.md S11 and RF15.
import 'package:pontual/core/errors/failures.dart';
import 'package:pontual/data/api/bus_api.dart';
import 'package:pontual/data/prefs/consent_store.dart';
import 'package:pontual/data/prefs/token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Outcome of a delete-my-data attempt.
enum DeleteOutcome {
  /// Server record deleted (or none existed) and local storage cleared.
  deleted,

  /// Server unreachable: nothing was cleared, try again online.
  offline,
}

/// Privacy actions for S11.
class PrivacyActions {
  /// Creates the actions.
  const PrivacyActions({
    required this.api,
    this.tokenStore = const TokenStore(),
    this.consentStore = const ConsentStore(),
  });

  /// Typed API client.
  final BusApi api;

  /// Token storage.
  final TokenStore tokenStore;

  /// Consent storage.
  final ConsentStore consentStore;

  /// Ends the active trip server-side, deletes the device record, and
  /// clears local storage. Returns offline when the server cannot be
  /// reached, leaving everything untouched.
  Future<DeleteOutcome> deleteMyData() async {
    final String? token = await tokenStore.read();
    if (token != null) {
      final Result<bool> res = await api.deleteMe(token);
      if (res is Err<bool>) {
        return DeleteOutcome.offline;
      }
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    return DeleteOutcome.deleted;
  }

  /// Best-effort ends any active trip and clears the local consent
  /// flag so the next trip asks again. Also forgets the server
  /// confirmation: the next acceptance re-posts instead of riding on
  /// the pre-revoke record. Full server-side revocation needs a
  /// DELETE /v1/consents endpoint (D54); until then re-posting is the
  /// honest re-affirmation within the current contract.
  Future<void> revokeConsent() async {
    final String? token = await tokenStore.read();
    if (token != null) {
      try {
        await api.endTrip(token).timeout(const Duration(seconds: 5));
      } catch (_) {
        // Best effort only; the server times trips out by itself.
      }
    }
    await consentStore.clear();
    await consentStore.clearPosted();
  }
}
