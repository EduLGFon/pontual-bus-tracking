// TimeRail: timetable layout with an hour label column and wrapping minute
// chips. Past minutes are dimmed by colour alpha, never by the Opacity
// widget. The next departure is highlighted with the primary fill.
// See docs/ui/UI_SPEC.md 7.6.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/components/pressable.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/design/tokens/colors.dart';
import 'package:pontual/ui/design/tokens/text.dart';

/// One hour of the timetable.
@immutable
class TimeRailHour {
  /// Creates the row.
  const TimeRailHour({required this.hour, required this.minutes});

  /// Hour label, for example "05".
  final String hour;

  /// Minutes present in the data for this hour.
  final List<String> minutes;
}

/// Timetable rail.
class TimeRail extends StatelessWidget {
  /// Creates the rail.
  const TimeRail({
    required this.hours,
    this.nextHour,
    this.nextMinute,
    this.nowMinutes,
    this.onSelect,
    this.scrollController,
    super.key,
  });

  /// Hours present in the data, in order.
  final List<TimeRailHour> hours;

  /// Hour of the next departure.
  final String? nextHour;

  /// Minute of the next departure.
  final String? nextMinute;

  /// Minutes since midnight, used to dim past chips.
  final int? nowMinutes;

  /// Called when a minute chip is tapped.
  final ValueChanged<String>? onSelect;

  /// Optional external scroll controller, for auto-scrolling to the next
  /// departure.
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListView.builder(
      controller: scrollController,
      itemCount: hours.length,
      itemExtent: 56,
      itemBuilder: (BuildContext context, int index) {
        final TimeRailHour row = hours[index];
        final bool isNext = row.hour == nextHour;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              width: Space.x8,
              child: Text(
                row.hour,
                style: context.text.title.copyWith(
                  fontSize: 18,
                  color: isNext ? colors.ink : colors.inkSubtle,
                ),
              ),
            ),
            const SizedBox(width: Space.x3),
            Expanded(
              child: Wrap(
                spacing: Space.x2,
                runSpacing: Space.x2,
                children: <Widget>[
                  for (final String minute in row.minutes)
                    _MinuteChip(
                      minute: minute,
                      hour: row.hour,
                      nowMinutes: nowMinutes,
                      highlight: isNext && minute == nextMinute,
                      onTap: onSelect,
                      colors: colors,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One minute chip.
class _MinuteChip extends StatelessWidget {
  const _MinuteChip({
    required this.minute,
    required this.hour,
    required this.nowMinutes,
    required this.highlight,
    required this.onTap,
    required this.colors,
  });

  /// Two-digit minute.
  final String minute;

  /// Two-digit hour of the chip.
  final String hour;

  /// Minutes since midnight, null when unknown.
  final int? nowMinutes;

  /// Whether this is the next departure.
  final bool highlight;

  /// Called on tap.
  final ValueChanged<String>? onTap;

  /// Token set.
  final PontualColors colors;

  @override
  Widget build(BuildContext context) {
    final String value = '$hour:$minute';
    final int? minutes = nowMinutes;
    final bool past = minutes != null && _minutesOf(value) <= minutes;
    final Color fill = highlight ? colors.primary : colors.surfaceSunken;
    final Color label = highlight
        ? colors.onPrimary
        : past
        ? colors.inkSubtle.withValues(alpha: 0.55)
        : colors.ink;
    return Pressable(
      onTap: onTap == null ? null : () => onTap!(value),
      semanticLabel: value,
      borderRadius: Radii.pill,
      child: Container(
        constraints: const BoxConstraints(minHeight: 36, minWidth: 48),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: Space.x3),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Text(minute, style: PontualText.label.copyWith(color: label)),
      ),
    );
  }
}

/// Minutes since midnight of an HH:mm string.
int _minutesOf(String hhmm) {
  final List<String> parts = hhmm.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}
