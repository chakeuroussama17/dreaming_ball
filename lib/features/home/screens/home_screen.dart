import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/providers/admin_providers.dart';
import '../../../../core/providers/content_providers.dart';
import '../../../../core/providers/games_provider.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/rating_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/player_avatar.dart';
import '../../../../core/widgets/tier_badge.dart';
import '../../../../l10n/app_localizations.dart';

// ── Data models ───────────────────────────────────────────────────────────────

class _BannerData {
  final String label;
  final List<Color> gradient;
  final String title;
  final String subtitle;
  final String? photoUrl;
  const _BannerData({
    required this.label,
    required this.gradient,
    required this.title,
    required this.subtitle,
    this.photoUrl,
  });
}

class _PlayerData {
  final String id, name, position;
  final PlayerTier tier;
  final int xp, rank;
  final String? avatarUrl;
  const _PlayerData({
    required this.id,
    required this.name,
    required this.position,
    required this.tier,
    required this.xp,
    required this.rank,
    this.avatarUrl,
  });

  factory _PlayerData.fromTop(TopPlayer p, int rank) => _PlayerData(
        id: p.userId,
        name: p.name,
        position: p.position,
        tier: p.tier,
        xp: p.xp,
        rank: rank,
        avatarUrl: p.avatarUrl,
      );
}

// ── Screen ────────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _bannerController = PageController();
  int _currentBanner = 0;
  Timer? _bannerTimer;
  Timer? _clockTimer; // re-checks the 30-min pre-match window

  String _selectedFormat = 'All';
  int _currentNav = 0;

  static const _formats = ['All', '5-aside', '6-aside', '7-aside', '11-aside'];

  @override
  void initState() {
    super.initState();
    // Fetch the real feed from Supabase.
    Future.microtask(() => ref.read(gamesProvider.notifier).load());
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final count =
          ref.read(announcementsRemoteProvider).valueOrNull?.length ?? 0;
      if (count < 2 || !_bannerController.hasClients) return;
      _bannerController.animateToPage(
        (_currentBanner + 1) % count,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
    // The "Starting Soon" panel opens on its own once the clock crosses
    // kickoff − 30 min, so rebuild periodically.
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _clockTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    setState(() => _currentNav = index);
    switch (index) {
      case 1:
        context.goNamed('leaderboard');
      case 2:
        context.goNamed('private-room');
      case 3:
        context.goNamed('profile');
      default:
        break;
    }
  }

  /// Grey placeholder cards shown while a rail is loading.
  Widget _skeletonRail(
      {required double width, required Color surface, required Color border}) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      scrollDirection: Axis.horizontal,
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (_, _) => Container(
        width: width,
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(16),
        ),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .fade(begin: 0.45, end: 1, duration: 700.ms),
    );
  }

  /// Shown when the games fetch fails.
  Widget _errorRetry(Color secondary) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off, size: 32, color: secondary),
          const SizedBox(height: 8),
          Text("Couldn't load games",
              style: GoogleFonts.inter(fontSize: 13, color: secondary)),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => ref.read(gamesProvider.notifier).load(),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.orange),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Retry',
                style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w700, color: AppColors.orange)),
          ),
        ],
      ),
    );
  }

  // Shown when an unverified agent taps the locked create-game button.
  void _showLockedSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final primary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final status = ref.read(agentVerificationProvider);
    final pending = status == AgentVerification.pending;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(pending ? Icons.hourglass_top : Icons.lock_outline,
                size: 44, color: AppColors.orange),
            const SizedBox(height: 14),
            Text(
              pending ? 'Verification under review' : 'Verify to create games',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 18, fontWeight: FontWeight.w700, color: primary),
            ),
            const SizedBox(height: 8),
            Text(
              pending
                  ? "We're reviewing your ID and bank details. You can create games once you're approved."
                  : 'Submit your ID and a Malaysian DuitNow bank account in your profile. Once an admin approves, you can create games.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, height: 1.5, color: secondary),
            ),
            const SizedBox(height: 20),
            if (!pending)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppColors.pink, AppColors.orange]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.goNamed('profile');
                    },
                    child: Text('Go to Verification',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final primary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final l = AppLocalizations.of(context);

    final games = ref.watch(gamesProvider);
    final gamesStatus = ref.watch(gamesStatusProvider);
    final topPlayersAsync = ref.watch(topPlayersProvider);
    final myProfile = ref.watch(myProfileProvider).valueOrNull;
    final canCreate = ref.watch(canCreateGamesProvider);
    final isAgent = ref.watch(userRoleProvider) == UserRole.agent;
    // Live section: only games this user is part of. Players see a game here
    // once the agent starts it; the agent also sees his own games from
    // 30 min before kickoff (pre-match window) so he can check attendance.
    final myLiveGames = games.where((g) {
      if (g.live) return g.joined || (isAgent && g.mine);
      // Finished match: stays pinned (green) while the 3-hour review window
      // is open, so players can comment and the agent can fix stats.
      if (g.ended) return g.inReviewWindow && (g.joined || (isAgent && g.mine));
      return isAgent && g.mine && g.inAgentWindow;
    }).toList();
    final hasLive = myLiveGames.any((g) => g.live);
    final hasUpcomingMine = myLiveGames.any((g) => !g.live && !g.ended);
    final banners = (ref.watch(announcementsRemoteProvider).valueOrNull ??
            const <Announcement>[])
        .map((a) => _BannerData(
              label: a.badge.label,
              gradient: a.badge.gradient,
              title: a.title,
              subtitle: a.subtitle,
              photoUrl: a.photoUrl,
            ))
        .toList();
    // Games This Week only offers joinable games: not started, not finished,
    // kickoff still ahead. (The DB also rejects joins once status ≠ scheduled.)
    final upcoming = games
        .where((g) =>
            !g.live && !g.ended && g.kickoff.isAfter(DateTime.now()))
        .toList();
    final filteredGames = _selectedFormat == 'All'
        ? upcoming
        : upcoming.where((g) => g.format == _selectedFormat).toList();

    // Agent ratings (star badge on cards) and "near you" matching by the
    // player's city/state against each game's free-text location.
    final ratings =
        ref.watch(agentRatingsProvider).valueOrNull ?? const <String, AgentRating>{};
    final myCity = myProfile?.city?.trim() ?? '';
    final myState = myProfile?.state?.trim() ?? '';
    bool isNearby(Game g) {
      final loc = g.location.toLowerCase();
      if (loc.isEmpty) return false;
      if (myCity.isNotEmpty && loc.contains(myCity.toLowerCase())) return true;
      if (myState.isNotEmpty && loc.contains(myState.toLowerCase())) return true;
      return false;
    }

    final nearGames = upcoming.where(isNearby).toList();

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.orange,
          onRefresh: () async {
            ref.invalidate(announcementsRemoteProvider);
            ref.invalidate(topPlayersProvider);
            await ref.read(gamesProvider.notifier).load();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
            // ── Top bar ───────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    PlayerAvatar(
                      imageUrl: myProfile?.avatarUrl,
                      fallbackInitials: (myProfile?.fullName.isNotEmpty ?? false)
                          ? myProfile!.fullName.substring(0, 1)
                          : 'ME',
                      radius: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ShaderMask(
                        shaderCallback: (b) => AppColors.brandGradient.createShader(b),
                        child: Text(
                          'Dreaming Ball',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: Icon(Icons.notifications_outlined, color: primary),
                          onPressed: () => context.pushNamed('notifications'),
                        ),
                        // Live unread badge (realtime on notifications table).
                        if (ref.watch(unreadNotificationsProvider) > 0)
                          Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),
            ),

            // ── Banner carousel ───────────────────────────────────────────────
            if (banners.isNotEmpty)
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    SizedBox(
                      height: 180,
                      child: PageView.builder(
                        controller: _bannerController,
                        itemCount: banners.length,
                        onPageChanged: (i) => setState(() => _currentBanner = i),
                        itemBuilder: (ctx, i) => _BannerCard(data: banners[i]),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(banners.length, (i) {
                        final active = i == _currentBanner;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: active ? 20 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            gradient: active ? AppColors.brandGradient : null,
                            color: active ? null : secondary.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(100),
                          ),
                        );
                      }),
                    ),
                  ],
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
              ),

            // ── Live Now (your games only) ────────────────────────────────────
            if (myLiveGames.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: hasLive
                                    ? AppColors.tierElite
                                    : hasUpcomingMine
                                        ? AppColors.orange
                                        // Finished — review window open
                                        : const Color(0xFF22C55E),
                                shape: BoxShape.circle),
                          )
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .fade(begin: 1, end: 0.3, duration: 750.ms),
                          const SizedBox(width: 8),
                          Text(
                            hasLive
                                ? l.liveNow
                                : hasUpcomingMine
                                    ? l.startingSoon
                                    : l.matchReport,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...myLiveGames.map((g) {
                        // red = live, orange = pre-match (agent), green =
                        // finished & review window open (3h to comment/fix).
                        const green = Color(0xFF22C55E);
                        final accent = g.live
                            ? AppColors.tierElite
                            : g.ended
                                ? green
                                : AppColors.orange;
                        final label = g.live
                            ? ((isAgent && g.mine)
                                ? l.manageLive
                                : l.watchLive)
                            : g.ended
                                ? l.matchReport
                                : l.checkAttendance;
                        final subtitle = g.live
                            ? g.dateTime
                            : g.ended
                                ? ((isAgent && g.mine)
                                    ? 'Finished — review stats & player comments'
                                    : 'Finished — check your stats & comment')
                                : 'Kick-off ${g.kickoffLabel} · attendance open';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.06),
                            border: Border.all(
                                color: accent.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      g.fieldName,
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: primary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      subtitle,
                                      style: GoogleFonts.inter(
                                          fontSize: 12, color: secondary),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => context.pushNamed('live-match',
                                    pathParameters: {'id': g.id}),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 9),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                        colors: g.live
                                            ? const [
                                                AppColors.tierElite,
                                                AppColors.pink
                                              ]
                                            : g.ended
                                                ? const [
                                                    Color(0xFF22C55E),
                                                    AppColors.cyan
                                                  ]
                                                : const [
                                                    AppColors.pink,
                                                    AppColors.orange
                                                  ]),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    label,
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ).animate().fadeIn(duration: 350.ms),
              ),

            // ── Format filter pills ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: SizedBox(
                height: 46,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  scrollDirection: Axis.horizontal,
                  itemCount: _formats.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final active = _formats[i] == _selectedFormat;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedFormat = _formats[i]),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: active ? AppColors.brandGradient : null,
                          border: Border.all(
                            color: active ? Colors.transparent : border,
                          ),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          _formats[i],
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                            color: active ? Colors.white : secondary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // ── Near You ───────────────────────────────────────────────────────
            if (nearGames.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 18, color: AppColors.orange),
                      const SizedBox(width: 6),
                      Text(
                        l.nearYou,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                      if (myCity.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text('· $myCity',
                            style: GoogleFonts.inter(
                                fontSize: 13, color: secondary)),
                      ],
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 265,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    scrollDirection: Axis.horizontal,
                    itemCount: nearGames.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (ctx, i) {
                      final g = nearGames[i];
                      return _HomeGameCard(
                        data: g,
                        rating: ratings[g.agentId],
                        isDark: isDark,
                        primary: primary,
                        secondary: secondary,
                        border: border,
                        onTap: () => context.pushNamed(
                          g.live ? 'live-match' : 'game-detail',
                          pathParameters: {'id': g.id},
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],

            // ── Games This Week ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l.gamesThisWeek,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                    Text(
                      l.viewAll,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 265,
                child: (gamesStatus == GamesStatus.loading ||
                            gamesStatus == GamesStatus.initial) &&
                        games.isEmpty
                    ? _skeletonRail(width: 220, surface: isDark
                        ? AppColors.darkSurface
                        : AppColors.lightSurface, border: border)
                    : gamesStatus == GamesStatus.error && games.isEmpty
                        ? _errorRetry(secondary)
                        : filteredGames.isEmpty
                            ? Center(
                                child: Text(
                                  l.noGamesThisWeek,
                                  style: GoogleFonts.inter(
                                      fontSize: 14, color: secondary),
                                ),
                              )
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 0, 20, 0),
                                scrollDirection: Axis.horizontal,
                                itemCount: filteredGames.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (ctx, i) {
                                  final g = filteredGames[i];
                                  return _HomeGameCard(
                                    data: g,
                                    rating: ratings[g.agentId],
                                    isDark: isDark,
                                    primary: primary,
                                    secondary: secondary,
                                    border: border,
                                    onTap: () => context.pushNamed(
                                      g.live ? 'live-match' : 'game-detail',
                                      pathParameters: {'id': g.id},
                                    ),
                                  );
                                },
                              ),
              ),
            ),

            // ── Top Players This Week ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l.topPlayers,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.goNamed('leaderboard'),
                      child: Text(
                        'View all',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 225,
                child: topPlayersAsync.when(
                  loading: () => _skeletonRail(
                      width: 132,
                      surface: isDark
                          ? AppColors.darkSurface
                          : AppColors.lightSurface,
                      border: border),
                  error: (_, _) => Center(
                    child: Text("Couldn't load players",
                        style:
                            GoogleFonts.inter(fontSize: 13, color: secondary)),
                  ),
                  data: (top) => top.isEmpty
                      ? Center(
                          child: Text('No players yet — be the first!',
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: secondary)),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                          scrollDirection: Axis.horizontal,
                          itemCount: top.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: 12),
                          itemBuilder: (ctx, i) {
                            final p = _PlayerData.fromTop(top[i], i + 1);
                            return _PlayerCard(
                              data: p,
                              isDark: isDark,
                              primary: primary,
                              secondary: secondary,
                              border: border,
                              onTap: () => context.pushNamed('profile-view',
                                  pathParameters: {'id': p.id}),
                            );
                          },
                        ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentNav,
        onTap: _onNavTap,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: l.navHome,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.leaderboard_outlined),
            activeIcon: const Icon(Icons.leaderboard),
            label: l.navLeaderboard,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.lock_outline),
            activeIcon: const Icon(Icons.lock),
            label: l.navPrivateRoom,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: l.navProfile,
          ),
        ],
      ),
      floatingActionButton: isAgent
          ? SizedBox(
              width: 58,
              height: 58,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: canCreate
                      ? AppColors.brandGradient
                      : LinearGradient(colors: [
                          AppColors.pink.withValues(alpha: 0.4),
                          AppColors.orange.withValues(alpha: 0.4),
                        ]),
                ),
                child: FloatingActionButton(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  onPressed: () => canCreate
                      ? context.pushNamed('create-game')
                      : _showLockedSheet(context),
                  child: Icon(
                    canCreate ? Icons.add : Icons.lock_outline,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

// ── Banner card ───────────────────────────────────────────────────────────────

class _BannerCard extends StatelessWidget {
  final _BannerData data;
  const _BannerCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: data.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Uploaded banner image fills the card; the gradient stays as the
          // fallback while it loads (or if it fails).
          if (data.photoUrl != null)
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: data.photoUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  // Stronger scrim over a photo so the text stays readable.
                  colors: data.photoUrl != null
                      ? const [Color(0x33000000), Color(0x99000000)]
                      : const [Colors.transparent, Color(0x44000000)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    data.label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  data.title,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Home game card ────────────────────────────────────────────────────────────

class _HomeGameCard extends StatelessWidget {
  final Game data;
  final AgentRating? rating;
  final bool isDark;
  final Color primary, secondary, border;
  final VoidCallback onTap;

  const _HomeGameCard({
    required this.data,
    this.rating,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final slotRatio = data.filledSlots / data.totalSlots;
    final isFull = data.filledSlots >= data.totalSlots;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: cardBg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Field photo (uploaded) or placeholder
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: data.photoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: data.photoUrl!,
                          height: 110,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Container(
                            height: 110,
                            color: isDark
                                ? const Color(0xFF1A1A2E)
                                : const Color(0xFFE2E8F0),
                          ),
                        )
                      : data.photo != null
                      ? Image.memory(
                          data.photo!,
                          height: 110,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          height: 110,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isDark
                                  ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                                  : [const Color(0xFFE2E8F0), const Color(0xFFCBD5E1)],
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.sports_soccer,
                              size: 38,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : Colors.black.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                ),
                // Format pill (+ LIVE badge when live)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Row(
                    children: [
                      if (data.live) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.tierElite,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                    color: Colors.white, shape: BoxShape.circle),
                              )
                                  .animate(onPlay: (c) => c.repeat(reverse: true))
                                  .fade(begin: 1, end: 0.3, duration: 750.ms),
                              const SizedBox(width: 4),
                              Text('LIVE',
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.pink, AppColors.orange],
                          ),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          data.format,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Age group pill
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      data.ageGroup,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // Agent rating badge (top-right of the photo)
                if (rating != null && rating!.count > 0)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 12, color: Color(0xFFFBBF24)),
                          const SizedBox(width: 2),
                          Text(
                            rating!.avg.toStringAsFixed(1),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            // Card content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.fieldName,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.location_on_outlined, size: 12, color: secondary),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        data.location,
                        style: GoogleFonts.inter(fontSize: 11, color: secondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Row(children: [
                    Icon(Icons.schedule, size: 12, color: secondary),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        data.dateTime,
                        style: GoogleFonts.inter(fontSize: 11, color: secondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 9),
                  // Slot progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(children: [
                      Container(height: 5, color: border),
                      FractionallySizedBox(
                        widthFactor: slotRatio,
                        child: Container(
                          height: 5,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isFull
                                  ? [AppColors.tierElite, AppColors.pink]
                                  : [AppColors.orange, AppColors.cyan],
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isFull ? 'Full' : '${data.filledSlots}/${data.totalSlots} players',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: isFull ? AppColors.tierElite : secondary,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'RM ${data.price.toStringAsFixed(0)}',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.orange,
                        ),
                      ),
                      Builder(builder: (_) {
                        // Already-joined upcoming game → green "Joined ✓" chip.
                        final joined =
                            data.joined && !data.live && !data.ended;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: (joined || (isFull && !data.live))
                                ? null
                                : LinearGradient(
                                    colors: data.live
                                        ? [AppColors.tierElite, AppColors.pink]
                                        : [AppColors.pink, AppColors.orange],
                                  ),
                            color: joined
                                ? AppColors.cyan.withValues(alpha: 0.15)
                                : (isFull && !data.live)
                                    ? secondary.withValues(alpha: 0.12)
                                    : null,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (joined) ...[
                                const Icon(Icons.check_circle,
                                    size: 13, color: AppColors.cyan),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                joined
                                    ? l.joinedTick
                                    : data.live
                                        ? l.watchLive
                                        : (isFull ? l.gameFull : l.joinGame),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: joined
                                      ? AppColors.cyan
                                      : (isFull && !data.live)
                                          ? secondary
                                          : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Player card ───────────────────────────────────────────────────────────────

class _PlayerCard extends StatelessWidget {
  final _PlayerData data;
  final bool isDark;
  final Color primary, secondary, border;
  final VoidCallback onTap;

  const _PlayerCard({
    required this.data,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 132,
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
        decoration: BoxDecoration(
          color: cardBg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                PlayerAvatar(
                  imageUrl: data.avatarUrl,
                  fallbackInitials: data.name.substring(0, 1),
                  radius: 28,
                ),
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.pink, AppColors.orange],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: cardBg, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        '#${data.rank}',
                        style: const TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              data.name,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: primary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              data.position,
              style: GoogleFonts.inter(fontSize: 11, color: secondary),
            ),
            const SizedBox(height: 7),
            TierBadge(tier: data.tier),
            const SizedBox(height: 7),
            Text(
              '+${data.xp} XP',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
