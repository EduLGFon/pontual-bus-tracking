// Modal sheet listing every line serving a tapped stop, with fixed
// timetable departures and live predicted arrivals. Opened from the line
// map. See docs/ui/UI_SPEC.md 7.5.
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/domain/learning/global_stop.dart';
import 'package:pontual/ui/adapters/arrivals_adapter.dart';
import 'package:pontual/ui/adapters/lines_adapter.dart';
import 'package:pontual/ui/adapters/now_clock.dart';
import 'package:pontual/ui/adapters/vehicles_adapter.dart';
import 'package:pontual/ui/design/components/line_badge.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/models/arrival_vm.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:pontual/ui/util/format_eta.dart';

/// Shows the stop sheet as a modal bottom sheet on the root navigator.
Future<void> showStopSheet(BuildContext context, GlobalStop stop) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (BuildContext ctx) => StopSheet(stop: stop),
  );
}

/// Sheet body for one global stop.
class StopSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const StopSheet({required this.stop, super.key});

  /// The tapped stop.
  final GlobalStop stop;

  @override
  ConsumerState<StopSheet> createState() => _StopSheetState();
}

class _StopSheetState extends ConsumerState<StopSheet> {
  int _lastRefreshMs = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refresh(force: true);
      }
    });
  }

  void _refresh({bool force = false}) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (!force && now - _lastRefreshMs < 15000) {
      return;
    }
    _lastRefreshMs = now;
    ref.invalidate(stopArrivalsProvider(widget.stop.id));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<int>>(vehicleTickProvider, (_, _) {
      _refresh();
    });

    final AsyncValue<List<StaticLine>> linesAsync = ref.watch(linesProvider);
    final List<StaticLine> lines = linesAsync.value ?? const <StaticLine>[];
    final Map<int, StaticLine> byId = <int, StaticLine>{
      for (final StaticLine l in lines) l.id: l,
    };
    final DateTime now = ref.watch(currentNowProvider);

    final List<StopLineRef> distinct = <StopLineRef>[];
    final Set<int> seen = <int>{};
    for (final StopLineRef r in widget.stop.lines) {
      if (seen.add(r.lineId)) {
        distinct.add(r);
      }
    }

    final AsyncValue<StopArrivals?> arrivalsAsync = ref.watch(
      stopArrivalsProvider(widget.stop.id),
    );
    final StopArrivals? arrivals = arrivalsAsync.value;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.x4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.stop.name == null || widget.stop.name!.isEmpty
                  ? UiStrings.stopTitle
                  : widget.stop.name!,
              style: context.text.title,
            ),
            const SizedBox(height: Space.x3),
            if (linesAsync.isLoading && lines.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (distinct.isEmpty)
              Text(UiStrings.stopNoLines, style: context.text.body)
            else
              for (final StopLineRef r in distinct)
                _LineRow(
                  line: byId[r.lineId],
                  lineId: r.lineId,
                  now: now,
                  arrivals: arrivals,
                  arrivalsLoading: arrivalsAsync.isLoading && arrivals == null,
                  arrivalsFailed: arrivalsAsync.hasError,
                ),
          ],
        ),
      ),
    );
  }
}

/// A real prediction, not the server's passed or fallback sentinel. A
/// zero-second fallback is unsnappable and must never mask a real bus.
bool _isSelectablePrediction(StopArrivalItem item) {
  if (item.method == 'passed' || item.method == 'fallback') {
    return false;
  }
  if (item.etaS < 0) {
    return false;
  }
  if (item.etaS == 0 && item.method != 'learned') {
    return false;
  }
  return true;
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.line,
    required this.lineId,
    required this.now,
    required this.arrivals,
    required this.arrivalsLoading,
    required this.arrivalsFailed,
  });

  final StaticLine? line;
  final int lineId;
  final DateTime now;
  final StopArrivals? arrivals;
  final bool arrivalsLoading;
  final bool arrivalsFailed;

  @override
  Widget build(BuildContext context) {
    final StaticLine? l = line;
    final String name = l?.name ?? UiStrings.stopLineFallback(lineId);
    final Widget badge = l == null
        ? LineBadge(lineKey: '$lineId', text: '$lineId')
        : LineBadge.ofLine(lineVmOf(l));

    // Fixed times are terminal departures, never stop passage times.
    final TimetableArrivalsSource? source = l == null
        ? null
        : TimetableArrivalsSource(line: l, now: now);
    final List<ArrivalVM> fixed = source == null
        ? const <ArrivalVM>[]
        : source.departures(ArrivalQuery(lineKey: l!.code, limit: 2));

    StopArrivalItem? predicted;
    if (arrivals != null) {
      for (final StopArrivalItem it in arrivals!.items) {
        if (it.lineId != lineId || !_isSelectablePrediction(it)) continue;
        if (predicted == null || it.etaS < predicted.etaS) {
          predicted = it;
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.x2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          badge,
          const SizedBox(width: Space.x2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(name, style: context.text.headline),
                const SizedBox(height: Space.x1),
                Text(UiStrings.stopFixedLabel, style: context.text.caption),
                if (fixed.isEmpty)
                  Text(
                    l != null && l.schedules.isEmpty
                        ? UiStrings.stopNoSchedules
                        : UiStrings.stopNoFixed,
                    style: context.text.body,
                  )
                else
                  for (final ArrivalVM a in fixed)
                    Text(formatClock(a.at), style: context.text.clock),
                const SizedBox(height: Space.x1),
                Text(
                  UiStrings.stopPredictionLabel,
                  style: context.text.caption,
                ),
                if (arrivalsFailed)
                  Text(UiStrings.stopFetchFailed, style: context.text.body)
                else if (arrivalsLoading)
                  const SizedBox(
                    height: Space.x3,
                    width: Space.x3,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (predicted == null)
                  Text(UiStrings.stopNoPrediction, style: context.text.body)
                else
                  Text(
                    predicted.etaS <= 60
                        ? UiStrings.stopNow
                        : UiStrings.myStopEta((predicted.etaS / 60).ceil()),
                    style: context.text.body,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
