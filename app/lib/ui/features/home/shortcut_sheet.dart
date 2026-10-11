// Shortcut sheets and local state for Início. The list lives in a Notifier
// over ShortcutsStore; the add-or-edit sheet and the long-press actions are
// pure presentation on top of it. No personal data is collected.
// See docs/ui/UI_SPEC.md 6.3 and 7.2.
import 'dart:async';

import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/domain/schedule.dart';
import 'package:pontual/ui/adapters/arrivals_adapter.dart';
import 'package:pontual/ui/adapters/lines_adapter.dart';
import 'package:pontual/ui/adapters/local_stores.dart';
import 'package:pontual/ui/adapters/now_clock.dart';
import 'package:pontual/ui/design/components/buttons.dart';
import 'package:pontual/ui/design/components/chip.dart';
import 'package:pontual/ui/design/components/line_badge.dart';
import 'package:pontual/ui/design/components/pontual_sheet.dart';
import 'package:pontual/ui/design/components/search_field.dart';
import 'package:pontual/ui/design/components/surface_card.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/models/line_vm.dart';
import 'package:pontual/ui/models/shortcut_vm.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

// Copy genuinely absent from ui_strings.dart. Kept private here and reported
// as a foundation gap instead of editing the shared strings file.
const String _editorTitleAdd = 'Adicionar atalho';
const String _editorTitleEdit = 'Editar atalho';
const String _editorSave = 'Salvar';
const String _editorEdit = 'Editar';
const String _editorRemove = 'Remover';
const String _editorCustomHint = 'Nome do atalho';
const String _editorSearchHint = 'Buscar linha';
const String _editorNoLines = 'Nenhuma linha encontrada';
const String _kindHome = 'Casa';
const String _kindWork = 'Trabalho';
const String _kindSchool = 'Escola';
const String _kindUniversity = 'Faculdade';
const String _kindCustom = 'Outro';

/// pt-BR label of a shortcut kind. Kept here so the home first-run cards and
/// the add sheet stay consistent.
String shortcutKindLabel(ShortcutKind kind) {
  return switch (kind) {
    ShortcutKind.home => _kindHome,
    ShortcutKind.work => _kindWork,
    ShortcutKind.school => _kindSchool,
    ShortcutKind.university => _kindUniversity,
    ShortcutKind.custom => _kindCustom,
  };
}

bool _sameShortcut(ShortcutVM a, ShortcutVM b) {
  return a.kind == b.kind &&
      a.lineKey == b.lineKey &&
      a.originLabel == b.originLabel;
}

/// Maps a [DayType] onto the day_type key used by the static data.
String _dayTypeKey(DayType type) {
  return switch (type) {
    DayType.weekday => 'weekday',
    DayType.saturday => 'saturday',
    DayType.sundayHoliday => 'sunday_holiday',
  };
}

/// Origin terminals of a line for the current day type, from the timetable.
List<String> _originsOf(List<StaticLine> statics, LineVM line, DateTime now) {
  final StaticLine? source = _staticOf(statics, line.key);
  if (source == null) {
    return const <String>[];
  }
  return TimetableArrivalsSource(
    line: source,
    now: now,
  ).originsFor(_dayTypeKey(dayTypeFor(now)));
}

StaticLine? _staticOf(List<StaticLine> statics, String code) {
  for (final StaticLine line in statics) {
    if (line.code == code) {
      return line;
    }
  }
  return null;
}

/// Holds the shortcut list, loaded once and updated optimistically.
class ShortcutsNotifier extends Notifier<List<ShortcutVM>> {
  @override
  List<ShortcutVM> build() {
    unawaited(_load());
    return const <ShortcutVM>[];
  }

  Future<void> _load() async {
    try {
      state = await const ShortcutsStore().read();
    } on Object {
      // Defaults (empty) stand when prefs are unavailable.
    }
  }

  /// Appends [shortcut]. Silently ignored past [maxShortcuts].
  void add(ShortcutVM shortcut) {
    if (state.length >= maxShortcuts) {
      return;
    }
    state = <ShortcutVM>[...state, shortcut];
    _persist();
  }

  /// Replaces the entry equal to [previous] with [updated].
  void update(ShortcutVM previous, ShortcutVM updated) {
    final int index = state.indexWhere(
      (ShortcutVM e) => _sameShortcut(e, previous),
    );
    if (index < 0) {
      add(updated);
      return;
    }
    final List<ShortcutVM> next = <ShortcutVM>[...state];
    next[index] = updated;
    state = next;
    _persist();
  }

  /// Removes the entry equal to [shortcut].
  void remove(ShortcutVM shortcut) {
    state = state.where((ShortcutVM e) => !_sameShortcut(e, shortcut)).toList();
    _persist();
  }

  void _persist() {
    unawaited(const ShortcutsStore().write(state));
  }
}

/// Provides the shortcut list of Início.
final NotifierProvider<ShortcutsNotifier, List<ShortcutVM>> shortcutsProvider =
    NotifierProvider<ShortcutsNotifier, List<ShortcutVM>>(
      ShortcutsNotifier.new,
    );

/// Opens the add sheet, or the edit sheet when [existing] is provided.
Future<void> showShortcutEditor(
  BuildContext context, {
  ShortcutVM? existing,
  ShortcutKind initialKind = ShortcutKind.home,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (BuildContext sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: ShortcutEditorSheet(
          existing: existing,
          initialKind: initialKind,
        ),
      );
    },
  );
}

/// Opens the long-press actions sheet with Editar and Remover.
Future<void> showShortcutActions(
  BuildContext hostContext,
  WidgetRef ref,
  ShortcutVM shortcut,
) {
  return showModalBottomSheet<void>(
    context: hostContext,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (BuildContext sheetContext) {
      return PontualSheet(
        title: shortcut.label,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SecondaryButton(
              label: _editorEdit,
              icon: Icons.edit_outlined,
              onPressed: () {
                Navigator.of(sheetContext).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (hostContext.mounted) {
                    showShortcutEditor(hostContext, existing: shortcut);
                  }
                });
              },
            ),
            const SizedBox(height: Space.x3),
            DangerButton(
              label: _editorRemove,
              icon: Icons.delete_outline_rounded,
              onPressed: () {
                ref.read(shortcutsProvider.notifier).remove(shortcut);
                Navigator.of(sheetContext).pop();
              },
            ),
          ],
        ),
      );
    },
  );
}

/// Body of the add-or-edit sheet.
class ShortcutEditorSheet extends ConsumerStatefulWidget {
  /// Creates the sheet. [existing] non-null means edit mode.
  const ShortcutEditorSheet({
    this.existing,
    this.initialKind = ShortcutKind.home,
    super.key,
  });

  /// Shortcut being edited, null when adding.
  final ShortcutVM? existing;

  /// Kind preselected when adding.
  final ShortcutKind initialKind;

  @override
  ConsumerState<ShortcutEditorSheet> createState() =>
      _ShortcutEditorSheetState();
}

class _ShortcutEditorSheetState extends ConsumerState<ShortcutEditorSheet> {
  late ShortcutKind _kind;
  late String? _selectedLineKey;
  late String? _initialOrigin;
  late String? _pickedOrigin;
  late final TextEditingController _labelController;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    final ShortcutVM? existing = widget.existing;
    _kind = existing?.kind ?? widget.initialKind;
    _selectedLineKey = existing?.lineKey;
    _initialOrigin = existing?.originLabel;
    _pickedOrigin = existing?.originLabel;
    _labelController = TextEditingController(
      text: existing != null && existing.kind == ShortcutKind.custom
          ? existing.label
          : '',
    );
    _searchController = TextEditingController();
    _labelController.addListener(_onLabelChanged);
  }

  void _onLabelChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _labelController.removeListener(_onLabelChanged);
    _labelController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool get _isCustom => _kind == ShortcutKind.custom;

  bool get _canSave {
    if (_selectedLineKey == null) {
      return false;
    }
    return !_isCustom || _labelController.text.trim().isNotEmpty;
  }

  List<LineVM> _filtered(List<LineVM> lines) {
    final String query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return lines;
    }
    return lines
        .where(
          (LineVM l) =>
              l.name.toLowerCase().contains(query) ||
              l.key.toLowerCase().contains(query) ||
              l.badgeText.toLowerCase().contains(query),
        )
        .toList();
  }

  void _save(List<StaticLine> statics, List<LineVM> lines) {
    if (!_canSave) {
      return;
    }
    final String label = _isCustom
        ? _labelController.text.trim()
        : shortcutKindLabel(_kind);
    final LineVM? line = _lineOf(lines, _selectedLineKey);
    final List<String> origins = line == null
        ? const <String>[]
        : _originsOf(statics, line, _nowRef());
    final ShortcutVM shortcut = ShortcutVM(
      kind: _kind,
      label: label,
      lineKey: _selectedLineKey!,
      originLabel:
          _pickedOrigin ??
          _initialOrigin ??
          (origins.isNotEmpty ? origins.first : null),
    );
    final ShortcutVM? existing = widget.existing;
    if (existing == null) {
      ref.read(shortcutsProvider.notifier).add(shortcut);
    } else {
      ref.read(shortcutsProvider.notifier).update(existing, shortcut);
    }
    Navigator.of(context).pop();
  }

  DateTime _nowRef() {
    return ref.read(currentNowProvider);
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = ref.watch(currentNowProvider);
    final List<StaticLine> statics =
        ref.watch(linesProvider).asData?.value ?? const <StaticLine>[];
    final List<LineVM> lines = _filtered(ref.watch(linesVmProvider));
    return PontualSheet(
      title: widget.existing == null ? _editorTitleAdd : _editorTitleEdit,
      scrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _kindChips(),
          if (_isCustom) ...<Widget>[
            const SizedBox(height: Space.x3),
            _customLabelField(),
          ],
          const SizedBox(height: Space.x4),
          SearchField(
            hint: _editorSearchHint,
            controller: _searchController,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.x3),
          // The list grows with its content inside the outer sheet scroll:
          // a fixed-height box clipped at large text scales, and a nested
          // scrollable fought the sheet drag for gestures.
          _lineList(lines),
          _originSection(statics, lines, now),
          const SizedBox(height: Space.x4),
          PrimaryButton(
            label: _editorSave,
            onPressed: _canSave ? () => _save(statics, lines) : null,
          ),
        ],
      ),
    );
  }

  Widget _kindChips() {
    return Wrap(
      spacing: Space.x2,
      runSpacing: Space.x2,
      children: <Widget>[
        for (final ShortcutKind kind in ShortcutKind.values)
          Chip(
            label: shortcutKindLabel(kind),
            selected: _kind == kind,
            onTap: () => setState(() => _kind = kind),
          ),
      ],
    );
  }

  Widget _customLabelField() {
    return TextField(
      controller: _labelController,
      decoration: InputDecoration(
        hintText: _editorCustomHint,
        filled: true,
        fillColor: context.colors.surfaceSunken,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.m),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _lineList(List<LineVM> lines) {
    if (lines.isEmpty) {
      return Center(child: Text(_editorNoLines, style: context.text.body));
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: lines.length,
      itemBuilder: (BuildContext context, int index) {
        final LineVM line = lines[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: Space.x2),
          child: SurfaceCard(
            selected: _selectedLineKey == line.key,
            onTap: () => setState(() {
              _selectedLineKey = line.key;
              _pickedOrigin = null;
              _initialOrigin = null;
            }),
            padding: const EdgeInsets.symmetric(
              horizontal: Space.x4,
              vertical: Space.x3,
            ),
            child: Row(
              children: <Widget>[
                LineBadge.ofLine(line, size: BadgeSize.m),
                const SizedBox(width: Space.x3),
                Expanded(
                  child: Text(
                    line.name,
                    style: context.text.headline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_selectedLineKey == line.key)
                  Icon(Icons.check_rounded, color: context.colors.primary),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _originSection(
    List<StaticLine> statics,
    List<LineVM> lines,
    DateTime now,
  ) {
    final LineVM? line = _lineOf(lines, _selectedLineKey);
    final List<String> origins = line == null
        ? const <String>[]
        : _originsOf(statics, line, now);
    if (origins.length <= 1) {
      return const SizedBox.shrink();
    }
    final String selected = _pickedOrigin ?? _initialOrigin ?? origins.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: Space.x3),
        Text(UiStrings.originLabel, style: context.text.caption),
        const SizedBox(height: Space.x2),
        Wrap(
          spacing: Space.x2,
          runSpacing: Space.x2,
          children: <Widget>[
            for (final String origin in origins)
              Chip(
                label: origin,
                selected: selected == origin,
                onTap: () => setState(() => _pickedOrigin = origin),
              ),
          ],
        ),
      ],
    );
  }

  LineVM? _lineOf(List<LineVM> lines, String? key) {
    if (key == null) {
      return null;
    }
    for (final LineVM line in lines) {
      if (line.key == key) {
        return line;
      }
    }
    return null;
  }
}
