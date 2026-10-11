// Shortcuts section of Início: the horizontal snap list of saved journeys,
// the first-run add cards, and the sort that puts the earliest next arrival
// first. Pure presentation over the shortcut notifier and the timetable seam.
// See docs/ui/UI_SPEC.md 7.2.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/ui/adapters/arrivals_adapter.dart';
import 'package:pontual/ui/adapters/lines_adapter.dart';
import 'package:pontual/ui/adapters/now_clock.dart';
import 'package:pontual/ui/design/components/section_header.dart';
import 'package:pontual/ui/design/components/shortcut_card.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/models/arrival_vm.dart';
import 'package:pontual/ui/models/line_vm.dart';
import 'package:pontual/ui/models/shortcut_vm.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:pontual/ui/features/home/home_providers.dart';
import 'package:pontual/ui/features/home/shortcut_sheet.dart';

/// Kinds offered as first-run placeholder cards.
const List<ShortcutKind> _firstRunKinds = <ShortcutKind>[
  ShortcutKind.home,
  ShortcutKind.work,
  ShortcutKind.school,
  ShortcutKind.university,
];

/// A shortcut bound to the views it renders with.
class _ShortcutEntry {
  _ShortcutEntry({required this.shortcut, required this.line, this.arrival});

  /// Stored shortcut.
  final ShortcutVM shortcut;

  /// Line view-model for the line badge.
  final LineVM line;

  /// Next upcoming arrival, when the timetable has one.
  final ArrivalVM? arrival;
}

StaticLine? _staticOf(List<StaticLine> lines, String code) {
  for (final StaticLine line in lines) {
    if (line.code == code) {
      return line;
    }
  }
  return null;
}

/// Next upcoming arrival for a shortcut. Falls back to the merged timetable
/// when an origin yields nothing, which keeps the card honest.
ArrivalVM? _nextArrival(StaticLine line, String? origin, DateTime now) {
  final TimetableArrivalsSource source = TimetableArrivalsSource(
    line: line,
    now: now,
  );
  List<ArrivalVM> departures = source.departures(
    ArrivalQuery(lineKey: line.code, originLabel: origin, limit: 0),
  );
  if (departures.isEmpty && origin != null) {
    departures = source.departures(ArrivalQuery(lineKey: line.code, limit: 0));
  }
  for (final ArrivalVM arrival in departures) {
    if (!arrival.isPast(now)) {
      return arrival;
    }
  }
  return null;
}

/// Horizontal snap list of shortcuts, or the first-run add cards.
class ShortcutsSection extends ConsumerWidget {
  /// Creates the shortcuts section.
  const ShortcutsSection({super.key});

  List<_ShortcutEntry> _entries(
    List<ShortcutVM> shortcuts,
    List<LineVM> lines,
    List<StaticLine> statics,
    DateTime now,
  ) {
    final List<_ShortcutEntry> entries = <_ShortcutEntry>[];
    for (final ShortcutVM shortcut in shortcuts) {
      final LineVM? line = lineByKey(lines, shortcut.lineKey);
      if (line == null) {
        continue;
      }
      final StaticLine? static = _staticOf(statics, shortcut.lineKey);
      entries.add(
        _ShortcutEntry(
          shortcut: shortcut,
          line: line,
          arrival: static == null
              ? null
              : _nextArrival(static, shortcut.originLabel, now),
        ),
      );
    }
    entries.sort((_ShortcutEntry a, _ShortcutEntry b) {
      final DateTime? pa = a.arrival?.at;
      final DateTime? pb = b.arrival?.at;
      if (pa == null && pb == null) {
        return 0;
      }
      if (pa == null) {
        return 1;
      }
      if (pb == null) {
        return -1;
      }
      return pa.compareTo(pb);
    });
    return entries;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<ShortcutVM> shortcuts = ref.watch(shortcutsProvider);
    final List<StaticLine> statics =
        ref.watch(linesProvider).asData?.value ?? const <StaticLine>[];
    final List<LineVM> lines = ref.watch(linesVmProvider);
    final DateTime now = ref.watch(currentNowProvider);

    final List<Widget> cards = <Widget>[];
    if (shortcuts.isEmpty) {
      for (final ShortcutKind kind in _firstRunKinds) {
        cards.add(
          AddShortcutCard(
            label: shortcutKindLabel(kind),
            icon: iconOfKind(kind),
            onTap: () =>
                unawaited(showShortcutEditor(context, initialKind: kind)),
          ),
        );
      }
    } else {
      for (final _ShortcutEntry entry in _entries(
        shortcuts,
        lines,
        statics,
        now,
      )) {
        final String tag =
            '${entry.shortcut.kind.name}-${entry.shortcut.lineKey}'
            '-${entry.shortcut.originLabel ?? ''}';
        cards.add(
          ShortcutCard(
            key: ValueKey<String>(tag),
            label: entry.shortcut.label,
            line: entry.line,
            arrival: entry.arrival,
            now: entry.arrival == null ? null : now,
            icon: iconOfKind(entry.shortcut.kind),
            onTap: () => context.push('/line/${entry.shortcut.lineKey}'),
            onLongPress: () =>
                unawaited(showShortcutActions(context, ref, entry.shortcut)),
          ),
        );
      }
      cards.add(
        AddShortcutCard(
          label: UiStrings.addShortcut,
          onTap: () => unawaited(showShortcutEditor(context)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(title: UiStrings.homeShortcuts),
        // The strip grows with the cards: at large text scales the cards
        // are taller than the 112 dp minimum, and clipping them would
        // hide content from the users who need it most.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const _SnapScrollPhysics(
            itemExtent: Sizes.shortcutWidth + Space.x3,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int i = 0; i < cards.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: Space.x3),
                cards[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Snaps a horizontal list to card boundaries, dependency-free.
class _SnapScrollPhysics extends ScrollPhysics {
  const _SnapScrollPhysics({required this.itemExtent, super.parent});

  /// Distance between the start of two neighbouring cards.
  final double itemExtent;

  @override
  _SnapScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _SnapScrollPhysics(
      itemExtent: itemExtent,
      parent: buildParent(ancestor),
    );
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final double target = (position.pixels + velocity / 8) / itemExtent;
    final int index = velocity.abs() > 400
        ? (velocity > 0 ? target.ceil() : target.floor())
        : target.round();
    final double snapped = (index * itemExtent).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((snapped - position.pixels).abs() < 1) {
      return null;
    }
    return ScrollSpringSimulation(
      const SpringDescription(mass: 1, stiffness: 600, damping: 35),
      position.pixels,
      snapped,
      velocity,
    );
  }
}
