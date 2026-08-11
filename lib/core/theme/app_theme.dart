import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Boundless F.C. theme.
///
/// Dark mode is the club's native look — the navy crest field with gold
/// hardware. Light mode is the same identity inverted onto warm ivory.
///
/// Depth comes from real elevation (layered shadows on cards, dialogs and
/// menus) rather than flat fills, so surfaces stack visibly instead of sitting
/// on one plane.
class AppTheme {
  AppTheme._();

  static const _radius = 16.0;
  static const _fieldRadius = 14.0;

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkBg,
        canvasColor: AppColors.darkSurface,
        splashColor: AppColors.gold.withValues(alpha: 0.10),
        highlightColor: AppColors.gold.withValues(alpha: 0.06),
        colorScheme: const ColorScheme.dark(
          primary: AppColors.gold,
          onPrimary: AppColors.navyDeep,
          secondary: AppColors.goldDeep,
          onSecondary: AppColors.cream,
          tertiary: AppColors.ice,
          surface: AppColors.darkSurface,
          onSurface: AppColors.darkTextPrimary,
          surfaceContainerHighest: AppColors.navyElev,
          outline: AppColors.darkBorder,
          error: AppColors.danger,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme)
            .apply(bodyColor: AppColors.darkTextPrimary),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.darkSurface,
          foregroundColor: AppColors.darkTextPrimary,
          elevation: 0,
          scrolledUnderElevation: 3,
          shadowColor: Color(0x66000000),
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: AppColors.navySurface,
          shadowColor: const Color(0xB3000000),
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
            side: const BorderSide(color: AppColors.darkBorder),
          ),
        ),
        dividerColor: AppColors.darkBorder,
        iconTheme: const IconThemeData(color: AppColors.darkTextSecondary),
        inputDecorationTheme: _inputTheme(
          fill: AppColors.navy,
          border: AppColors.darkBorder,
          hint: AppColors.darkTextMuted,
          label: AppColors.darkTextSecondary,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.navy,
          selectedItemColor: AppColors.gold,
          unselectedItemColor: AppColors.darkTextMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 12,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.navySurface,
          surfaceTintColor: Colors.transparent,
          elevation: 16,
          shadowColor: const Color(0xCC000000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.darkBorder),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.navySurface,
          surfaceTintColor: Colors.transparent,
          elevation: 16,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: AppColors.navyElev,
          surfaceTintColor: Colors.transparent,
          elevation: 12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.darkBorder),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.navyElev,
          side: const BorderSide(color: AppColors.darkBorder),
          labelStyle: const TextStyle(color: AppColors.darkTextPrimary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.navyElev,
          contentTextStyle: const TextStyle(color: AppColors.cream),
          actionTextColor: AppColors.gold,
          elevation: 10,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        progressIndicatorTheme:
            const ProgressIndicatorThemeData(color: AppColors.gold),
        switchTheme: _switchTheme(track: AppColors.navyElev),
        tabBarTheme: const TabBarThemeData(
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.darkTextMuted,
          indicatorColor: AppColors.gold,
        ),
        elevatedButtonTheme: _elevatedButtonTheme(),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.gold),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.navyDeep,
          elevation: 10,
        ),
      );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.lightBg,
        canvasColor: AppColors.lightSurface,
        splashColor: AppColors.gold.withValues(alpha: 0.12),
        highlightColor: AppColors.gold.withValues(alpha: 0.06),
        colorScheme: const ColorScheme.light(
          primary: AppColors.goldDeep,
          onPrimary: AppColors.cream,
          secondary: AppColors.gold,
          onSecondary: AppColors.navyDeep,
          tertiary: AppColors.navy,
          surface: AppColors.lightSurface,
          onSurface: AppColors.lightTextPrimary,
          surfaceContainerHighest: Color(0xFFF0ECE0),
          outline: AppColors.lightBorder,
          error: AppColors.danger,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme)
            .apply(bodyColor: AppColors.lightTextPrimary),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.lightSurface,
          foregroundColor: AppColors.lightTextPrimary,
          elevation: 0,
          scrolledUnderElevation: 3,
          shadowColor: Color(0x1F131C2E),
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: AppColors.lightCard,
          shadowColor: const Color(0x26131C2E),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
            side: const BorderSide(color: AppColors.lightBorder),
          ),
        ),
        dividerColor: AppColors.lightBorder,
        iconTheme: const IconThemeData(color: AppColors.lightTextSecondary),
        inputDecorationTheme: _inputTheme(
          fill: AppColors.lightSurface,
          border: AppColors.lightBorder,
          hint: AppColors.lightTextMuted,
          label: AppColors.lightTextSecondary,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.lightSurface,
          selectedItemColor: AppColors.goldDeep,
          unselectedItemColor: AppColors.lightTextMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 12,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.lightSurface,
          surfaceTintColor: Colors.transparent,
          elevation: 12,
          shadowColor: const Color(0x33131C2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.lightBorder),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.lightSurface,
          surfaceTintColor: Colors.transparent,
          elevation: 12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: AppColors.lightSurface,
          surfaceTintColor: Colors.transparent,
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.lightBorder),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFF0ECE0),
          side: const BorderSide(color: AppColors.lightBorder),
          labelStyle: const TextStyle(color: AppColors.lightTextPrimary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.navy,
          contentTextStyle: const TextStyle(color: AppColors.cream),
          actionTextColor: AppColors.gold,
          elevation: 8,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        progressIndicatorTheme:
            const ProgressIndicatorThemeData(color: AppColors.goldDeep),
        switchTheme: _switchTheme(track: const Color(0xFFE0DACB)),
        tabBarTheme: const TabBarThemeData(
          labelColor: AppColors.goldDeep,
          unselectedLabelColor: AppColors.lightTextMuted,
          indicatorColor: AppColors.goldDeep,
        ),
        elevatedButtonTheme: _elevatedButtonTheme(),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.goldDeep),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.navyDeep,
          elevation: 8,
        ),
      );

  // ── Shared builders ─────────────────────────────────────────────────────────

  static InputDecorationTheme _inputTheme({
    required Color fill,
    required Color border,
    required Color hint,
    required Color label,
  }) {
    OutlineInputBorder side(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(_fieldRadius),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      border: side(border),
      enabledBorder: side(border),
      focusedBorder: side(AppColors.gold, 1.5),
      errorBorder: side(AppColors.danger),
      focusedErrorBorder: side(AppColors.danger, 1.5),
      hintStyle: TextStyle(color: hint),
      labelStyle: TextStyle(color: label),
      floatingLabelStyle: const TextStyle(color: AppColors.gold),
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.navyDeep,
        elevation: 6,
        shadowColor: AppColors.goldDeep.withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_fieldRadius),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  static SwitchThemeData _switchTheme({required Color track}) {
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.gold
            : AppColors.darkTextMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.gold.withValues(alpha: 0.35)
            : track,
      ),
    );
  }
}
