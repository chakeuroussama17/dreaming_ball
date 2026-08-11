import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// A game listing, rendered as a raised panel.
///
/// The card lifts off the page with a layered shadow and a top bevel, the price
/// sits on a gold pill, and the slot meter is a recessed channel with a metal
/// fill — the same depth language used by [XpBar] and [CustomButton].
class GameCard extends StatelessWidget {
  final String fieldName;
  final String dateTime;
  final int filledSlots;
  final int totalSlots;
  final double price;
  final VoidCallback? onTap;

  const GameCard({
    super.key,
    required this.fieldName,
    required this.dateTime,
    required this.filledSlots,
    required this.totalSlots,
    required this.price,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final primary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final track = isDark ? AppColors.navyDeep : const Color(0xFFE6DFCE);

    final slotRatio = totalSlots == 0 ? 0.0 : filledSlots / totalSlots;
    final isFull = filledSlots >= totalSlots;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          gradient: isDark
              ? AppColors.darkCardGradient
              : AppColors.lightCardGradient,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.shadowSoft,
        ),
        child: Stack(
          children: [
            // Top bevel — the light catching the card's leading edge.
            Positioned(
              top: 0,
              left: 12,
              right: 12,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: isDark ? 0.16 : 0.9),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          fieldName,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Gold price pill.
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: AppColors.goldMetal,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: AppColors.bevelGoldLight,
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          'RM ${price.toStringAsFixed(0)}',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navyDeep,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 14, color: secondary),
                      const SizedBox(width: 4),
                      Text(dateTime,
                          style:
                              GoogleFonts.inter(fontSize: 13, color: secondary)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: track,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.black
                                  .withValues(alpha: isDark ? 0.35 : 0.06),
                            ),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: slotRatio.clamp(0.0, 1.0),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: isFull
                                    ? AppColors.metalFor(AppColors.tierElite)
                                    : AppColors.goldMetal,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isFull
                                            ? AppColors.tierElite
                                            : AppColors.gold)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 6,
                                    spreadRadius: -1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isFull ? 'Full' : '$filledSlots/$totalSlots',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isFull ? AppColors.tierElite : secondary,
                        ),
                      ),
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
