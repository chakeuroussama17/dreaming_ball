import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  // ── Headings — Space Grotesk ────────────────────────────────────────────────
  static TextStyle h1(Color color) => GoogleFonts.spaceGrotesk(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: color,
      );

  static TextStyle h2(Color color) => GoogleFonts.spaceGrotesk(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle h3(Color color) => GoogleFonts.spaceGrotesk(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle h4(Color color) => GoogleFonts.spaceGrotesk(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: color,
      );

  // ── Body — Inter ────────────────────────────────────────────────────────────
  static TextStyle body(Color color) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle bodyMedium(Color color) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color,
      );

  static TextStyle caption(Color color) => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color,
      );

  // ── Convenience — dark mode defaults ────────────────────────────────────────
  static TextStyle get darkH1      => h1(AppColors.darkTextPrimary);
  static TextStyle get darkH2      => h2(AppColors.darkTextPrimary);
  static TextStyle get darkH3      => h3(AppColors.darkTextPrimary);
  static TextStyle get darkH4      => h4(AppColors.darkTextPrimary);
  static TextStyle get darkBody    => body(AppColors.darkTextSecondary);
  static TextStyle get darkCaption => caption(AppColors.darkTextMuted);

  // ── Convenience — light mode defaults ───────────────────────────────────────
  static TextStyle get lightH1      => h1(AppColors.lightTextPrimary);
  static TextStyle get lightH2      => h2(AppColors.lightTextPrimary);
  static TextStyle get lightH3      => h3(AppColors.lightTextPrimary);
  static TextStyle get lightH4      => h4(AppColors.lightTextPrimary);
  static TextStyle get lightBody    => body(AppColors.lightTextSecondary);
  static TextStyle get lightCaption => caption(AppColors.lightTextMuted);
}
