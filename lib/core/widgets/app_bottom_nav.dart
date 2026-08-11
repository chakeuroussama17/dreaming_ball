import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

/// The app's 5-tab bottom navigation, shared by every root tab screen so the
/// order/labels/routing stay consistent.
///
/// Order: Home · Tournament · Rankings · Private · Profile
///
/// The bar is a raised slab: a top bevel line, a hard shadow cast upward onto
/// the page, and a gold medallion behind whichever tab is active.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = isDark ? AppColors.navy : AppColors.lightSurface;

    final items = <({IconData icon, IconData active, String label})>[
      (icon: Icons.home_outlined, active: Icons.home, label: l.navHome),
      (
        icon: Icons.emoji_events_outlined,
        active: Icons.emoji_events,
        label: l.navTournaments
      ),
      (
        icon: Icons.leaderboard_outlined,
        active: Icons.leaderboard,
        label: l.navLeaderboard
      ),
      (icon: Icons.lock_outline, active: Icons.lock, label: l.navPrivateRoom),
      (icon: Icons.person_outline, active: Icons.person, label: l.navProfile),
    ];

    return Container(
      decoration: BoxDecoration(
        color: barColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      // The tabs use InkWell, which needs a Material ancestor — Scaffold does
      // not provide one for bottomNavigationBar.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Gold hairline along the top edge — the bevel.
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.gold.withValues(alpha: 0.45),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: _NavTab(
                        icon: items[i].icon,
                        activeIcon: items[i].active,
                        label: items[i].label,
                        selected: i == current,
                        isDark: isDark,
                        onTap: () {
                          if (i == current) return;
                          context.goNamed(_routes[i]);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _NavTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final idle = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final activeTint = isDark ? AppColors.gold : AppColors.goldDeep;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      splashColor: AppColors.gold.withValues(alpha: 0.10),
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                // The medallion behind the active tab.
                gradient: selected ? AppColors.goldMetal : null,
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.40),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                selected ? activeIcon : icon,
                size: 21,
                color: selected ? AppColors.navyDeep : idle,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? activeTint : idle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
