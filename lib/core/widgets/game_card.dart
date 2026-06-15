import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

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
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final cardBg  = isDark ? AppColors.darkCard    : AppColors.lightCard;
    final border  = isDark ? AppColors.darkBorder  : AppColors.lightBorder;
    final primary = isDark ? AppColors.darkTextPrimary   : AppColors.lightTextPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final track   = isDark ? AppColors.darkBorder  : AppColors.lightBorder;

    final slotRatio = totalSlots == 0 ? 0.0 : filledSlots / totalSlots;
    final isFull    = filledSlots >= totalSlots;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(fieldName,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 16, fontWeight: FontWeight.w700, color: primary)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.pink, AppColors.orange]),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'RM ${price.toStringAsFixed(0)}',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
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
                    style: GoogleFonts.inter(fontSize: 13, color: secondary)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(children: [
                      Container(height: 6, color: track),
                      FractionallySizedBox(
                        widthFactor: slotRatio,
                        child: Container(
                          height: 6,
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
                ),
                const SizedBox(width: 8),
                Text(
                  isFull ? 'Full' : '$filledSlots/$totalSlots',
                  style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w500,
                    color: isFull ? AppColors.tierElite : secondary,
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
