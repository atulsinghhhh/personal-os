import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../luma/widgets/luma_tab_bar.dart';

/// The 5-tab bottom navigation shell (Today/Plan/Future/Money/Review),
/// drawn with the Luma tab bar. Each tab keeps its own navigation stack via
/// [StatefulShellRoute.indexedStack] — switching tabs never rebuilds the
/// others from scratch.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: LumaTabBar(
        currentIndex: navigationShell.currentIndex,
        onSelect: (int index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
