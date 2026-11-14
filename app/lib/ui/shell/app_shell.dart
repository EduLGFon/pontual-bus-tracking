// App shell: banner slot, current branch, the active trip bar, the toast
// slot and the navigation. Below 600 dp the navigation is a bottom bar; from
// 600 dp up it becomes a rail on the side. The trip bar lives in normal
// layout so it pushes content instead of covering it. The idle "Estou no
// ônibus" CTA is inline in each branch, never a floating overlay here.
// See docs/ui/UI_SPEC.md 6.5, 6.6 and 7.1.
import 'dart:async';

import 'package:flutter/material.dart' hide Banner;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/features/trip/trip_controller.dart';
import 'package:pontual/ui/adapters/trip_adapter.dart';
import 'package:pontual/ui/design/components/banner.dart';
import 'package:pontual/ui/design/components/toast.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/shell/bottom_nav.dart';
import 'package:pontual/ui/shell/dock_host.dart';
import 'package:pontual/ui/shell/offline_bridge.dart';
import 'package:pontual/ui/shell/toast_host.dart';
import 'package:pontual/ui/shell/trip_host.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Wraps the three top-level branches.
class AppShell extends ConsumerWidget {
  /// Creates the shell around [navigationShell].
  const AppShell({required this.navigationShell, super.key});

  /// The shell owned by go_router.
  final StatefulNavigationShell navigationShell;

  /// Branches without the active trip bar. Settings (index 2) owns a
  /// sharing banner instead, so the bar would duplicate it.
  static const Set<int> _dockHiddenBranches = <int>{2};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Breakpoint breakpoint = Breakpoint.of(
      MediaQuery.sizeOf(context).width,
    );
    final bool rail = breakpoint != Breakpoint.compact;
    // Sheets open with useRootNavigator above this shell, so the overlay
    // already covers the bar. As a fallback (branch-level sheets, e.g.
    // dev gallery entries), the bar still hides while this route is not
    // current, so a sheet owns the bottom of the screen either way.
    final bool modalOpen = !(ModalRoute.of(context)?.isCurrent ?? true);
    final bool hideDock = _dockHiddenBranches.contains(
      navigationShell.currentIndex,
    );
    // The branch keeps the bottom of the content column: toast overlay plus
    // the active trip bar. The bar is a sibling of the branch, so it takes
    // real layout space and can never sit on top of a row or field.
    final Widget content = Column(
      children: <Widget>[
        Expanded(
          child: Stack(
            children: <Widget>[
              navigationShell,
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: ToastSlot(
                    controller: ref.watch(toastControllerProvider),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!modalOpen && !hideDock)
          if (rail)
            const SafeArea(top: false, child: _ActiveTripBar())
          else
            const _ActiveTripBar(),
      ],
    );
    return Scaffold(
      body: Column(
        children: <Widget>[
          BannerSlot(banner: _banner(context, ref)),
          Expanded(
            child: Row(
              children: <Widget>[
                if (rail)
                  NavRail(
                    currentIndex: navigationShell.currentIndex,
                    onSelect: (int index) => _select(ref, index),
                  ),
                Expanded(child: content),
              ],
            ),
          ),
          if (!rail)
            BottomNav(
              currentIndex: navigationShell.currentIndex,
              onSelect: (int index) => _select(ref, index),
            ),
        ],
      ),
    );
  }

  /// Selects a branch, re-tapping the active one returns to its root.
  /// Home and Linhas refresh live dots on open, throttled in the refresher.
  void _select(WidgetRef ref, int index) {
    HapticFeedback.selectionClick();
    if (index == 0 || index == 1) {
      unawaited(ref.read(liveRefresherProvider).refresh());
    }
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  Widget? _banner(BuildContext context, WidgetRef ref) {
    if (!ref.watch(offlineFlagProvider)) {
      return null;
    }
    return const Banner(
      message: UiStrings.offlineBanner,
      icon: Icons.cloud_off_rounded,
    );
  }
}

/// Active trip bar of the shell. Occupies layout space only while a trip is
/// running, so the branch content is pushed instead of covered. Hidden while
/// no trip exists or after the trip ends, even before the host detaches the
/// controller. Tapping opens the live trip through [LiveDockHost].
class _ActiveTripBar extends ConsumerWidget {
  const _ActiveTripBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TripController? controller = ref.watch(tripHostProvider);
    if (controller == null) {
      return const SizedBox.shrink();
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        if (!tripVmOf(controller).inProgress) {
          return const SizedBox.shrink();
        }
        return const Padding(
          padding: EdgeInsets.only(top: Space.x2, bottom: Space.x3),
          child: LiveDockHost(showIdle: false),
        );
      },
    );
  }
}
