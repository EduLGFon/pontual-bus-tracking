// iOS "Add to Home Screen" hint. Shown once on iOS web browsers so
// viewers get the PWA experience (standalone, geolocation on tap).
// See PLAN.md 8.12 and T39.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Prefs key recording that the install hint was dismissed.
const String installHintSeenKey = 'install_hint_seen';

/// Returns true when the hint should show: iOS web browser, not seen.
bool shouldShowInstallHint({
  required bool isWeb,
  required bool isIos,
  required bool seen,
}) {
  return isWeb && isIos && !seen;
}

/// Persists the install-hint dismissal.
class InstallHintStore {
  /// Creates the store.
  const InstallHintStore();

  /// True after the user dismissed the hint once.
  Future<bool> seen() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(installHintSeenKey) ?? false;
  }

  /// Records the dismissal. Shown only once by design.
  Future<void> markSeen() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(installHintSeenKey, true);
  }
}

/// One-time iOS install hint card with Safari share-sheet steps.
class InstallHintCard extends StatelessWidget {
  /// Creates the card. [onDismiss] records the dismissal.
  const InstallHintCard({required this.onDismiss, super.key});

  /// Called when the user taps the dismiss button.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: UiStrings.installHintTitle,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Row(
                children: <Widget>[
                  Icon(Icons.add_to_home_screen),
                  SizedBox(width: 8),
                  Expanded(child: Text(UiStrings.installHintTitle)),
                ],
              ),
              const SizedBox(height: 4),
              const Text(UiStrings.installHintBody),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onDismiss,
                  child: const Text(UiStrings.installHintDismiss),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Slot placed at the top of Home on web. Loads the dismissal flag once
/// and shows the card only to unseen iOS browsers.
class InstallHintSlot extends StatefulWidget {
  /// Creates the slot.
  const InstallHintSlot({this.store = const InstallHintStore(), super.key});

  /// Store for tests.
  final InstallHintStore store;

  @override
  State<InstallHintSlot> createState() => _InstallHintSlotState();
}

class _InstallHintSlotState extends State<InstallHintSlot> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    bool seen = true;
    try {
      seen = await widget.store.seen();
    } catch (_) {
      // Prefs unavailable: stay hidden rather than nagging.
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _show = shouldShowInstallHint(
        isWeb: kIsWeb,
        isIos: defaultTargetPlatform == TargetPlatform.iOS,
        seen: seen,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) {
      return const SizedBox.shrink();
    }
    return InstallHintCard(
      onDismiss: () async {
        try {
          await widget.store.markSeen();
        } catch (_) {
          // Best effort only.
        }
        if (mounted) {
          setState(() {
            _show = false;
          });
        }
      },
    );
  }
}
