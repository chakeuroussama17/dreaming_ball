import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/providers/admin_providers.dart';
import '../../../../core/providers/content_providers.dart';
import '../../../../core/providers/games_provider.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_input.dart';
import '../../../../app/app.dart';
import '../../../../l10n/app_localizations.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final user = await AuthService.signIn(
        email: _emailCtrl.text.trim().toLowerCase(),
        password: _passwordCtrl.text,
      );
      if (!mounted) return;
      // Drop every cached per-user provider (profile, bell, games...) so
      // this session never shows the previous user's data.
      resetUserScopedProviders(ref);
      // Load this user's own saved light/dark preference.
      ref.read(themeModeProvider.notifier).applyFor(SupabaseService.userId);
      ref.read(gamesProvider.notifier).load();

      if (user.isAdmin) {
        ref.read(isAdminProvider.notifier).state = true;
        context.goNamed('admin-dashboard');
        return;
      }

      ref.read(isAdminProvider.notifier).state = false;
      ref.read(userRoleProvider.notifier).state =
          user.isAgent ? UserRole.agent : UserRole.player;
      if (user.isAgent) {
        // Restore where the agent is in the verification pipeline so the
        // create-game lock and dashboard access are correct after login.
        final status = await AuthService.fetchAgentStatus(user.id);
        if (!mounted) return;
        ref.read(agentVerificationProvider.notifier).state =
            agentVerificationFromStatus(status);
      }
      context.goNamed('home');
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong — please try again');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final dividerColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button
                IconButton(
                  onPressed: () => context.goNamed('welcome'),
                  icon:
                      Icon(Icons.arrow_back_ios_new, color: textPrimary, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),

                const SizedBox(height: 32),

                // Title
                Text(
                  l.loginTitle,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.2, end: 0, duration: 400.ms),

                const SizedBox(height: 6),

                Text(
                  l.loginSubtitle,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF555555),
                  ),
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                const SizedBox(height: 36),

                // Email
                CustomInput(
                  label: l.fieldEmail,
                  hint: 'your@email.com',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email is required';
                    if (!v.contains('@') || !v.contains('.')) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                )
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 400.ms)
                    .slideY(begin: 0.2, end: 0, delay: 200.ms, duration: 400.ms),

                const SizedBox(height: 16),

                // Password
                CustomInput(
                  label: l.fieldPassword,
                  hint: 'Min. 8 characters',
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.darkTextMuted,
                      size: 20,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 8) return 'At least 8 characters required';
                    return null;
                  },
                )
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 400.ms)
                    .slideY(begin: 0.2, end: 0, delay: 300.ms, duration: 400.ms),

                const SizedBox(height: 10),

                // Forgot password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.goNamed('forgot-password'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      l.forgotPassword,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.orange,
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 400.ms),

                const SizedBox(height: 24),

                // Inline auth error
                if (_error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.tierElite.withValues(alpha: 0.08),
                      border: Border.all(
                          color: AppColors.tierElite.withValues(alpha: 0.35)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            size: 18, color: AppColors.tierElite),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: GoogleFonts.inter(
                                fontSize: 13, color: AppColors.tierElite),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Sign In button
                CustomButton(
                  label: l.logIn,
                  isLoading: _isLoading,
                  onPressed: _submit,
                )
                    .animate()
                    .fadeIn(delay: 500.ms, duration: 400.ms)
                    .slideY(begin: 0.2, end: 0, delay: 500.ms, duration: 400.ms),

                const SizedBox(height: 32),

                // "or" divider
                Row(
                  children: [
                    Expanded(child: Divider(color: dividerColor)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: dividerColor)),
                  ],
                ).animate().fadeIn(delay: 600.ms),

                const SizedBox(height: 24),

                // Sign up link
                Center(
                  child: GestureDetector(
                    onTap: () => context.goNamed('register'),
                    child: RichText(
                      text: TextSpan(
                        text: '${l.noAccountPrompt}  ',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: textSecondary,
                        ),
                        children: [
                          WidgetSpan(
                            alignment: PlaceholderAlignment.baseline,
                            baseline: TextBaseline.alphabetic,
                            child: ShaderMask(
                              shaderCallback: (b) =>
                                  AppColors.brandGradient.createShader(b),
                              child: Text(
                                l.signUp,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 700.ms),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
