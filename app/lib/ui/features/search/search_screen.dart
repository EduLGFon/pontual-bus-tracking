// Search screen: local, instant and offline over the bundled line index.
// Results are grouped by kind through the SearchProvider interface, so a
// future stop or place kind adds a group with no change here.
// See docs/ui/UI_SPEC.md 7.3.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/ui/adapters/lines_adapter.dart';
import 'package:pontual/ui/adapters/local_stores.dart';
import 'package:pontual/ui/features/search/place_search.dart';
import 'package:pontual/ui/design/components/empty_state.dart';
import 'package:pontual/ui/design/components/icon_btn.dart';
import 'package:pontual/ui/design/components/line_badge.dart';
import 'package:pontual/ui/design/components/line_row.dart';
import 'package:pontual/ui/design/components/search_field.dart';
import 'package:pontual/ui/design/components/section_header.dart';
import 'package:pontual/ui/design/components/surface_card.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/domain/learning/learned_route_index.dart';
import 'package:pontual/domain/learning/place.dart';
import 'package:pontual/ui/models/line_vm.dart';
import 'package:pontual/ui/util/platform.dart';
import 'package:pontual/ui/util/search_index.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// One search result. Another kind wraps its own model; the screen only
/// reads [key] to record the opening in recents.
abstract interface class SearchHit {
  /// Stable id, also the key recorded in recents when the hit is opened.
  String get key;
}

/// One kind of results. Adding stops or places later means adding another
/// implementation, which adds a group and changes nothing else.
abstract interface class SearchProvider {
  /// Group header label in pt-BR, from the strings file.
  String get groupLabel;

  /// Ranked hits for [query]. Empty for an empty query.
  List<SearchHit> search(String query);

  /// Row for one hit. [onTap] opens the result.
  Widget row(SearchHit hit, VoidCallback onTap);
}

/// The typed query, dropped when the route is left.
class _QueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

/// Recent line keys, newest first, persisted through [RecentsStore].
class _RecentsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    unawaited(_load());
    return const <String>[];
  }

  Future<void> _load() async {
    try {
      state = await const RecentsStore().read();
    } on Object {
      // Defaults (empty) stand when prefs are unavailable.
    }
  }

  /// Records [key] as the most recent opening.
  Future<void> record(String key) async {
    const RecentsStore store = RecentsStore();
    await store.add(key);
    state = await store.read();
  }

  /// Forgets every recent.
  Future<void> clear() async {
    state = const <String>[];
    await const RecentsStore().clear();
  }
}

final _queryProvider = NotifierProvider.autoDispose<_QueryNotifier, String>(
  _QueryNotifier.new,
);

final _recentsProvider = NotifierProvider<_RecentsNotifier, List<String>>(
  _RecentsNotifier.new,
);

/// One group of rows in the single view: a result group, recents or
/// suggestions.
class _Section {
  _Section({
    required this.label,
    required this.hits,
    this.provider,
    this.actionLabel,
    this.onAction,
  });

  /// Header label. Empty hides the header.
  final String label;

  /// Rows of the section, already ranked.
  final List<SearchHit> hits;

  /// Source of the rows, null for the plain line rows of the browse state.
  final SearchProvider? provider;

  final String? actionLabel;
  final VoidCallback? onAction;
}

/// The browse state of an empty query: recents, then suggestions.
final _browseProvider = Provider<List<_Section>>((Ref ref) {
  final List<LineVM> all = ref.watch(linesVmProvider);
  final List<LineVM> recentLines = _recentLinesOf(
    ref.watch(_recentsProvider),
    all,
  );
  List<SearchHit> hitsOf(List<LineVM> lines) {
    return lines.map((LineVM line) => _LineHit(line: line, query: '')).toList();
  }

  return <_Section>[
    if (recentLines.isNotEmpty)
      _Section(
        label: UiStrings.searchRecents,
        hits: hitsOf(recentLines),
        actionLabel: UiStrings.homeRecentsClear,
        onAction: () => ref.read(_recentsProvider.notifier).clear(),
      ),
    _Section(label: UiStrings.searchSuggestions, hits: hitsOf(all)),
  ];
});

/// Grouped results for the current query, one section per provider, empty
/// dropped.
final _searchGroupsProvider = Provider<List<_Section>>((Ref ref) {
  final String query = ref.watch(_queryProvider);
  final List<SearchProvider> providers = <SearchProvider>[
    _LineSearchProvider(ref.watch(lineIndexProvider)),
  ];
  final LearnedRoutesIndex index =
      ref.watch(learnedRoutesIndexProvider).asData?.value ??
      LearnedRoutesIndex.empty;
  final List<Place> places =
      ref.watch(placesProvider).asData?.value ?? const <Place>[];
  final List<LineVM> lines = ref.watch(linesVmProvider);
  if (index.entries.isNotEmpty && places.isNotEmpty) {
    providers.add(
      PlaceSearchProvider(places: places, index: index, lines: lines),
    );
  }
  final List<_Section> sections = <_Section>[];
  for (final SearchProvider provider in providers) {
    final List<SearchHit> hits = provider.search(query);
    if (hits.isNotEmpty) {
      sections.add(
        _Section(label: provider.groupLabel, hits: hits, provider: provider),
      );
    }
  }
  return sections;
});

/// Recent keys that no longer exist in the data simply disappear.
List<LineVM> _recentLinesOf(List<String> recents, List<LineVM> all) {
  final List<LineVM> lines = <LineVM>[];
  for (final String key in recents) {
    for (final LineVM line in all) {
      if (line.key == key) {
        lines.add(line);
        break;
      }
    }
  }
  return lines;
}

/// A line hit.
class _LineHit implements SearchHit {
  _LineHit({required this.line, required this.query});

  final LineVM line;

  /// Normalised query, used to highlight the match.
  final String query;

  @override
  String get key => line.key;
}

/// The line search over the local index.
class _LineSearchProvider implements SearchProvider {
  _LineSearchProvider(this.index);

  final List<LineIndex> index;

  @override
  String get groupLabel => UiStrings.searchLines;

  @override
  List<SearchHit> search(String query) {
    return searchLines(
      index,
      query,
    ).map((LineMatch m) => _LineHit(line: m.line, query: query)).toList();
  }

  @override
  Widget row(SearchHit hit, VoidCallback onTap) {
    if (hit is! _LineHit) {
      return const SizedBox.shrink();
    }
    return _ResultRow(line: hit.line, query: hit.query, onTap: onTap);
  }
}

/// Focuses the field from anywhere.
class _FocusFieldIntent extends Intent {
  const _FocusFieldIntent();
}

/// Closes the screen, dismissing the keyboard first.
class _CloseIntent extends Intent {
  const _CloseIntent();
}

/// Moves the focus through the rows by [delta], negative upwards.
class _MoveFocusIntent extends Intent {
  const _MoveFocusIntent(this.delta);

  final int delta;
}

/// Web-only arrow shortcuts, registered by the screen.
const Map<ShortcutActivator, Intent> _moveShortcuts =
    <ShortcutActivator, Intent>{
      SingleActivator(LogicalKeyboardKey.arrowDown): _MoveFocusIntent(1),
      SingleActivator(LogicalKeyboardKey.arrowUp): _MoveFocusIntent(-1),
    };

/// The Busca screen.
class SearchScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _fieldFocus = FocusNode();
  List<SearchHit> _navHits = const <SearchHit>[];
  int _focused = 0;

  @override
  void dispose() {
    _controller.dispose();
    _fieldFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String query = ref.watch(_queryProvider);
    final bool browsing = query.isEmpty;
    final List<_Section> sections = browsing
        ? ref.watch(_browseProvider)
        : ref.watch(_searchGroupsProvider);
    _navHits = sections.expand((_Section section) => section.hits).toList();
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        if (PlatformInfo.isWeb)
          const SingleActivator(LogicalKeyboardKey.slash):
              const _FocusFieldIntent(),
        if (PlatformInfo.isWeb) ..._moveShortcuts,
        const SingleActivator(LogicalKeyboardKey.escape): const _CloseIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _FocusFieldIntent: CallbackAction<_FocusFieldIntent>(
            onInvoke: (_) => _fieldFocus.requestFocus(),
          ),
          _CloseIntent: CallbackAction<_CloseIntent>(onInvoke: (_) => _close()),
          _MoveFocusIntent: CallbackAction<_MoveFocusIntent>(
            onInvoke: (_MoveFocusIntent intent) => _moveFocus(intent.delta),
          ),
        },
        child: Scaffold(
          backgroundColor: context.colors.bg,
          body: SafeArea(
            child: Column(
              children: <Widget>[
                _TopBar(
                  controller: _controller,
                  focusNode: _fieldFocus,
                  onChanged: _onQueryChanged,
                  onSubmitted: _onSubmit,
                  onBack: _close,
                ),
                Expanded(
                  child: !browsing && sections.isEmpty
                      ? _noResults()
                      : _list(sections),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onQueryChanged(String value) {
    ref.read(_queryProvider.notifier).set(value);
    setState(() => _focused = 0);
  }

  /// Opens the first hit on Enter, leaving the browse state alone.
  void _onSubmit(String query) {
    if (query.trim().isEmpty || _navHits.isEmpty) {
      return;
    }
    _open(_navHits.first.key);
  }

  void _open(String key) {
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(ref.read(_recentsProvider.notifier).record(key));
    unawaited(context.push('/line/$key'));
  }

  /// Esc and back close with the keyboard dismissed first.
  void _close() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (context.canPop()) {
      context.pop();
    }
  }

  /// Moves the focus along the reading order, which is the row order.
  void _moveFocus(int delta) {
    final FocusNode? focus = FocusManager.instance.primaryFocus;
    if (focus == null) {
      return;
    }
    if (delta > 0) {
      focus.nextFocus();
    } else {
      focus.previousFocus();
    }
  }

  Widget _list(List<_Section> sections) {
    final List<Widget> slivers = <Widget>[];
    int base = 0;
    for (final _Section section in sections) {
      final int offset = base;
      base += section.hits.length;
      // A lone result group needs no header; browse sections always do.
      if (section.label.isNotEmpty &&
          (sections.length > 1 || section.provider == null)) {
        slivers.add(SliverToBoxAdapter(child: _header(section)));
      }
      slivers.add(
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: marginFor(context)),
          sliver: SliverList.builder(
            itemCount: section.hits.length,
            itemBuilder: (BuildContext context, int index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: Space.x2),
                child: _row(offset + index, _rowOf(section, index)),
              );
            },
          ),
        ),
      );
    }
    return CustomScrollView(slivers: slivers);
  }

  Widget _rowOf(_Section section, int index) {
    final SearchHit hit = section.hits[index];
    void open() => _open(hit.key);
    if (section.provider != null) {
      return section.provider!.row(hit, open);
    }
    if (hit is! _LineHit) {
      return const SizedBox.shrink();
    }
    return _BrowseLineRow(line: hit.line, onTap: open);
  }

  Widget _noResults() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(marginFor(context)),
        child: const EmptyState(
          art: EmptyArt.search,
          title: UiStrings.searchEmptyTitle,
          message: UiStrings.searchEmptyTip,
        ),
      ),
    );
  }

  Widget _header(_Section section) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: marginFor(context)),
      child: SectionHeader(
        title: section.label,
        actionLabel: section.actionLabel,
        onAction: section.onAction,
      ),
    );
  }

  /// Wraps a row so it takes keyboard focus and shows the focus ring. Rows
  /// are the only focusable things in the list, so Tab and the arrows walk
  /// them in order.
  Widget _row(int index, Widget child) {
    return Focus(
      debugLabel: 'search-result',
      canRequestFocus: true,
      skipTraversal: false,
      descendantsAreFocusable: false,
      onFocusChange: (bool focused) {
        if (focused && _focused != index) {
          setState(() => _focused = index);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.l),
          border: Border.all(
            color: index == _focused
                ? context.colors.primary
                : context.colors.line,
            width: index == _focused ? 2 : 1,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Back button and the search field, with the label the field needs.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onBack,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        marginFor(context),
        Space.x2,
        marginFor(context),
        Space.x2,
      ),
      child: Row(
        children: <Widget>[
          IconBtn(
            icon: Icons.arrow_back_rounded,
            semanticLabel: UiStrings.back,
            onTap: onBack,
          ),
          Expanded(
            child: SearchField(
              hint: UiStrings.searchHint,
              semanticLabel: UiStrings.searchHint,
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
            ),
          ),
        ],
      ),
    );
  }
}

/// A line hit: badge, name with the matched part in bold, terminals.
class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.line,
    required this.query,
    required this.onTap,
  });

  final LineVM line;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: Space.x4,
        vertical: Space.x3,
      ),
      child: Row(
        children: <Widget>[
          LineBadge.ofLine(line, size: BadgeSize.m),
          const SizedBox(width: Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text.rich(
                  TextSpan(children: _spans(context)),
                  style: context.text.headline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (line.terminalsText.isNotEmpty)
                  Text(
                    line.terminalsText,
                    style: context.text.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Splits the name into plain and bold spans around the match, so bold is
  /// never the only cue that this row matched.
  List<TextSpan> _spans(BuildContext context) {
    final TextStyle base = context.text.headline;
    final TextStyle strong = base.copyWith(fontWeight: FontWeight.w700);
    final List<int> range = highlightRanges(line.name, query);
    if (range.length < 2) {
      return <TextSpan>[TextSpan(text: line.name, style: base)];
    }
    return <TextSpan>[
      TextSpan(text: line.name.substring(0, range[0]), style: base),
      TextSpan(text: line.name.substring(range[0], range[1]), style: strong),
      TextSpan(text: line.name.substring(range[1]), style: base),
    ];
  }
}

/// Browse-state line row with its shared status. Only the status text
/// rebuilds on tick, using the same adapter provider as Linhas.
class _BrowseLineRow extends ConsumerWidget {
  /// Creates the row for [line].
  const _BrowseLineRow({required this.line, required this.onTap});

  /// Line shown by the row.
  final LineVM line;

  /// Called when the row is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LineRow(
      line: line,
      status: ref.watch(lineStatusProvider(line.key)),
      onTap: onTap,
    );
  }
}
