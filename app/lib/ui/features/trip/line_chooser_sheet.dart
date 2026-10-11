// Line chooser sheet of the trip flow: sharing-capable lines, live ones
// first, filtered through the shared search index. The rider picks a line
// only when the dock did not bind one; picking one returns it to the flow.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/ui/adapters/lines_adapter.dart';
import 'package:pontual/ui/design/components/empty_state.dart';
import 'package:pontual/ui/design/components/line_row.dart';
import 'package:pontual/ui/design/components/pontual_sheet.dart';
import 'package:pontual/ui/design/components/search_field.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/models/line_vm.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:pontual/ui/util/search_index.dart';

/// Chooser sheet body: search field plus the sharing-capable lines.
class LineChooserSheet extends StatefulWidget {
  /// Creates the chooser.
  const LineChooserSheet({super.key});

  @override
  State<LineChooserSheet> createState() => _LineChooserSheetState();
}

class _LineChooserSheetState extends State<LineChooserSheet> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PontualSheet(
      title: UiStrings.chooseLineTitle,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SearchField(
              hint: UiStrings.searchHint,
              controller: _query,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Space.x3),
            Expanded(
              child: Consumer(
                builder: (BuildContext context, WidgetRef ref, _) {
                  final List<LineVM> lines = ref
                      .watch(linesVmProvider)
                      .where((LineVM line) => line.supportsSharing)
                      .toList();
                  if (lines.isEmpty) {
                    return Center(
                      child: Text(
                        UiStrings.lineNoTracking,
                        style: context.text.body,
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return _ChooserLines(
                    index: buildLineIndex(lines),
                    query: _query.text,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ranked list of the chooser. Live lines come first, ranked by the shared
/// search index, so the rider finds a line in a few keystrokes.
class _ChooserLines extends StatelessWidget {
  /// Creates the list of [index] entries filtered by [query].
  const _ChooserLines({required this.index, required this.query});

  /// Search index of the sharing-capable lines.
  final List<LineIndex> index;

  /// Current query, empty shows everything.
  final String query;

  @override
  Widget build(BuildContext context) {
    final List<LineVM> lines = query.isEmpty
        ? index.map((LineIndex entry) => entry.line).toList()
        : searchLines(index, query).map((LineMatch hit) => hit.line).toList();
    if (lines.isEmpty) {
      return const EmptyState(
        title: UiStrings.searchEmptyTitle,
        message: UiStrings.searchEmptyTip,
        art: EmptyArt.search,
      );
    }
    return ListView.builder(
      key: const ValueKey<String>('chooser-lines'),
      itemCount: lines.length,
      itemBuilder: (BuildContext context, int i) {
        final LineVM line = lines[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: Space.x2),
          child: LineRow(
            line: line,
            semanticLabel: UiStrings.openLine,
            onTap: () => Navigator.of(context).pop(line),
          ),
        );
      },
    );
  }
}
