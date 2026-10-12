// Always-visible banner for web trips. Sharing works only while the
// page is open and unlocked, so the banner never dismisses. See PLAN
// 8.12.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Banner shown during every web trip.
class WebTripBanner extends StatelessWidget {
  /// Creates the banner. Set [paused] while the page is hidden and
  /// [wakeUnsupported] when the browser has no wake lock.
  const WebTripBanner({
    this.paused = false,
    this.wakeUnsupported = false,
    super.key,
  });

  /// True while the page is hidden and sends are paused.
  final bool paused;

  /// True when the browser cannot hold a Screen Wake Lock.
  final bool wakeUnsupported;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: UiStrings.webKeepOpen,
      liveRegion: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.stay_current_portrait, color: context.colors.ink),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      UiStrings.webKeepOpen,
                      style: context.text.bodyStrong,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(UiStrings.webWakeNote, style: context.text.body),
              if (wakeUnsupported) ...<Widget>[
                const SizedBox(height: 4),
                Text(UiStrings.webWakeUnsupported, style: context.text.body),
              ],
              if (paused) ...<Widget>[
                const SizedBox(height: 4),
                Text(UiStrings.webHiddenPaused, style: context.text.body),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
