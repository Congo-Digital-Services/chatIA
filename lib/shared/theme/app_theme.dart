import 'package:flutter/material.dart';

class AppThemeColors {
  static const background = Color(0xFFF8F8F5);
  static const card = Color(0xFFFBFBF9);
  static const cardStrong = Color(0xFFF1F1EE);
  static const stroke = Color(0xFFE6E7E1);
  static const pill = Color(0xFFF4F4F1);
  static const pillSelected = Color(0xFFDEDEDA);
  static const textStrong = Color(0xFF0E0E0E);
  static const textSoft = Color(0xFF5F635B);
  static const textMuted = Color(0xFF8C9087);
  static const accent = Color(0xFF19B38D);
}

class AppThemeShadows {
  static const soft = [
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 36,
      offset: Offset(0, 12),
    ),
  ];
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Geist Sans',
      scaffoldBackgroundColor: AppThemeColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppThemeColors.accent,
        brightness: Brightness.light,
        surface: AppThemeColors.background,
      ),
    );

    return base.copyWith(
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.4,
          color: AppThemeColors.textStrong,
        ),
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          color: AppThemeColors.textStrong,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: AppThemeColors.textStrong,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: AppThemeColors.textStrong,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppThemeColors.textStrong,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppThemeColors.textStrong,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppThemeColors.textStrong,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppThemeColors.textMuted,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.88),
        hintStyle: const TextStyle(color: AppThemeColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppThemeColors.stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppThemeColors.stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppThemeColors.accent, width: 1.4),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppThemeColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: AppThemeColors.stroke),
        ),
      ),
      dividerColor: AppThemeColors.stroke,
    );
  }

  static ThemeData dark() => light();
}
