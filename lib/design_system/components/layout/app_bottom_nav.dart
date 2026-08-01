import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../tokens/app_icons.dart';

class NavDestinationSpec {
  const NavDestinationSpec({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

List<NavDestinationSpec> buildNavDestinationSpecs(AppLocalizations l10n) {
  return [
    NavDestinationSpec(
      icon: AppIcons.homeOutlined,
      selectedIcon: AppIcons.home,
      label: l10n.homeTab,
    ),
    NavDestinationSpec(
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore,
      label: l10n.discoverTab,
    ),
    NavDestinationSpec(
      icon: AppIcons.coursesOutlined,
      selectedIcon: AppIcons.courses,
      label: l10n.coursesTab,
    ),
    NavDestinationSpec(
      icon: AppIcons.todoOutlined,
      selectedIcon: AppIcons.todo,
      label: l10n.todoTab,
    ),
    NavDestinationSpec(
      icon: AppIcons.profileOutlined,
      selectedIcon: AppIcons.profile,
      label: l10n.profileTab,
    ),
  ];
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final destinations = buildNavDestinationSpecs(l10n);

    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      destinations: destinations
          .map(
            (destination) => NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: destination.label,
            ),
          )
          .toList(),
    );
  }
}
