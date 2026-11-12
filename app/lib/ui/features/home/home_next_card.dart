// "Sua próxima saída" hero of Início. It answers the screen's first
// question with the earliest timetable departure across the rider's
// favourites and shortcuts. Scheduled only: a live vehicle on the line is
// stated as a chip, never as a fabricated arrival. See docs/ui/UI_SPEC.md
// 3, 7.2 and 12.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/ui/adapters/lines_adapter.dart';
import 'package:pontual/ui/adapters/now_clock.dart';
import 'package:pontual/ui/design/components/buttons.dart';
import 'package:pontual/ui/design/components/certainty_badge.dart';
import 'package:pontual/ui/design/components/eta_text.dart';
import 'package:pontual/ui/design/components/ghost_link.dart';
import 'package:pontual/ui/design/components/line_badge.dart';
import 'package:pontual/ui/design/components/live_dot.dart';
import 'package:pontual/ui/design/components/surface_card.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/features/home/home_logic.dart';
import 'package:pontual/ui/features/home/home_providers.dart';
import 'package:pontual/ui/features/home/shortcut_sheet.dart';
import 'package:pontual/ui/features/lines/favorites_store_bridge.dart';
import 'package:pontual/ui/models/arrival_vm.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/models/line_vm.dart';
import 'package:pontual/ui/models/shortcut_vm.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:pontual/ui/util/format_eta.dart';

/// Hero card with the next departure across favourites and shortcuts.
class NextDepartureHero extends ConsumerWidget {
  /// Creates the hero.
  const NextDepartureHero({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Set<String> favorites = ref.watch(favoritesProvider);
    final List<ShortcutVM> shortcuts = ref.watch(shortcutsProvider);
    if (favorites.isEmpty && shortcuts.isEmpty) {
      return const SizedBox.shrink();
    }
    final List<StaticLine> statics =
        ref.watch(linesProvider).asData?.value ?? const <StaticLine>[];
    final DateTime now = ref.watch(currentNowProvider);
    final NextDepartureChoice? choice = nextDepartureChoice(
      favoriteKeys: favorites,
      shortcuts: shortcuts,
      statics: statics,
      now: now,
    );
    if (choice == null) {
      return const SizedBox.shrink();
    }
    final LineVM? line = lineByKey(ref.watch(linesVmProvider), choice.lineKey);
    if (line == null) {
      return const SizedBox.shrink();
    }
    final ArrivalVM? today = choice.today;
    final Widget card = today != null
        ? _NextDepartureCard(line: line, arrival: today, now: now)
        : _TomorrowCard(line: line, tomorrowAt: choice.tomorrowAt!);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.x4),
      child: card,
    );
  }
}

class _NextDepartureCard extends StatelessWidget {
  const _NextDepartureCard({
    required this.line,
    required this.arrival,
    required this.now,
  });

  /// Line of the departure.
  final LineVM line;

  /// Scheduled departure later today.
  final ArrivalVM arrival;

  /// Current instant for the countdown.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final EtaFormat eta = formatEta(arrival, now);
    final int liveCount = line.isLive ? line.liveVehicleCount : 0;
    final String sentence = <String>[
      UiStrings.homeNextEyebrow,
      '${line.name}.',
      eta.a11y,
      if (liveCount > 0) '${UiStrings.homeNextLineLive(liveCount)}.',
    ].join(' ');
    return Semantics(
      container: true,
      label: sentence,
      child: SurfaceCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              UiStrings.homeNextEyebrow,
              style: context.text.label.copyWith(color: context.colors.primary),
            ),
            const SizedBox(height: Space.x2),
            _LineIdentity(line: line),
            const SizedBox(height: Space.x2),
            EtaText.ofArrival(arrival, now, hero: true),
            const SizedBox(height: Space.x2),
            Wrap(
              spacing: Space.x2,
              runSpacing: Space.x1,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                CertaintyBadge(certainty: arrival.certainty),
                Text(
                  UiStrings.homeNextTimetable,
                  style: context.text.caption.copyWith(
                    color: context.colors.inkMuted,
                  ),
                ),
              ],
            ),
            if (liveCount > 0) ...<Widget>[
              const SizedBox(height: Space.x2),
              _LiveChip(count: liveCount),
            ],
            const SizedBox(height: Space.x3),
            PrimaryButton(
              label: UiStrings.homeNextOpen,
              onPressed: () => context.push('/line/${line.key}'),
            ),
            const SizedBox(height: Space.x1),
            Align(
              alignment: Alignment.center,
              child: GhostLink(
                label: UiStrings.homeNextTimetableAction,
                icon: Icons.schedule_outlined,
                onTap: () => context.push('/line/${line.key}?tab=horarios'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TomorrowCard extends StatelessWidget {
  const _TomorrowCard({required this.line, required this.tomorrowAt});

  /// Line with the first departure tomorrow.
  final LineVM line;

  /// Earliest departure tomorrow.
  final DateTime tomorrowAt;

  @override
  Widget build(BuildContext context) {
    final String hhmm = formatClock(tomorrowAt);
    final String sentence = <String>[
      UiStrings.homeNextEyebrow,
      '${line.name}.',
      UiStrings.homeNextNoMore,
      '${UiStrings.homeNextTomorrow(hhmm)}.',
    ].join(' ');
    return Semantics(
      container: true,
      label: sentence,
      child: SurfaceCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              UiStrings.homeNextEyebrow,
              style: context.text.label.copyWith(color: context.colors.primary),
            ),
            const SizedBox(height: Space.x2),
            _LineIdentity(line: line),
            const SizedBox(height: Space.x3),
            Text(UiStrings.homeNextNoMore, style: context.text.headline),
            const SizedBox(height: Space.x1),
            Text(
              UiStrings.homeNextTomorrow(hhmm),
              style: context.text.body.copyWith(color: context.colors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Line badge with the full line name, allowed to wrap instead of clip.
class _LineIdentity extends StatelessWidget {
  const _LineIdentity({required this.line});

  /// Line shown by the badge and name.
  final LineVM line;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LineBadge.ofLine(line, size: BadgeSize.m),
        const SizedBox(width: Space.x3),
        Expanded(child: Text(line.name, style: context.text.headline)),
      ],
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip({required this.count});

  /// Live vehicles on the line.
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.x3,
        vertical: Space.x2,
      ),
      decoration: BoxDecoration(
        color: context.colors.surfaceSunken,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: context.colors.line),
      ),
      child: Wrap(
        spacing: Space.x2,
        runSpacing: Space.x1,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          const LiveDot(certainty: Certainty.live),
          Text(
            UiStrings.homeNextLineLive(count),
            style: context.text.caption.copyWith(color: context.colors.ink),
          ),
        ],
      ),
    );
  }
}
