// Início screen: wordmark, greeting, search entry and the dynamic sections
// (shortcuts, live now, recents, all lines) plus the first-run affordances.
// Paints from cached lines; live info fills in later without layout jump.
// See docs/ui/UI_SPEC.md 7.2.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/ui/adapters/lines_adapter.dart';
import 'package:pontual/ui/adapters/now_clock.dart';
import 'package:pontual/ui/design/components/live_dot.dart';
import 'package:pontual/ui/design/components/search_field.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/design/tokens/text.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/models/line_vm.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:pontual/ui/features/home/first_run.dart';
import 'package:pontual/ui/features/home/home_providers.dart';
import 'package:pontual/ui/features/home/home_sections.dart';
import 'package:pontual/ui/features/home/home_lists.dart';
import 'package:pontual/ui/features/home/welcome_state.dart';

/// Maximum live lines shown in the live section.
const int _liveSectionMax = 5;

/// Maximum content width on expanded windows.
const double _contentMaxWidth = 720;

/// pt-BR greeting for a São Mateus wall-clock instant.
String greetingFor(DateTime now) {
  final int hour = now.hour;
  if (hour >= 5 && hour < 12) {
    return UiStrings.greetingMorning;
  }
  if (hour >= 12 && hour < 18) {
    return UiStrings.greetingAfternoon;
  }
  return UiStrings.greetingEvening;
}

/// The Início screen.
class HomeScreen extends ConsumerWidget {
  /// Creates the screen.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<LineVM> lines = ref.watch(linesVmProvider);
    final features = ref.watch(homeFeaturesProvider);
    final onboarding = ref.watch(onboardingProvider);
    final bool liveKnown = ref.watch(liveProvider).hasValue;
    final DateTime now = ref.watch(currentNowProvider);

    int liveTotal = 0;
    for (final LineVM line in lines) {
      if (line.isLive) {
        liveTotal += line.liveVehicleCount;
      }
    }
    final List<LineVM> liveLines = lines.where((LineVM l) => l.isLive).toList()
      ..sort(
        (LineVM a, LineVM b) =>
            b.liveVehicleCount.compareTo(a.liveVehicleCount),
      );
    final List<LineVM> liveCapped = liveLines.take(_liveSectionMax).toList();

    final double margin = marginFor(context);
    final Breakpoint breakpoint = Breakpoint.of(
      MediaQuery.sizeOf(context).width,
    );
    final bool expanded = breakpoint == Breakpoint.expanded;

    final Widget welcome = onboarding.welcomeSeen
        ? const SizedBox.shrink()
        : WelcomeCard(
            onDismiss: () =>
                ref.read(onboardingProvider.notifier).dismissWelcome(),
          );
    final Widget header = _HomeHeader(
      greeting: greetingFor(now),
      liveTotal: liveTotal,
      liveKnown: liveKnown,
    );
    final Widget shortcutsSection = features.shortcuts
        ? const ShortcutsSection()
        : const SizedBox.shrink();
    final Widget saindoAgora = features.shortcuts
        ? const SaindoAgoraSection()
        : const SizedBox.shrink();
    final Widget liveOrEmpty = liveCapped.isNotEmpty
        ? LiveNowSection(lines: liveCapped)
        : const NoLiveCard();
    final Widget recentsSection = features.recents
        ? RecentsSection(lines: lines)
        : const SizedBox.shrink();
    const Widget allLines = AllLinesRow();

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        welcome,
        header,
        if (expanded)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    shortcutsSection,
                    saindoAgora,
                    liveOrEmpty,
                  ],
                ),
              ),
              const SizedBox(width: Space.x6),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[recentsSection, allLines],
                ),
              ),
            ],
          )
        else
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              shortcutsSection,
              saindoAgora,
              liveOrEmpty,
              recentsSection,
              allLines,
            ],
          ),
        const SizedBox(height: Space.x8),
      ],
    );

    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  margin,
                  Space.x3,
                  margin,
                  dockClearance,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _contentMaxWidth,
                    ),
                    child: content,
                  ),
                ),
              ),
            ),
            if (!onboarding.coachmarkSeen)
              Positioned(
                left: margin,
                right: margin,
                bottom: Space.x8,
                child: CoachmarkBubble(
                  onDismiss: () =>
                      ref.read(onboardingProvider.notifier).dismissCoachmark(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Wordmark, greeting, subtitle, live summary chip and search entry.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.greeting,
    required this.liveTotal,
    required this.liveKnown,
  });

  /// pt-BR greeting.
  final String greeting;

  /// Total vehicles sharing, for the summary chip.
  final int liveTotal;

  /// False while the live count is still unknown.
  final bool liveKnown;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Text(
                UiStrings.wordmark,
                style: context.text.title.copyWith(color: colors.primary),
              ),
            ),
            _LiveSummaryChip(shown: liveKnown, total: liveTotal),
          ],
        ),
        const SizedBox(height: Space.x4),
        Text(greeting, style: context.text.display),
        const SizedBox(height: Space.x1),
        Text(
          UiStrings.homeSubtitle,
          style: context.text.body.copyWith(color: colors.inkMuted),
        ),
        const SizedBox(height: Space.x4),
        SearchEntry(
          hint: UiStrings.searchHint,
          onTap: () => context.push('/search'),
        ),
      ],
    );
  }
}

/// Live count chip that reserves its height even while the count is unknown.
class _LiveSummaryChip extends StatelessWidget {
  const _LiveSummaryChip({required this.shown, required this.total});

  /// False hides the chip but keeps its height reserved.
  final bool shown;

  /// Vehicles sharing right now.
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: Sizes.badgeL,
      child: Center(
        child: shown
            ? Semantics(
                label: '$total ${UiStrings.liveCount}',
                excludeSemantics: true,
                child: Container(
                  height: 30,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: Space.x3),
                  decoration: BoxDecoration(
                    color: colors.surfaceSunken,
                    borderRadius: BorderRadius.circular(Radii.pill),
                    border: Border.all(color: colors.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const LiveDot(certainty: Certainty.live),
                      const SizedBox(width: Space.x2),
                      Text(
                        '$total ${UiStrings.liveCount}',
                        style: PontualText.label.copyWith(color: colors.ink),
                      ),
                    ],
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
