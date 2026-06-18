import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/providers/games_provider.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/nav.dart';

class AgentDashboardScreen extends ConsumerStatefulWidget {
  const AgentDashboardScreen({super.key});

  @override
  ConsumerState<AgentDashboardScreen> createState() =>
      _AgentDashboardScreenState();
}

class _AgentDashboardScreenState extends ConsumerState<AgentDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Ensure the agent's created games are loaded even when the dashboard is
    // opened without visiting Home first.
    Future.microtask(() {
      if (ref.read(gamesProvider).isEmpty) {
        ref.read(gamesProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final primary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    final approved =
        ref.watch(agentVerificationProvider) == AgentVerification.approved;
    final myGames = ref.watch(gamesProvider).where((g) => g.mine).toList();

    // Confirmed-payment counts per game (paid players only) drive the money.
    final paidCounts =
        ref.watch(agentConfirmedCountsProvider).valueOrNull ?? const {};
    int paidOf(Game g) => paidCounts[g.id] ?? 0;

    final gamesCreated = myGames.length;
    // Players confirmed (paid) across all the agent's games.
    final totalPlayers =
        myGames.fold<int>(0, (s, g) => s + paidOf(g));
    // Money the agent has actually collected from players (paid × price).
    final collected =
        myGames.fold<double>(0, (s, g) => s + paidOf(g) * g.price);
    // The agent's realized profit: each paid player carries commission/players.
    final commissionEarned = myGames.fold<double>(
        0,
        (s, g) =>
            s + (g.totalSlots == 0 ? 0 : paidOf(g) * g.commission / g.totalSlots));

    // Group games by status so the agent sees what's happening at a glance.
    final liveGames = myGames.where((g) => g.live).toList()
      ..sort((a, b) => a.kickoff.compareTo(b.kickoff));
    final upcomingGames = myGames.where((g) => !g.live && !g.ended).toList()
      ..sort((a, b) => a.kickoff.compareTo(b.kickoff));
    final pastGames = myGames.where((g) => g.ended).toList()
      ..sort((a, b) => b.kickoff.compareTo(a.kickoff));

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: primary),
          onPressed: () => context.safePop('profile'),
        ),
        title: Text('My Dashboard',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 18, fontWeight: FontWeight.w700, color: primary)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (!approved)
            _banner(
              color: AppColors.orange,
              icon: Icons.lock_outline,
              title: 'Not verified yet',
              body:
                  'Complete verification in your profile to start creating games and earning.',
            ).animate().fadeIn(duration: 300.ms),
          if (!approved) const SizedBox(height: 16),

          // ── Earnings summary ──────────────────────────────────────────────
          _earningsCard(collected, commissionEarned, primary, secondary, border),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _miniStat('Games created', '$gamesCreated',
                      Icons.sports_soccer, primary, secondary, border, surface)),
              const SizedBox(width: 12),
              Expanded(
                  child: _miniStat('Players confirmed', '$totalPlayers',
                      Icons.groups_outlined, primary, secondary, border, surface)),
            ],
          ),
          const SizedBox(height: 24),

          if (myGames.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: surface,
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.sports_soccer,
                      size: 40, color: secondary.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text('No games yet',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: primary)),
                  const SizedBox(height: 4),
                  Text(
                    approved
                        ? 'Tap the + button on the home screen to create your first game.'
                        : 'Get verified, then create games from the home screen.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 12, color: secondary),
                  ),
                ],
              ),
            )
          else ...[
            if (liveGames.isNotEmpty) ...[
              _sectionHeader('Live now', liveGames.length, secondary,
                  color: AppColors.tierElite),
              ...liveGames.map((g) => _gameCard(context, g, paidOf(g), primary,
                  secondary, border, surface)),
              const SizedBox(height: 12),
            ],
            if (upcomingGames.isNotEmpty) ...[
              _sectionHeader('Upcoming', upcomingGames.length, secondary),
              ...upcomingGames.map((g) => _gameCard(context, g, paidOf(g),
                  primary, secondary, border, surface)),
              const SizedBox(height: 12),
            ],
            if (pastGames.isNotEmpty) ...[
              _sectionHeader('Past games', pastGames.length, secondary),
              ...pastGames.map((g) => _gameCard(context, g, paidOf(g), primary,
                  secondary, border, surface)),
            ],
          ],
        ],
      ),
    );
  }

  /// Big, clear money card: total collected from players vs the agent's own
  /// commission (profit). Players pay the agent directly — no admin payout.
  Widget _earningsCard(double collected, double commission, Color primary,
      Color secondary, Color border) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.pink.withValues(alpha: 0.10),
          AppColors.orange.withValues(alpha: 0.10),
        ]),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  size: 16, color: AppColors.orange),
              const SizedBox(width: 6),
              Text('Your earnings',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: secondary)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RM ${collected.toStringAsFixed(0)}',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF22C55E))),
                    Text('Collected',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: secondary)),
                  ],
                ),
              ),
              Container(width: 1, height: 38, color: border),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RM ${commission.toStringAsFixed(0)}',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.orange)),
                    Text('Your commission',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: secondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
              'Players pay you directly. "Collected" counts confirmed payments; '
              'the rest covers your pitch rental.',
              style: GoogleFonts.inter(fontSize: 11, color: secondary)),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, IconData icon, Color primary,
      Color secondary, Color border, Color surface) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.orange),
          const SizedBox(height: 8),
          Text(value,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 20, fontWeight: FontWeight.w800, color: primary)),
          Text(label,
              style: GoogleFonts.inter(fontSize: 11, color: secondary)),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text, int count, Color secondary,
      {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (color != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
          ],
          Text(text,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color ?? secondary)),
          const SizedBox(width: 6),
          Text('($count)',
              style: GoogleFonts.inter(fontSize: 13, color: secondary)),
        ],
      ),
    );
  }

  Widget _banner(
      {required Color color,
      required IconData icon,
      required String title,
      required String body}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: color)),
                const SizedBox(height: 4),
                Text(body,
                    style: GoogleFonts.inter(
                        fontSize: 12, height: 1.5, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gameCard(BuildContext context, Game g, int paidCount, Color primary,
      Color secondary, Color border, Color surface) {
    final ratio = g.totalSlots == 0 ? 0.0 : g.filledSlots / g.totalSlots;
    final collected = paidCount * g.price;
    final realizedCommission =
        g.totalSlots == 0 ? 0.0 : paidCount * g.commission / g.totalSlots;
    final pendingCount =
        (g.filledSlots - paidCount).clamp(0, g.totalSlots);
    return GestureDetector(
      // Ended games open the match report (review window: edit stats,
      // read player comments); upcoming/live games open the match panel.
      onTap: () =>
          context.pushNamed('live-match', pathParameters: {'id': g.id}),
      child: Container(
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
              Expanded(
                child: Text(g.fieldName,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: primary)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (g.isFull
                          ? const Color(0xFF22C55E)
                          : const Color(0xFF3B82F6))
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(g.isFull ? 'Full' : 'Open',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: g.isFull
                            ? const Color(0xFF22C55E)
                            : const Color(0xFF3B82F6))),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('${g.dateTime} · ${g.format}',
              style: GoogleFonts.inter(fontSize: 12, color: secondary)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(children: [
                    Container(height: 6, color: border),
                    FractionallySizedBox(
                      widthFactor: ratio,
                      child: Container(
                        height: 6,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                              colors: [AppColors.orange, AppColors.cyan]),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              Text('${g.filledSlots}/${g.totalSlots} players',
                  style: GoogleFonts.inter(fontSize: 12, color: secondary)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'RM ${collected.toStringAsFixed(0)} collected · RM ${realizedCommission.toStringAsFixed(0)} commission',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF22C55E)),
                ),
              ),
              // Payments still awaiting the agent's confirmation.
              if (pendingCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text('$pendingCount to confirm',
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.orange)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton(
                    onPressed: () => context.pushNamed('game-detail',
                        pathParameters: {'id': g.id}),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.orange),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Manage',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.orange)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: Builder(builder: (context) {
                    // Start unlocks 30 min before kickoff; ended games stay
                    // tappable — they open the post-match report.
                    final locked = !g.ended && !g.live && !g.inAgentWindow;
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: locked
                            ? null
                            : g.live
                                ? const LinearGradient(colors: [
                                    AppColors.tierElite,
                                    AppColors.pink
                                  ])
                                : const LinearGradient(colors: [
                                    AppColors.pink,
                                    AppColors.orange
                                  ]),
                        color: locked ? const Color(0xFF444444) : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: locked
                            ? null
                            : () => context.pushNamed('live-match',
                                pathParameters: {'id': g.id}),
                        child: Text(
                            g.ended
                                ? 'Match Report'
                                : g.live
                                    ? 'Go to Live'
                                    : g.inAgentWindow
                                        ? 'Start Match'
                                        : 'Opens 30 min before',
                            style: GoogleFonts.spaceGrotesk(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}
