import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import 'tier_badge.dart';

/// A single stat displayed in the FIFA-style card grid.
class PlayerStat {
  final IconData icon;
  final String label;
  final int value;
  const PlayerStat({
    required this.icon,
    required this.label,
    required this.value,
  });
}

/// Tier-specific background for the card.
///
/// Every tier sits on the crest navy, tinted by its own metal — so the cards
/// stay unmistakably Boundless while still reading as eight distinct ranks.
/// The gradient runs light-to-dark diagonally, which is what gives the flat
/// panel its sense of a lit surface.
LinearGradient _tierGradient(PlayerTier tier) {
  final tint = tier.color;
  return LinearGradient(
    colors: [
      Color.lerp(AppColors.navySurface, tint, 0.18)!,
      Color.lerp(AppColors.navyDeep, tint, 0.06)!,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Faint grid-line overlay painted across the card background.
class _GridLinesPainter extends CustomPainter {
  final Color color;
  const _GridLinesPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridLinesPainter oldDelegate) =>
      oldDelegate.color != color;
}

class PlayerStatCard extends StatelessWidget {
  final String name;
  final String positionAbbr;
  final PlayerTier tier;
  final int overall;
  final int xp;
  final List<PlayerStat> stats; // 6 stats for the 2x3 grid
  final int games;
  final int winRate; // percentage

  const PlayerStatCard({
    super.key,
    required this.name,
    required this.positionAbbr,
    required this.tier,
    required this.overall,
    required this.xp,
    required this.stats,
    required this.games,
    required this.winRate,
  });

  String _formatXp(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final tierColor = tier.color;

    return Container(
      width: double.infinity,
      height: 410,
      decoration: BoxDecoration(
        gradient: _tierGradient(tier),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tierColor, width: 1.5),
        // The card is the hero object on the profile — it gets the deepest
        // elevation in the app, haloed in its own tier colour.
        boxShadow: [
          BoxShadow(
            color: tierColor.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
          const BoxShadow(
            color: Color(0x8C000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // ── Grid lines overlay ──────────────────────────────────────────
            Positioned.fill(
              child: CustomPaint(
                painter:
                    _GridLinesPainter(Colors.white.withValues(alpha: 0.03)),
              ),
            ),

            // ── Gloss sweep — a diagonal light across the card face ─────────
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: const [0.0, 0.42, 0.62],
                    colors: [
                      Colors.white.withValues(alpha: 0.09),
                      Colors.white.withValues(alpha: 0.02),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ── Watermark rating top-right ──────────────────────────────────
            Positioned(
              top: -16,
              right: 10,
              child: Text(
                '$overall',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 100,
                  fontWeight: FontWeight.w800,
                  color: tierColor.withValues(alpha: 0.06),
                ),
              ),
            ),

            // ── Content ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top section: rating + position vs name + tier + xp
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$overall',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 60,
                              fontWeight: FontWeight.w800,
                              color: tierColor,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            positionAbbr,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkTextSecondary,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            TierBadge(tier: tier),
                            const SizedBox(height: 8),
                            Text(
                              'XP: ${_formatXp(xp)}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Stats 2x3 grid
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 3,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.5,
                      children: stats
                          .map((s) => _StatCell(stat: s, tierColor: tierColor))
                          .toList(),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Brand label, stamped in gold foil
                  ShaderMask(
                    shaderCallback: (b) =>
                        AppColors.brandGradient.createShader(b),
                    child: Text(
                      'BOUNDLESS F.C.',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [tierColor, tierColor.withValues(alpha: 0.0)],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Career numbers
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _CareerStat(label: 'Games', value: '$games'),
                      _CareerStat(label: 'Win Rate', value: '$winRate%'),
                      _CareerStat(label: 'Total XP', value: _formatXp(xp)),
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

class _StatCell extends StatelessWidget {
  final PlayerStat stat;
  final Color tierColor;
  const _StatCell({required this.stat, required this.tierColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(stat.icon, size: 11, color: tierColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  stat.label.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkTextSecondary,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${stat.value}',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _CareerStat extends StatelessWidget {
  final String label;
  final String value;
  const _CareerStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: AppColors.darkTextSecondary,
          ),
        ),
      ],
    );
  }
}
