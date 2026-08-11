import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/providers/content_providers.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/player_avatar.dart';
import '../../../../core/widgets/tier_badge.dart';

class _Ranked {
  final int rank;
  final String name, position;
  final PlayerTier tier;
  final int xp;
  final bool isYou;
  final String? avatarUrl;
  const _Ranked({
    required this.rank,
    required this.name,
    required this.position,
    required this.tier,
    required this.xp,
    this.isYou = false,
    this.avatarUrl,
  });
}

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  static const _positions = ['All', 'GK', 'Defender', 'Midfielder', 'Striker'];
  String _selectedPosition = 'All';

  // Filter sheet selections
  String _filterPosition = 'All';
  String _filterAge = 'All';
  String _filterPeriod = 'All Time';

  static _Ranked _toRanked(LeaderboardEntry e) => _Ranked(
        rank: e.rank,
        name: e.name,
        position: e.position,
        tier: playerTierFromLabel(e.tier),
        xp: e.xp,
        isYou: e.isYou,
        avatarUrl: e.avatarUrl,
      );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final primary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    // Pill + sheet filters all re-fetch through the provider family.
    final period = _filterPeriod == 'This Week' ? 'this_week' : 'all_time';
    // Position pill wins; otherwise fall back to the sheet's position filter.
    final pos =
        _selectedPosition != 'All' ? _selectedPosition : _filterPosition;
    final asyncEntries =
        ref.watch(leaderboardProvider('$pos|$period|$_filterAge'));

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShaderMask(
                    shaderCallback: (b) =>
                        AppColors.brandGradient.createShader(b),
                    child: Text(
                      'Rankings',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.tune, color: primary),
                    onPressed: () => _openFilterSheet(isDark),
                  ),
                ],
              ),
            ),

            // ── Scrollable body ─────────────────────────────────────────────
            Expanded(
              child: asyncEntries.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.gold, strokeWidth: 2.5)),
                error: (_, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Couldn't load rankings",
                          style: GoogleFonts.inter(
                              fontSize: 13, color: secondary)),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () => ref.invalidate(leaderboardProvider),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.gold),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Retry',
                            style: GoogleFonts.spaceGrotesk(
                                fontWeight: FontWeight.w700,
                                color: AppColors.gold)),
                      ),
                    ],
                  ),
                ),
                data: (entries) {
                  final list = [for (final e in entries) _toRanked(e)];
                  final podium = list.take(3).toList();
                  final restRows = list.where((p) => p.rank > 3).toList();
                  _Ranked? you;
                  for (final p in list) {
                    if (p.isYou) you = p;
                  }
                  return Column(
                    children: [
                      Expanded(
                        child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  if (podium.length == 3)
                    _Podium(podium: podium)
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.08, end: 0),

                  const SizedBox(height: 16),

                  // Filter pills
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      itemCount: _positions.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (ctx, i) {
                        final active = _positions[i] == _selectedPosition;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedPosition = _positions[i]),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              gradient:
                                  active ? AppColors.brandGradient : null,
                              border: Border.all(
                                color: active ? Colors.transparent : border,
                              ),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              _positions[i],
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight:
                                    active ? FontWeight.w600 : FontWeight.w400,
                                color: active ? Colors.white : secondary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  // List rank >= 4
                  if (restRows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Text(
                          'No more players for this filter',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: secondary),
                        ),
                      ),
                    )
                  else
                    ...List.generate(restRows.length, (i) {
                      final p = restRows[i];
                      return Column(
                        children: [
                          _LeaderRow(
                            data: p,
                            primary: primary,
                            secondary: secondary,
                          ),
                          if (i != restRows.length - 1)
                            Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : Colors.black.withValues(alpha: 0.04),
                            ),
                        ],
                      );
                    }),
                ],
                        ),
                      ),

                      // ── Pinned "your rank" row ──────────────────────────
                      if (you != null && you.rank > 3)
                        _PinnedYouRow(
                          you: you,
                          allAbove: list,
                          primary: primary,
                          secondary: secondary,
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(current: 2),
    );
  }

  // ── Filter bottom sheet ───────────────────────────────────────────────────
  void _openFilterSheet(bool isDark) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final primary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        var pos = _filterPosition;
        var age = _filterAge;
        var period = _filterPeriod;

        return StatefulBuilder(
          builder: (ctx, setSheet) {
            Widget group(String title, List<String> options, String selected,
                ValueChanged<String> onPick) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: secondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: options.map((o) {
                      final active = o == selected;
                      return GestureDetector(
                        onTap: () => setSheet(() => onPick(o)),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            gradient: active ? AppColors.brandGradient : null,
                            border: Border.all(
                              color: active ? Colors.transparent : border,
                            ),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            o,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight:
                                  active ? FontWeight.w600 : FontWeight.w400,
                              color: active ? Colors.white : secondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              );
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Filter Rankings',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  group('Position', const [
                    'All', 'GK', 'Defender', 'Midfielder', 'Striker'
                  ], pos, (v) => pos = v),
                  const SizedBox(height: 18),
                  group('Age Group', const [
                    'All', 'Under 16', '16-20', '21-25', '26-30', '30+'
                  ], age, (v) => age = v),
                  const SizedBox(height: 18),
                  group('Time Period',
                      const ['All Time', 'This Month', 'This Week'], period,
                      (v) => period = v),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: OutlinedButton(
                            onPressed: () => setSheet(() {
                              pos = 'All';
                              age = 'All';
                              period = 'All Time';
                            }),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              'Reset',
                              style: GoogleFonts.spaceGrotesk(
                                fontWeight: FontWeight.w700,
                                color: secondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.goldActionStart, AppColors.goldActionEnd],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _filterPosition = pos;
                                  _filterAge = age;
                                  _filterPeriod = period;
                                  _selectedPosition = pos;
                                });
                                Navigator.of(ctx).pop();
                              },
                              child: Text(
                                'Apply',
                                style: GoogleFonts.spaceGrotesk(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── Podium ──────────────────────────────────────────────────────────────────

class _Podium extends StatelessWidget {
  final List<_Ranked> podium; // [#1, #2, #3]
  const _Podium({required this.podium});

  @override
  Widget build(BuildContext context) {
    final first = podium[0];
    final second = podium.length > 1 ? podium[1] : null;
    final third = podium.length > 2 ? podium[2] : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: second == null
                ? const SizedBox()
                : _PodiumPlayer(
                    data: second,
                    avatarRadius: 26,
                    blockHeight: 50,
                    blockColor: Colors.white.withValues(alpha: 0.1),
                    showCrown: false,
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _PodiumPlayer(
              data: first,
              avatarRadius: 32,
              blockHeight: 70,
              blockGradient: const LinearGradient(
                colors: [AppColors.goldActionStart, AppColors.goldActionEnd],
              ),
              showCrown: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: third == null
                ? const SizedBox()
                : _PodiumPlayer(
                    data: third,
                    avatarRadius: 26,
                    blockHeight: 40,
                    blockColor: Colors.white.withValues(alpha: 0.08),
                    showCrown: false,
                  ),
          ),
        ],
      ),
    );
  }
}

class _PodiumPlayer extends StatelessWidget {
  final _Ranked data;
  final double avatarRadius;
  final double blockHeight;
  final Color? blockColor;
  final Gradient? blockGradient;
  final bool showCrown;

  const _PodiumPlayer({
    required this.data,
    required this.avatarRadius,
    required this.blockHeight,
    this.blockColor,
    this.blockGradient,
    required this.showCrown,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showCrown)
          const Text('👑', style: TextStyle(fontSize: 22))
        else
          const SizedBox(height: 22),
        const SizedBox(height: 4),
        PlayerAvatar(
          imageUrl: data.avatarUrl,
          fallbackInitials: data.name.substring(0, 1),
          radius: avatarRadius,
        ),
        const SizedBox(height: 6),
        Text(
          data.name,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        TierBadge(tier: data.tier),
        const SizedBox(height: 4),
        Text(
          '${_formatXp(data.xp)} XP',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.gold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: blockHeight,
          decoration: BoxDecoration(
            color: blockColor,
            gradient: blockGradient,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '#${data.rank}',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Leaderboard row ───────────────────────────────────────────────────────────

class _LeaderRow extends StatelessWidget {
  final _Ranked data;
  final Color primary, secondary;
  const _LeaderRow({
    required this.data,
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final highlight = data.isYou;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: highlight ? 12 : 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: highlight
          ? BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.08),
              border: const Border(
                left: BorderSide(color: AppColors.gold, width: 3),
              ),
              borderRadius: BorderRadius.circular(10),
            )
          : null,
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#${data.rank}',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: secondary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          PlayerAvatar(
            imageUrl: data.avatarUrl,
            fallbackInitials: data.name.substring(0, 1),
            radius: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        data.name,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (highlight) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(you)',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gold,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      data.position,
                      style: GoogleFonts.inter(fontSize: 11, color: secondary),
                    ),
                    Text('  ·  ',
                        style:
                            GoogleFonts.inter(fontSize: 11, color: secondary)),
                    Text(
                      '${data.tier.emoji} ${data.tier.label}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: data.tier.color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_formatXp(data.xp)} XP',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.gold,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pinned "you" row ──────────────────────────────────────────────────────────

class _PinnedYouRow extends StatelessWidget {
  final _Ranked you;
  final List<_Ranked> allAbove;
  final Color primary, secondary;
  const _PinnedYouRow({
    required this.you,
    required this.allAbove,
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    // XP gap to the next rank up
    final above = allAbove.where((p) => p.rank == you.rank - 1).toList();
    final gapText = above.isEmpty
        ? "You're at the top!"
        : '${_formatXp(above.first.xp - you.xp)} XP to reach rank #${above.first.rank}';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.06),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  '#${you.rank}',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.gold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              PlayerAvatar(
                imageUrl: you.avatarUrl,
                fallbackInitials: you.name.substring(0, 1),
                radius: 16,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        you.name,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(you)',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gold,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${_formatXp(you.xp)} XP',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 38),
            child: Text(
              gapText,
              style: GoogleFonts.inter(fontSize: 11, color: secondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared helper ─────────────────────────────────────────────────────────────

String _formatXp(int v) {
  final s = v.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
