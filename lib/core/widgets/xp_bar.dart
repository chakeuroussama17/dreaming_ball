import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';

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
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final track   = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final ratio   = (currentXp / maxXp).clamp(0.0, 1.0);

    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
        children: [
          Container(
            width: constraints.maxWidth,
            height: height,
            decoration: BoxDecoration(
              color: track,
              borderRadius: BorderRadius.circular(height),
            ),
          ),
          Container(
            width: constraints.maxWidth * ratio,
            height: height,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.pink, AppColors.orange, AppColors.cyan],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(height),
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
