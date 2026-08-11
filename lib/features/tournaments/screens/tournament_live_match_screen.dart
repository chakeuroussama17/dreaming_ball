import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/tournament_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/nav.dart';

class TournamentLiveMatchScreen extends ConsumerStatefulWidget {
  final String id; // match id
  const TournamentLiveMatchScreen({super.key, required this.id});

  @override
  ConsumerState<TournamentLiveMatchScreen> createState() =>
      _TournamentLiveMatchScreenState();
}

class _TournamentLiveMatchScreenState
    extends ConsumerState<TournamentLiveMatchScreen> {
  TournamentMatch? _match;
  TournamentTeam? _teamA;
  TournamentTeam? _teamB;
  bool _loading = true;
  bool _canEdit = false;

  int _scoreA = 0, _scoreB = 0;
  String _status = 'scheduled';

  final _presentA = <String>{};
  final _presentB = <String>{};

  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final m = await TournamentService.fetchMatch(widget.id);
      if (m == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final t = await TournamentService.fetchTournament(m.tournamentId);
      final teams = await TournamentService.fetchTeams(m.tournamentId);
      TournamentTeam? find(String? id) {
        for (final x in teams) {
          if (x.id == id) return x;
        }
        return null;
      }

      if (!mounted) return;
      setState(() {
        _match = m;
        _teamA = find(m.teamAId);
        _teamB = find(m.teamBId);
        _canEdit = t?.mine ?? false;
        _scoreA = m.teamAScore ?? 0;
        _scoreB = m.teamBScore ?? 0;
        _status = m.status;
        _presentA.addAll(_teamA?.players.map((p) => p.playerId) ?? const []);
        _presentB.addAll(_teamB?.players.map((p) => p.playerId) ?? const []);
        _loading = false;
      });
      if (_status == 'live') _startTimer();
      _subscribe();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribe() {
    _sub = TournamentService.matchStream(widget.id).listen((rows) {
      if (!mounted || rows.isEmpty) return;
      final r = rows.first;
      setState(() {
        _scoreA = (r['team_a_score'] ?? _scoreA) as int;
        _scoreB = (r['team_b_score'] ?? _scoreB) as int;
        final s = (r['status'] ?? _status) as String;
        if (s == 'live' && _status != 'live') _startTimer();
        _status = s;
      });
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  bool get _windowOpen {
    final at = _match?.scheduledAt;
    if (at == null) return true; // unscheduled — allow owner to run it
    return DateTime.now()
        .isAfter(at.subtract(const Duration(minutes: 30)));
  }

  // Organiser's discretion — only needs at least one present player per side
  // to start (keeps small/test squads playable).
  int get _minPerSide => 1;

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

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: primary),
          onPressed: () => context.safePop('tournaments'),
        ),
        title: Text(_match?.roundName ?? 'Match',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 18, fontWeight: FontWeight.w700, color: primary)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.gold))
          : _match == null
              ? Center(
                  child: Text('Match not found',
                      style: GoogleFonts.inter(color: secondary)))
              : _body(primary, secondary, border, surface),
    );
  }

  Widget _body(Color primary, Color secondary, Color border, Color surface) {
    if (_status == 'completed') {
      return _completedView(primary, secondary, surface, border);
    }
    if (_status == 'live') {
      return _liveView(primary, secondary, border, surface);
    }
    // Pre-match.
    if (_canEdit && _windowOpen) {
      return _attendanceView(primary, secondary, border, surface);
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_clock, size: 48, color: secondary),
            const SizedBox(height: 14),
            Text(
              _windowOpen
                  ? 'Waiting for the organiser to start the match.'
                  : 'This match opens 30 minutes before kick-off.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: secondary),
            ),
          ],
        ),
      ),
    );
  }

  // ── Attendance (owner) ───────────────────────────────────────────────────
  Widget _attendanceView(
      Color primary, Color secondary, Color border, Color surface) {
    final okA = _presentA.length >= _minPerSide;
    final okB = _presentB.length >= _minPerSide;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Check Attendance',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 18, fontWeight: FontWeight.w700, color: primary)),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: _rosterColumn(_teamA, _presentA, primary, secondary,
                      border, surface)),
              Container(width: 1, color: border),
              Expanded(
                  child: _rosterColumn(_teamB, _presentB, primary, secondary,
                      border, surface)),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: (okA && okB)
                      ? const LinearGradient(
                          colors: [AppColors.goldActionStart, AppColors.goldActionEnd])
                      : null,
                  color: (okA && okB) ? null : AppColors.darkTextMuted,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: (okA && okB) ? _start : null,
                  child: Text(
                      (okA && okB)
                          ? 'Start Match'
                          : 'Need $_minPerSide+ per team',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _rosterColumn(TournamentTeam? team, Set<String> present, Color primary,
      Color secondary, Color border, Color surface) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(team?.name ?? 'Team',
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
                fontSize: 14, fontWeight: FontWeight.w800, color: primary)),
        const SizedBox(height: 10),
        for (final p in team?.players ?? const <TournamentPlayer>[])
          GestureDetector(
            onTap: () => setState(() {
              if (present.contains(p.playerId)) {
                present.remove(p.playerId);
              } else {
                present.add(p.playerId);
              }
            }),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: surface,
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                      present.contains(p.playerId)
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      size: 18,
                      color: present.contains(p.playerId)
                          ? AppColors.success
                          : secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: primary)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── Live scoring ─────────────────────────────────────────────────────────
  Widget _liveView(
      Color primary, Color secondary, Color border, Color surface) {
    final mm = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Column(
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.tierElite.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('🔴', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 5),
                Text('LIVE  $mm:$ss',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.tierElite)),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 26),
        // Score
        Row(
          children: [
            Expanded(child: _scoreSide(_teamA, _scoreA, primary, secondary)),
            Text('-',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 40, fontWeight: FontWeight.w800, color: secondary)),
            Expanded(child: _scoreSide(_teamB, _scoreB, primary, secondary)),
          ],
        ),
        const Spacer(),
        if (_canEdit) ...[
          Row(
            children: [
              Expanded(
                  child: _goalBtn(_teamA?.name ?? 'Team A', () => _goal(true))),
              const SizedBox(width: 12),
              Expanded(
                  child: _goalBtn(_teamB?.name ?? 'Team B', () => _goal(false))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _undoBtn(() => _undo(true), secondary, border)),
              const SizedBox(width: 12),
              Expanded(child: _undoBtn(() => _undo(false), secondary, border)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: _end,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.tierElite.withValues(alpha: 0.6)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('End Match',
                  style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w700, color: AppColors.tierElite)),
            ),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('🔴 LIVE — watching ${_match?.roundName ?? ''}',
                style: GoogleFonts.inter(fontSize: 13, color: secondary)),
          ),
        SafeArea(top: false, child: const SizedBox(height: 8)),
      ],
    );
  }

  Widget _scoreSide(TournamentTeam? team, int score, Color primary,
      Color secondary) {
    return Column(
      children: [
        if (team?.logoUrl != null)
          CircleAvatar(radius: 28, backgroundImage: NetworkImage(team!.logoUrl!))
        else
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.gold.withValues(alpha: 0.18),
            child: Text((team?.name ?? '?').substring(0, 1),
                style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w800, color: AppColors.gold)),
          ),
        const SizedBox(height: 8),
        ShaderMask(
          shaderCallback: (b) => AppColors.brandGradient.createShader(b),
          child: Text('$score',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 64,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ),
        Text(team?.name ?? '—',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w600, color: primary)),
      ],
    );
  }

  Widget _goalBtn(String team, VoidCallback onTap) => SizedBox(
        height: 64,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient:
                const LinearGradient(colors: [AppColors.goldActionStart, AppColors.goldActionEnd]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: onTap,
            child: Text('⚽  $team',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
        ),
      );

  Widget _undoBtn(VoidCallback onTap, Color secondary, Color border) => SizedBox(
        height: 36,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: border),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text('−1',
              style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w700, color: secondary)),
        ),
      );

  Future<void> _start() async {
    await TournamentService.startMatch(widget.id);
    if (mounted) {
      setState(() => _status = 'live');
      _startTimer();
    }
  }

  Future<void> _goal(bool teamA) async {
    setState(() => teamA ? _scoreA++ : _scoreB++);
    await TournamentService.updateScore(widget.id, _scoreA, _scoreB);
  }

  Future<void> _undo(bool teamA) async {
    setState(() {
      if (teamA && _scoreA > 0) _scoreA--;
      if (!teamA && _scoreB > 0) _scoreB--;
    });
    await TournamentService.updateScore(widget.id, _scoreA, _scoreB);
  }

  Future<void> _end() async {
    final isGroup = _match?.isGroup ?? false;
    String? winnerId;
    if (_scoreA > _scoreB) {
      winnerId = _teamA?.id;
    } else if (_scoreB > _scoreA) {
      winnerId = _teamB?.id;
    } else if (isGroup) {
      // Group-stage draw stands as a draw (both teams get a point) — no
      // penalties, no winner. Standings are computed from the score.
      winnerId = null;
    } else {
      // Knockout draw → must be decided on penalties to advance someone.
      winnerId = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Draw — penalties'),
          content: const Text('Who won on penalties?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, _teamA?.id),
                child: Text(_teamA?.name ?? 'Team A')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, _teamB?.id),
                child: Text(_teamB?.name ?? 'Team B')),
          ],
        ),
      );
      if (winnerId == null) return; // cancelled
    }

    // Knockout matches must resolve to a winner; group matches may be a draw.
    if (!isGroup && winnerId == null) return;
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End match?'),
        content: Text('Final score $_scoreA - $_scoreB. End match?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('End')),
        ],
      ),
    );
    if (confirm != true) return;
    await TournamentService.endMatch(widget.id, winnerId);
    if (mounted) context.safePop('tournaments');
  }

  // ── Completed ──────────────────────────────────────────────────────────────
  Widget _completedView(
      Color primary, Color secondary, Color surface, Color border) {
    final winName = _match?.winnerTeamId == _teamA?.id
        ? _teamA?.name
        : _match?.winnerTeamId == _teamB?.id
            ? _teamB?.name
            : null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified, size: 48, color: AppColors.success),
            const SizedBox(height: 12),
            Text('Full time',
                style: GoogleFonts.inter(fontSize: 13, color: secondary)),
            const SizedBox(height: 8),
            Text('${_teamA?.name ?? 'A'}  $_scoreA - $_scoreB  ${_teamB?.name ?? 'B'}',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: primary)),
            if (winName != null) ...[
              const SizedBox(height: 12),
              Text('Winner: $winName',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gold)),
            ],
          ],
        ),
      ),
    );
  }
}
