// Trip status block: one compact status line, one banner for the primary
// issue, one neutral keep-awake tip. Everything renders from the pure
// health model plus the measured values already carried by the
// controller, so the same sentence never appears twice and the phone
// metric never carries connectivity. PRIVACY: no coordinates, no tokens.
import 'dart:async';

import 'package:flutter/material.dart' hide Banner;
import 'package:geolocator/geolocator.dart';
import 'package:pontual/domain/trip/sharing_health.dart';
import 'package:pontual/domain/trip/trip_state.dart';
import 'package:pontual/platform/android/gnss_quality.dart';
import 'package:pontual/features/trip/trip_controller.dart';
import 'package:pontual/platform/android/battery_optimization.dart';
import 'package:pontual/platform/web/web_banner.dart';
import 'package:pontual/ui/design/components/banner.dart';
import 'package:pontual/ui/design/components/pressable.dart';
import 'package:pontual/ui/design/components/buttons.dart';
import 'package:pontual/ui/design/components/surface_card.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:pontual/ui/util/platform.dart';

import 'trip_metrics.dart';

/// Milliseconds a new issue must hold before the banner flips, so a
/// flapping signal does not flicker the screen.
const int bannerHoldMs = 2000;

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
/// Rebuilds on the trip screen's one coarse clock (5 s), so it owns no
/// timer of its own.
class StatusBlock extends StatefulWidget {
  /// Creates the block for [controller].
  const StatusBlock({
    required this.controller,
    required this.wakeUnsupported,
    this.screenOn = true,
    this.isWeb,
    this.nowMs,
    this.requestExemption = requestIgnoreBatteryOptimizations,
    super.key,
  });

  /// Trip controller being read.
  final TripController controller;

  /// True when the browser cannot hold a Screen Wake Lock.
  final bool wakeUnsupported;

  /// True while the rider asked the screen to stay on. The web banner
  /// uses it to stop claiming the screen stays on once toggled off.
  final bool screenOn;

  /// Overrides web detection for tests. Null follows the real platform.
  final bool? isWeb;

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
    final bool isWeb = widget.isWeb ?? PlatformInfo.isWeb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _StatusSummaryLine(
          key: const ValueKey<String>('tripStatusLine'),
          health: health,
          gnss: c.lastGnssQuality,
          accuracyM: c.lastAccuracyM,
          intervalS: c.intervalS,
          role: c.role,
          onTap: () => unawaited(
            _openStatusDetails(
              context,
              health,
              c.lastGnssQuality,
              c.lastAccuracyM,
              c.intervalS,
              c.role,
            ),
          ),
        ),
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
        // exactly when the OS battery optimization pauses our uploads.
        // User-tapped only, Android only, never blocks sharing.
        if (shown == SharingIssue.offline &&
            PlatformInfo.isAndroid) ...<Widget>[
          const SizedBox(height: Space.x3),
          _BatteryExemptionCard(
            onRequest: () => unawaited(_requestExemption()),
          ),
        ],
        if (isWeb) ...<Widget>[
          const SizedBox(height: Space.x3),
          WebTripBanner(
            paused: c.isWebHidden,
            wakeUnsupported: widget.wakeUnsupported,
            screenOn: widget.screenOn,
          ),
        ],
        const SizedBox(height: Space.x3),
        _KeepAwakeTip(key: const ValueKey<String>('tripTip'), isWeb: isWeb),
      ],
    );
  }

  /// Opens the details bottom sheet with the full StatusMetrics.
  Future<void> _openStatusDetails(
    BuildContext context,
    SharingHealth health,
    GnssQuality? gnss,
    double? accuracyM,
    int? intervalS,
    TripRole? role,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(Space.x4),
          child: StatusMetrics(
            health: health,
            gnss: gnss,
            accuracyM: accuracyM,
            intervalS: intervalS,
            role: role,
          ),
        );
      },
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
      SharingIssue.imprecise => const _BannerSpec(
        message: UiStrings.impreciseLocation,
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
      SharingIssue.imprecise => const _BannerSpec(
        message: UiStrings.impreciseLocation,
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

/// Compact status line that summarizes sharing health and opens the
/// details sheet with the full metrics.
class _StatusSummaryLine extends StatelessWidget {
  /// Creates the line.
  const _StatusSummaryLine({
    required this.health,
    required this.gnss,
    required this.accuracyM,
    required this.intervalS,
    required this.role,
    required this.onTap,
    super.key,
  });

  /// Resolved health.
  final SharingHealth health;

  /// Latest GNSS quality sample.
  final GnssQuality? gnss;

  /// Last accepted fix accuracy.
  final double? accuracyM;

  /// Server-instructed send interval.
  final int? intervalS;

  /// Current sampling role.
  final TripRole? role;

  /// Opens the details sheet.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Color accent = health.overall == SharingOverall.live
        ? colors.liveText
        : health.overall == SharingOverall.paused
        ? colors.warningText
        : colors.inkMuted;
    final IconData icon = health.overall == SharingOverall.live
        ? Icons.sensors_rounded
        : health.overall == SharingOverall.paused
        ? Icons.pause_circle_rounded
        : Icons.hourglass_top_rounded;
    final String lead = switch (health.overall) {
      SharingOverall.live =>
        health.lastSendStale
            ? UiStrings.metricSendStale
            : intervalS == null
            ? UiStrings.tripStatusLive
            : UiStrings.tripStatusSending(intervalS!),
      SharingOverall.starting => UiStrings.tripStatusStarting,
      SharingOverall.paused =>
        health.connectionValue == ConnectionValue.offline
            ? UiStrings.tripStatusOffline
            : UiStrings.tripStatusPaused,
      SharingOverall.ended => UiStrings.tripStatusEnded,
    };
    final String sentence = '$lead ${UiStrings.tripStatusDetails}';
    return Pressable(
      onTap: onTap,
      semanticLabel: sentence,
      borderRadius: Radii.s,
      child: SurfaceCard(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.x4,
          vertical: Space.x3,
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: accent),
            const SizedBox(width: Space.x3),
            Expanded(
              child: Text(
                sentence,
                style: context.text.body.copyWith(color: colors.ink),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.inkMuted),
          ],
        ),
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
  /// Creates the tip for the current platform.
  const _KeepAwakeTip({required this.isWeb, super.key});

  /// True on the web build, which uses the tab-visibility copy.
  final bool isWeb;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final String message = isWeb
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
