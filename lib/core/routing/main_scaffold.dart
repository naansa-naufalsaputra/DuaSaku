import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

import '../widgets/glass/glass_navigation_bar.dart';

class MainScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffold({
    super.key,
    required this.navigationShell,
  });

  void _onItemTapped(int index) {
    // Memberikan haptic feedback setiap pindah tab sesuai instruksi Plan
    HapticFeedback.lightImpact();
    
    // Berpindah stateful branch
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: GlassNavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onItemTapped,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: 'tabs.home'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long),
            label: 'tabs.history'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.auto_graph_outlined),
            selectedIcon: const Icon(Icons.auto_graph),
            label: 'tabs.insights'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: 'tabs.profile'.tr(),
          ),
        ],
      ),
    );
  }
}
