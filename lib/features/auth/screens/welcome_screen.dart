import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppColors.darkTextSecondary;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Full-screen background image ─────────────────────────────────
          Image.asset(
            'assets/images/welcome page.png',
            fit: BoxFit.cover,
          ),

          // ── Gradient overlay: transparent → #0A0A0F (bottom 40%) ─────────
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.55, 0.78, 1.0],
                colors: [
                  Colors.transparent,
                  Color(0x66000000),
                  Color(0xCC0A0A0F),
                  AppColors.darkBg,
                ],
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(),

                // Text block — centred
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Welcome To',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      ShaderMask(
                        shaderCallback: (b) =>
                            AppColors.brandGradient.createShader(b),
                        child: Text(
                          'Dreaming Ball',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'The street is your stage.\nEvery game is your chance.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          height: 1.7,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  )
                      .animate()
                      .fadeIn(delay: 150.ms, duration: 500.ms)
                      .slideY(
                          begin: 0.12,
                          end: 0,
                          delay: 150.ms,
                          duration: 500.ms),
                ),

                const SizedBox(height: 32),

                // Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          label: 'Sign In',
                          variant: ButtonVariant.ghost,
                          onPressed: () => context.goNamed('login'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomButton(
                          label: 'Sign Up',
                          onPressed: () => context.goNamed('register'),
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(delay: 350.ms, duration: 500.ms)
                    .slideY(begin: 0.12, end: 0, delay: 350.ms, duration: 500.ms),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
