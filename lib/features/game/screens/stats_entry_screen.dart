import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/nav.dart';
import '../../../../core/widgets/player_avatar.dart';
import '../../../../core/widgets/tier_badge.dart';

class _PlayerStatEntry {
  final String name, position;
  final PlayerTier tier;
  int goals = 0;
  int assists = 0;
  int cleanSheets = 0;
  int spirit = 0; // 0–5
  final TextEditingController notes = TextEditingController();

  _PlayerStatEntry({required this.name, required this.position, required this.tier});

  bool get isKeeperOrDefender => position == 'GK' || position == 'Defender';

  /// Position-specific XP + fighting-spirit bonus (per spec).
  int get estXp {
    final positionXp = switch (position) {
      'Striker' => goals * 10 + assists * 5,
      'Midfielder' => assists * 10 + goals * 5,
      'Defender' => cleanSheets * 15 + spirit * 3,
      'GK' => cleanSheets * 20 + spirit * 5,
      _ => goals * 8 + assists * 6,
    };
    final fightingBonus = spirit * 10; // 10–50 XP, all positions
    return positionXp + fightingBonus;
  }
}

class StatsEntryScreen extends StatefulWidget {
  final String id;
  const StatsEntryScreen({super.key, required this.id});

  @override
  State<StatsEntryScreen> createState() => _StatsEntryScreenState();
}

class _StatsEntryScreenState extends State<StatsEntryScreen> {
  static const _gameName = 'ABC Football Field · Jun 8';

  final _players = [
    _PlayerStatEntry(name: 'Karim R.', position: 'GK', tier: PlayerTier.legend),
    _PlayerStatEntry(name: 'Ahmed M.', position: 'Midfielder', tier: PlayerTier.platinum),
    _PlayerStatEntry(name: 'Youssef S.', position: 'Defender', tier: PlayerTier.diamond),
    _PlayerStatEntry(name: 'Omar B.', position: 'Defender', tier: PlayerTier.gold),
    _PlayerStatEntry(name: 'Imran M.', position: 'Striker', tier: PlayerTier.silver),
    _PlayerStatEntry(name: 'Farid K.', position: 'Midfielder', tier: PlayerTier.bronze),
  ];

  bool _submitted = false;
  DateTime? _windowCloses;
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void dispose() {
    _timer?.cancel();
    for (final p in _players) {
      p.notes.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final missing = _players.where((p) => p.spirit == 0).toList();
    if (missing.isNotEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
      final primary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
      final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('Missing ratings',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 18, fontWeight: FontWeight.w700, color: primary)),
          content: Text(
            "Some players don't have a fighting spirit rating. Are you sure you want to submit?",
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
                backgroundColor: AppColors.gold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _finalize();
              },
              child: const Text('Submit', style: TextStyle(color: AppColors.navyDeep)),
            ),
          ],
        ),
      );
      return;
    }
    _finalize();
  }

  void _finalize() {
    setState(() {
      _submitted = true;
      _windowCloses = DateTime.now().add(const Duration(hours: 3));
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final d = _windowCloses!.difference(DateTime.now());
      setState(() => _remaining = d.isNegative ? Duration.zero : d);
    });
  }

  String get _closesAt =>
      _windowCloses == null ? '' : TimeOfDay.fromDateTime(_windowCloses!).format(context);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final primary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

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
            Text('Enter Stats',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 18, fontWeight: FontWeight.w700, color: primary)),
            Text(_gameName, style: GoogleFonts.inter(fontSize: 11, color: secondary)),
          ],
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.schedule, size: 16, color: AppColors.gold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Stats must be entered within 3 hours of game end. Players can dispute during this window.',
                    style: GoogleFonts.inter(fontSize: 12, height: 1.4, color: AppColors.gold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(_players.length, (i) {
            return _playerCard(_players[i], primary, secondary, border, surface)
                .animate()
                .fadeIn(delay: (i * 60).ms, duration: 300.ms);
          }),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
        color: surface,
        child: _submitted
            ? Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                        const SizedBox(width: 8),
                        Text('Stats submitted!',
                            style: GoogleFonts.spaceGrotesk(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Players have 3 hours to review and dispute.',
                        style: GoogleFonts.inter(fontSize: 12, color: secondary)),
                    Text(
                      'Window closes at $_closesAt · ${_remaining.inHours}h ${_remaining.inMinutes % 60}m left',
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.gold),
                    ),
                  ],
                ),
              )
            : SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.goldActionStart, AppColors.goldActionEnd]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _submit,
                    child: Text('Submit All Stats',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _playerCard(_PlayerStatEntry p, Color primary, Color secondary,
      Color border, Color surface) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PlayerAvatar(fallbackInitials: p.name.substring(0, 1), radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${p.name} · ${p.position}',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 14, fontWeight: FontWeight.w700, color: primary)),
                    const SizedBox(height: 4),
                    TierBadge(tier: p.tier),
                  ],
                ),
              ),
            ],
          ),
          Divider(height: 24, color: border),
          _counterRow('Goals', p.goals, (v) => setState(() => p.goals = v), primary, secondary),
          const SizedBox(height: 10),
          _counterRow('Assists', p.assists, (v) => setState(() => p.assists = v), primary, secondary),
          if (p.isKeeperOrDefender) ...[
            const SizedBox(height: 10),
            _counterRow('Clean Sheets', p.cleanSheets,
                (v) => setState(() => p.cleanSheets = v), primary, secondary),
          ],
          const SizedBox(height: 16),
          Text('Fighting Spirit',
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w500, color: secondary)),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (i) {
              final filled = i < p.spirit;
              return GestureDetector(
                onTap: () => setState(() => p.spirit = i + 1),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(filled ? Icons.star : Icons.star_border,
                      size: 28,
                      color: filled ? AppColors.gold : secondary.withValues(alpha: 0.5)),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: p.notes,
            maxLength: 100,
            style: GoogleFonts.inter(fontSize: 13, color: primary),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'Notes (optional)',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: secondary),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.gold),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('Est. XP: +${p.estXp}',
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.gold)),
        ],
      ),
    );
  }

  Widget _counterRow(String label, int value, ValueChanged<int> onChanged,
      Color primary, Color secondary) {
    return Row(
      children: [
        Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 14, color: secondary))),
        _counterBtn(Icons.remove, value > 0, () => onChanged(value > 0 ? value - 1 : 0)),
        SizedBox(
          width: 44,
          child: Text('$value',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 22, fontWeight: FontWeight.w800, color: primary)),
        ),
        _counterBtn(Icons.add, true, () => onChanged(value + 1)),
      ],
    );
  }

  Widget _counterBtn(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: enabled
              ? const LinearGradient(colors: [AppColors.goldActionStart, AppColors.goldActionEnd])
              : null,
          color: enabled ? null : AppColors.darkTextMuted,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
