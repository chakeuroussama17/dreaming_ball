import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/nav.dart';
import '../../../../core/widgets/player_avatar.dart';
import '../../../../core/widgets/tier_badge.dart';

class _Attendee {
  final String name, position, joined;
  final PlayerTier tier;
  bool present = false;
  _Attendee({
    required this.name,
    required this.position,
    required this.joined,
    required this.tier,
  });
}

class AttendanceScreen extends StatefulWidget {
  final String id;
  const AttendanceScreen({super.key, required this.id});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  static const _gameName = 'ABC Football Field · 5-aside';

  late DateTime _kickoff;
  Timer? _timer;
  Duration _remaining = Duration.zero;

  final _players = <_Attendee>[
    _Attendee(name: 'Karim R.', position: 'GK', joined: '2 days ago', tier: PlayerTier.legend),
    _Attendee(name: 'Ahmed M.', position: 'Midfielder', joined: '3 days ago', tier: PlayerTier.platinum),
    _Attendee(name: 'Youssef S.', position: 'Defender', joined: '1 day ago', tier: PlayerTier.diamond),
    _Attendee(name: 'Omar B.', position: 'Defender', joined: '5 hours ago', tier: PlayerTier.gold),
    _Attendee(name: 'Imran M.', position: 'Striker', joined: '4 days ago', tier: PlayerTier.silver),
    _Attendee(name: 'Farid K.', position: 'Midfielder', joined: '2 days ago', tier: PlayerTier.bronze),
    _Attendee(name: 'Zaid A.', position: 'GK', joined: '6 hours ago', tier: PlayerTier.silver),
    _Attendee(name: 'Haris N.', position: 'Striker', joined: '1 day ago', tier: PlayerTier.bronze),
    _Attendee(name: 'Adam S.', position: 'Defender', joined: '3 days ago', tier: PlayerTier.beginner),
    _Attendee(name: 'Bilal T.', position: 'Midfielder', joined: '2 days ago', tier: PlayerTier.gold),
    _Attendee(name: 'Nabil R.', position: 'Striker', joined: '7 hours ago', tier: PlayerTier.silver),
    _Attendee(name: 'Sami L.', position: 'Defender', joined: '1 day ago', tier: PlayerTier.bronze),
  ];

  int get _present => _players.where((p) => p.present).length;
  int get _absent => _players.where((p) => !p.present).length;

  @override
  void initState() {
    super.initState();
    _kickoff = DateTime.now().add(const Duration(hours: 2, minutes: 34));
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final r = _kickoff.difference(DateTime.now());
    if (mounted) setState(() => _remaining = r.isNegative ? Duration.zero : r);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _countdown {
    final h = _remaining.inHours;
    final m = _remaining.inMinutes % 60;
    final s = _remaining.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    return '${m}m ${s}s';
  }

  void _start() {
    if (_present < 4) return;
    if (_present < 8) {
      showDialog<void>(
        context: context,
        builder: (ctx) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
          final primary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
          final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
          return AlertDialog(
            backgroundColor: surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Text('Low turnout',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 18, fontWeight: FontWeight.w700, color: primary)),
            content: Text(
              'Only $_present present — minimum for a game is 4. Continue?',
              style: GoogleFonts.inter(fontSize: 14, color: secondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, color: secondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  context.pushNamed('stats-entry', pathParameters: {'id': widget.id});
                },
                child: const Text('Continue', style: TextStyle(color: AppColors.navyDeep)),
              ),
            ],
          );
        },
      );
      return;
    }
    context.pushNamed('stats-entry', pathParameters: {'id': widget.id});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final primary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    final enough = _present >= 4;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: primary),
          onPressed: () => context.safePop(),
        ),
        title: Column(
          children: [
            Text('Attendance',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 18, fontWeight: FontWeight.w700, color: primary)),
            Text(_gameName, style: GoogleFonts.inter(fontSize: 11, color: secondary)),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          if (_remaining > Duration.zero)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.schedule, size: 16, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Text('Game starts in $_countdown',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.gold)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Mark Attendance ($_present/${_players.length})',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 16, fontWeight: FontWeight.w700, color: primary)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    for (final p in _players) {
                      p.present = true;
                    }
                  }),
                  child: Text('Mark All Present',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600, color: AppColors.gold)),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    for (final p in _players) {
                      p.present = false;
                    }
                  }),
                  child: Text('Reset All',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600, color: secondary)),
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
                      PlayerAvatar(fallbackInitials: p.name.substring(0, 1), radius: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(p.name,
                                      style: GoogleFonts.spaceGrotesk(
                                          fontSize: 14, fontWeight: FontWeight.w700, color: primary),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                                const SizedBox(width: 6),
                                Text('· ${p.position}',
                                    style: GoogleFonts.inter(fontSize: 11, color: secondary)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                TierBadge(tier: p.tier),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text('Joined ${p.joined}',
                                      style: GoogleFonts.inter(fontSize: 11, color: secondary),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _presentButton(p, border, secondary),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            color: surface,
            child: Text('Present: $_present · Absent: $_absent · Not marked: 0',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: secondary)),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
        color: surface,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: enough
                  ? const LinearGradient(colors: [AppColors.goldActionStart, AppColors.goldActionEnd])
                  : null,
              color: enough ? null : AppColors.darkTextMuted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: enough ? _start : null,
              child: Text('Start Game ($_present present)',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ),
      ).animate().fadeIn(duration: 300.ms),
    );
  }

  Widget _presentButton(_Attendee p, Color border, Color secondary) {
    if (p.present) {
      return GestureDetector(
        onTap: () => setState(() => p.present = false),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.success,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check, size: 14, color: Colors.white),
              const SizedBox(width: 4),
              Text('Present',
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: () => setState(() => p.present = true),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text('Mark Present',
            style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w600, color: secondary)),
      ),
    );
  }
}
