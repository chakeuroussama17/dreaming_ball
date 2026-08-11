import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/tournament_providers.dart';
import '../../../core/services/tournament_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/player_avatar.dart';
import '../widgets/status_chip.dart';

class TournamentListScreen extends ConsumerStatefulWidget {
  const TournamentListScreen({super.key});

  @override
  ConsumerState<TournamentListScreen> createState() =>
      _TournamentListScreenState();
}

class _TournamentListScreenState extends ConsumerState<TournamentListScreen> {
  int _tab = 0; // 0 live, 1 upcoming, 2 completed

  static const _upcoming = {
    'pending_approval',
    'approved',
    'building_teams',
    'bracket_generated',
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final primary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    final isAgent = ref.watch(userRoleProvider) == UserRole.agent;
    final async = ref.watch(tournamentsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.goNamed('home');
      },
      child: Scaffold(
        backgroundColor: bg,
        bottomNavigationBar: const AppBottomNav(current: 1),
        body: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                child: Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (b) =>
                          AppColors.brandGradient.createShader(b),
                      child: Text('Tournaments',
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ),
                    const Spacer(),
                    if (isAgent)
                      IconButton(
                        onPressed: () => context.pushNamed('tournament-apply'),
                        icon: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                                colors: [AppColors.goldActionStart, AppColors.goldActionEnd]),
                          ),
                          child: const Icon(Icons.add,
                              color: Colors.white, size: 20),
                        ),
                      ),
                  ],
                ),
              ),
              // Tabs
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: surface,
                    border: Border.all(color: border),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      _tabBtn('Live Now', 0, secondary),
                      _tabBtn('Upcoming', 1, secondary),
                      _tabBtn('Completed', 2, secondary),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: async.when(
                  loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.gold)),
                  error: (_, _) => Center(
                    child: Text('Could not load tournaments',
                        style:
                            GoogleFonts.inter(fontSize: 14, color: secondary)),
                  ),
                  data: (all) {
                    final list = all.where((t) {
                      if (_tab == 0) return t.status == 'in_progress';
                      if (_tab == 2) return t.status == 'completed';
                      // Upcoming: open states, plus the owner's own pending/rejected.
                      return _upcoming.contains(t.status) ||
                          (t.mine &&
                              (t.status == 'rejected' ||
                                  t.status == 'pending_approval'));
                    }).toList();
                    if (list.isEmpty) {
                      return _empty(secondary);
                    }
                    return RefreshIndicator(
                      color: AppColors.gold,
                      onRefresh: () async =>
                          ref.refresh(tournamentsProvider.future),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (ctx, i) => _card(
                            list[i], primary, secondary, border, surface),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabBtn(String label, int index, Color secondary) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: active ? AppColors.brandGradient : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : secondary)),
        ),
      ),
    );
  }

  Widget _empty(Color secondary) => ListView(
        children: [
          const SizedBox(height: 90),
          Icon(Icons.emoji_events_outlined,
              size: 56, color: secondary.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Center(
            child: Text('No tournaments here yet',
                style: GoogleFonts.inter(fontSize: 14, color: secondary)),
          ),
        ],
      );

  Widget _card(Tournament t, Color primary, Color secondary, Color border,
      Color surface) {
    return GestureDetector(
      onTap: () async {
        await context.pushNamed('tournament-detail',
            pathParameters: {'id': t.id});
        if (mounted) ref.invalidate(tournamentsProvider);
      },
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(18),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner
            SizedBox(
              height: 130,
              width: double.infinity,
              child: t.bannerImageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: t.bannerImageUrl!, fit: BoxFit.cover)
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          AppColors.goldDeep.withValues(alpha: 0.25),
                          AppColors.gold.withValues(alpha: 0.25),
                        ]),
                      ),
                      child: const Center(
                        child: Icon(Icons.emoji_events,
                            size: 44, color: Colors.white70),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(t.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.spaceGrotesk(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: primary)),
                      ),
                      TournamentStatusChip(t.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _pill(t.gameFormat, secondary, border),
                      const SizedBox(width: 6),
                      _pill(t.isKnockout ? 'Knockout' : 'Group Stage', secondary,
                          border),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      PlayerAvatar(
                          imageUrl: t.agentAvatarUrl,
                          fallbackInitials: t.agentName.substring(0, 1),
                          radius: 11),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(t.agentName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 12, color: secondary)),
                      ),
                      Text('${t.teamCount} teams · ${t.playerCount} players',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: secondary)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.06, end: 0);
  }

  Widget _pill(String label, Color secondary, Color border) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w600, color: secondary)),
      );
}
