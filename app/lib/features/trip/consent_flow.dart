// Consent flow: sheet plus local versioning plus server record. Offline
// acceptance is stored locally and retried before starting. A trip never
// starts without covering consent. See ARCHITECTURE.md S06 and RF14.
import 'package:pontual/core/errors/failures.dart';
import 'package:pontual/data/prefs/consent_store.dart';

/// Outcome of the consent flow.
enum ConsentResult {
  /// Ready to start: local and server both cover the version.
  granted,

  /// User declined or dismissed the sheet.
  declined,

  /// Accepted locally but the server record failed; retry before starting.
  offlinePending,
}

/// Ensures consent for [currentVersion]. [showSheet] presents the S06
/// sheet; [postConsents] calls POST /v1/consents and returns true on 200.
/// The server record is reconciled only while unconfirmed: a locally
/// stored acceptance from an offline run must still be posted, or trip
/// start fails the server consent guard. The server upserts, so reposting
/// is safe. Confirmed versions cost no request (the consents endpoint is
/// rate limited to a few posts per hour per device).
Future<ConsentResult> ensureConsent({
  required int currentVersion,
  required ConsentStore store,
  required Future<bool> Function() showSheet,
  required Future<Result<bool>> Function() postConsents,
}) async {
  if (!await store.covers(currentVersion)) {
    final bool accepted = await showSheet();
    if (!accepted) {
      return ConsentResult.declined;
    }
    await store.write(currentVersion);
  }
  if (await store.readPosted() == currentVersion) {
    return ConsentResult.granted;
  }
  final Result<bool> posted = await postConsents();
  if (posted is Ok<bool>) {
    await store.markPosted(currentVersion);
    return ConsentResult.granted;
  }
  return ConsentResult.offlinePending;
}
