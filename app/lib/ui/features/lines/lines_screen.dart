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
import 'package:pontual/ui/adapters/lines_adapter.dart';
import 'package:pontual/ui/design/components/chip.dart';
import 'package:pontual/ui/design/components/empty_state.dart';
import 'package:pontual/ui/design/components/line_row.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/line_colors.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/features/lines/favorites_store_bridge.dart';
import 'package:pontual/ui/features/lines/lines_logic.dart';
import 'package:pontual/ui/features/timetable/timetable_data.dart';
import 'package:pontual/ui/models/line_status.dart';
import 'package:pontual/ui/models/line_vm.dart';
import 'package:pontual/ui/shell/offline_bridge.dart';
import 'package:pontual/ui/shell/toast_host.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

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

/// Static lines keyed by code, so the header can count timetabled lines.
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

/// The Linhas screen.
class LinesScreen extends ConsumerWidget {
  /// Creates the screen.
  const LinesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LinesFilter filter = _filterOf(context);
    final List<LineVM> all = ref.watch(linesVmProvider);
    final Set<String> favorites = ref.watch(favoritesProvider);
    final bool offline = ref.watch(offlineFlagProvider);
    final Map<String, StaticLine> statics = ref.watch(staticLinesByKeyProvider);
    int withTimes = 0;
    int liveLines = 0;
    for (final LineVM vm in all) {
      final StaticLine? s = statics[vm.key];
      if (s != null && hasTimetable(s)) {
        withTimes++;
      }
      if (vm.isLive) {
        liveLines++;
      }
    }
    final List<LineVM> filtered = _filtered(all, filter, favorites);
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
            SliverPersistentHeader(
              pinned: true,
              delegate: _PinnedChips(
                liveCount: liveLines,
                favoriteCount: favorites.length,
                offline: offline,
              ),
            ),
            if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(marginFor(context)),
                    child: _EmptyState(filter: filter, offline: offline),
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

/// Pinned chips delegate: the filter row stays visible while the list
/// scrolls. Opaque background so rows slide under it without ghosting.
class _PinnedChips extends SliverPersistentHeaderDelegate {
  /// Creates the delegate.
  const _PinnedChips({
    required this.liveCount,
    required this.favoriteCount,
    required this.offline,
  });

  /// Lines currently sharing. Unknown when [offline] is true.
  final int liveCount;

  /// Favourite lines.
  final int favoriteCount;

  /// True while the app is offline.
  final bool offline;

  @override
  double get minExtent => Sizes.chip + Space.x3;

  @override
  double get maxExtent => Sizes.chip + Space.x3;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: context.colors.bg,
      child: _FilterRow(
        liveCount: liveCount,
        favoriteCount: favoriteCount,
        offline: offline,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedChips oldDelegate) {
    return oldDelegate.liveCount != liveCount ||
        oldDelegate.favoriteCount != favoriteCount ||
        oldDelegate.offline != offline;
  }
}

/// The chips row. Tapping a chip writes the filter to the URL.
/// Counts are cheap and derived: live lines and favourites. When offline
/// the live count is unknown, so the chip shows no count.
class _FilterRow extends StatelessWidget {
  /// Creates the chips row.
  const _FilterRow({
    required this.liveCount,
    required this.favoriteCount,
    required this.offline,
  });

  /// Lines currently sharing. Unknown when [offline] is true.
  final int liveCount;

  /// Favourite lines.
  final int favoriteCount;

  /// True while the app is offline.
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final LinesFilter current = _filterOf(context);
    String liveLabel = UiStrings.filterLive;
    if (!offline && liveCount > 0) {
      liveLabel = '${UiStrings.filterLive} ($liveCount)';
    }
    String favLabel = UiStrings.filterFavorites;
    if (favoriteCount > 0) {
      favLabel = '${UiStrings.filterFavorites} ($favoriteCount)';
    }
    final Map<LinesFilter, String> labels = <LinesFilter, String>{
      LinesFilter.all: UiStrings.filterAll,
      LinesFilter.live: liveLabel,
      LinesFilter.favorites: favLabel,
    };
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
              label: labels[value]!,
              selected: value == current,
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

/// One row of the list, with its star toggle and its live status.
/// The status comes from the shared adapter provider, so only the small
/// status text rebuilds on tick, not the list order.
class _LineCard extends ConsumerWidget {
  /// Creates the row for [line].
  const _LineCard({required this.line});

  /// Line shown by the row.
  final LineVM line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LineStatus status = ref.watch(lineStatusProvider(line.key));
    final bool isFavorite = ref.watch(favoritesProvider).contains(line.key);
    return LineRow(
      line: line,
      status: status,
      isFavorite: isFavorite,
      onToggleFavorite: () => _toggleFavorite(context, ref),
      onTap: () => context.push('/line/${line.key}'),
    );
  }

  void _toggleFavorite(BuildContext context, WidgetRef ref) {
    HapticFeedback.selectionClick();
    final bool wasFavorite = ref.read(favoritesProvider).contains(line.key);
    unawaited(ref.read(favoritesProvider.notifier).toggle(line.key));
    ref
        .read(toastControllerProvider.notifier)
        .show(
          wasFavorite ? UiStrings.linesFavRemoved : UiStrings.linesFavAdded,
          actionLabel: UiStrings.undo,
          onAction: () =>
              unawaited(ref.read(favoritesProvider.notifier).toggle(line.key)),
        );
  }
}

/// Empty state per filter, always with a way back to the other filters.
/// Offline live is unknown, not zero: the empty state says timetables
/// still work instead of claiming nothing is sharing.
class _EmptyState extends StatelessWidget {
  /// Creates the empty state for [filter].
  const _EmptyState({required this.filter, required this.offline});

  /// Filter that produced no lines.
  final LinesFilter filter;

  /// True while the app is offline.
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final bool noData = filter == LinesFilter.all;
    if (filter == LinesFilter.live && offline) {
      return EmptyState(
        art: EmptyArt.cloud,
        title: UiStrings.filterLive,
        message: UiStrings.linesLiveOffline,
        actionLabel: UiStrings.filterAll,
        onAction: () => _select(context, LinesFilter.all),
      );
    }
    return EmptyState(
      art: filter == LinesFilter.live ? EmptyArt.bus : EmptyArt.search,
      title: switch (filter) {
        LinesFilter.live => UiStrings.homeNoLive,
        LinesFilter.favorites => UiStrings.filterFavorites,
        LinesFilter.all => filter.label,
      },
      message: switch (filter) {
        LinesFilter.live => UiStrings.linesNoLiveBody,
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
