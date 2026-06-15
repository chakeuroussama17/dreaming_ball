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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Radial glow + logo placeholder
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 220,
                  height: 220,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0x1FFF3CAC), Colors.transparent],
                    ),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 600.ms),

            const SizedBox(height: 24),

            // "Dreaming Ball" — gradient text
            ShaderMask(
              shaderCallback: (bounds) =>
                  AppColors.brandGradient.createShader(bounds),
              child: Text(
                'Dreaming Ball',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            )
                .animate()
                .fadeIn(delay: 400.ms, duration: 500.ms)
                .slideY(begin: 0.3, end: 0, delay: 400.ms, duration: 500.ms),

            const SizedBox(height: 8),

            Text(
              'Chase Yours.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF444444),
                letterSpacing: 0.5,
              ),
            ).animate().fadeIn(delay: 700.ms, duration: 400.ms),
          ],
        ),
      ),
    );
  }
}
