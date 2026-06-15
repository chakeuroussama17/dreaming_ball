import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/providers/games_provider.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/game_service.dart';
import '../../../../core/services/live_match_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/nav.dart';
import '../../../../core/widgets/player_avatar.dart';
import '../../../../core/widgets/tier_badge.dart';

// ── Live player model ───────────────────────────────────────────────────────

class _LivePlayer {
  final String id, name, position;
  final PlayerTier tier;
  bool isPresent = true;
  int goals = 0;
  int assists = 0;
  int goalsConceded = 0; // per-player, agent judges individually
  int goodBehavior = 1; // 0 or 1
  _LivePlayer({
    required this.id,
    required this.name,
    required this.position,
    required this.tier,
  });

  /// XP estimate — mirrors the calculate_xp() function in the database
  /// (the cron awards the real value once the dispute window closes).
  int get estXp {
    final goalPts = switch (position) {
      'Defender' => 12,
      'GK' => 16,
      _ => 10, // Striker / Midfielder
    };
    final assistPts = position == 'GK' ? 7 : 5;
    final gcBonus = switch (position) {
      'GK' => goalsConceded < 3 ? 8 : (goalsConceded <= 6 ? 4 : 2),
      'Defender' => goalsConceded < 3 ? 5 : (goalsConceded <= 6 ? 3 : 1),
      'Midfielder' => goalsConceded < 3 ? 3 : (goalsConceded <= 6 ? 1 : 0),
      _ => goalsConceded < 3 ? 2 : (goalsConceded <= 6 ? 1 : 0),
    };
    final gbBonus = goodBehavior == 1 ? 20 : -10;
    final total = goals * goalPts + assists * assistPts + gcBonus + gbBonus;
    return total < 5 ? 5 : total; // attendance floor
  }
}

// Column widths shared by the header and every row so they stay aligned.
const double _statW = 68, _gbW = 40;

class LiveMatchScreen extends ConsumerStatefulWidget {
  final String id;
  const LiveMatchScreen({super.key, required this.id});

  @override
  ConsumerState<LiveMatchScreen> createState() => _LiveMatchScreenState();
}

class _LiveMatchScreenState extends ConsumerState<LiveMatchScreen> {
  // Highlighted row in watch mode: the signed-in player.
  String get _youId => SupabaseService.userId ?? '';

  // Edit rights: only the agent who created this game may record stats.
  bool _canEdit = false;
  // Watch rights: players who registered & paid for this game.
  bool _canWatch = false;

  bool _started = false;
  bool _ended = false;
  bool _submitted = false;

  Timer? _timer;
  Timer? _clockTimer; // refreshes the pre-match 30-min window state
  Duration _elapsed = Duration.zero;

  // Roster from game_players + live stats from live_match_stats.
  List<_LivePlayer> _players = [];
  bool _loadingRoster = true;
  StreamSubscription<List<Map<String, dynamic>>>? _liveSub;

  // Post-match review: panel stays open during the 3-hour dispute window —
  // players comment, the agent can still correct stats.
  bool _review = false;
  bool _loadingReview = true;
  bool _commentsReady = true;
  List<FinalStatRow> _finalStats = [];
  List<MatchComment> _comments = [];
  Timer? _reviewTimer;
  final _commentCtrl = TextEditingController();
  bool _posting = false;

  // A match needs at least 2 present players to start.
  static const _minPlayersToStart = 2;

  List<_LivePlayer> get _present => _players.where((p) => p.isPresent).toList();
  int get _presentCount => _present.length;
  int get _totalGoals => _present.fold(0, (s, p) => s + p.goals);

  String get _gameName =>
      ref.read(gamesProvider.notifier).byId(widget.id)?.fieldName ?? 'Game';

  @override
  void initState() {
    super.initState();
    final game = ref.read(gamesProvider.notifier).byId(widget.id);
    final role = ref.read(userRoleProvider);
    _canEdit = role == UserRole.agent && (game?.mine ?? false);
    _canWatch = (game?.joined ?? false) || _canEdit;
    // Match already over → straight to the post-match review panel.
    if (game?.ended ?? false) {
      _review = true;
      _loadingRoster = false;
      if (_canWatch) _loadReview();
      return;
    }
    // If the match is already live (e.g. watcher joins mid-game), show the
    // live table immediately.
    if (game?.live ?? false) {
      _started = true;
      _startTimer();
    } else if (_canEdit) {
      // Re-check every 15s so the Start button unlocks on its own once the
      // clock crosses kickoff − 30 min.
      _clockTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (mounted && !_started) setState(() {});
      });
    }
    if (_canWatch) _loadRoster();
  }

  /// Final stats + comments for the review panel. Polled every 30s so the
  /// countdown ticks and the agent's corrections / new comments arrive.
  Future<void> _loadReview() async {
    try {
      final stats = await LiveMatchService.fetchFinalStats(widget.id);
      if (!mounted) return;
      setState(() {
        _finalStats = stats;
        _loadingReview = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingReview = false);
    }
    try {
      final comments = await LiveMatchService.fetchComments(widget.id);
      if (mounted) {
        setState(() {
          _comments = comments;
          _commentsReady = true;
        });
      }
    } catch (_) {
      // match_comments table missing or offline — hide the comment box.
      if (mounted) setState(() => _commentsReady = false);
    }
    _reviewTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadReview();
    });
  }

  /// Agent corrects a submitted stat during the window (local + DB).
  void _editFinal(FinalStatRow s, String statType, int value) {
    setState(() {
      switch (statType) {
        case 'goals':
          s.goals = value;
        case 'assists':
          s.assists = value;
        case 'goals_conceded':
          s.goalsConceded = value;
        case 'good_behavior':
          s.goodBehavior = value;
      }
    });
    LiveMatchService.updateFinalStat(
            statId: s.statId, statType: statType, value: value)
        .catchError((_) {
      // Next 30s poll reconciles with the database.
    });
  }

  Future<void> _postComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _posting) return;
    setState(() => _posting = true);
    try {
      await LiveMatchService.addComment(widget.id, text);
      _commentCtrl.clear();
      final comments = await LiveMatchService.fetchComments(widget.id);
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _posting = false;
      });
    } on GameServiceException catch (e) {
      if (!mounted) return;
      setState(() => _posting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Roster + current live stats; watchers also subscribe to realtime.
  Future<void> _loadRoster() async {
    try {
      final results = await Future.wait([
        GameService.fetchGamePlayers(widget.id),
        LiveMatchService.fetchLiveStats(widget.id),
      ]);
      if (!mounted) return;
      final squad = results[0] as List<SquadPlayer>;
      setState(() {
        _players = [
          for (final s in squad)
            _LivePlayer(
              id: s.userId,
              name: s.name,
              position: s.position,
              tier: playerTierFromLabel(s.tier),
            )
        ];
        _applyStats(results[1] as List<LiveStatRow>);
        _loadingRoster = false;
      });
      if (!_canEdit) {
        // Watchers get the agent's edits pushed live.
        _liveSub = LiveMatchService.subscribeToLiveMatch(widget.id, (rows) {
          if (mounted) setState(() => _applyStats(rows));
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRoster = false);
    }
  }

  void _applyStats(List<LiveStatRow> rows) {
    for (final r in rows) {
      for (final p in _players) {
        if (p.id == r.playerId) {
          p.isPresent = r.isPresent;
          p.goals = r.goals;
          p.assists = r.assists;
          p.goalsConceded = r.goalsConceded;
          p.goodBehavior = r.goodBehavior;
        }
      }
    }
  }

  /// Fire-and-forget write of one stat (agent side). Realtime delivers it
  /// to every watcher.
  void _pushStat(_LivePlayer p, String statType, int value) {
    LiveMatchService.updatePlayerStat(
      gameId: widget.id,
      playerId: p.id,
      statType: statType,
      value: value,
    ).catchError((_) {
      // Watchers reconcile via realtime; agent retries on next tap.
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clockTimer?.cancel();
    _reviewTimer?.cancel();
    _liveSub?.cancel();
    _commentCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_ended) {
        setState(() => _elapsed += const Duration(seconds: 1));
      }
    });
  }

  String get _timeText {
    final m = _elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _startMatch() async {
    final game = ref.read(gamesProvider.notifier).byId(widget.id);
    // Start is allowed from kick-off time onward, never before.
    final kickoffReached =
        game == null || !DateTime.now().isBefore(game.kickoff);
    if (_presentCount < _minPlayersToStart || !kickoffReached) return;
    _clockTimer?.cancel();
    setState(() => _started = true);
    _startTimer();
    try {
      // games.status = 'live' + one live_match_stats row per present player.
      await LiveMatchService.startMatch(
          widget.id, [for (final p in _present) p.id]);
      if (game != null) {
        ref.read(gamesProvider.notifier).upsertLocal(game.copyWith(live: true));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not start the match — check your connection')));
      }
    }
  }

  void _endMatch() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final primary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('End the match?',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 18, fontWeight: FontWeight.w700, color: primary)),
        content: Text(
          'Total goals: $_totalGoals. Stats will be locked and players get 3 hours to dispute before XP is added.',
          style: GoogleFonts.inter(fontSize: 14, height: 1.5, color: secondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: secondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.tierElite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _timer?.cancel();
              setState(() => _ended = true);
              // TODO: Supabase — lock stats, open 3-hour dispute window
            },
            child: const Text('End Match', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final primary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: !_canWatch
            ? _blocked(primary, secondary)
            : Column(
                children: [
                  _header(primary, secondary),
                  Expanded(
                    child: _review
                        ? _postMatch(isDark, primary, secondary)
                        : _loadingRoster
                            ? const Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.orange, strokeWidth: 2.5))
                            : _players.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(32),
                                      child: Text(
                                        'No players have joined this game yet.',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(
                                            fontSize: 13, color: secondary),
                                      ),
                                    ),
                                  )
                                : _ended
                                    ? _summary(isDark, primary, secondary)
                                    : _started
                                        ? _liveScoring(
                                            isDark, primary, secondary)
                                        : _attendance(
                                            isDark, primary, secondary),
                  ),
                ],
              ),
      ),
    );
  }

  // ── ACCESS BLOCKED ──────────────────────────────────────────────────────
  Widget _blocked(Color primary, Color secondary) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, size: 18, color: primary),
            onPressed: () => context.safePop(),
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 48, color: secondary),
                  const SizedBox(height: 14),
                  Text('This live match is private',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 16, fontWeight: FontWeight.w700, color: primary)),
                  const SizedBox(height: 6),
                  Text(
                    'Only players who joined and paid for this game can watch its live stats.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 13, height: 1.5, color: secondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── HEADER ──────────────────────────────────────────────────────────────
  Widget _header(Color primary, Color secondary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, size: 18, color: primary),
            onPressed: () => context.safePop(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (_started && !_ended && !_review)
                  _livePill()
                else
                  Text(
                      _review
                          ? 'MATCH REPORT'
                          : _ended
                              ? 'MATCH ENDED'
                              : 'PRE-MATCH',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: secondary)),
                const SizedBox(height: 2),
                Text(_gameName,
                    style: GoogleFonts.inter(fontSize: 12, color: secondary)),
              ],
            ),
          ),
          SizedBox(
            width: 64,
            child: _started
                ? Text(_timeText,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.orange))
                : const SizedBox(),
          ),
        ],
      ),
    );
  }

  Widget _livePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.tierElite.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
                color: AppColors.tierElite, shape: BoxShape.circle),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fade(begin: 1, end: 0.3, duration: 750.ms),
          const SizedBox(width: 6),
          Text('LIVE',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: AppColors.tierElite)),
        ],
      ),
    );
  }

  // ── SCORE DISPLAY ─────────────────────────────────────────────────────────
  Widget _scoreDisplay(Color secondary) {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (b) => AppColors.brandGradient.createShader(b),
          child: Text('$_totalGoals',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 64, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
        Text('Total Goals',
            style: GoogleFonts.inter(fontSize: 12, color: secondary)),
      ],
    );
  }

  // ── ATTENDANCE PHASE ──────────────────────────────────────────────────────
  Widget _attendance(bool isDark, Color primary, Color secondary) {
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    if (!_canEdit) {
      // Player waiting for the agent to start.
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.schedule, size: 48, color: AppColors.orange),
              const SizedBox(height: 14),
              Text('Match hasn’t started yet',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 16, fontWeight: FontWeight.w700, color: primary)),
              const SizedBox(height: 6),
              Text('The agent is checking attendance. Live stats appear here once the match begins.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 13, height: 1.5, color: secondary)),
            ],
          ),
        ),
      );
    }

    final game = ref.watch(gamesProvider).where((g) => g.id == widget.id).firstOrNull;
    final windowOpen = game?.inAgentWindow ?? true;
    // The 30-min window is for attendance only; Start unlocks at kick-off
    // time and stays manual (matches often kick off at 3:02, not 3:00).
    final kickoffReached =
        game == null || !DateTime.now().isBefore(game.kickoff);
    final canStart = kickoffReached && _presentCount >= _minPlayersToStart;

    return Column(
      children: [
        if (!kickoffReached)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.08),
              border: Border.all(color: AppColors.orange.withValues(alpha: 0.35)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule, size: 18, color: AppColors.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Kick-off at ${game.kickoffLabel} — check attendance now; Start unlocks at kick-off time.',
                    style: GoogleFonts.inter(
                        fontSize: 12, height: 1.4, color: AppColors.orange),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Check Attendance ($_presentCount/${_players.length})',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: primary)),
                    Text('Mark who showed up, then start the match',
                        style: GoogleFonts.inter(fontSize: 12, color: secondary)),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  for (final p in _players) {
                    p.isPresent = true;
                  }
                }),
                child: Text('Mark All',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, color: AppColors.orange)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            itemCount: _players.length,
            itemBuilder: (ctx, i) {
              final p = _players[i];
              return GestureDetector(
                onTap: () => setState(() => p.isPresent = !p.isPresent),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: surface,
                    border: Border.all(color: border),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      _checkbox(p.isPresent),
                      const SizedBox(width: 12),
                      Opacity(
                        opacity: p.isPresent ? 1 : 0.4,
                        child: PlayerAvatar(
                            fallbackInitials: p.name.substring(0, 1), radius: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Opacity(
                          opacity: p.isPresent ? 1 : 0.4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name,
                                  style: GoogleFonts.spaceGrotesk(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: primary)),
                              const SizedBox(height: 4),
                              Row(children: [
                                Text('${p.position} · ',
                                    style: GoogleFonts.inter(
                                        fontSize: 12, color: secondary)),
                                TierBadge(tier: p.tier),
                              ]),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        _bottomBar(
          child: _gradientButton(
            !windowOpen
                ? 'Opens 30 min before kick-off'
                : kickoffReached
                    ? 'Start Match ($_presentCount present)'
                    : 'Starts at ${game.kickoffLabel}',
            canStart ? _startMatch : null,
          ),
        ),
      ],
    );
  }

  Widget _checkbox(bool checked) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        gradient: checked ? AppColors.brandGradient : null,
        borderRadius: BorderRadius.circular(7),
        border: checked ? null : Border.all(color: const Color(0xFF555555), width: 1.5),
      ),
      child: checked
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );
  }

  // ── LIVE SCORING PHASE ──────────────────────────────────────────────────
  Widget _liveScoring(bool isDark, Color primary, Color secondary) {
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return Column(
      children: [
        const SizedBox(height: 4),
        _scoreDisplay(secondary),
        const SizedBox(height: 12),

        if (!_canEdit)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.tierElite.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Text('🔴', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('LIVE — Agent is recording stats',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.tierElite)),
                ),
              ],
            ),
          ),

        // Quick goal entry (agent only)
        if (_canEdit)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: _gradientButton('⚽  GOAL', _openQuickGoal, height: 48),
          ),

        // Column headers
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          color: surface,
          child: Row(
            children: [
              Expanded(
                child: Text('PLAYER',
                    style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w700, color: secondary)),
              ),
              _hCell('G', secondary, _statW),
              _hCell('A', secondary, _statW),
              _hCell('GC', secondary, _statW),
              _hCell('GB', secondary, _gbW),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            itemCount: _present.length,
            itemBuilder: (ctx, i) =>
                _scoreRow(_present[i], primary, secondary, border, surface),
          ),
        ),

        if (_canEdit)
          _bottomBar(
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.tierElite.withValues(alpha: 0.6)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _endMatch,
                child: Text('End Match',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.tierElite)),
              ),
            ),
          )
        else
          _bottomBar(
            child: Text('Stats finalize 3 hours after the match ends.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: secondary)),
          ),
      ],
    );
  }

  Widget _hCell(String label, Color secondary, double w) => SizedBox(
        width: w,
        child: Text(label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w700, color: secondary)),
      );

  Widget _scoreRow(_LivePlayer p, Color primary, Color secondary, Color border,
      Color surface) {
    final role = ref.read(userRoleProvider);
    final isYou = !_canEdit && role == UserRole.player && p.id == _youId;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isYou ? AppColors.orange.withValues(alpha: 0.08) : surface,
        border: isYou
            ? const Border(left: BorderSide(color: AppColors.orange, width: 3))
            : Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Identity
          Expanded(
            child: Row(
              children: [
                PlayerAvatar(fallbackInitials: p.name.substring(0, 1), radius: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(p.name,
                                style: GoogleFonts.spaceGrotesk(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: primary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (isYou)
                            Text('  (you)',
                                style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.orange)),
                        ],
                      ),
                      Text('${p.position} · ${p.tier.label}',
                          style: GoogleFonts.inter(
                              fontSize: 10, color: secondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // G
          SizedBox(
            width: _statW,
            child: _stepper(p.goals, () {
              setState(() {
                if (p.goals > 0) p.goals--;
              });
              _pushStat(p, 'goals', p.goals);
            }, () {
              setState(() => p.goals++);
              _pushStat(p, 'goals', p.goals);
            }, primary),
          ),
          // A
          SizedBox(
            width: _statW,
            child: _stepper(p.assists, () {
              setState(() {
                if (p.assists > 0) p.assists--;
              });
              _pushStat(p, 'assists', p.assists);
            }, () {
              setState(() => p.assists++);
              _pushStat(p, 'assists', p.assists);
            }, primary),
          ),
          // GC — per-player, judged individually by the agent
          SizedBox(
            width: _statW,
            child: _stepper(p.goalsConceded, () {
              setState(() {
                if (p.goalsConceded > 0) p.goalsConceded--;
              });
              _pushStat(p, 'goals_conceded', p.goalsConceded);
            }, () {
              setState(() => p.goalsConceded++);
              _pushStat(p, 'goals_conceded', p.goalsConceded);
            }, primary),
          ),
          // GB toggle
          SizedBox(
            width: _gbW,
            child: GestureDetector(
              onTap: _canEdit
                  ? () {
                      setState(() =>
                          p.goodBehavior = p.goodBehavior == 1 ? 0 : 1);
                      _pushStat(p, 'good_behavior', p.goodBehavior);
                    }
                  : null,
              child: Icon(
                p.goodBehavior == 1 ? Icons.thumb_up : Icons.thumb_down,
                size: 20,
                color: p.goodBehavior == 1
                    ? const Color(0xFF22C55E)
                    : AppColors.tierElite,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepper(int value, VoidCallback onMinus, VoidCallback onPlus,
      Color primary) {
    if (!_canEdit) {
      return Text('$value',
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceGrotesk(
              fontSize: 18, fontWeight: FontWeight.w800, color: primary));
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _roundBtn(Icons.remove, value > 0, onMinus, gradient: false),
        SizedBox(
          width: 20,
          child: Text('$value',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 17, fontWeight: FontWeight.w800, color: primary)),
        ),
        _roundBtn(Icons.add, true, onPlus, gradient: true),
      ],
    );
  }

  Widget _roundBtn(IconData icon, bool enabled, VoidCallback onTap,
      {required bool gradient}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: (gradient && enabled)
              ? const LinearGradient(colors: [AppColors.pink, AppColors.orange])
              : null,
          color: gradient
              ? (enabled ? null : const Color(0xFF444444))
              : Colors.white.withValues(alpha: enabled ? 0.12 : 0.04),
        ),
        child: Icon(icon,
            size: 14,
            color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.4)),
      ),
    );
  }

  // ── QUICK GOAL SHEET ──────────────────────────────────────────────────────
  void _openQuickGoal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final primary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    String? scorerId;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final pickingAssist = scorerId != null;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: border, borderRadius: BorderRadius.circular(99)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(pickingAssist ? 'Who assisted? (optional)' : 'Who scored?',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: primary)),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      if (pickingAssist)
                        _sheetTile('No assist', Icons.block, secondary, border, () {
                          _applyGoal(scorerId!, null);
                          Navigator.pop(ctx);
                        }),
                      ..._present
                          .where((p) => !pickingAssist || p.id != scorerId)
                          .map((p) => _playerTile(p, primary, secondary, border, () {
                                if (!pickingAssist) {
                                  setSheet(() => scorerId = p.id);
                                } else {
                                  _applyGoal(scorerId!, p.id);
                                  Navigator.pop(ctx);
                                }
                              })),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _applyGoal(String scorerId, String? assistId) {
    final scorer = _players.firstWhere((p) => p.id == scorerId);
    final assister = assistId == null
        ? null
        : _players.firstWhere((p) => p.id == assistId);
    setState(() {
      scorer.goals++;
      assister?.assists++;
    });
    // Realtime fans these out to every watcher.
    _pushStat(scorer, 'goals', scorer.goals);
    if (assister != null) _pushStat(assister, 'assists', assister.assists);
  }

  Widget _playerTile(_LivePlayer p, Color primary, Color secondary, Color border,
      VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              PlayerAvatar(fallbackInitials: p.name.substring(0, 1), radius: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(p.name,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 14, fontWeight: FontWeight.w600, color: primary)),
              ),
              Text('${p.position} · ${p.tier.label}',
                  style: GoogleFonts.inter(fontSize: 11, color: secondary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetTile(String label, IconData icon, Color secondary, Color border,
      VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: secondary),
              const SizedBox(width: 10),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w600, color: secondary)),
            ],
          ),
        ),
      ),
    );
  }

  // ── SUMMARY (after End Match) ───────────────────────────────────────────
  Widget _summary(bool isDark, Color primary, Color secondary) {
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    if (_submitted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [AppColors.pink, AppColors.orange]),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 34),
              ).animate().scale(
                  duration: 400.ms,
                  curve: Curves.elasticOut,
                  begin: const Offset(0.4, 0.4),
                  end: const Offset(1, 1)),
              const SizedBox(height: 16),
              Text('Stats submitted!',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 20, fontWeight: FontWeight.w800, color: primary)),
              const SizedBox(height: 6),
              Text('Players have 3 hours to review and dispute before XP is added.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 13, height: 1.5, color: secondary)),
              const SizedBox(height: 24),
              _gradientButton('Back to Dashboard',
                  () => context.safePop('agent-dashboard')),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        const SizedBox(height: 8),
        Text('Final: $_totalGoals goals',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 16, fontWeight: FontWeight.w700, color: primary)),
        const SizedBox(height: 4),
        Text('Review each player, then submit.',
            style: GoogleFonts.inter(fontSize: 12, color: secondary)),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            itemCount: _present.length,
            itemBuilder: (ctx, i) {
              final p = _present[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: surface,
                  border: Border.all(color: border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    PlayerAvatar(fallbackInitials: p.name.substring(0, 1), radius: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name,
                              style: GoogleFonts.spaceGrotesk(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: primary)),
                          Text('${p.goals}G · ${p.assists}A · GC ${p.goalsConceded} · ${p.goodBehavior == 1 ? "👍" : "👎"}',
                              style: GoogleFonts.inter(fontSize: 12, color: secondary)),
                        ],
                      ),
                    ),
                    Text('+${p.estXp} XP',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.orange)),
                  ],
                ),
              );
            },
          ),
        ),
        _bottomBar(
          child: _gradientButton('Submit Stats', () async {
            if (_submitted) return;
            setState(() => _submitted = true);
            try {
              // games.status = 'completed' + live stats copied to
              // player_stats with the 3-hour dispute window.
              await LiveMatchService.endMatch(widget.id);
              final g = ref.read(gamesProvider.notifier).byId(widget.id);
              if (g != null) {
                ref.read(gamesProvider.notifier).upsertLocal(g.copyWith(
                    live: false, ended: true, endedAt: DateTime.now()));
              }
              // Straight into the review panel: players can comment and the
              // agent can still correct stats during the window.
              if (mounted) {
                setState(() {
                  _review = true;
                  _loadingReview = true;
                });
                _loadReview();
              }
            } catch (_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content:
                        Text('Could not submit stats — check your connection')));
                setState(() => _submitted = false);
              }
            }
          }),
        ),
      ],
    );
  }

  // ── POST-MATCH REVIEW (3-hour dispute window) ────────────────────────────
  Widget _postMatch(bool isDark, Color primary, Color secondary) {
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    if (_loadingReview) {
      return const Center(
          child: CircularProgressIndicator(
              color: AppColors.orange, strokeWidth: 2.5));
    }
    if (_finalStats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('No stats were submitted for this match.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: secondary)),
        ),
      );
    }

    final windowOpen = _finalStats.any((s) =>
        s.status != 'confirmed' &&
        (s.confirmedAt?.isAfter(DateTime.now()) ?? false));
    final deadline = _finalStats
        .map((s) => s.confirmedAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
    String countdown = '';
    if (windowOpen && deadline != null) {
      final r = deadline.difference(DateTime.now());
      countdown = '${r.inHours}h ${r.inMinutes % 60}m';
    }

    return Column(
      children: [
        // Status banner
        Container(
          margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (windowOpen ? AppColors.orange : const Color(0xFF22C55E))
                .withValues(alpha: 0.08),
            border: Border.all(
                color:
                    (windowOpen ? AppColors.orange : const Color(0xFF22C55E))
                        .withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(windowOpen ? Icons.timer_outlined : Icons.verified_outlined,
                  size: 18,
                  color:
                      windowOpen ? AppColors.orange : const Color(0xFF22C55E)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  windowOpen
                      ? (_canEdit
                          ? 'Stats final in $countdown — you can still correct them. Player comments appear below.'
                          : 'Stats final in $countdown — leave a comment below if something looks wrong.')
                      : 'Stats are final — XP has been awarded.',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      height: 1.4,
                      color: windowOpen
                          ? AppColors.orange
                          : const Color(0xFF22C55E)),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            children: [
              // Column headers
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Expanded(child: SizedBox()),
                    for (final h in ['G', 'A', 'GC', 'GB'])
                      SizedBox(
                        width: h == 'GB' ? _gbW : _statW,
                        child: Text(h,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: secondary)),
                      ),
                  ],
                ),
              ),
              ..._finalStats.map(
                  (s) => _finalRow(s, windowOpen, primary, secondary, border, surface)),

              // Formal corrections go through the dispute flow; comments
              // below are for conversation.
              if (windowOpen) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () => context.pushNamed('dispute',
                        pathParameters: {'id': widget.id}),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: AppColors.tierElite.withValues(alpha: 0.6)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.flag_outlined,
                        size: 16, color: AppColors.tierElite),
                    label: Text(
                      _canEdit ? 'View disputes' : 'Dispute a stat',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.tierElite),
                    ),
                  ),
                ),
              ],

              // Comments
              const SizedBox(height: 18),
              Text('Comments',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: primary)),
              const SizedBox(height: 8),
              if (!_commentsReady)
                Text("Comments aren't available right now.",
                    style: GoogleFonts.inter(fontSize: 12, color: secondary))
              else if (_comments.isEmpty)
                Text(
                    windowOpen
                        ? 'No comments yet — players can message the agent here.'
                        : 'No comments were left for this match.',
                    style: GoogleFonts.inter(fontSize: 12, color: secondary))
              else
                ..._comments.map((c) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: surface,
                        border: Border.all(color: border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                  c.userId == SupabaseService.userId
                                      ? '${c.name} (you)'
                                      : c.name,
                                  style: GoogleFonts.spaceGrotesk(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: primary)),
                              const Spacer(),
                              Text(
                                  '${c.createdAt.hour}:${c.createdAt.minute.toString().padLeft(2, '0')}',
                                  style: GoogleFonts.inter(
                                      fontSize: 11, color: secondary)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(c.message,
                              style: GoogleFonts.inter(
                                  fontSize: 13, height: 1.4, color: primary)),
                        ],
                      ),
                    )),
            ],
          ),
        ),

        // Comment input — window open only
        if (windowOpen && _commentsReady)
          _bottomBar(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    maxLength: 300,
                    style: GoogleFonts.inter(fontSize: 13, color: primary),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: _canEdit
                          ? 'Reply to your players...'
                          : 'Message the agent about your stats...',
                      hintStyle:
                          GoogleFonts.inter(fontSize: 13, color: secondary),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.orange),
                      ),
                    ),
                    onSubmitted: (_) => _postComment(),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _postComment,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                          colors: [AppColors.pink, AppColors.orange]),
                    ),
                    child: _posting
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send,
                            size: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// One review row: stats are editable by the agent while the window is
  /// open, read-only for players; confirmed rows show the awarded XP.
  Widget _finalRow(FinalStatRow s, bool windowOpen, Color primary,
      Color secondary, Color border, Color surface) {
    final editable = _canEdit && windowOpen && s.status == 'pending';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: primary)),
                Text(
                    s.status == 'confirmed'
                        ? '+${s.xpEarned ?? 0} XP'
                        : s.position,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: s.status == 'confirmed'
                            ? AppColors.orange
                            : secondary)),
              ],
            ),
          ),
          SizedBox(
            width: _statW,
            child: editable
                ? _stepper(s.goals, () {
                    if (s.goals > 0) _editFinal(s, 'goals', s.goals - 1);
                  }, () => _editFinal(s, 'goals', s.goals + 1), primary)
                : _finalValue(s.goals, primary),
          ),
          SizedBox(
            width: _statW,
            child: editable
                ? _stepper(s.assists, () {
                    if (s.assists > 0) _editFinal(s, 'assists', s.assists - 1);
                  }, () => _editFinal(s, 'assists', s.assists + 1), primary)
                : _finalValue(s.assists, primary),
          ),
          SizedBox(
            width: _statW,
            child: editable
                ? _stepper(s.goalsConceded, () {
                    if (s.goalsConceded > 0) {
                      _editFinal(s, 'goals_conceded', s.goalsConceded - 1);
                    }
                  }, () => _editFinal(s, 'goals_conceded', s.goalsConceded + 1),
                    primary)
                : _finalValue(s.goalsConceded, primary),
          ),
          SizedBox(
            width: _gbW,
            child: GestureDetector(
              onTap: editable
                  ? () => _editFinal(
                      s, 'good_behavior', s.goodBehavior == 1 ? 0 : 1)
                  : null,
              child: Icon(
                s.goodBehavior == 1 ? Icons.thumb_up : Icons.thumb_down,
                size: 18,
                color: s.goodBehavior == 1
                    ? const Color(0xFF22C55E)
                    : AppColors.tierElite,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _finalValue(int v, Color primary) => Text('$v',
      textAlign: TextAlign.center,
      style: GoogleFonts.spaceGrotesk(
          fontSize: 16, fontWeight: FontWeight.w800, color: primary));

  // ── Shared bits ───────────────────────────────────────────────────────────
  Widget _bottomBar({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: border)),
      ),
      child: child,
    );
  }

  Widget _gradientButton(String label, VoidCallback? onTap, {double height = 52}) {
    final enabled = onTap != null;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(colors: [AppColors.pink, AppColors.orange])
              : null,
          color: enabled ? null : const Color(0xFF444444),
          borderRadius: BorderRadius.circular(14),
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: onTap,
          child: Text(label,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ),
    );
  }
}
