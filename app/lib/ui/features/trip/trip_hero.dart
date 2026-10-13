// Trip hero: the live indicator inside its own bounds, the headline,
// the line badge with name and endpoints, the elapsed and last-send
// proof lines, and the trust line. Only the small time texts rebuild
// on the coarse timer; the rest rebuilds with the controller.
// PRIVACY: no coordinates are ever shown or logged.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/domain/trip/sharing_health.dart';
import 'package:pontual/features/trip/trip_controller.dart';
import 'package:pontual/ui/adapters/lines_adapter.dart';
import 'package:pontual/ui/design/components/chip.dart' as pontual;
import 'package:pontual/ui/design/components/line_badge.dart';
import 'package:pontual/ui/design/components/live_dot.dart';
import 'package:pontual/ui/design/components/live_pulse.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/models/line_vm.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Hero of the trip screen: indicator, headline, line, times, trust.
class TripHero extends ConsumerWidget {
  /// Creates the hero for [controller].
  const TripHero({
    required this.controller,
    required this.startedAtMs,
    required this.nowMs,
    super.key,
  });

  /// Trip controller being read.
  final TripController controller;

  /// Trip start in milliseconds, null before the start is confirmed.
  final int? startedAtMs;

  /// Clock in milliseconds.
  final int Function() nowMs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int? lineId = controller.lineId;
    final List<StaticLine>? lines = ref.watch(linesProvider).value;
    LineVM? line;
    if (lines != null && lineId != null) {
      for (final StaticLine candidate in lines) {
        if (candidate.id == lineId) {
          line = lineVmOf(candidate);
          break;
        }
      }
    }
    final SharingHealth health = controller.sharingHealth(nowMs());
    final bool starting = health.overall == SharingOverall.starting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: Space.x4),
        _LiveIndicator(
          key: const ValueKey<String>('tripIndicator'),
          overall: health.overall,
        ),
        const SizedBox(height: Space.x4),
        Text(
          starting ? UiStrings.tripStarting : UiStrings.tripHero,
          style: context.text.headline,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Space.x4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (line != null) ...<Widget>[
              LineBadge.ofLine(line, size: BadgeSize.l),
              const SizedBox(width: Space.x3),
            ],
            Flexible(
              child: Text(
                controller.lineLabel.isEmpty
                    ? (line?.name ?? '')
                    : controller.lineLabel,
                style: context.text.bodyStrong,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        if (line != null && line.terminalsText.isNotEmpty) ...<Widget>[
          const SizedBox(height: Space.x2),
          Center(child: pontual.Chip(label: line.terminalsText, compact: true)),
        ],
        const SizedBox(height: Space.x3),
        _TripTimes(
          controller: controller,
          startedAtMs: startedAtMs,
          nowMs: nowMs,
        ),
        const SizedBox(height: Space.x3),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.lock_rounded, size: 16, color: context.colors.inkMuted),
            const SizedBox(width: Space.x1),
            Flexible(
              child: Text(
                UiStrings.tripTrust,
                style: context.text.caption,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Truthful live indicator. Green pulses only while positions flow;
/// paused is a static amber dot, starting and ended are neutral.
/// The dot draws inside its own box and never overflows the app bar.
class _LiveIndicator extends StatelessWidget {
  /// Creates the indicator for [overall].
  const _LiveIndicator({required this.overall, super.key});

  /// Overall sharing state.
  final SharingOverall overall;

  @override
  Widget build(BuildContext context) {
    final Certainty certainty = switch (overall) {
      SharingOverall.live => Certainty.live,
      SharingOverall.paused => Certainty.stale,
      SharingOverall.starting => Certainty.scheduled,
      SharingOverall.ended => Certainty.scheduled,
    };
    final String label = switch (overall) {
      SharingOverall.live => 'Ao vivo. Compartilhando sua posição.',
      SharingOverall.paused => 'Compartilhamento pausado.',
      SharingOverall.starting => 'Iniciando compartilhamento.',
      SharingOverall.ended => 'Viagem encerrada.',
    };
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Center(
        child: LivePulse(child: LiveDot(certainty: certainty, size: 14)),
      ),
    );
  }
}

/// Elapsed time and last-send proof. Rebuilds only these two texts on
/// a coarse 5 s timer, which stops with the screen.
class _TripTimes extends StatefulWidget {
  /// Creates the times for [controller].
  const _TripTimes({
    required this.controller,
    required this.startedAtMs,
    required this.nowMs,
  });

  /// Trip controller being read.
  final TripController controller;

  /// Trip start in milliseconds, null before confirmation.
  final int? startedAtMs;

  /// Clock in milliseconds.
  final int Function() nowMs;

  @override
  State<_TripTimes> createState() => _TripTimesState();
}

class _TripTimesState extends State<_TripTimes> {
  Timer? _timer;
  late int _nowMs = widget.nowMs();

  @override
  void initState() {
    super.initState();
    // A ping success moves lastSuccessMs past the 5 s cached clock, which
    // rendered negative ages like "-3s". Refresh on every controller
    // notification so the age is measured against the real now.
    widget.controller.addListener(_onController);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        setState(() => _nowMs = widget.nowMs());
      }
    });
  }

  /// Refreshes the render clock when the controller notifies (ping
  /// success, role change, prompt flip), so a fresh success never reads
  /// older than the cached tick.
  void _onController() {
    if (mounted) {
      setState(() => _nowMs = widget.nowMs());
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int? startedAtMs = widget.startedAtMs;
    final int? lastSuccessMs = widget.controller.lastSuccessMs;
    final bool stale =
        lastSuccessMs != null && _nowMs - lastSuccessMs > staleSendAfterMs;
    // Clamped at zero: with the listener above this is normally fresh, but
    // an injected test clock can still sit behind the success timestamp.
    final int lastSentS = lastSuccessMs == null
        ? 0
        : ((_nowMs - lastSuccessMs) ~/ 1000).clamp(0, 1 << 30);
    final colors = context.colors;
    return Column(
      children: <Widget>[
        if (startedAtMs != null)
          Semantics(
            label:
                'Tempo de viagem ${UiStrings.agoLong(_elapsedS(startedAtMs))}',
            child: Text(
              UiStrings.elapsedAgo(_elapsedS(startedAtMs)),
              style: context.text.bodyStrong,
              textAlign: TextAlign.center,
            ),
          ),
        if (lastSuccessMs != null) ...<Widget>[
          const SizedBox(height: Space.x1),
          Semantics(
            label: 'Última posição enviada ${UiStrings.agoLong(lastSentS)}',
            child: Text(
              UiStrings.lastSentAgo(UiStrings.agoShort(lastSentS)),
              style: context.text.caption.copyWith(
                color: stale ? colors.warningText : colors.inkMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  int _elapsedS(int startedAtMs) {
    return ((_nowMs - startedAtMs) ~/ 1000).clamp(0, 1 << 30);
  }
}
