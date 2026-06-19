import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

/// Tournaments tab — placeholder for now ("coming soon"). Content TBD.
class TournamentsScreen extends StatelessWidget {
  const TournamentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final l = AppLocalizations.of(context);

    // Root tab: the system back button has nothing to pop, so send it Home.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.goNamed('home');
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          automaticallyImplyLeading: false,
          centerTitle: false,
          title: ShaderMask(
            shaderCallback: (b) => AppColors.brandGradient.createShader(b),
            child: Text(
              l.tournamentsTitle,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [
                      AppColors.pink.withValues(alpha: 0.18),
                      AppColors.orange.withValues(alpha: 0.18),
                    ]),
                    border:
                        Border.all(color: AppColors.orange.withValues(alpha: 0.35)),
                  ),
                  child: const Icon(Icons.emoji_events,
                      size: 46, color: AppColors.orange),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.06, 1.06),
                        duration: 1200.ms,
                        curve: Curves.easeInOut),
                const SizedBox(height: 24),
                ShaderMask(
                  shaderCallback: (b) =>
                      AppColors.brandGradient.createShader(b),
                  child: Text(
                    l.comingSoon,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l.tournamentsBlurb,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 14, height: 1.6, color: secondary),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: 2,
          type: BottomNavigationBarType.fixed,
          onTap: (i) {
            switch (i) {
              case 0:
                context.goNamed('home');
              case 1:
                context.goNamed('leaderboard');
              case 3:
                context.goNamed('private-room');
              case 4:
                context.goNamed('profile');
              default:
                break;
            }
          },
          items: [
            BottomNavigationBarItem(
                icon: const Icon(Icons.home_outlined), label: l.navHome),
            BottomNavigationBarItem(
                icon: const Icon(Icons.leaderboard_outlined),
                label: l.navLeaderboard),
            BottomNavigationBarItem(
                icon: const Icon(Icons.emoji_events),
                label: l.navTournaments),
            BottomNavigationBarItem(
                icon: const Icon(Icons.lock_outline), label: l.navPrivateRoom),
            BottomNavigationBarItem(
                icon: const Icon(Icons.person_outline), label: l.navProfile),
          ],
        ),
      ),
    );
  }
}
