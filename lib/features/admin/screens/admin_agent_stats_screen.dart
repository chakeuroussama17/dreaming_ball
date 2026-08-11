import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/providers/admin_providers.dart';
import '../../../../core/services/admin_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/nav.dart';

/// Admin view of agent performance — games, players, money collected and
/// commission, ranked by commission so the best earners surface first.
class AdminAgentStatsScreen extends ConsumerWidget {
  const AdminAgentStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final primary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    final async = ref.watch(agentLeaderboardProvider);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: primary),
          onPressed: () => context.safePop('admin-dashboard'),
        ),
        title: Text('Agent Performance',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 18, fontWeight: FontWeight.w700, color: primary)),
        centerTitle: true,
      ),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.gold)),
        error: (_, _) => Center(
          child: Text('Could not load agent stats',
              style: GoogleFonts.inter(fontSize: 14, color: secondary)),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return Center(
              child: Text('No agent activity yet',
                  style: GoogleFonts.inter(fontSize: 14, color: secondary)),
            );
          }
          final totalCollected =
              rows.fold<double>(0, (s, r) => s + r.collected);
          final totalCommission =
              rows.fold<double>(0, (s, r) => s + r.commission);
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(agentLeaderboardProvider.future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                // Platform totals
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      AppColors.goldDeep.withValues(alpha: 0.10),
                      AppColors.gold.withValues(alpha: 0.10),
                    ]),
                    border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.25)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                          child: _totalCell('Total collected',
                              'RM ${totalCollected.toStringAsFixed(0)}',
                              primary, secondary)),
                      Container(width: 1, height: 36, color: border),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _totalCell('Agent commission',
                              'RM ${totalCommission.toStringAsFixed(0)}',
                              primary, secondary)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < rows.length; i++)
                  _agentCard(rows[i], i + 1, primary, secondary, border,
                      surface),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _totalCell(
      String label, String value, Color primary, Color secondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: GoogleFonts.spaceGrotesk(
                fontSize: 22, fontWeight: FontWeight.w800, color: primary)),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: secondary)),
      ],
    );
  }

  Widget _agentCard(AgentLeaderRow r, int rank, Color primary, Color secondary,
      Color border, Color surface) {
    // Top 3 get a colored rank badge.
    final rankColor = switch (rank) {
      1 => const Color(0xFFFFD700),
      2 => const Color(0xFFC0C0C0),
      3 => const Color(0xFFCD7F32),
      _ => secondary,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 28,
                child: Text('#$rank',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: rankColor)),
              ),
              Expanded(
                child: Text(r.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: primary)),
              ),
              Text('RM ${r.commission.toStringAsFixed(0)}',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.gold)),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text('commission earned',
                style: GoogleFonts.inter(fontSize: 11, color: secondary)),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Row(
              children: [
                _stat('${r.gamesCreated}', 'games', primary, secondary),
                const SizedBox(width: 24),
                _stat('${r.playersConfirmed}', 'players', primary, secondary),
                const SizedBox(width: 24),
                _stat('RM ${r.collected.toStringAsFixed(0)}', 'collected',
                    primary, secondary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, Color primary, Color secondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: GoogleFonts.spaceGrotesk(
                fontSize: 15, fontWeight: FontWeight.w700, color: primary)),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: secondary)),
      ],
    );
  }
}
