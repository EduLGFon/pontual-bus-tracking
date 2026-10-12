// Horários (timetable) tab of the line screen: day types, origins, the next
// departure hero and the hour rail. Day types come from the static data;
// holidays are not auto-detected and the user switches manually.
// See docs/ui/UI_SPEC.md 7.6.
import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pontual/app/providers.dart';
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
class TimetableTab extends ConsumerStatefulWidget {
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
  ConsumerState<TimetableTab> createState() => _TimetableTabState();
}

class _TimetableTabState extends ConsumerState<TimetableTab> {
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
    final DayType today = dayTypeFor(local);
    final int nowMinutes = local.hour * 60 + local.minute;
    // The next highlight only applies to today. Past dimming in the rail
    // uses the same minute rule, so other days never dim or highlight.
    final String? next = _day == today ? nextDeparture(times, nowMinutes) : null;
    final List<ArrivalVM> arrivals = arrivalsOf(
      widget.line.code,
      times,
      local,
      originLabel: _origin.isEmpty ? null : _origin,
    );
    final List<Widget> sections = <Widget>[
      _hero(_day == today ? _heroOf(arrivals, times, next) : null),
      const SizedBox(height: Space.x4),
      _daySelector(today),
      _originSelector(),
      if (times.isEmpty)
        _EmptyTimetable(onSeeData: _firstDayWithData() == null ? null : _seeData)
      else ...<Widget>[
        _summary(times),
        if (_day == today) _tomorrowBanner(next, local),
        _railSection(times, _day == today ? next : null, nowMinutes),
      ],
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

  /// Hero arrival: the `next` departure, never the first time of the day
  /// (which is usually already gone). Null when nothing is left today.
  /// D-U26.
  ArrivalVM? _heroOf(
    List<ArrivalVM> arrivals,
    List<String> times,
    String? next,
  ) {
    if (next == null) {
      return null;
    }
    final int index = times.indexOf(next);
    if (index < 0 || index >= arrivals.length) {
      return null;
    }
    return arrivals[index];
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

  /// Day-type segments with the `hoje` mark on today. Holidays are not
  /// auto-detected: today is the weekday of the São Mateus date.
  Widget _daySelector(DayType today) {
    return Padding(
      padding: const EdgeInsets.only(top: Space.x4),
      child: Segmented(
        segments: <Segment>[
          for (final DayType d in dayTypes)
            Segment(
              value: dayTypeKeyOf(d),
              label: d == today
                  ? '${dayTypeLabelOf(d)} · ${UiStrings.todayMark}'
                  : dayTypeLabelOf(d),
            ),
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

  /// Origin selector, hidden when the line has a single origin. Two
  /// origins use the shared segmented control so the selected state
  /// matches the main tabs; more use chips.
  Widget _originSelector() {
    final List<String> origins = timetableOriginsOf(widget.line, _day);
    if (origins.length < 2) {
      return const SizedBox.shrink();
    }
    final String selected = origins.contains(_origin) ? _origin : origins.first;
    void select(String origin) {
      if (origin == _origin) {
        return;
      }
      setState(() {
        _origin = origin;
        _scrolledToNext = false;
      });
    }

    if (origins.length == 2) {
      return Padding(
        padding: const EdgeInsets.only(top: Space.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(UiStrings.originLabel, style: context.text.caption),
            const SizedBox(height: Space.x2),
            Segmented(
              segments: <Segment>[
                for (final String origin in origins)
                  Segment(value: origin, label: origin),
              ],
              value: selected,
              onChanged: select,
            ),
          ],
        ),
      );
    }
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
                  onTap: () => select(origin),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// One-line summary derived from data, for example
  /// `Primeira 06:40 · Última 22:10`.
  Widget _summary(List<String> times) {
    return Padding(
      padding: const EdgeInsets.only(top: Space.x4),
      child: Text(
        '${UiStrings.timetableFirst} ${times.first} · '
        '${UiStrings.timetableLast} ${times.last}',
        style: context.text.caption,
      ),
    );
  }

  /// Banner when nothing is left today but tomorrow has departures.
  /// Only rendered for today; other days show their rail as-is.
  Widget _tomorrowBanner(String? next, DateTime local) {
    if (next != null) {
      return const SizedBox.shrink();
    }
    final DayType tomorrowType = dayTypeFor(
      local.add(const Duration(days: 1)),
    );
    final List<String> tomorrow = timetableTimesOf(
      widget.line,
      tomorrowType,
      _origin.isEmpty ? null : _origin,
    );
    final String? first = earliestTime(tomorrow);
    if (first == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: Space.x4),
      child: Text(
        '${UiStrings.homeNoMoreToday}. '
        '${UiStrings.homeTomorrowAt(first)}.',
        style: context.text.body,
      ),
    );
  }

  /// First day type with any timetable data, null when the line has none.
  DayType? _firstDayWithData() {
    for (final DayType day in dayTypes) {
      if (timetableTimesOf(widget.line, day, null).isNotEmpty) {
        return day;
      }
    }
    return null;
  }

  /// Switches to the first day type with data.
  void _seeData() {
    final DayType? day = _firstDayWithData();
    if (day == null || day == _day) {
      return;
    }
    setState(() {
      _day = day;
      final List<String> origins = timetableOriginsOf(widget.line, day);
      _origin = origins.isEmpty ? '' : origins.first;
      _scrolledToNext = false;
    });
  }

  /// Hour rail with the auto-scroll towards the next departure.
  Widget _railSection(List<String> times, String? next, int nowMinutes) {
    // Chips carry the minute part only ("40" under hour "06"): the full
    // "HH:mm" strings would rebuild "06:06:40" values, break the past
    // dimming and never match the next-departure highlight. D-U26.
    final List<TimeRailHour> hours = <TimeRailHour>[
      for (final MapEntry<String, List<String>> e in groupByHour(times).entries)
        TimeRailHour(
          hour: e.key,
          minutes: <String>[for (final String t in e.value) t.split(':').last],
        ),
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

  /// Footnote with the bundle timetable date and the sources link. The date
  /// comes from the manifest, never from the clock.
  Widget _footnote() {
    final String date = ref.watch(timetableDateProvider).value ?? '';
    return Padding(
      padding: const EdgeInsets.only(top: Space.x6, bottom: Space.x4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              '${UiStrings.timetableFootnote}$date',
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

/// Empty state of a day with no schedules, with a jump to the first day
/// that has data when one exists.
class _EmptyTimetable extends StatelessWidget {
  /// Creates the empty state.
  const _EmptyTimetable({this.onSeeData});

  /// Called by the jump action, null when the line has no data at all.
  final VoidCallback? onSeeData;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Space.x6, bottom: Space.x4),
      child: EmptyState(
        title: UiStrings.timetableEmpty,
        message: UiStrings.aboutSourceLines,
        art: EmptyArt.search,
        actionLabel: onSeeData == null ? null : UiStrings.timetableSeeData,
        onAction: onSeeData,
      ),
    );
  }
}
