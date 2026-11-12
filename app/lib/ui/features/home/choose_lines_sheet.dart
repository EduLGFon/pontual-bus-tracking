// First-run line picker of Início. Local only: the shared line index filters
// the bundled active lines, and saving writes the favourites store. No
// network call and no location permission in this flow.
// See docs/ui/UI_SPEC.md 7.2, 7.10 and 10.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/ui/adapters/lines_adapter.dart';
import 'package:pontual/ui/design/components/buttons.dart';
import 'package:pontual/ui/design/components/line_badge.dart';
import 'package:pontual/ui/design/components/pontual_sheet.dart';
import 'package:pontual/ui/design/components/pressable.dart';
import 'package:pontual/ui/design/components/search_field.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/features/home/welcome_state.dart';
import 'package:pontual/ui/features/lines/favorites_store_bridge.dart';
import 'package:pontual/ui/models/line_vm.dart';
import 'package:pontual/ui/shell/toast_host.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:pontual/ui/util/search_index.dart';

/// Opens the first-run line picker as a root-level, scroll-controlled sheet.
Future<void> showChooseLines(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Root navigator so the sheet sits above the shell and its dock. D-U26.
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (BuildContext sheetContext) {
      return Padding(
        // The search field takes focus: keep the list above the keyboard.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: const ChooseLinesSheet(),
      );
    },
  );
}

/// Body of the first-run line picker.
class ChooseLinesSheet extends ConsumerStatefulWidget {
  /// Creates the picker.
  const ChooseLinesSheet({super.key});

  @override
  ConsumerState<ChooseLinesSheet> createState() => _ChooseLinesSheetState();
}

class _ChooseLinesSheetState extends ConsumerState<ChooseLinesSheet> {
  final TextEditingController _query = TextEditingController();
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.of(ref.read(favoritesProvider));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _toggle(String key) {
    setState(() {
      if (!_selected.add(key)) {
        _selected.remove(key);
      }
    });
  }

  void _save() {
    if (_selected.isEmpty) {
      return;
    }
    unawaited(
      ref.read(favoritesProvider.notifier).setAll(Set<String>.of(_selected)),
    );
    ref.read(onboardingProvider.notifier).dismissWelcome();
    ref.read(toastControllerProvider.notifier).show(UiStrings.homeChooseSaved);
    Navigator.of(context).pop();
  }

  List<LineVM> _visibleLines(List<LineVM> lines, List<LineIndex> index) {
    final String query = _query.text.trim();
    if (query.isEmpty) {
      return lines;
    }
    return searchLines(
      index,
      query,
    ).map((LineMatch match) => match.line).toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<LineVM> lines = ref.watch(linesVmProvider);
    final List<LineIndex> index = ref.watch(lineIndexProvider);
    final List<LineVM> visible = _visibleLines(lines, index);
    return PontualSheet(
      title: UiStrings.homeChooseTitle,
      scrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            UiStrings.homeChooseBody,
            style: context.text.body.copyWith(color: context.colors.inkMuted),
          ),
          const SizedBox(height: Space.x3),
          SearchField(
            hint: UiStrings.homeChooseSearchHint,
            controller: _query,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.x3),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.x4),
              child: Text(
                UiStrings.homeChooseEmpty,
                style: context.text.body.copyWith(
                  color: context.colors.inkMuted,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            ListView.builder(
              key: const ValueKey<String>('choose-lines-list'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visible.length,
              itemBuilder: (BuildContext context, int i) {
                return _lineTile(visible[i]);
              },
            ),
          const SizedBox(height: Space.x4),
          PrimaryButton(
            label: UiStrings.homeChooseSave,
            onPressed: _selected.isEmpty ? null : _save,
          ),
        ],
      ),
    );
  }

  Widget _lineTile(LineVM line) {
    final bool selected = _selected.contains(line.key);
    final Color border = selected
        ? context.colors.primary
        : context.colors.line;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.x2),
      child: Semantics(
        selected: selected,
        child: Pressable(
          onTap: () => _toggle(line.key),
          semanticLabel: line.name,
          borderRadius: Radii.l,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.x3,
              vertical: Space.x3,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? context.colors.primary.withValues(alpha: 0.08)
                  : context.colors.surfaceSunken,
              borderRadius: BorderRadius.circular(Radii.l),
              border: Border.all(color: border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                LineBadge.ofLine(line, size: BadgeSize.m),
                const SizedBox(width: Space.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(line.name, style: context.text.label),
                      if (line.terminalsText.isNotEmpty) ...<Widget>[
                        const SizedBox(height: Space.x1),
                        Text(
                          line.terminalsText,
                          style: context.text.caption.copyWith(
                            color: context.colors.inkMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: Space.x2),
                Icon(
                  selected
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  color: selected
                      ? context.colors.primary
                      : context.colors.inkMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
