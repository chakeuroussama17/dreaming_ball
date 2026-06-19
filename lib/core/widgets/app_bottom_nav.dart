import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';

/// The app's 5-tab bottom navigation, shared by every root tab screen so the
/// order/labels/routing stay consistent.
///
/// Order: Home · Tournament · Rankings · Private · Profile
class AppBottomNav extends StatelessWidget {
  final int current;
  const AppBottomNav({super.key, required this.current});

  static const _routes = [
    'home',
    'tournaments',
    'leaderboard',
    'private-room',
    'profile',
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BottomNavigationBar(
      currentIndex: current,
      type: BottomNavigationBarType.fixed,
      selectedFontSize: 11,
      unselectedFontSize: 11,
      onTap: (i) {
        if (i == current) return;
        context.goNamed(_routes[i]);
      },
      items: [
        BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: l.navHome),
        BottomNavigationBarItem(
            icon: const Icon(Icons.emoji_events_outlined),
            activeIcon: const Icon(Icons.emoji_events),
            label: l.navTournaments),
        BottomNavigationBarItem(
            icon: const Icon(Icons.leaderboard_outlined),
            activeIcon: const Icon(Icons.leaderboard),
            label: l.navLeaderboard),
        BottomNavigationBarItem(
            icon: const Icon(Icons.lock_outline),
            activeIcon: const Icon(Icons.lock),
            label: l.navPrivateRoom),
        BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: l.navProfile),
      ],
    );
  }
}
