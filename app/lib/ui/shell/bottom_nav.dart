// Bottom navigation. Destinations are data-driven from the enabled features
// so a future tab is an addition, not a rewrite.
// See docs/ui/UI_SPEC.md 6.6 and 7.1.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/ui/design/components/pressable.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/motion.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/design/tokens/text.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// One destination of the bottom navigation.
@immutable
class NavDestination {
  /// Creates a destination.
  const NavDestination({
    required this.path,
    required this.label,
    required this.icon,
    required this.semanticLabel,
  });

  /// Route path.
  final String path;

  /// Label in pt-BR, always visible.
  final String label;

  /// Outline icon.
  final IconData icon;

  /// Screen-reader label.
  final String semanticLabel;
}

/// Destinations of the alpha: Início, Linhas, Ajustes.
const List<NavDestination> navDestinations = <NavDestination>[
  NavDestination(
    path: '/',
    label: UiStrings.navHome,
    icon: Icons.home_outlined,
    semanticLabel: 'Início',
  ),
  NavDestination(
    path: '/lines',
    label: UiStrings.navLines,
    icon: Icons.directions_bus_outlined,
    semanticLabel: 'Linhas',
  ),
  NavDestination(
    path: '/settings',
    label: UiStrings.navSettings,
    icon: Icons.tune_rounded,
    semanticLabel: 'Ajustes',
  ),
];

/// The bottom navigation bar.
class BottomNav extends ConsumerWidget {
  /// Creates the bar.
  const BottomNav({
    required this.currentIndex,
    required this.onSelect,
    super.key,
  });

  /// Currently selected destination.
  final int currentIndex;

  /// Called with the tapped index.
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: SafeArea(
        top: false,
        // Minimum height, never fixed: at large text scales the labels
        // grow and the bar grows with them instead of clipping.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Sizes.navBar),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.x2),
            child: Row(
              children: <Widget>[
                for (int i = 0; i < navDestinations.length; i++)
                  Expanded(
                    child: _NavItem(
                      destination: navDestinations[i],
                      selected: i == currentIndex,
                      onTap: () => onSelect(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  /// Destination this item points at.
  final NavDestination destination;

  /// Whether the item is selected.
  final bool selected;

  /// Called on tap.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Pressable(
      onTap: onTap,
      semanticLabel: destination.semanticLabel,
      borderRadius: Radii.m,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          AnimatedContainer(
            duration: Motion.fast,
            padding: const EdgeInsets.symmetric(
              horizontal: Space.x3,
              vertical: Space.x1,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? colors.primary.withValues(alpha: 0.12)
                  : colors.primary.withValues(alpha: 0),
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            child: Icon(
              destination.icon,
              size: 22,
              color: selected ? colors.primary : colors.inkMuted,
            ),
          ),
          const SizedBox(height: Space.x1),
          Text(
            destination.label,
            style: PontualText.label.copyWith(
              color: selected ? colors.ink : colors.inkMuted,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Navigation rail used from the medium breakpoint up.
class NavRail extends StatelessWidget {
  /// Creates the rail.
  const NavRail({
    required this.currentIndex,
    required this.onSelect,
    super.key,
  });

  /// Currently selected destination.
  final int currentIndex;

  /// Called with the tapped index.
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 80,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: colors.line)),
      ),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            const SizedBox(height: Space.x4),
            for (int i = 0; i < navDestinations.length; i++)
              _RailItem(
                destination: navDestinations[i],
                selected: i == currentIndex,
                onTap: () => onSelect(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  /// Destination this item points at.
  final NavDestination destination;

  /// Whether the item is selected.
  final bool selected;

  /// Called on tap.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.x1),
      child: Pressable(
        onTap: onTap,
        semanticLabel: destination.semanticLabel,
        borderRadius: Radii.m,
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedContainer(
                duration: Motion.fast,
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.x4,
                  vertical: Space.x2,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? colors.primary.withValues(alpha: 0.12)
                      : colors.primary.withValues(alpha: 0),
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Icon(
                  destination.icon,
                  size: 22,
                  color: selected ? colors.primary : colors.inkMuted,
                ),
              ),
              const SizedBox(height: Space.x1),
              Text(
                destination.label,
                style: PontualText.label.copyWith(
                  color: selected ? colors.ink : colors.inkMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
