// App shell: banner slot, current branch, the trip dock and the navigation.
// Below 600 dp the navigation is a bottom bar above the dock; from 600 dp
// up it becomes a rail on the side. See docs/ui/UI_SPEC.md 6.5 and 7.1.
import 'package:flutter/material.dart' hide Banner;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pontual/ui/design/components/banner.dart';
import 'package:pontual/ui/design/components/toast.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/shell/bottom_nav.dart';
import 'package:pontual/ui/shell/dock_host.dart';
import 'package:pontual/ui/shell/offline_bridge.dart';
import 'package:pontual/ui/shell/toast_host.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Wraps the three top-level branches.
class AppShell extends ConsumerWidget {
  /// Creates the shell around [navigationShell].
  const AppShell({required this.navigationShell, super.key});

  /// The shell owned by go_router.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Breakpoint breakpoint = Breakpoint.of(
      MediaQuery.sizeOf(context).width,
    );
    final bool rail = breakpoint != Breakpoint.compact;
    return Scaffold(
      body: Column(
        children: <Widget>[
          BannerSlot(banner: _banner(context, ref)),
          Expanded(
            child: Stack(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    if (rail)
                      NavRail(
                        currentIndex: navigationShell.currentIndex,
                        onSelect: _select,
                      ),
                    Expanded(child: navigationShell),
                  ],
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        ToastSlot(
                          controller: ref.watch(toastControllerProvider),
                        ),
                        // The idle pill is the global trip entry point, so
                        // it stays mounted even with no trip running.
                        const Padding(
                          padding: EdgeInsets.only(bottom: Space.x3),
                          child: LiveDockHost(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!rail)
            BottomNav(
              currentIndex: navigationShell.currentIndex,
              onSelect: _select,
            ),
        ],
      ),
    );
  }

  /// Selects a branch, re-tapping the active one returns to its root.
  void _select(int index) {
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
