// Lines screen: the Linhas tab. The filter lives in the URL so links and the
// browser back button restore the same view, and every count comes from the
// data. See docs/ui/UI_SPEC.md 7.4.
import 'dart:async';

import 'package:flutter/material.dart' hide Chip;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/domain/line_category.dart';
import 'package:pontual/domain/schedule.dart';
import 'package:pontual/ui/adapters/lines_adapter.dart';
import 'package:pontual/ui/adapters/now_clock.dart';
import 'package:pontual/ui/design/components/chip.dart';
import 'package:pontual/ui/design/components/empty_state.dart';
import 'package:pontual/ui/design/components/line_row.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/line_colors.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/features/lines/favorites_store_bridge.dart';
import 'package:pontual/ui/features/lines/lines_logic.dart';
import 'package:pontual/ui/features/timetable/timetable_data.dart';
import 'package:pontual/ui/models/arrival_vm.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/models/line_vm.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:pontual/ui/util/format_eta.dart';

/// Filters offered by the chips row.
enum LinesFilter {
  /// Every active line.
  all('all', UiStrings.filterAll),

  /// Only lines with at least one vehicle sharing.
  live('live', UiStrings.filterLive),

  /// Only favourite lines.
  favorites('favorites', UiStrings.filterFavorites);

  /// Query parameter value of the filter.
  final String value;

  /// Chip label in pt-BR.
  final String label;

  /// Creates a filter with its query value and chip label.
  const LinesFilter(this.value, this.label);
}

/// Static lines keyed by code, so each row can reach its arrivals source.
final Provider<Map<String, StaticLine>> staticLinesByKeyProvider =
    Provider<Map<String, StaticLine>>((Ref ref) {
      return ref
          .watch(linesProvider)
          .maybeWhen(
            data: (List<StaticLine> lines) => <String, StaticLine>{
              for (final StaticLine line in lines) line.code: line,
            },
            orElse: () => const <String, StaticLine>{},
          );
    });

/// Next departure of a line key. Today wins at or after now; otherwise the
/// first departure of the next service day wins as `Amanhã HH:mm`; empty
/// when the line has no timetable at all. Uses the shared minute rule from
/// domain/schedule so Home and Linhas agree. `currentNowProvider` already
/// holds São Mateus wall clock, so no extra conversion applies here.
final nextDepartureProvider = Provider.family<String, String>((
  Ref ref,
  String key,
) {
  final StaticLine? line = ref.watch(staticLinesByKeyProvider)[key];
  if (line == null) {
    return '';
  }
  final DateTime now = ref.watch(currentNowProvider);
  final int nowMinutes = nowMinutesOf(now);
  final List<String> today = timetableTimesOf(line, dayTypeFor(now), null);
  final DayType tomorrowType = dayTypeFor(now.add(const Duration(days: 1)));
  final List<String> tomorrow = timetableTimesOf(line, tomorrowType, null);
  final NextDeparture? next = resolveNextDeparture(
    todayTimes: today,
    tomorrowTimes: tomorrow,
    nowMinutes: nowMinutes,
  );
  if (next == null) {
    return '';
  }
  if (next.isTomorrow) {
    return UiStrings.homeTomorrowAt(next.time);
  }
  final int minutes = minutesOf(next.time);
  return formatEta(
    ArrivalVM(
      lineKey: key,
      at: DateTime.utc(
        now.year,
        now.month,
        now.day,
        minutes ~/ 60,
        minutes % 60,
      ),
      certainty: Certainty.scheduled,
      asOf: now,
    ),
    now,
  ).primary;
});

/// The Linhas screen.
class LinesScreen extends ConsumerWidget {
  /// Creates the screen.
  const LinesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LinesFilter filter = _filterOf(context);
    final List<LineVM> all = ref.watch(linesVmProvider);
    final Map<String, StaticLine> statics = ref.watch(
      staticLinesByKeyProvider,
    );
    int withTimes = 0;
    for (final LineVM vm in all) {
      final StaticLine? s = statics[vm.key];
      if (s != null && hasTimetable(s)) {
        withTimes++;
      }
    }
    final List<LineVM> filtered = _filtered(
      all,
      filter,
      ref.watch(favoritesProvider),
    );
    final List<LinesListItem> items = filter == LinesFilter.all
        ? groupedLines(filtered)
        : sortedByCategory(filtered).map(LinesLineItem.new).toList();
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: _Header(total: all.length, withTimes: withTimes),
            ),
            const SliverToBoxAdapter(child: _FilterRow()),
            if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(marginFor(context)),
                    child: _EmptyState(filter: filter),
                  ),
                ),
              )
            else ...<Widget>[
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: marginFor(context)),
                sliver: SliverList.builder(
                  itemCount: items.length,
                  itemBuilder: (BuildContext context, int index) {
                    final LinesListItem item = items[index];
                    if (item is LinesHeaderItem) {
                      return _CategoryHeader(item: item);
                    }
                    final LineVM line = (item as LinesLineItem).line;
                    return Padding(
                      key: ValueKey<String>(line.key),
                      padding: const EdgeInsets.only(bottom: Space.x2),
                      child: _LineCard(line: line),
                    );
                  },
                ),
              ),
              // Clearance so the floating dock never covers the last row.
              const SliverToBoxAdapter(child: SizedBox(height: dockClearance)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Section header for one category: dot, name and count. Muted and compact.
class _CategoryHeader extends StatelessWidget {
  /// Creates the header for [item].
  const _CategoryHeader({required this.item});

  /// Header data with the category and its count.
  final LinesHeaderItem item;

  @override
  Widget build(BuildContext context) {
    final Color dot = categoryColorOf(
      item.category,
      brightness: Theme.of(context).brightness,
    );
    final String label = lineCategoryLabel(item.category);
    return Padding(
      padding: const EdgeInsets.only(top: Space.x4, bottom: Space.x2),
      child: Row(
        children: <Widget>[
          Container(
            width: Space.x2,
            height: Space.x2,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: Space.x2),
          Expanded(
            child: Text(
              '$label · ${item.count} ${item.count == 1 ? _oneLine : UiStrings.linesCount}',
              style: context.text.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Screen title and the honest totals derived from the data.
class _Header extends StatelessWidget {
  /// Creates the header for [total] lines with [withTimes] timetabled.
  const _Header({required this.total, required this.withTimes});

  /// Total active lines.
  final int total;

  /// Lines with at least one timetable time.
  final int withTimes;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        marginFor(context),
        Space.x6,
        marginFor(context),
        Space.x2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(UiStrings.linesTitle, style: context.text.title),
          Text(
            '$total ${total == 1 ? _oneLine : UiStrings.linesCount} '
            '· $withTimes ${UiStrings.linesWithTimes}',
            style: context.text.caption,
          ),
        ],
      ),
    );
  }
}

/// The chips row. Tapping a chip writes the filter to the URL.
class _FilterRow extends StatelessWidget {
  /// Creates the chips row.
  const _FilterRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        marginFor(context),
        0,
        marginFor(context),
        Space.x3,
      ),
      child: Row(
        children: <Widget>[
          for (final LinesFilter value in LinesFilter.values) ...<Widget>[
            Chip(
              label: value.label,
              selected: value == _filterOf(context),
              onTap: () => _select(context, value),
            ),
            if (value != LinesFilter.values.last)
              const SizedBox(width: Space.x2),
          ],
        ],
      ),
    );
  }
}

/// One row of the list, with its star toggle and its next departure.
class _LineCard extends ConsumerWidget {
  /// Creates the row for [line].
  const _LineCard({required this.line});

  /// Line shown by the row.
  final LineVM line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String next = ref.watch(nextDepartureProvider(line.key));
    final bool isFavorite = ref.watch(favoritesProvider).contains(line.key);
    final StaticLine? staticLine = ref.watch(staticLinesByKeyProvider)[line.key];
    final bool timed = staticLine != null && hasTimetable(staticLine);
    return LineRow(
      line: line,
      nextEta: next,
      isFavorite: isFavorite,
      hasTimetable: timed,
      onToggleFavorite: () => _toggleFavorite(ref),
      onTap: () => context.push('/line/${line.key}'),
    );
  }

  void _toggleFavorite(WidgetRef ref) {
    HapticFeedback.selectionClick();
    unawaited(ref.read(favoritesProvider.notifier).toggle(line.key));
  }
}

/// Empty state per filter, always with a way back to the other filters.
class _EmptyState extends StatelessWidget {
  /// Creates the empty state for [filter].
  const _EmptyState({required this.filter});

  /// Filter that produced no lines.
  final LinesFilter filter;

  @override
  Widget build(BuildContext context) {
    final bool noData = filter == LinesFilter.all;
    return EmptyState(
      art: filter == LinesFilter.live ? EmptyArt.bus : EmptyArt.search,
      title: filter == LinesFilter.live ? UiStrings.linesNoLive : filter.label,
      message: switch (filter) {
        LinesFilter.live => UiStrings.homeNoLiveHint,
        LinesFilter.favorites => UiStrings.linesNoFavorites,
        LinesFilter.all => _noLinesMessage,
      },
      actionLabel: noData ? null : UiStrings.filterAll,
      onAction: noData ? null : () => _select(context, LinesFilter.all),
    );
  }
}

/// Selects [filter], writing it to the URL so links keep working.
void _select(BuildContext context, LinesFilter filter) {
  HapticFeedback.selectionClick();
  final Uri uri = Uri.parse('/lines')
      .replace(queryParameters: <String, String>{'filter': filter.value});
  context.go(uri.toString());
}

/// Filter of the current URL, defaulting to "Todas".
LinesFilter _filterOf(BuildContext context) {
  if (GoRouter.maybeOf(context) == null) {
    return LinesFilter.all;
  }
  final String? raw = GoRouterState.of(context).uri.queryParameters['filter'];
  return LinesFilter.values.firstWhere(
    (LinesFilter filter) => filter.value == raw,
    orElse: () => LinesFilter.all,
  );
}

/// Lines for [filter], unsorted. Sorting and grouping own the order:
/// category first, then line number. Favorites are never pinned to the top.
List<LineVM> _filtered(
  List<LineVM> all,
  LinesFilter filter,
  Set<String> favorites,
) {
  return all.where((LineVM line) {
    return switch (filter) {
      LinesFilter.all => true,
      LinesFilter.live => line.isLive,
      LinesFilter.favorites => favorites.contains(line.key),
    };
  }).toList();
}

/// Singular of the count. The strings file only carries the plural form.
const String _oneLine = 'linha';

/// Message shown when the static data has no line at all.
const String _noLinesMessage = 'Nenhuma linha encontrada.';
