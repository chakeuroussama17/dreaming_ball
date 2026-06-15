import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/providers/admin_providers.dart';
import '../../../../core/providers/games_provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final primary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    final users = ref.watch(adminUsersProvider);
    final agents = ref.watch(adminAgentsProvider);
    final disputes = ref.watch(adminDisputesProvider);
    final games = ref.watch(gamesProvider);
    // valueOrNull (not .value) so a missing payout function / load error
    // leaves the dashboard empty instead of crashing it.
    final payouts = ref.watch(adminPayoutsProvider).valueOrNull ?? const [];

    final totalPlayers = users.where((u) => u.role == 'Player').length;
    final totalAgents = users.where((u) => u.role == 'Agent').length;
    final pendingAgents =
        agents.where((a) => a.status == AdminAgentStatus.pending).length;
    final openDisputes =
        disputes.where((d) => d.status == AdminDisputeStatus.open).length;
    // Real platform earnings = your cut on games already paid out.
    final revenue = payouts
        .where((p) => p.paidOut)
        .fold<double>(0, (s, p) => s + p.currentCut);
    // Amount you still owe agents (everyone paid, not yet sent).
    final owed = payouts
        .where((p) => p.allPaid && !p.paidOut)
        .fold<double>(0, (s, p) => s + p.agentPayout);
    final payoutsDue =
        payouts.where((p) => p.allPaid && !p.paidOut).length;

    final stats = [
      ('Total Players', '$totalPlayers', Icons.groups_outlined),
      ('Total Agents', '$totalAgents', Icons.shield_outlined),
      ('Games This Week', '${games.length}', Icons.sports_soccer),
      ('Platform Revenue', 'RM ${revenue.toStringAsFixed(0)}', Icons.payments_outlined),
    ];

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            // Top bar
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Admin Panel',
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: primary)),
                      Text('Dreaming Ball',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: secondary)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.logout, color: primary),
                  onPressed: () async {
                    // Clear the real Supabase session too, not just the flag.
                    await AuthService.signOut();
                    if (!context.mounted) return;
                    ref.read(isAdminProvider.notifier).state = false;
                    context.goNamed('login');
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Stats grid 2x2
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: stats
                  .map((s) => Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surface,
                          border: Border.all(color: border),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(s.$3, size: 20, color: AppColors.orange),
                            Text(s.$2,
                                style: GoogleFonts.spaceGrotesk(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: primary)),
                            Text(s.$1,
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: secondary)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),

            _navCard(context, primary, secondary, border, surface,
                icon: Icons.payments_outlined,
                title: 'Payouts',
                subtitle: payoutsDue == 0
                    ? 'No agents waiting for payment'
                    : 'RM ${owed.toStringAsFixed(0)} to send · $payoutsDue game${payoutsDue == 1 ? '' : 's'}',
                badge: payoutsDue,
                route: 'admin-payouts'),
            _navCard(context, primary, secondary, border, surface,
                icon: Icons.verified_user_outlined,
                title: 'Agent Verification',
                subtitle: pendingAgents == 0
                    ? 'No agents pending approval'
                    : '$pendingAgents agent${pendingAgents == 1 ? '' : 's'} pending approval',
                badge: pendingAgents,
                route: 'admin-agents'),
            _navCard(context, primary, secondary, border, surface,
                icon: Icons.campaign_outlined,
                title: 'Announcements',
                subtitle: 'Manage home screen banners',
                route: 'admin-announcements'),
            _navCard(context, primary, secondary, border, surface,
                icon: Icons.people_outline,
                title: 'All Users',
                subtitle: 'Browse and manage users',
                route: 'admin-users'),
            _navCard(context, primary, secondary, border, surface,
                icon: Icons.gavel_outlined,
                title: 'Disputes',
                subtitle: openDisputes == 0
                    ? 'No open disputes'
                    : '$openDisputes open dispute${openDisputes == 1 ? '' : 's'}',
                badge: openDisputes,
                route: 'admin-disputes'),
          ],
        ).animate().fadeIn(duration: 350.ms),
      ),
    );
  }

  Widget _navCard(
    BuildContext context,
    Color primary,
    Color secondary,
    Color border,
    Color surface, {
    required IconData icon,
    required String title,
    required String subtitle,
    int badge = 0,
    required String route,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => context.goNamed(route),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.orange, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: primary)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: secondary)),
                  ],
                ),
              ),
              if (badge > 0)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [AppColors.pink, AppColors.orange]),
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.all(Radius.circular(99)),
                  ),
                  child: Text('$badge',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              Icon(Icons.chevron_right, color: secondary),
            ],
          ),
        ),
      ),
    );
  }
}
