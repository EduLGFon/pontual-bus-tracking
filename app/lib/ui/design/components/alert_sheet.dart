// AlertSheet: "Avisar quando faltar" with minute chips, day chips and a
// weekday-repeat toggle. Flagged off with arrivalAlerts; no push channel
// exists in alpha, so onSave only persists through AlertsStore callers.
// See docs/ui/UI_SPEC.md 13.2.
import 'package:flutter/material.dart' hide Chip;
import 'package:pontual/ui/design/components/buttons.dart';
import 'package:pontual/ui/design/components/chip.dart';
import 'package:pontual/ui/design/components/pontual_sheet.dart';
import 'package:pontual/ui/design/components/pressable.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Minute choices offered by the sheet.
const List<int> alertMinuteChoices = <int>[2, 5, 10];

/// Weekday labels Mon to Sun with DateTime weekday values 1 to 7.
const List<(int, String)> alertWeekdays = <(int, String)>[
  (1, 'Seg'),
  (2, 'Ter'),
  (3, 'Qua'),
  (4, 'Qui'),
  (5, 'Sex'),
  (6, 'Sáb'),
  (7, 'Dom'),
];

/// Sheet collecting one alert rule.
class AlertSheet extends StatefulWidget {
  /// Creates the sheet.
  const AlertSheet({
    this.initialMinutes = 5,
    this.initialDays = const <int>[],
    this.initialRepeat = false,
    required this.onSave,
    super.key,
  });

  /// Preselected minutes before the arrival.
  final int initialMinutes;

  /// Preselected weekdays, empty for today only.
  final List<int> initialDays;

  /// Preselected repeat toggle.
  final bool initialRepeat;

  /// Called with the chosen rule.
  final void Function(int minutes, List<int> days, bool repeat) onSave;

  @override
  State<AlertSheet> createState() => _AlertSheetState();
}

class _AlertSheetState extends State<AlertSheet> {
  late int _minutes = widget.initialMinutes;
  late final List<int> _days = List<int>.from(widget.initialDays);
  late bool _repeat = widget.initialRepeat;

  @override
  Widget build(BuildContext context) {
    return PontualSheet(
      title: UiStrings.alertTitle,
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Wrap(
            spacing: Space.x2,
            runSpacing: Space.x2,
            children: <Widget>[
              for (final int m in alertMinuteChoices)
                Chip(
                  label: '$m min',
                  selected: _minutes == m,
                  onTap: () => setState(() => _minutes = m),
                ),
            ],
          ),
          const SizedBox(height: Space.x4),
          Wrap(
            spacing: Space.x2,
            runSpacing: Space.x2,
            children: <Widget>[
              for (final (int, String) day in alertWeekdays)
                Chip(
                  label: day.$2,
                  selected: _days.contains(day.$1),
                  compact: true,
                  onTap: () => setState(() {
                    if (_days.contains(day.$1)) {
                      _days.remove(day.$1);
                    } else {
                      _days.add(day.$1);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: Space.x2),
          Pressable(
            semanticLabel: 'Repetir nos dias úteis',
            onTap: () => setState(() => _repeat = !_repeat),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Repetir nos dias úteis',
                    style: context.text.body,
                  ),
                ),
                Switch(
                  value: _repeat,
                  onChanged: (bool v) => setState(() => _repeat = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.x2),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: UiStrings.alertSave,
              onPressed: () => widget.onSave(_minutes, _days, _repeat),
            ),
          ),
        ],
      ),
    );
  }
}
