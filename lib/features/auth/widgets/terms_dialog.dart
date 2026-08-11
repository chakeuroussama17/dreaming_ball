import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/legal/terms.dart';
import '../../../../core/theme/app_colors.dart';

/// Shows the required Terms of Use / Acceptable-Use agreement. Returns `true`
/// only if the user ticks the box and taps "I Agree". Not dismissible by
/// tapping outside — the user must make a choice.
Future<bool> showTermsDialog(BuildContext context) async {
  final agreed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _TermsDialog(),
  );
  return agreed ?? false;
}

class _TermsDialog extends StatefulWidget {
  const _TermsDialog();

  @override
  State<_TermsDialog> createState() => _TermsDialogState();
}

class _TermsDialogState extends State<_TermsDialog> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final primary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final size = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Terms of Use & Fair Play',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: primary)),
              const SizedBox(height: 4),
              Text('Version $kTermsVersion · $kTermsEffectiveDate',
                  style: GoogleFonts.inter(fontSize: 11, color: secondary)),
              const SizedBox(height: 12),

              // Scrollable terms body.
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(kTermsIntro,
                          style: GoogleFonts.inter(
                              fontSize: 13, height: 1.6, color: secondary)),
                      const SizedBox(height: 14),
                      for (final s in kTermsSections) ...[
                        Text(s.title,
                            style: GoogleFonts.spaceGrotesk(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: primary)),
                        const SizedBox(height: 4),
                        Text(s.body,
                            style: GoogleFonts.inter(
                                fontSize: 13, height: 1.6, color: secondary)),
                        const SizedBox(height: 14),
                      ],
                    ],
                  ),
                ),
              ),

              const Divider(height: 20),

              // Consent checkbox.
              InkWell(
                onTap: () => setState(() => _checked = !_checked),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _checked,
                        activeColor: AppColors.gold,
                        onChanged: (v) =>
                            setState(() => _checked = v ?? false),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'I have read and agree to the Terms of Use and '
                            'Acceptable-Use Rules, and I will use the app for '
                            'lawful, football purposes only.',
                            style: GoogleFonts.inter(
                                fontSize: 12.5, height: 1.5, color: primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text('Cancel',
                          style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.w700, color: secondary)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: _checked ? AppColors.brandGradient : null,
                        color: _checked ? null : (isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ElevatedButton(
                        onPressed: _checked
                            ? () => Navigator.pop(context, true)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text('I Agree & Create Account',
                            style: GoogleFonts.spaceGrotesk(
                                fontWeight: FontWeight.w700,
                                color: _checked ? Colors.white : secondary)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
