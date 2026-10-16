// Trip status block: three health tiles, one banner for the primary
// issue, one neutral keep-awake tip. Everything renders from the pure
// health model, so the same sentence never appears twice and the device
// tile never carries connectivity. PRIVACY: no coordinates, no tokens.
import 'dart:async';

import 'package:flutter/material.dart' hide Banner;
import 'package:geolocator/geolocator.dart';
import 'package:pontual/domain/trip/sharing_health.dart';
import 'package:pontual/features/trip/trip_controller.dart';
import 'package:pontual/platform/android/battery_optimization.dart';
import 'package:pontual/platform/android/gnss_quality.dart';
import 'package:pontual/platform/web/web_banner.dart';
import 'package:pontual/ui/design/components/banner.dart';
import 'package:pontual/ui/design/components/buttons.dart';
import 'package:pontual/ui/design/components/surface_card.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:pontual/ui/util/platform.dart';

/// Milliseconds a new issue must hold before the banner flips, so a
/// flapping signal does not flicker the screen.
const int bannerHoldMs = 2000;

/// Width at which the three tiles sit in a row instead of stacking.
const double tilesRowBreakpoint = 600;

/// Holds the visible banner issue back until a new issue is stable.
class IssueDebouncer {
  /// Currently shown issue.
  SharingIssue shown = SharingIssue.none;

  /// Pending issue waiting out the hold, if any.
  SharingIssue? pending;

  /// When the pending issue first appeared, in milliseconds.
  int? pendingSinceMs;

  /// Returns the issue to show for [next] at [nowMs].
  SharingIssue update(SharingIssue next, int nowMs) {
    if (next == shown) {
      pending = null;
      pendingSinceMs = null;
      return shown;
    }
    if (pending != next) {
      pending = next;
      pendingSinceMs = nowMs;
      return shown;
    }
    if (nowMs - pendingSinceMs! >= bannerHoldMs) {
      shown = next;
      pending = null;
      pendingSinceMs = null;
    }
    return shown;
  }
}

/// Holds the status tiles, the single banner, and the platform tip.
class StatusBlock extends StatefulWidget {
  /// Creates the block for [controller].
  const StatusBlock({
    required this.controller,
    required this.wakeUnsupported,
    this.nowMs,
    this.requestExemption = requestIgnoreBatteryOptimizations,
    super.key,
  });

  /// Trip controller being read.
  final TripController controller;

  /// True when the browser cannot hold a Screen Wake Lock.
  final bool wakeUnsupported;

  /// Clock in milliseconds, injectable for deterministic tests.
  final int Function()? nowMs;

  /// Battery exemption request, injectable so widget tests never touch a
  /// platform channel. Production fires the system dialog. Called only
  /// from the card action while the trip is offline.
  final RequestExemption requestExemption;

  @override
  State<StatusBlock> createState() => _StatusBlockState();
}

class _StatusBlockState extends State<StatusBlock> {
  final IssueDebouncer _debouncer = IssueDebouncer();

  int _nowMs() {
    final int Function()? injected = widget.nowMs;
    return injected != null
        ? injected()
        : DateTime.now().millisecondsSinceEpoch;
  }

  @override
  Widget build(BuildContext context) {
    final TripController c = widget.controller;
    final SharingHealth health = c.sharingHealth(_nowMs());
    final SharingIssue shown = _debouncer.update(health.issue, _nowMs());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        StatusTiles(health: health, gnss: c.lastGnssQuality),
        if (_bannerOf(shown) != null) ...<Widget>[
          const SizedBox(height: Space.x3),
          _IssueBanner(
            issue: shown,
            onOpenLocation: () => unawaited(_openLocationSettings()),
            onOpenApp: () => unawaited(_openAppSettings()),
          ),
        ],
        // Battery exemption card: the right moment is a visible stall.
        // Offline means 3 failed sends or 120 s without success, which is
        // exactly when OEM skins pause background GPS. User-tapped only,
        // Android only, never blocks sharing.
        if (shown == SharingIssue.offline &&
            PlatformInfo.isAndroid) ...<Widget>[
          const SizedBox(height: Space.x3),
          _BatteryExemptionCard(
            onRequest: () => unawaited(_requestExemption()),
          ),
        ],
        if (PlatformInfo.isWeb) ...<Widget>[
          const SizedBox(height: Space.x3),
          WebTripBanner(
            paused: c.isWebHidden,
            wakeUnsupported: widget.wakeUnsupported,
          ),
        ],
        const SizedBox(height: Space.x3),
        const _KeepAwakeTip(key: ValueKey<String>('tripTip')),
      ],
    );
  }

  /// Banner spec for [issue], or null when the tile suffices.
  _BannerSpec? _bannerOf(SharingIssue issue) {
    return switch (issue) {
      SharingIssue.none => null,
      SharingIssue.offline => const _BannerSpec(
        message: UiStrings.roleOffline,
        tone: BannerTone.warning,
        icon: Icons.cloud_off_rounded,
      ),
      SharingIssue.gpsWeak => const _BannerSpec(
        message: UiStrings.gpsWeakBanner,
        tone: BannerTone.warning,
        icon: Icons.gps_not_fixed_rounded,
      ),
      SharingIssue.gpsNoFix => null,
      SharingIssue.locationOff => const _BannerSpec(
        message: UiStrings.gpsOffBanner,
        tone: BannerTone.warning,
        icon: Icons.location_disabled_rounded,
        action: _BannerAction.activateGps,
      ),
      SharingIssue.permission => const _BannerSpec(
        message: UiStrings.permissionBanner,
        tone: BannerTone.danger,
        icon: Icons.block_rounded,
        action: _BannerAction.openSettings,
      ),
      SharingIssue.lowBattery => const _BannerSpec(
        message: UiStrings.lowBatteryBanner,
        tone: BannerTone.warning,
        icon: Icons.battery_alert_rounded,
      ),
    };
  }

  /// Opens the device location settings. Failures keep the banner text.
  Future<void> _openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } on Object {
      // No settings page on this device: the banner text stays on screen.
    }
  }

  /// Opens the app settings for a revoked permission. Failures keep text.
  Future<void> _openAppSettings() async {
    try {
      await Geolocator.openAppSettings();
    } on Object {
      // No settings page on this device: the banner text stays on screen.
    }
  }

  /// Fires the battery exemption dialog from the card action. Best effort:
  /// denial only toasts and sharing continues. Never throws.
  Future<void> _requestExemption() async {
    final bool granted = await widget.requestExemption();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? UiStrings.batteryExemptionGranted
              : UiStrings.batteryExemptionKept,
        ),
      ),
    );
  }
}

/// Banner actions the issue banner can offer.
enum _BannerAction {
  /// Open the system location settings.
  activateGps,

  /// Open the app settings.
  openSettings,
}

/// Static banner content for one issue.
class _BannerSpec {
  /// Creates banner content.
  const _BannerSpec({
    required this.message,
    required this.tone,
    required this.icon,
    this.action,
  });

  /// Message in pt-BR from the strings file.
  final String message;

  /// Banner tone.
  final BannerTone tone;

  /// Leading icon.
  final IconData icon;

  /// Optional action, if any.
  final _BannerAction? action;
}

/// Single banner for the visible primary issue.
class _IssueBanner extends StatelessWidget {
  /// Creates the banner for [issue].
  const _IssueBanner({
    required this.issue,
    required this.onOpenLocation,
    required this.onOpenApp,
  });

  /// Visible issue, never none or a banner-less one.
  final SharingIssue issue;

  /// Opens the system location settings.
  final VoidCallback onOpenLocation;

  /// Opens the app settings.
  final VoidCallback onOpenApp;

  @override
  Widget build(BuildContext context) {
    final _BannerSpec spec = _specOf(issue);
    return Banner(
      message: spec.message,
      tone: spec.tone,
      icon: spec.icon,
      actionLabel: switch (spec.action) {
        _BannerAction.activateGps => UiStrings.activateGps,
        _BannerAction.openSettings => UiStrings.openSettings,
        null => null,
      },
      onAction: switch (spec.action) {
        _BannerAction.activateGps => onOpenLocation,
        _BannerAction.openSettings => onOpenApp,
        null => null,
      },
    );
  }

  _BannerSpec _specOf(SharingIssue value) {
    return switch (value) {
      SharingIssue.offline => const _BannerSpec(
        message: UiStrings.roleOffline,
        tone: BannerTone.warning,
        icon: Icons.cloud_off_rounded,
      ),
      SharingIssue.gpsWeak => const _BannerSpec(
        message: UiStrings.gpsWeakBanner,
        tone: BannerTone.warning,
        icon: Icons.gps_not_fixed_rounded,
      ),
      SharingIssue.locationOff => const _BannerSpec(
        message: UiStrings.gpsOffBanner,
        tone: BannerTone.warning,
        icon: Icons.location_disabled_rounded,
        action: _BannerAction.activateGps,
      ),
      SharingIssue.permission => const _BannerSpec(
        message: UiStrings.permissionBanner,
        tone: BannerTone.danger,
        icon: Icons.block_rounded,
        action: _BannerAction.openSettings,
      ),
      SharingIssue.lowBattery => const _BannerSpec(
        message: UiStrings.lowBatteryBanner,
        tone: BannerTone.warning,
        icon: Icons.battery_alert_rounded,
      ),
      SharingIssue.none || SharingIssue.gpsNoFix => const _BannerSpec(
        message: '',
        tone: BannerTone.info,
        icon: Icons.info_rounded,
      ),
    };
  }
}

/// Three health tiles. The value sits under the label so long values
/// never squeeze into a narrow right column. Wide screens show a row,
/// narrow screens and large text stack full-width rows.
class StatusTiles extends StatelessWidget {
  /// Creates the tiles for [health].
  const StatusTiles({required this.health, this.gnss, super.key});

  /// Resolved health to render.
  final SharingHealth health;

  /// Latest GNSS quality, if any. Shown as a satellite subtitle on the
  /// GPS tile while weak or unfixed: it tells sky-blocked apart from
  /// permission or services problems at a glance. See D69.
  final GnssQuality? gnss;

  @override
  Widget build(BuildContext context) {
    final List<Widget> tiles = <Widget>[
      _HealthTile(
        key: const ValueKey<String>('tileConnection'),
        icon: _connectionIcon(health.connectionValue),
        label: UiStrings.connection,
        value: _connectionText(health.connectionValue),
        level: health.connectionLevel,
      ),
      _HealthTile(
        key: const ValueKey<String>('tileGps'),
        icon: _gpsIcon(health.gpsValue),
        label: UiStrings.gps,
        value: _gpsText(health.gpsValue, gnss),
        level: health.gpsLevel,
      ),
      _HealthTile(
        key: const ValueKey<String>('tileDevice'),
        icon: _deviceIcon(health.deviceValue),
        label: UiStrings.device,
        value: _deviceText(health.deviceValue),
        level: health.deviceLevel,
      ),
    ];
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth >= tilesRowBreakpoint) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: tiles[0]),
              const SizedBox(width: Space.x4),
              Expanded(child: tiles[1]),
              const SizedBox(width: Space.x4),
              Expanded(child: tiles[2]),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            tiles[0],
            const SizedBox(height: Space.x3),
            tiles[1],
            const SizedBox(height: Space.x3),
            tiles[2],
          ],
        );
      },
    );
  }

  IconData _connectionIcon(ConnectionValue value) {
    return switch (value) {
      ConnectionValue.connected => Icons.wifi_rounded,
      ConnectionValue.offline => Icons.cloud_off_rounded,
      ConnectionValue.reconnecting => Icons.sync_rounded,
    };
  }

  String _connectionText(ConnectionValue value) {
    return switch (value) {
      ConnectionValue.connected => UiStrings.connected,
      ConnectionValue.offline => UiStrings.connOffline,
      ConnectionValue.reconnecting => UiStrings.connReconnecting,
    };
  }

  IconData _gpsIcon(GpsValue value) {
    return switch (value) {
      GpsValue.good => Icons.location_on_rounded,
      GpsValue.weak => Icons.gps_not_fixed_rounded,
      GpsValue.noFix => Icons.gps_not_fixed_rounded,
      GpsValue.off => Icons.location_disabled_rounded,
      GpsValue.noPermission => Icons.block_rounded,
      GpsValue.searching => Icons.location_searching_rounded,
    };
  }

  String _gpsText(GpsValue value, GnssQuality? gnss) {
    final String base = switch (value) {
      GpsValue.good => UiStrings.gpsGood,
      GpsValue.weak => UiStrings.gpsWeak,
      GpsValue.noFix => UiStrings.noSignal,
      GpsValue.off => UiStrings.gpsOffShort,
      GpsValue.noPermission => UiStrings.gpsNoPermission,
      GpsValue.searching => UiStrings.gpsSearching,
    };
    if (gnss == null) {
      return base;
    }
    if (value != GpsValue.weak && value != GpsValue.noFix) {
      return base;
    }
    return '$base, ${UiStrings.satsInFix(gnss.satsUsed)}';
  }

  IconData _deviceIcon(DeviceValue value) {
    return switch (value) {
      DeviceValue.screenOn => Icons.phone_android_rounded,
      DeviceValue.lowBattery => Icons.battery_alert_rounded,
    };
  }

  String _deviceText(DeviceValue value) {
    return switch (value) {
      DeviceValue.screenOn => UiStrings.deviceScreenOn,
      DeviceValue.lowBattery => UiStrings.deviceLowBattery,
    };
  }
}

/// One health tile: icon plus label with the short value underneath.
/// Color never carries the meaning alone; every tile has icon and text.
class _HealthTile extends StatelessWidget {
  /// Creates a tile.
  const _HealthTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.level,
    super.key,
  });

  /// Leading icon.
  final IconData icon;

  /// Tile label in pt-BR.
  final String label;

  /// Short value in pt-BR, one or two words.
  final String value;

  /// Severity, which tints the icon and the value only.
  final SharingLevel level;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Color accent = switch (level) {
      SharingLevel.ok => colors.liveText,
      SharingLevel.warn => colors.warningText,
      SharingLevel.error => colors.dangerText,
      SharingLevel.neutral => colors.inkMuted,
    };
    return Semantics(
      label: '$label: $value',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: accent),
          const SizedBox(width: Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: context.text.caption),
                Text(
                  value,
                  style: context.text.bodyStrong.copyWith(color: accent),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Battery exemption card shown while the trip is offline on Android.
/// Title plus body plus one action. Never blocks sharing: denial only
/// toasts and the trip keeps retrying.
class _BatteryExemptionCard extends StatelessWidget {
  /// Creates the card with the tap handler.
  const _BatteryExemptionCard({required this.onRequest});

  /// Fires the system exemption dialog. User-tapped only.
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      semanticLabel:
          '${UiStrings.batteryExemptionTitle}. ${UiStrings.batteryExemptionBody}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.battery_saver_rounded,
                size: 20,
                color: context.colors.inkMuted,
              ),
              const SizedBox(width: Space.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      UiStrings.batteryExemptionTitle,
                      style: context.text.bodyStrong,
                    ),
                    const SizedBox(height: Space.x1),
                    Text(
                      UiStrings.batteryExemptionBody,
                      style: context.text.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.x3),
          SecondaryButton(
            label: UiStrings.batteryExemptionAction,
            icon: Icons.battery_saver_rounded,
            compact: true,
            onPressed: onRequest,
          ),
        ],
      ),
    );
  }
}

/// The single keep-awake tip. Neutral color always, exactly once.
class _KeepAwakeTip extends StatelessWidget {
  /// Creates the tip.
  const _KeepAwakeTip({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final String message = PlatformInfo.isWeb
        ? UiStrings.keepAwakeTipWeb
        : UiStrings.keepAwakeTip;
    return Semantics(
      label: message,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.stay_current_portrait_rounded,
            size: 20,
            color: colors.inkMuted,
          ),
          const SizedBox(width: Space.x3),
          Expanded(
            child: Text(
              message,
              style: context.text.caption.copyWith(color: colors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}
