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
import '../../../l10n/app_localizations.dart';

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
    final locale = ref.watch(localeProvider);
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: primary),
          onPressed: () => context.safePop('profile'),
        ),
        title: Text(l.settingsTitle,
            style: GoogleFonts.spaceGrotesk(
                fontSize: 18, fontWeight: FontWeight.w700, color: primary)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _sectionLabel(l.settingsTheme, secondary),
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

          // ── Language ──────────────────────────────────────────────────
          _sectionLabel(l.settingsLanguage, secondary),
          const SizedBox(height: 10),
          _tile(Icons.language, _langName(l, locale.languageCode), primary,
              secondary, border, surface,
              () => _showLanguageSheet(context, ref, l, surface, border,
                  primary, secondary)),
          const SizedBox(height: 24),

          _sectionLabel(l.settingsAccount, secondary),
          const SizedBox(height: 10),
          _tile(Icons.person_outline, 'Edit Profile', primary, secondary,
              border, surface, () => context.pushNamed('edit-profile')),
          _tile(Icons.notifications_outlined, l.settingsNotifications, primary,
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
                // Back to the guest theme so the next user doesn't inherit this
                // account's light/dark choice.
                ref.read(themeModeProvider.notifier).applyFor(null);
                context.goNamed('login');
              },
              icon: const Icon(Icons.logout, size: 18, color: AppColors.tierElite),
              label: Text(l.settingsLogout,
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

  /// Autonym for a language code (shown the same in every locale).
  String _langName(AppLocalizations l, String code) => switch (code) {
        'ms' => l.languageMalay,
        'zh' => l.languageChinese,
        'ja' => l.languageJapanese,
        'ru' => l.languageRussian,
        _ => l.languageEnglish,
      };

  void _showLanguageSheet(BuildContext context, WidgetRef ref,
      AppLocalizations l, Color surface, Color border, Color primary,
      Color secondary) {
    final current = ref.read(localeProvider).languageCode;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(l.chooseLanguage,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: primary)),
              ),
            ),
            for (final loc in LocaleNotifier.supported)
              ListTile(
                title: Text(_langName(l, loc.languageCode),
                    style: GoogleFonts.inter(fontSize: 15, color: primary)),
                trailing: loc.languageCode == current
                    ? const Icon(Icons.check, color: AppColors.orange)
                    : null,
                onTap: () {
                  ref.read(localeProvider.notifier).set(loc);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
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
