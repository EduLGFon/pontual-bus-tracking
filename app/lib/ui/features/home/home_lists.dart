// Remaining Início sections: the live-now list, the recents chips, the
// no-live empty card and the all-lines link row. Pure presentation.
// See docs/ui/UI_SPEC.md 7.2.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pontual/ui/design/components/line_badge.dart';
import 'package:pontual/ui/design/components/line_row.dart';
import 'package:pontual/ui/design/components/pressable.dart';
import 'package:pontual/ui/design/components/section_header.dart';
import 'package:pontual/ui/design/components/surface_card.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/models/line_status.dart';
import 'package:pontual/ui/models/line_vm.dart';
import 'package:pontual/ui/shell/toast_host.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:pontual/ui/features/home/home_providers.dart';

/// Maximum recent lines shown on Início. The store keeps more.
const int _recentsShownMax = 4;

/// Characters of a line name shown on a recent chip.
const int _recentNameMax = 14;

/// Lines that have live vehicles, most vehicles first.
class LiveNowSection extends StatelessWidget {
  /// Creates the section from the live lines to show.
  const LiveNowSection({required this.lines, super.key});

  /// Live lines, already sorted and capped by the caller.
  final List<LineVM> lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: UiStrings.homeLiveNow,
          actionLabel: UiStrings.homeLiveAll,
          // The Linhas tab owns its branch: go switches the bottom bar to
          // it, while push would stack it over Início and leave Início
          // highlighted.
          onAction: () => context.go('/lines?filter=live'),
        ),
        for (final LineVM line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.x2),
            child: LineRow(
              line: line,
              status: const LineStatus.live(),
              onTap: () => context.push('/line/${line.key}'),
            ),
          ),
        const SizedBox(height: Space.x2),
      ],
    );
  }
}

/// Recently opened lines as chips. Renders nothing when the list is empty.
class RecentsSection extends ConsumerWidget {
  /// Creates the recents section.
  const RecentsSection({required this.lines, super.key});

  /// All lines, used to resolve recent keys.
  final List<LineVM> lines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<String> keys = ref.watch(homeRecentsProvider);
    final List<LineVM> items = <LineVM>[];
    for (final String key in keys.take(_recentsShownMax)) {
      final LineVM? line = lineByKey(lines, key);
      if (line != null) {
        items.add(line);
      }
    }
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: UiStrings.homeRecents,
          actionLabel: UiStrings.homeRecentsClear,
          // Single tap clears with an undo toast instead of a confirm
          // dialog. The toast action restores the previous list.
          onAction: () {
            final List<String> previous = ref.read(homeRecentsProvider);
            ref.read(homeRecentsProvider.notifier).clear();
            ref
                .read(toastControllerProvider.notifier)
                .show(
                  UiStrings.homeRecentsCleared,
                  actionLabel: UiStrings.undo,
                  onAction: () =>
                      ref.read(homeRecentsProvider.notifier).restore(previous),
                );
          },
        ),
        Wrap(
          spacing: Space.x2,
          runSpacing: Space.x2,
          children: <Widget>[
            for (final LineVM line in items)
              _RecentLineChip(
                line: line,
                onTap: () => context.push('/line/${line.key}'),
              ),
          ],
        ),
        const SizedBox(height: Space.x4),
      ],
    );
  }
}

class _RecentLineChip extends StatelessWidget {
  const _RecentLineChip({required this.line, required this.onTap});

  /// Line the chip opens.
  final LineVM line;

  /// Called on tap.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String shown = line.name.length <= _recentNameMax
        ? line.name
        : line.name.substring(0, _recentNameMax);
    return Pressable(
      onTap: onTap,
      semanticLabel: 'Abrir linha ${line.name}',
      borderRadius: Radii.pill,
      child: Container(
        height: Sizes.chip,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: Space.x3),
        decoration: BoxDecoration(
          color: context.colors.surfaceSunken,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            LineBadge.ofLine(line, size: BadgeSize.s),
            const SizedBox(width: Space.x2),
            Text(shown, style: context.text.label),
          ],
        ),
      ),
    );
  }
}

/// Compact card shown when no line is sharing a live position. No
/// timetable link: the `Todas as linhas` row below already covers that.
class NoLiveCard extends StatelessWidget {
  /// Creates the no-live empty card.
  const NoLiveCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(UiStrings.homeNoLive, style: context.text.headline),
          const SizedBox(height: Space.x1),
          Text(
            UiStrings.homeNoLiveHint,
            style: context.text.body.copyWith(color: context.colors.inkMuted),
          ),
          const SizedBox(height: Space.x2),
          Row(
            children: <Widget>[
              Icon(
                Icons.privacy_tip_outlined,
                size: 16,
                color: context.colors.inkMuted,
              ),
              const SizedBox(width: Space.x2),
              Expanded(
                child: Text(UiStrings.homeTrust, style: context.text.caption),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Link row to the full lines list.
class AllLinesRow extends StatelessWidget {
  /// Creates the all-lines link row.
  const AllLinesRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Space.x2, bottom: Space.x2),
      child: SurfaceCard(
        // Branch switch, not a push: Início and Linhas are sibling tabs.
        onTap: () => context.go('/lines'),
        semanticLabel: '${UiStrings.homeAllLines}. ${UiStrings.homeAllLinesGo}',
        child: Row(
          children: <Widget>[
            Icon(Icons.directions_bus_rounded, color: context.colors.primary),
            const SizedBox(width: Space.x3),
            Expanded(
              child: Text(UiStrings.homeAllLines, style: context.text.headline),
            ),
            const SizedBox(width: Space.x2),
            Text(
              UiStrings.homeAllLinesGo,
              style: context.text.label.copyWith(color: context.colors.primary),
            ),
            Icon(Icons.chevron_right_rounded, color: context.colors.primary),
          ],
        ),
      ),
    );
  }
}
