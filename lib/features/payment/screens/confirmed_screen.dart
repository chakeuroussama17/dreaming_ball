import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';

class ConfirmedScreen extends StatelessWidget {
  const ConfirmedScreen({super.key});

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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [AppColors.goldActionStart, AppColors.goldActionEnd]),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 38),
              ).animate().scale(
                  duration: 400.ms,
                  curve: Curves.elasticOut,
                  begin: const Offset(0.4, 0.4),
                  end: const Offset(1, 1)),
              const SizedBox(height: 18),
              ShaderMask(
                shaderCallback: (b) => AppColors.brandGradient.createShader(b),
                child: Text("You're in!",
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              const SizedBox(height: 6),
              Text('Spot confirmed. See you on the pitch.',
                  style: GoogleFonts.inter(fontSize: 14, color: secondary)),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surface,
                  border: Border.all(color: border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _row('Game', 'ABC Football Field', secondary, primary),
                    _row('Date', 'Sat, Jun 14 · 8:00 PM', secondary, primary),
                    _row('Amount paid', 'RM 25.00', secondary, primary),
                    _row('Booking ref', 'DB48213', secondary, primary),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
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
                    onPressed: () => context.goNamed('home'),
                    child: Text('Back to Games',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String k, String v, Color secondary, Color primary) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: GoogleFonts.inter(fontSize: 13, color: secondary)),
          Text(v,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 13, fontWeight: FontWeight.w600, color: primary)),
        ],
      ),
    );
  }
}
