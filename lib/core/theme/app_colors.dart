import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Brand Gradient ──────────────────────────────────────────────────────────
  static const Color pink   = Color(0xFFFF3CAC);
  static const Color orange = Color(0xFFF97316);
  static const Color cyan   = Color(0xFF22D3EE);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [pink, orange, cyan],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // ── Dark Mode ───────────────────────────────────────────────────────────────
  static const Color darkBg            = Color(0xFF0A0A0F);
  static const Color darkSurface       = Color(0xFF111118);
  static const Color darkCard          = Color(0x0AFFFFFF); // rgba(255,255,255,0.04)
  static const Color darkBorder        = Color(0x12FFFFFF); // rgba(255,255,255,0.07)
  static const Color darkTextPrimary   = Color(0xFFF0F0F0);
  static const Color darkTextSecondary = Color(0xFF888888);
  static const Color darkTextMuted     = Color(0xFF444444);

  // ── Light Mode ──────────────────────────────────────────────────────────────
  static const Color lightBg             = Color(0xFFF8F9FA);
  static const Color lightSurface        = Color(0xFFFFFFFF);
  static const Color lightCard           = Color(0xFFFFFFFF);
  static const Color lightBorder         = Color(0xFFEEEEEE);
  static const Color lightTextPrimary    = Color(0xFF111111);
  static const Color lightTextSecondary  = Color(0xFF888888);
  static const Color lightTextMuted      = Color(0xFFBBBBBB);

  // ── Tier Colors ─────────────────────────────────────────────────────────────
  static const Color tierBeginner = Color(0xFF9CA3AF);
  static const Color tierBronze   = Color(0xFFBC8F4F);
  static const Color tierSilver   = Color(0xFFB0BEC5);
  static const Color tierGold     = Color(0xFFF97316);
  static const Color tierPlatinum = Color(0xFF22D3EE);
  static const Color tierDiamond  = Color(0xFF8B5CF6);
  static const Color tierElite    = Color(0xFFFF453A);
  static const Color tierLegend   = Color(0xFFFF3CAC);
}
