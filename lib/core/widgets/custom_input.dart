import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// A labelled text field that reads as recessed into the page.
///
/// Where buttons and cards push toward the viewer, inputs sink away from them:
/// the fill is darker than the surrounding surface and a soft inner shadow sits
/// under the top edge. Focus lights the gold rim and adds a faint halo.
class CustomInput extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLength;

  const CustomInput({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLength,
  });

  @override
  State<CustomInput> createState() => _CustomInputState();
}

class _CustomInputState extends State<CustomInput> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.navyDeep : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final hintColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    OutlineInputBorder side(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _focused
                ? AppColors.gold
                : (isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary),
          ),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            // The recess: a tight dark shadow hugging the field, plus a gold
            // halo once focused.
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
              if (_focused)
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Focus(
            onFocusChange: (v) => setState(() => _focused = v),
            child: TextFormField(
              controller: widget.controller,
              obscureText: widget.obscureText,
              keyboardType: widget.keyboardType,
              validator: widget.validator,
              onChanged: widget.onChanged,
              maxLength: widget.maxLength,
              cursorColor: AppColors.gold,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: GoogleFonts.inter(fontSize: 14, color: hintColor),
                filled: true,
                fillColor: bg,
                prefixIcon: widget.prefixIcon,
                suffixIcon: widget.suffixIcon,
                border: side(border),
                enabledBorder: side(border),
                focusedBorder: side(AppColors.gold, 1.5),
                errorBorder: side(AppColors.danger),
                focusedErrorBorder: side(AppColors.danger, 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
