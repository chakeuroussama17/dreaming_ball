import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

enum PlayerTier { beginner, bronze, silver, gold, platinum, diamond, elite, legend }

/// Maps a current_tier string from Supabase ('Gold', 'Legend'…) to the enum.
PlayerTier playerTierFromLabel(String? label) {
  return switch (label) {
    'Bronze' => PlayerTier.bronze,
    'Silver' => PlayerTier.silver,
    'Gold' => PlayerTier.gold,
    'Platinum' => PlayerTier.platinum,
    'Diamond' => PlayerTier.diamond,
    'Elite' => PlayerTier.elite,
    'Legend' => PlayerTier.legend,
    _ => PlayerTier.beginner,
  };
}

extension TierExtension on PlayerTier {
  String get label {
    switch (this) {
      case PlayerTier.beginner: return 'Beginner';
      case PlayerTier.bronze:   return 'Bronze';
      case PlayerTier.silver:   return 'Silver';
      case PlayerTier.gold:     return 'Gold';
      case PlayerTier.platinum: return 'Platinum';
      case PlayerTier.diamond:  return 'Diamond';
      case PlayerTier.elite:    return 'Elite';
      case PlayerTier.legend:   return 'Legend';
    }
  }

  String get emoji {
    switch (this) {
      case PlayerTier.beginner: return '🌱';
      case PlayerTier.bronze:   return '🥉';
      case PlayerTier.silver:   return '🥈';
      case PlayerTier.gold:     return '🥇';
      case PlayerTier.platinum: return '💎';
      case PlayerTier.diamond:  return '💠';
      case PlayerTier.elite:    return '🔥';
      case PlayerTier.legend:   return '👑';
    }
  }

  Color get color {
    switch (this) {
      case PlayerTier.beginner: return AppColors.tierBeginner;
      case PlayerTier.bronze:   return AppColors.tierBronze;
      case PlayerTier.silver:   return AppColors.tierSilver;
      case PlayerTier.gold:     return AppColors.tierGold;
      case PlayerTier.platinum: return AppColors.tierPlatinum;
      case PlayerTier.diamond:  return AppColors.tierDiamond;
      case PlayerTier.elite:    return AppColors.tierElite;
      case PlayerTier.legend:   return AppColors.tierLegend;
    }
  }
}

/// A tier shown as a struck metal pill.
///
/// The fill is a tint of the tier colour rather than the raw metal, so the
/// label stays legible; the depth comes from the bevelled rim (bright top,
/// dark bottom), a coloured glow, and a sheen across the top half.
class TierBadge extends StatelessWidget {
  final PlayerTier tier;

  const TierBadge({super.key, required this.tier});

  @override
  Widget build(BuildContext context) {
    final c = tier.color;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        gradient: LinearGradient(
          colors: [
            c.withValues(alpha: 0.28),
            c.withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: c.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: c.withValues(alpha: 0.30),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Sheen across the top half of the pill.
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: Align(
                alignment: Alignment.topCenter,
                child: FractionallySizedBox(
                  heightFactor: 0.5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.22),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              '${tier.emoji} ${tier.label}',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: c,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
