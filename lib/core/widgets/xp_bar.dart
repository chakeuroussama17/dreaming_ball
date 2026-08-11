import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';

/// XP progress rendered as a gold bar seated in a recessed channel.
///
/// Three layers create the depth: the track carries an inner shadow so it reads
/// as a groove, the fill uses the brand metal gradient, and a highlight streak
/// along the fill's top edge gives it a cylindrical curve.
class XpBar extends StatelessWidget {
  final int currentXp;
  final int maxXp;
  final double height;

  const XpBar({
    super.key,
    required this.currentXp,
    required this.maxXp,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final track = isDark ? AppColors.navyDeep : const Color(0xFFE6DFCE);
    final ratio = maxXp <= 0 ? 0.0 : (currentXp / maxXp).clamp(0.0, 1.0);

    return LayoutBuilder(builder: (context, constraints) {
      final fillWidth = constraints.maxWidth * ratio;

      return Stack(
        children: [
          // Recessed channel.
          Container(
            width: constraints.maxWidth,
            height: height,
            decoration: BoxDecoration(
              color: track,
              borderRadius: BorderRadius.circular(height),
              border: Border.all(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
          ),
          // Gold fill.
          Container(
            width: fillWidth,
            height: height,
            decoration: BoxDecoration(
              gradient: AppColors.goldMetal,
              borderRadius: BorderRadius.circular(height),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.45),
                  blurRadius: 8,
                  spreadRadius: -1,
                ),
              ],
            ),
            child: Align(
              alignment: Alignment.topCenter,
              // Highlight streak — the curve of the bar.
              child: Container(
                height: height * 0.34,
                margin: EdgeInsets.symmetric(horizontal: height * 0.4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
            ),
          )
              .animate()
              .scaleX(
                begin: 0,
                end: 1,
                alignment: Alignment.centerLeft,
                duration: 800.ms,
                curve: Curves.easeOut,
              ),
        ],
      );
    });
  }
}
