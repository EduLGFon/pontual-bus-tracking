// Local flag for the one automatic viewer-location attempt on the line
// screen. The OS or browser prompt is the first-use permission UI, so the
// app remembers that it already asked and never prompts again on its own.
// PRIVACY: a boolean only; no coordinates, accuracy or identifiers.
// See DECISIONS.md D96 and docs/ui/personal-arrival.md.
import 'package:shared_preferences/shared_preferences.dart';

/// Storage key of the automatic viewer-location attempt.
const String viewerLocationAutoRequestedKey =
    'viewer_location_auto_requested_v1';

/// Reads and writes whether this install already made its one automatic
/// viewer-location attempt.
class ViewerLocationAutoRequestStore {
  /// Creates the store.
  const ViewerLocationAutoRequestStore();

  /// True when an automatic attempt already happened on this install.
  Future<bool> requested() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(viewerLocationAutoRequestedKey) ?? false;
  }

  /// Records that the automatic attempt happened, whatever its outcome.
  Future<void> markRequested() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(viewerLocationAutoRequestedKey, true);
  }
}
