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
import 'package:pontual/domain/schedule.dart';
import 'package:pontual/ui/adapters/lines_adapter.dart';
import 'package:pontual/ui/adapters/now_clock.dart';
import 'package:pontual/ui/design/components/chip.dart';
import 'package:pontual/ui/design/components/empty_state.dart';
import 'package:pontual/ui/design/components/line_row.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/features/lines/favorites_store_bridge.dart';
import 'package:pontual/ui/features/timetable/timetable_data.dart';
import 'package:pontual/ui/models/arrival_vm.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/models/line_vm.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:pontual/ui/util/format_eta.dart';
import 'package:pontual/ui/util/search_index.dart';

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
    final List<LineVM> lines = _visible(
      ref.watch(linesVmProvider),
      filter,
      ref.watch(favoritesProvider),
    );
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(child: _Header(count: lines.length)),
            const SliverToBoxAdapter(child: _FilterRow()),
            if (lines.isEmpty)
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
                  itemCount: lines.length,
                  itemBuilder: (BuildContext context, int index) {
                    return Padding(
                      key: ValueKey<String>(lines[index].key),
                      padding: const EdgeInsets.only(bottom: Space.x2),
                      child: _LineCard(line: lines[index]),
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

/// Screen title and the count derived from the visible data.
class _Header extends StatelessWidget {
  /// Creates the header for [count] visible lines.
  const _Header({required this.count});

  /// Number of visible lines.
  final int count;

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
            '$count ${count == 1 ? _oneLine : UiStrings.linesCount}',
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
    return LineRow(
      line: line,
      nextEta: next,
      isFavorite: isFavorite,
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

/// Lines for [filter], sorted live first, then favourites, then name.
List<LineVM> _visible(
  List<LineVM> all,
  LinesFilter filter,
  Set<String> favorites,
) {
  final List<LineVM> lines = all.where((LineVM line) {
    return switch (filter) {
      LinesFilter.all => true,
      LinesFilter.live => line.isLive,
      LinesFilter.favorites => favorites.contains(line.key),
    };
  }).toList();
  lines.sort((LineVM a, LineVM b) => _compareLines(a, b, favorites));
  return lines;
}

/// Orders live first, then favourites, then accent-insensitive name.
int _compareLines(LineVM a, LineVM b, Set<String> favorites) {
  if (a.isLive != b.isLive) {
    return a.isLive ? -1 : 1;
  }
  final bool favoriteA = favorites.contains(a.key);
  final bool favoriteB = favorites.contains(b.key);
  if (favoriteA != favoriteB) {
    return favoriteA ? -1 : 1;
  }
  return normalizeText(a.name).compareTo(normalizeText(b.name));
}

/// Singular of the count. The strings file only carries the plural form.
const String _oneLine = 'linha';

/// Message shown when the static data has no line at all.
const String _noLinesMessage = 'Nenhuma linha encontrada.';
