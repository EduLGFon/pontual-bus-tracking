// Horários (timetable) tab of the line screen: day types, origins, the next
// departure hero and the hour rail. Day types come from the static data;
// holidays are not auto-detected and the user switches manually.
// See docs/ui/UI_SPEC.md 7.6.
import 'package:flutter/material.dart' hide Chip;
import 'package:go_router/go_router.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/domain/schedule.dart';
import 'package:pontual/ui/adapters/lines_adapter.dart';
import 'package:pontual/ui/design/components/arrival_row.dart';
import 'package:pontual/ui/design/components/chip.dart';
import 'package:pontual/ui/design/components/empty_state.dart';
import 'package:pontual/ui/design/components/ghost_link.dart';
import 'package:pontual/ui/design/components/segmented.dart';
import 'package:pontual/ui/design/components/time_rail.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/features/timetable/timetable_data.dart';
import 'package:pontual/ui/models/arrival_vm.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// The Horários tab of the line screen.
class TimetableTab extends StatefulWidget {
  /// Creates the tab.
  const TimetableTab({
    required this.line,
    required this.now,
    this.scrollable = true,
    super.key,
  });

  /// Static line with its schedules.
  final StaticLine line;

  /// Current instant, São Mateus wall clock.
  final DateTime now;

  /// Scrolls on its own. Set false when the parent already scrolls, as in
  /// the line sheet, where a nested scrollable would fight the sheet drag.
  final bool scrollable;

  @override
  State<TimetableTab> createState() => _TimetableTabState();
}

class _TimetableTabState extends State<TimetableTab> {
  late DayType _day;
  late String _origin;
  final ScrollController _rail = ScrollController();
  bool _scrolledToNext = false;

  @override
  void initState() {
    super.initState();
    _day = dayTypeFor(saoMateusTime(widget.now));
    final List<String> origins = timetableOriginsOf(widget.line, _day);
    _origin = origins.isEmpty ? '' : origins.first;
  }

  @override
  void dispose() {
    _rail.dispose();
    super.dispose();
  }

  /// Times of the selected day and origin.
  List<String> get _times =>
      timetableTimesOf(widget.line, _day, _origin.isEmpty ? null : _origin);

  @override
  Widget build(BuildContext context) {
    final List<String> times = _times;
    final DateTime local = saoMateusTime(widget.now);
    final int nowMinutes = local.hour * 60 + local.minute;
    final String? next = nextDeparture(times, nowMinutes);
    final List<ArrivalVM> arrivals = arrivalsOf(
      widget.line.code,
      times,
      local,
      limit: next == null ? 0 : 1,
      originLabel: _origin.isEmpty ? null : _origin,
    );
    final List<Widget> sections = <Widget>[
      _hero(arrivals.isEmpty ? null : arrivals.first),
      const SizedBox(height: Space.x4),
      _daySelector(),
      _originSelector(),
      if (times.isEmpty)
        const _EmptyTimetable()
      else
        _railSection(times, next, nowMinutes),
      _footnote(),
    ];
    if (!widget.scrollable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: sections,
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: Space.x8),
      children: sections,
    );
  }

  /// Hero row for the next scheduled departure.
  Widget _hero(ArrivalVM? arrival) {
    if (arrival == null) {
      return const SizedBox.shrink();
    }
    return ArrivalRow(
      arrival: arrival,
      now: saoMateusTime(widget.now),
      line: lineVmOf(widget.line),
      large: true,
    );
  }

  /// Day-type segments. Holidays are not auto-detected.
  Widget _daySelector() {
    return Padding(
      padding: const EdgeInsets.only(top: Space.x4),
      child: Segmented(
        segments: <Segment>[
          for (final DayType d in dayTypes)
            Segment(value: dayTypeKeyOf(d), label: dayTypeLabelOf(d)),
        ],
        value: dayTypeKeyOf(_day),
        onChanged: (String value) {
          final DayType? day = dayForKey(value);
          if (day == null || day == _day) {
            return;
          }
          setState(() {
            _day = day;
            final List<String> origins = timetableOriginsOf(widget.line, day);
            _origin = origins.isEmpty ? '' : origins.first;
            _scrolledToNext = false;
          });
        },
      ),
    );
  }

  /// Origin chips, hidden when the line has a single origin.
  Widget _originSelector() {
    final List<String> origins = timetableOriginsOf(widget.line, _day);
    if (origins.length < 2) {
      return const SizedBox.shrink();
    }
    final String selected = origins.contains(_origin) ? _origin : origins.first;
    return Padding(
      padding: const EdgeInsets.only(top: Space.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(UiStrings.originLabel, style: context.text.caption),
          const SizedBox(height: Space.x2),
          Wrap(
            spacing: Space.x2,
            runSpacing: Space.x2,
            children: <Widget>[
              for (final String origin in origins)
                Chip(
                  label: origin,
                  selected: origin == selected,
                  onTap: () {
                    if (origin == _origin) {
                      return;
                    }
                    setState(() {
                      _origin = origin;
                      _scrolledToNext = false;
                    });
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Hour rail with the auto-scroll towards the next departure.
  Widget _railSection(List<String> times, String? next, int nowMinutes) {
    final List<TimeRailHour> hours = <TimeRailHour>[
      for (final MapEntry<String, List<String>> e in groupByHour(times).entries)
        TimeRailHour(hour: e.key, minutes: e.value),
    ];
    _scrollToNext(hours, next);
    return Padding(
      padding: const EdgeInsets.only(top: Space.x4),
      child: SizedBox(
        height: railRowDp * hours.length,
        child: TimeRail(
          hours: hours,
          nextHour: next?.split(':').first,
          nextMinute: next?.split(':').last,
          nowMinutes: nowMinutes,
          scrollController: _rail,
        ),
      ),
    );
  }

  /// Scrolls the next hour near the top third. Only when it is far away, and
  /// instantly when the platform asks for reduced motion.
  void _scrollToNext(List<TimeRailHour> hours, String? next) {
    if (next == null || _scrolledToNext) {
      return;
    }
    final int index = hours.indexWhere(
      (TimeRailHour h) => h.hour == next.split(':').first,
    );
    _scrolledToNext = true;
    if (index < 2) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_rail.hasClients) {
        return;
      }
      final double offset = (index * railRowDp - railRowDp * 2).clamp(
        0.0,
        _rail.position.maxScrollExtent,
      );
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        _rail.jumpTo(offset);
        return;
      }
      _rail.animateTo(
        offset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// Footnote with the timetable date and the sources link.
  Widget _footnote() {
    return Padding(
      padding: const EdgeInsets.only(top: Space.x6, bottom: Space.x4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              '${UiStrings.timetableFootnote}${formatDateLabel(widget.now)}',
              style: context.text.caption,
            ),
          ),
          GhostLink(
            label: UiStrings.sources,
            onTap: () => GoRouter.of(context).push('/about'),
          ),
        ],
      ),
    );
  }
}

/// Empty state of a day with no schedules.
class _EmptyTimetable extends StatelessWidget {
  const _EmptyTimetable();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: Space.x6, bottom: Space.x4),
      child: EmptyState(
        title: UiStrings.timetableEmpty,
        message: UiStrings.aboutSourceLines,
        art: EmptyArt.search,
      ),
    );
  }
}
