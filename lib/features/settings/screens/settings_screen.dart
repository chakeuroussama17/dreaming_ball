import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/app.dart';
import '../../../core/providers/content_providers.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/nav.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final primary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    final mode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: primary),
          onPressed: () => context.safePop('profile'),
        ),
        title: Text('Settings',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 18, fontWeight: FontWeight.w700, color: primary)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _sectionLabel('Appearance', secondary),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: surface,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _modePill('System', ThemeMode.system, mode, secondary, ref),
                _modePill('Light', ThemeMode.light, mode, secondary, ref),
                _modePill('Dark', ThemeMode.dark, mode, secondary, ref),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _sectionLabel('Account', secondary),
          const SizedBox(height: 10),
          _tile(Icons.person_outline, 'Edit Profile', primary, secondary,
              border, surface, () => context.pushNamed('edit-profile')),
          _tile(Icons.notifications_outlined, 'Notifications', primary,
              secondary, border, surface, () => context.pushNamed('notifications')),
          _tile(Icons.lock_reset, 'Change Password', primary, secondary, border,
              surface, () => context.pushNamed('forgot-password')),

          const SizedBox(height: 24),
          _sectionLabel('About', secondary),
          const SizedBox(height: 10),
          _tile(Icons.info_outline, 'Dreaming Ball v1.0.0', primary, secondary,
              border, surface, null),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.tierElite.withValues(alpha: 0.6)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () async {
                await AuthService.signOut();
                if (!context.mounted) return;
                ref.read(userRoleProvider.notifier).state = UserRole.player;
                ref.read(agentVerificationProvider.notifier).state =
                    AgentVerification.notSubmitted;
                resetUserScopedProviders(ref);
                context.goNamed('login');
              },
              icon: const Icon(Icons.logout, size: 18, color: AppColors.tierElite),
              label: Text('Log Out',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.tierElite)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modePill(String label, ThemeMode value, ThemeMode current,
      Color secondary, WidgetRef ref) {
    final active = value == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(themeModeProvider.notifier).set(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: active ? AppColors.brandGradient : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : secondary)),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, Color secondary) => Text(text,
      style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w600, color: secondary));

  Widget _tile(IconData icon, String label, Color primary, Color secondary,
      Color border, Color surface, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surface,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: primary)),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: secondary),
            ],
          ),
        ),
      ),
    );
  }
}
