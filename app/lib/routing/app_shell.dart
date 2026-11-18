import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:campus_arena/l10n/app_localizations.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final destinations = [
      NavigationDestination(
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home),
        label: l10n.homeTab,
      ),
      NavigationDestination(
        icon: const Icon(Icons.map_outlined),
        selectedIcon: const Icon(Icons.map),
        label: l10n.mapTab,
      ),
      NavigationDestination(
        icon: const Icon(Icons.leaderboard_outlined),
        selectedIcon: const Icon(Icons.leaderboard),
        label: l10n.leaderboardsTab,
      ),
      NavigationDestination(
        icon: const Icon(Icons.person_outline),
        selectedIcon: const Icon(Icons.person),
        label: l10n.profileTab,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          // Tablet layout
          final colors = Theme.of(context).colorScheme;
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  backgroundColor: colors.surfaceContainer,
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: _onTap,
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.sports_tennis,
                        color: colors.onPrimary,
                        size: 24,
                      ),
                    ),
                  ),
                  destinations: destinations
                      .map(
                        (d) => NavigationRailDestination(
                          icon: d.icon,
                          selectedIcon: d.selectedIcon,
                          label: Text(d.label),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: navigationShell),
              ],
            ),
          );
        }
        // Phone layout. The bar goes in the Scaffold's bottomNavigationBar slot
        // (not a manual Column) so the home-indicator inset is applied once and
        // identically on every tab — a manual Column let nested screen Scaffolds
        // like the map resolve that inset differently, so the bar looked shorter
        // there.
        return Scaffold(
          body: navigationShell,
          bottomNavigationBar: NavigationBar(
            // Matches M3's default 80dp bar to ensure comfortable spacing
            // and proper padding around icons and labels.
            height: 80,
            // Match the scaffold and drop the M3 surface-tint so the bar reads as
            // part of the screen, not a lighter floating block.
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _onTap,
            destinations: destinations,
          ),
        );
      },
    );
  }
}
