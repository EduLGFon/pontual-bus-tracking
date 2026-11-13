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
import 'package:pontual/ui/features/home/choose_lines_sheet.dart';
import 'package:pontual/ui/features/home/first_run.dart';
import 'package:pontual/ui/features/home/home_next_card.dart';
import 'package:pontual/ui/features/home/home_providers.dart';
import 'package:pontual/ui/features/home/home_sections.dart';
import 'package:pontual/ui/features/home/home_lists.dart';
import 'package:pontual/ui/features/home/welcome_state.dart';
import 'package:pontual/ui/features/lines/favorites_store_bridge.dart';
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
    final Set<String> favorites = ref.watch(favoritesProvider);
    final bool liveKnown = ref.watch(liveProvider).hasValue;
    final bool offline = ref.watch(offlineFlagProvider);
    // Select the greeting instead of watching the minute clock: this
    // screen then rebuilds when the greeting changes (three times a day),
    // not on every clock tick. Sections with countdowns still watch the
    // clock directly.
    final String greeting = ref.watch(currentNowProvider.select(greetingFor));

    final int liveTotal = ref.watch(homeLiveTotalProvider);
    final List<LineVM> liveLines = ref.watch(homeLiveLinesProvider);
    final List<LineVM> liveCapped = liveLines.take(_liveSectionMax).toList();

    final double margin = marginFor(context);
    final Breakpoint breakpoint = Breakpoint.of(
      MediaQuery.sizeOf(context).width,
    );
    final bool expanded = breakpoint == Breakpoint.expanded;

    // A rider who already has favourites does not need the setup card,
    // even when the welcome flag never got written (reinstall, restore).
    final bool showWelcome = !onboarding.welcomeSeen && favorites.isEmpty;
    final Widget welcome = showWelcome
        ? WelcomeCard(
            onChoose: () => showChooseLines(context),
            onDismiss: () =>
                ref.read(onboardingProvider.notifier).dismissWelcome(),
          )
        : const SizedBox.shrink();
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
            child: ShareCard(),
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
        if (showWelcome) const SizedBox(height: Space.x4),
        const AndroidAppDownloadSlot(),
        header,
        const SizedBox(height: Space.x2),
        const NextDepartureHero(),
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
        child: RefreshIndicator(
          // ARCHITECTURE.md 9.5 S03: pull-to-refresh is one of the three triggers for
          // /v1/live; the refresher keeps a 10 s floor.
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
                constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
                child: content,
              ),
            ),
          ),
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
        // Wrap instead of Row: at 320 dp with 2x text the chip moves to its
        // own line instead of squeezing the wordmark. D-U26.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Space.x2,
          runSpacing: Space.x1,
          children: <Widget>[
            Text(
              UiStrings.wordmark,
              style: context.text.title.copyWith(color: colors.primary),
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
    // Minimum height only: the chip reserves a stable slot while the live
    // count is unknown, then grows with 2x text instead of clipping it.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: Sizes.badgeL),
      child: shown
          // widthFactor keeps the chip hugging its content: inside a Wrap the
          // constraints are bounded, so a plain Center would stretch it across
          // the whole header row.
          ? Center(
              widthFactor: 1,
              child: Semantics(
                label: text,
                excludeSemantics: true,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 30),
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.x3,
                    vertical: Space.x1,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceSunken,
                    borderRadius: BorderRadius.circular(Radii.pill),
                    border: Border.all(color: colors.line),
                  ),
                  child: Center(
                    widthFactor: 1,
                    child: Wrap(
                      spacing: Space.x2,
                      runSpacing: Space.x1,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        // LiveDot centers its painted ring and that Center
                        // expands when the Wrap hands it a bounded width,
                        // which would stretch the pill, so pin the dot to
                        // the ring footprint it already paints inside.
                        SizedBox.square(
                          dimension: 24,
                          child: LiveDot(certainty: certainty),
                        ),
                        Text(
                          text,
                          style: PontualText.label.copyWith(color: colors.ink),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
