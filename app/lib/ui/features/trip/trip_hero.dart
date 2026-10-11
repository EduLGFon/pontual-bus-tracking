// Trip hero: the live dot inside one shared pulse ring, the headline, the
// line badge and name, and the private one-second clock of this screen.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/features/trip/trip_controller.dart';
import 'package:pontual/ui/adapters/lines_adapter.dart';
import 'package:pontual/ui/adapters/trip_adapter.dart';
import 'package:pontual/ui/design/components/line_badge.dart';
import 'package:pontual/ui/design/components/live_dot.dart';
import 'package:pontual/ui/design/components/live_pulse.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/models/line_vm.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Hero of the trip screen: live dot, headline, line, and elapsed time.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: Space.x4),
        const Center(
          child: LivePulse(child: LiveDot(certainty: Certainty.live, size: 14)),
        ),
        const SizedBox(height: Space.x4),
        Text(
          UiStrings.tripHero,
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
        const SizedBox(height: Space.x4),
        Center(
          child: _ElapsedClock(startedAtMs: startedAtMs, nowMs: nowMs),
        ),
      ],
    );
  }
}

/// Private one-second clock for this screen. It is the only timer the trip
/// screen owns and it exists only while the screen is mounted.
class _ElapsedClock extends StatefulWidget {
  /// Creates the clock measuring from [startedAtMs].
  const _ElapsedClock({required this.startedAtMs, required this.nowMs});

  /// Trip start in milliseconds, null before the start is confirmed.
  final int? startedAtMs;

  /// Clock in milliseconds.
  final int Function() nowMs;

  @override
  State<_ElapsedClock> createState() => _ElapsedClockState();
}

class _ElapsedClockState extends State<_ElapsedClock> {
  Timer? _timer;
  late int _nowMs = widget.nowMs();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _nowMs = widget.nowMs());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int? startedAtMs = widget.startedAtMs;
    final int elapsedS = startedAtMs == null
        ? 0
        : ((_nowMs - startedAtMs) ~/ 1000).clamp(0, 1 << 30);
    return Semantics(
      label: '${UiStrings.dockSharing} ${formatElapsed(elapsedS)}',
      child: Text(formatElapsed(elapsedS), style: context.text.clock),
    );
  }
}
