// Trip status block: connection, GPS and device rows, the offline and GPS
// banners, the Android battery tip, and the web notes. Icon plus text
// everywhere, so colour never carries the meaning alone.
import 'dart:async';

import 'package:flutter/material.dart' hide Banner;
import 'package:geolocator/geolocator.dart';
import 'package:pontual/domain/trip/trip_state.dart';
import 'package:pontual/features/trip/trip_controller.dart';
import 'package:pontual/platform/web/web_banner.dart';
import 'package:pontual/ui/design/components/banner.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:pontual/ui/util/platform.dart';

/// Holds the status rows, banners, and the platform notes.
class StatusBlock extends StatefulWidget {
  /// Creates the block for [controller].
  const StatusBlock({
    required this.controller,
    required this.wakeUnsupported,
    super.key,
  });

  /// Trip controller being read.
  final TripController controller;

  /// True when the browser cannot hold a Screen Wake Lock.
  final bool wakeUnsupported;

  @override
  State<StatusBlock> createState() => _StatusBlockState();
}

class _StatusBlockState extends State<StatusBlock> {
  bool _tipDismissed = false;

  @override
  Widget build(BuildContext context) {
    final TripController c = widget.controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _StatusRow(
          icon: c.isOffline ? Icons.cloud_off_rounded : Icons.wifi_rounded,
          label: UiStrings.connection,
          value: c.isOffline ? UiStrings.dockReconnecting : UiStrings.connected,
          good: !c.isOffline,
        ),
        const SizedBox(height: Space.x3),
        _StatusRow(
          icon: c.isPaused
              ? Icons.location_disabled_rounded
              : Icons.location_on_rounded,
          label: UiStrings.gps,
          value: c.isPaused ? UiStrings.dockGpsOff : UiStrings.gpsGood,
          good: !c.isPaused,
        ),
        const SizedBox(height: Space.x3),
        _roleRow(context, c),
        if (c.isOffline) ...<Widget>[
          const SizedBox(height: Space.x3),
          const Banner(
            message: UiStrings.roleOffline,
            tone: BannerTone.warning,
            icon: Icons.cloud_off_rounded,
          ),
        ],
        if (c.isPaused) ...<Widget>[
          const SizedBox(height: Space.x3),
          Banner(
            message: UiStrings.locationOff,
            tone: BannerTone.warning,
            icon: Icons.location_disabled_rounded,
            actionLabel: UiStrings.openSettings,
            onAction: () => unawaited(_openLocationSettings()),
          ),
        ],
        if (PlatformInfo.isAndroid && !_tipDismissed) ...<Widget>[
          const SizedBox(height: Space.x3),
          Banner(
            message: UiStrings.batteryTip,
            icon: Icons.battery_saver_rounded,
            actionLabel: UiStrings.close,
            onAction: () => setState(() => _tipDismissed = true),
          ),
        ],
        if (PlatformInfo.isWeb && c.isWebHidden) ...<Widget>[
          const SizedBox(height: Space.x3),
          const Banner(
            message: UiStrings.webKeepOpen,
            tone: BannerTone.warning,
            icon: Icons.stay_current_portrait_rounded,
          ),
        ],
        if (PlatformInfo.isWeb) ...<Widget>[_webNote(context)],
      ],
    );
  }

  /// Device row plus the role copy that explains the sharing rhythm.
  Widget _roleRow(BuildContext context, TripController c) {
    if (c.isOffline) {
      return const _StatusRow(
        icon: Icons.phone_android_rounded,
        label: UiStrings.device,
        value: UiStrings.roleOffline,
      );
    }
    final TripRole? role = activeRole(c.state);
    final String value;
    final String hint;
    switch (role) {
      case TripRole.leader:
        value = UiStrings.roleLeader;
        hint = UiStrings.roleLeaderHint;
      case TripRole.follower:
        value = UiStrings.roleFollower;
        hint = UiStrings.roleFollowerHint;
      case TripRole.waiting:
      case TripRole.offlineSaver:
      case null:
        value = UiStrings.roleWaiting;
        hint = '';
    }
    return _StatusRow(
      icon: Icons.phone_android_rounded,
      label: UiStrings.device,
      value: value,
      hint: hint.isEmpty ? null : hint,
      good: role == TripRole.leader || role == TripRole.follower,
    );
  }

  /// Web trip banner plus the wake-lock status line.
  Widget _webNote(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: Space.x3),
        Semantics(
          label: UiStrings.webKeepOpen,
          child: WebTripBanner(
            paused: widget.controller.isWebHidden,
            wakeUnsupported: widget.wakeUnsupported,
          ),
        ),
        const SizedBox(height: Space.x3),
        _StatusRow(
          icon: Icons.screen_lock_portrait_rounded,
          label: UiStrings.webKeepOpen,
          value: UiStrings.webBrightness,
          good: !widget.wakeUnsupported,
        ),
      ],
    );
  }

  /// Opens the device location settings, the action the permission matrix
  /// gives a GPS-off trip. A failure keeps the banner text as the fallback.
  Future<void> _openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } on Object {
      // No settings page on this device: the banner text stays on screen.
    }
  }
}

/// One status row: icon plus label plus value, so colour never carries the
/// meaning alone.
class _StatusRow extends StatelessWidget {
  /// Creates a row.
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
    this.hint,
    this.good = true,
  });

  /// Leading icon.
  final IconData icon;

  /// Row label in pt-BR.
  final String label;

  /// Row value in pt-BR.
  final String value;

  /// Optional explanation under the value.
  final String? hint;

  /// Whether the state is a healthy one, which only tints the icon.
  final bool good;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 20, color: colors.inkMuted),
        const SizedBox(width: Space.x3),
        Expanded(child: Text(label, style: context.text.body)),
        const SizedBox(width: Space.x2),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                value,
                style: context.text.bodyStrong.copyWith(
                  color: good ? colors.liveText : colors.warningText,
                ),
                textAlign: TextAlign.right,
              ),
              if (hint != null) ...<Widget>[
                const SizedBox(height: Space.x1),
                Text(
                  hint!,
                  style: context.text.caption,
                  textAlign: TextAlign.right,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
