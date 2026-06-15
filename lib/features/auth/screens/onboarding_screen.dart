import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _slides = [
    _SlideData(
      imagePath: 'assets/images/slide 1.png',
      glowColor: Color(0x1FFF3CAC),
      heading1: "The dream didn't end",
      heading2: 'on the street.',
      subtitle: 'Find real games near you. Join in seconds.\nThe pitch is still yours.',
      buttonLabel: 'Next',
    ),
    _SlideData(
      imagePath: 'assets/images/slide 2.png',
      glowColor: Color(0x1FF97316),
      heading1: 'Every goal you score',
      heading2: 'means something.',
      subtitle: 'Earn XP. Climb from Bronze to Legend.\nYour stats. Your name. Your legacy.',
      buttonLabel: 'Next',
    ),
    _SlideData(
      imagePath: 'assets/images/slide 3.png',
      glowColor: Color(0x1A22D3EE),
      heading1: 'Run the game.',
      heading2: 'Organize. Referee. Earn.',
      subtitle: 'Agents create games, manage players\nand get paid automatically.',
      buttonLabel: "Let's go",
    ),
  ];

  void _next() {
    if (_currentPage < 2) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      context.goNamed('welcome');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(
        children: [
          // ── Slides ────────────────────────────────────────────────────────
          PageView.builder(
            controller: _controller,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, i) => _OnboardingPage(
              key: ValueKey(i),
              data: _slides[i],
            ),
          ),

          // ── Skip button ───────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: TextButton(
              onPressed: () => context.goNamed('welcome'),
              child: Text(
                'Skip',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ),
          ),

          // ── Dots + Next button ────────────────────────────────────────────
          Positioned(
            bottom: 36,
            left: 24,
            right: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_slides.length, (i) {
                    final active = i == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: active ? AppColors.brandGradient : null,
                        color: active ? null : const Color(0x55FFFFFF),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                CustomButton(
                  label: _slides[_currentPage].buttonLabel,
                  onPressed: _next,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Slide data ────────────────────────────────────────────────────────────────

class _SlideData {
  final String imagePath;
  final Color glowColor;
  final String heading1;
  final String heading2;
  final String subtitle;
  final String buttonLabel;

  const _SlideData({
    required this.imagePath,
    required this.glowColor,
    required this.heading1,
    required this.heading2,
    required this.subtitle,
    required this.buttonLabel,
  });
}

// ── Single slide ──────────────────────────────────────────────────────────────

class _OnboardingPage extends StatelessWidget {
  final _SlideData data;

  const _OnboardingPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Full-width cover image with glow overlay ──────────────────────
        Stack(
          children: [
            // Photo — full width, cover
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
              child: Image.asset(
                data.imagePath,
                width: screenW,
                height: screenH * 0.52,
                fit: BoxFit.cover,
              ),
            )
                .animate()
                .fadeIn(duration: 500.ms),

            // Subtle glow tint from slide colour
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      data.glowColor,
                    ],
                  ),
                ),
              ),
            ),

            // Dark gradient at bottom of image so text reads over it
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: screenH * 0.14,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, AppColors.darkBg],
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 28),

        // ── Centred text block ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Heading line 1
              Text(
                data.heading1,
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              )
                  .animate()
                  .fadeIn(delay: 150.ms, duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, delay: 150.ms, duration: 400.ms),

              // Heading line 2 — brand gradient
              ShaderMask(
                shaderCallback: (b) => AppColors.brandGradient.createShader(b),
                child: Text(
                  data.heading2,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 220.ms, duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, delay: 220.ms, duration: 400.ms),

              const SizedBox(height: 12),

              Text(
                data.subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.65,
                  color: AppColors.darkTextSecondary,
                ),
              ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
            ],
          ),
        ),
      ],
    );
  }
}
