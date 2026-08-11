import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_input.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final primary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: primary),
          onPressed: () => context.goNamed('login'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _sent
              ? _sentView(primary, secondary)
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Forgot Password?',
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: primary)),
                      const SizedBox(height: 6),
                      Text(
                        "Enter your email and we'll send you a reset link.",
                        style: GoogleFonts.inter(fontSize: 14, color: secondary),
                      ),
                      const SizedBox(height: 32),
                      CustomInput(
                        label: 'Email address',
                        hint: 'your@email.com',
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!v.contains('@') || !v.contains('.')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      CustomButton(
                        label: 'Send Reset Link',
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            // TODO: Supabase auth.resetPasswordForEmail()
                            setState(() => _sent = true);
                          }
                        },
                      ),
                    ],
                  ).animate().fadeIn(duration: 350.ms),
                ),
        ),
      ),
    );
  }

  Widget _sentView(Color primary, Color secondary) {
    return Center(
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
            child: const Icon(Icons.mark_email_read_outlined,
                color: Colors.white, size: 36),
          ).animate().scale(
              duration: 400.ms,
              curve: Curves.elasticOut,
              begin: const Offset(0.4, 0.4),
              end: const Offset(1, 1)),
          const SizedBox(height: 20),
          Text('Check your inbox',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 22, fontWeight: FontWeight.w800, color: primary)),
          const SizedBox(height: 8),
          Text(
            'We sent a reset link to\n${_emailCtrl.text.trim()}',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, height: 1.5, color: secondary),
          ),
          const SizedBox(height: 28),
          CustomButton(
            label: 'Back to Login',
            onPressed: () => context.goNamed('login'),
          ),
        ],
      ),
    );
  }
}
