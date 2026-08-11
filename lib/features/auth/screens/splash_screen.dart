import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/providers/admin_providers.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  /// Restores the Supabase session (if any) and routes accordingly,
  /// showing the splash for at least 2 seconds.
  Future<void> _boot() async {
    final results = await Future.wait([
      _resolveSession(),
      Future<void>.delayed(const Duration(seconds: 2)),
    ]);
    if (!mounted) return;
    context.goNamed(results[0] as String);
  }

  Future<String> _resolveSession() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user == null) return 'onboarding';

      if (user.isAdmin) {
        ref.read(isAdminProvider.notifier).state = true;
        return 'admin-dashboard';
      }

      ref.read(isAdminProvider.notifier).state = false;
      ref.read(userRoleProvider.notifier).state =
          user.isAgent ? UserRole.agent : UserRole.player;
      if (user.isAgent) {
        final status = await AuthService.fetchAgentStatus(user.id);
        ref.read(agentVerificationProvider.notifier).state =
            agentVerificationFromStatus(status);
      }
      return 'home';
    } catch (_) {
      // Session restore failed (offline, expired…) — start logged out.
      return 'onboarding';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: DecoratedBox(
        // Navy vignette so the crest sits in a pool of light rather than on a
        // flat black field.
        decoration: const BoxDecoration(gradient: AppColors.backdropGlow),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Gold halo + the club crest
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.gold.withValues(alpha: 0.22),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.30),
                          blurRadius: 32,
                          offset: const Offset(0, 12),
                        ),
                        const BoxShadow(
                          color: Color(0x99000000),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset(
                        'assets/images/newlogo.png',
                        width: 132,
                        height: 132,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 600.ms).scale(
                    begin: const Offset(0.88, 0.88),
                    end: const Offset(1, 1),
                    duration: 700.ms,
                    curve: Curves.easeOutBack,
                  ),

              const SizedBox(height: 28),

              // "Boundless" — struck in gold foil
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppColors.brandGradient.createShader(bounds),
                child: Text(
                  'Boundless',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 500.ms)
                  .slideY(begin: 0.3, end: 0, delay: 400.ms, duration: 500.ms),

              const SizedBox(height: 10),

              Text(
                'Chase Yours.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.darkTextSecondary,
                  letterSpacing: 2.5,
                ),
              ).animate().fadeIn(delay: 700.ms, duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}
