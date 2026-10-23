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
import 'package:pontual/ui/shell/offline_bridge.dart';
import 'package:pontual/platform/web/android_app_download.dart';

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
    final bool offline = ref.watch(offlineFlagProvider);
    // Select the greeting instead of watching the minute clock: this
    // screen then rebuilds when the greeting changes (three times a day),
    // not on every clock tick. Sections with countdowns still watch the
    // clock directly.
    final String greeting = ref.watch(currentNowProvider.select(greetingFor));

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
      greeting: greeting,
      liveTotal: liveTotal,
      liveKnown: liveKnown,
      offline: offline,
    );
    final Widget shortcutsSection = features.shortcuts
        ? const ShortcutsSection()
        : const SizedBox.shrink();
    final Widget saindoAgora = features.shortcuts
        ? const SaindoAgoraSection()
        : const SizedBox.shrink();
    final Widget liveOrEmpty = liveCapped.isNotEmpty
        ? LiveNowSection(lines: liveCapped)
        // The empty card carries no header of its own, so it reserves its
        // own top spacing: otherwise it sits almost glued to the shortcut
        // strip on first run, when only the placeholder cards exist. D-U26.
        : const Padding(
            padding: EdgeInsets.only(top: Space.x4),
            child: NoLiveCard(),
          );
    final Widget recentsSection = features.recents
        ? RecentsSection(lines: lines)
        : const SizedBox.shrink();
    const Widget allLines = AllLinesRow();

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        welcome,
        if (!onboarding.welcomeSeen) const SizedBox(height: Space.x4),
        const AndroidAppDownloadSlot(),
        header,
        const SizedBox(height: Space.x2),
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
              child: RefreshIndicator(
                // PLAN.md 9.5 S03: pull-to-refresh is one of the three
                // triggers for /v1/live; the refresher keeps a 10 s floor.
                onRefresh: () => ref.read(liveRefresherProvider).refresh(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
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
    required this.offline,
  });

  /// pt-BR greeting.
  final String greeting;

  /// Total vehicles sharing, for the summary chip.
  final int liveTotal;

  /// False while the live count is still unknown.
  final bool liveKnown;

  /// True while the app is offline.
  final bool offline;

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
            _LiveSummaryChip(
              shown: liveKnown,
              total: liveTotal,
              offline: offline,
            ),
          ],
        ),
        const SizedBox(height: Space.x3),
        Text(greeting, style: context.text.display),
        const SizedBox(height: Space.x1),
        Text(
          UiStrings.homeSubtitle,
          style: context.text.body.copyWith(color: colors.inkMuted),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: Space.x3),
        SearchEntry(
          hint: UiStrings.searchHint,
          onTap: () => context.push('/search'),
        ),
      ],
    );
  }
}

/// Live count chip that reserves its height even while the count is unknown.
///
/// Honest states: zero buses show a neutral dot with `Nenhum ao vivo`
/// (no green reads as live while nothing is live); one or more show the
/// green dot with `N ao vivo`; offline shows `Offline`.
class _LiveSummaryChip extends StatelessWidget {
  const _LiveSummaryChip({
    required this.shown,
    required this.total,
    required this.offline,
  });

  /// False hides the chip but keeps its height reserved.
  final bool shown;

  /// Vehicles sharing right now.
  final int total;

  /// True while the app is offline.
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Certainty certainty = offline || total <= 0
        ? (offline ? Certainty.stale : Certainty.scheduled)
        : Certainty.live;
    final String text = offline
        ? UiStrings.homeOffline
        : (total <= 0
              ? UiStrings.homeLiveNone
              : '$total ${UiStrings.liveCount}');
    return SizedBox(
      height: Sizes.badgeL,
      child: Center(
        child: shown
            ? Semantics(
                label: text,
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
                      LiveDot(certainty: certainty),
                      const SizedBox(width: Space.x2),
                      Text(
                        text,
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
