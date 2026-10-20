// Trip metrics panel: GPS, phone battery and send cadence as one tonal
// card with a big value, a meter where a real fraction exists, and a
// short caption. Every number shown comes from the controller or the
// native GNSS channel; nothing is inferred or invented.
// PRIVACY: accuracy and battery are device data already sent with each
// fix. No coordinates, tokens or identifiers ever reach this widget.
import 'package:flutter/material.dart';
import 'package:pontual/core/config/env.dart';
import 'package:pontual/domain/trip/sharing_health.dart';
import 'package:pontual/domain/trip/trip_state.dart';
import 'package:pontual/platform/android/gnss_quality.dart';
import 'package:pontual/ui/design/components/surface_card.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Width at which the three metrics sit side by side. Large text always
/// stacks them, whatever the width.
const double metricsRowBreakpoint = 600;

/// Text scale above which the metrics stack even on a wide screen. At
/// 1.3 the three columns still fit; above it the big values win.
const double metricsStackTextScale = 1.3;

/// One real-value metric, already resolved to copy.
class _Metric {
  const _Metric({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.level,
    required this.numeric,
    this.fraction,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final SharingLevel level;
  final bool numeric;

  /// Real fraction for the meter, null when the metric has no honest
  /// denominator. Only accuracy and battery use one.
  final double? fraction;
}

/// The three sharing metrics for one render.
class StatusMetrics extends StatelessWidget {
  /// Creates the panel from the health model plus the raw values that
  /// the health model does not carry.
  const StatusMetrics({
    required this.health,
    this.gnss,
    this.accuracyM,
    this.batteryPct,
    this.charging = false,
    this.intervalS,
    this.role,
    super.key,
  });

  /// Resolved health for this render.
  final SharingHealth health;

  /// Latest GNSS quality sample, null off Android or before a sample.
  final GnssQuality? gnss;

  /// Last accepted fix accuracy in meters, null before the first fix.
  final double? accuracyM;

  /// Last accepted fix battery bucket, null before the first fix.
  final int? batteryPct;

  /// Last accepted fix charging flag.
  final bool charging;

  /// Last server-instructed send interval in seconds.
  final int? intervalS;

  /// Current sampling role, null before the trip is active.
  final TripRole? role;

  @override
  Widget build(BuildContext context) {
    final List<Widget> cells = <Widget>[
      _MetricCell(metric: _gpsMetric()),
      _MetricCell(metric: _batteryMetric()),
      _MetricCell(metric: _sendMetric()),
    ];
    final double textScale = MediaQuery.textScalerOf(context).scale(1);
    final bool row =
        MediaQuery.sizeOf(context).width >= metricsRowBreakpoint &&
        textScale <= metricsStackTextScale;
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: row
          ? IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(child: cells[0]),
                  const _MetricDivider(vertical: true),
                  Expanded(child: cells[1]),
                  const _MetricDivider(vertical: true),
                  Expanded(child: cells[2]),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                cells[0],
                const _MetricDivider(vertical: false),
                cells[1],
                const _MetricDivider(vertical: false),
                cells[2],
              ],
            ),
    );
  }

  /// GPS: accuracy in meters plus satellites when Android reports them.
  _Metric _gpsMetric() {
    final GnssQuality? sample = gnss;
    final String sats = sample == null
        ? UiStrings.metricGpsLimitDetail(fixAccuracyMaxM)
        : UiStrings.metricSats(sample.satsUsed, sample.satsView);
    switch (health.gpsValue) {
      case GpsValue.good:
      case GpsValue.weak:
        final double? accuracy = accuracyM;
        if (accuracy == null) {
          return const _Metric(
            label: UiStrings.metricLabelGps,
            value: UiStrings.gpsSearching,
            detail: UiStrings.metricGpsSearchingDetail,
            icon: Icons.location_searching_rounded,
            level: SharingLevel.neutral,
            numeric: false,
          );
        }
        final double denominator = fixAccuracyMaxM <= 0
            ? 1
            : fixAccuracyMaxM.toDouble();
        return _Metric(
          label: UiStrings.metricLabelGps,
          value: UiStrings.metricAccuracy(accuracy.round()),
          detail: health.gpsValue == GpsValue.weak && sample == null
              ? UiStrings.metricGpsWeakDetail
              : sats,
          icon: health.gpsValue == GpsValue.weak
              ? Icons.gps_not_fixed_rounded
              : Icons.location_on_rounded,
          level: health.gpsLevel,
          numeric: true,
          fraction: (1 - accuracy / denominator).clamp(0, 1),
        );
      case GpsValue.noFix:
        return _Metric(
          label: UiStrings.metricLabelGps,
          value: UiStrings.noSignal,
          detail: sample == null
              ? UiStrings.metricGpsNoFixDetail
              : UiStrings.metricSats(sample.satsUsed, sample.satsView),
          icon: Icons.gps_not_fixed_rounded,
          level: SharingLevel.warn,
          numeric: false,
        );
      case GpsValue.off:
        return const _Metric(
          label: UiStrings.metricLabelGps,
          value: UiStrings.gpsOffShort,
          detail: UiStrings.metricGpsOffDetail,
          icon: Icons.location_disabled_rounded,
          level: SharingLevel.error,
          numeric: false,
        );
      case GpsValue.noPermission:
        return const _Metric(
          label: UiStrings.metricLabelGps,
          value: UiStrings.gpsNoPermission,
          detail: UiStrings.metricGpsPermissionDetail,
          icon: Icons.block_rounded,
          level: SharingLevel.error,
          numeric: false,
        );
      case GpsValue.imprecise:
        return const _Metric(
          label: UiStrings.metricLabelGps,
          value: UiStrings.gpsImprecise,
          detail: UiStrings.metricGpsImpreciseDetail,
          icon: Icons.block_rounded,
          level: SharingLevel.error,
          numeric: false,
        );
      case GpsValue.searching:
        return const _Metric(
          label: UiStrings.metricLabelGps,
          value: UiStrings.gpsSearching,
          detail: UiStrings.metricGpsSearchingDetail,
          icon: Icons.location_searching_rounded,
          level: SharingLevel.neutral,
          numeric: false,
        );
    }
  }

  /// Phone: real battery percentage, charging state and a level meter.
  _Metric _batteryMetric() {
    final int? raw = batteryPct;
    if (raw == null) {
      return const _Metric(
        label: UiStrings.metricLabelPhone,
        value: UiStrings.metricBatteryUnknown,
        detail: UiStrings.metricBatteryOnBatteryDetail,
        icon: Icons.battery_unknown_rounded,
        level: SharingLevel.neutral,
        numeric: false,
      );
    }
    final int pct = raw.clamp(0, 100);
    final bool low = pct <= lowBatteryPct && !charging;
    return _Metric(
      label: UiStrings.metricLabelPhone,
      value: UiStrings.metricPercent(pct),
      detail: low
          ? UiStrings.metricBatteryLowDetail
          : charging
          ? UiStrings.metricBatteryChargingDetail
          : UiStrings.metricBatteryOnBatteryDetail,
      icon: low
          ? Icons.battery_alert_rounded
          : charging
          ? Icons.battery_charging_full_rounded
          : Icons.battery_std_rounded,
      level: low ? SharingLevel.warn : SharingLevel.ok,
      numeric: true,
      fraction: pct / 100,
    );
  }

  /// Send: server cadence plus the role explanation, or the connection
  /// state when nothing is flowing.
  _Metric _sendMetric() {
    if (health.overall == SharingOverall.starting ||
        health.connectionValue == ConnectionValue.reconnecting) {
      return const _Metric(
        label: UiStrings.metricLabelSend,
        value: UiStrings.metricSendStarting,
        detail: UiStrings.metricSendStartingDetail,
        icon: Icons.send_rounded,
        level: SharingLevel.neutral,
        numeric: false,
      );
    }
    if (health.connectionValue == ConnectionValue.offline) {
      return const _Metric(
        label: UiStrings.metricLabelSend,
        value: UiStrings.connOffline,
        detail: UiStrings.metricSendOfflineDetail,
        icon: Icons.cloud_off_rounded,
        level: SharingLevel.warn,
        numeric: false,
      );
    }
    final bool stale = health.lastSendStale;
    final int? interval = intervalS;
    return _Metric(
      label: UiStrings.metricLabelSend,
      value: interval == null
          ? UiStrings.metricSendCalculating
          : UiStrings.metricInterval(interval),
      detail: stale
          ? UiStrings.metricSendStale
          : _roleDetail(role),
      icon: stale ? Icons.schedule_rounded : Icons.send_rounded,
      level: stale ? SharingLevel.warn : health.connectionLevel,
      numeric: interval != null,
    );
  }

  String _roleDetail(TripRole? role) {
    return switch (role) {
      TripRole.waiting => UiStrings.metricSendWaiting,
      TripRole.leader => UiStrings.metricSendLeader,
      TripRole.follower => UiStrings.metricSendFollower,
      TripRole.offlineSaver => UiStrings.metricSendOfflineDetail,
      null => UiStrings.metricSendIntervalDetail,
    };
  }
}

/// One metric cell: icon and label, big value, optional meter, detail.
class _MetricCell extends StatelessWidget {
  const _MetricCell({required this.metric});

  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Color accent = switch (metric.level) {
      SharingLevel.ok => colors.liveText,
      SharingLevel.warn => colors.warningText,
      SharingLevel.error => colors.dangerText,
      SharingLevel.neutral => colors.inkMuted,
    };
    final bool attention =
        metric.level == SharingLevel.warn ||
        metric.level == SharingLevel.error;
    final TextStyle valueStyle = metric.numeric
        ? context.text.metric
        : context.text.headline;
    return Semantics(
      label: UiStrings.metricSemantics(
        metric.label,
        metric.value,
        metric.detail,
      ),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.x4, Space.x3, Space.x4, Space.x3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(Radii.s),
                  ),
                  child: Icon(metric.icon, size: 18, color: accent),
                ),
                const SizedBox(width: Space.x2),
                Expanded(
                  child: Text(metric.label, style: context.text.caption),
                ),
              ],
            ),
            const SizedBox(height: Space.x2),
            Text(
              metric.value,
              style: valueStyle.copyWith(
                color: attention ? accent : colors.ink,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (metric.fraction != null) ...<Widget>[
              const SizedBox(height: Space.x2),
              _MetricMeter(fraction: metric.fraction!, color: accent),
            ],
            const SizedBox(height: Space.x1),
            Text(
              metric.detail,
              style: context.text.caption.copyWith(
                color: attention ? accent : colors.inkMuted,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Thin level bar. Decorative: the value and the caption carry the data.
class _MetricMeter extends StatelessWidget {
  const _MetricMeter({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.pill),
        child: SizedBox(
          height: 6,
          child: ColoredBox(
            color: context.colors.line,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction.clamp(0, 1),
              child: ColoredBox(color: color),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hairline between metric cells, horizontal when stacked.
class _MetricDivider extends StatelessWidget {
  const _MetricDivider({required this.vertical});

  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final Color color = context.colors.line;
    if (vertical) {
      return Container(width: 1, color: color);
    }
    return Divider(height: 1, thickness: 1, color: color);
  }
}
