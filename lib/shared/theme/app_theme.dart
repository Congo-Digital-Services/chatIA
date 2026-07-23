import 'package:flutter/material.dart';

class AppThemeColors {
  static Brightness currentBrightness = Brightness.dark;

  static bool get isDark => currentBrightness == Brightness.dark;

  static Color get background =>
      isDark ? const Color(0xFF0D0E12) : const Color(0xFFF7F7F8);
  static Color get backgroundSoft =>
      isDark ? const Color(0xFF13151A) : const Color(0xFFFFFFFF);
  static Color get surface =>
      isDark ? const Color(0xFF17191F) : const Color(0xFFFFFFFF);
  static Color get card =>
      isDark ? const Color(0xFF17191F) : const Color(0xFFFFFFFF);
  static Color get cardStrong =>
      isDark ? const Color(0xFF1B1D24) : const Color(0xFFFFFFFF);
  static Color get stroke =>
      isDark ? const Color(0xFF2A2D35) : const Color(0xFFE5E7EB);
  static Color get strokeStrong =>
      isDark ? const Color(0xFF353944) : const Color(0xFFD7DAE0);
  static Color get pill =>
      isDark ? const Color(0xFF20242C) : const Color(0xFFF1F2F4);
  static Color get pillSelected =>
      isDark ? const Color(0xFFF4F4F5) : const Color(0xFF111111);
  static Color get textStrong =>
      isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111111);
  static Color get textSoft =>
      isDark ? const Color(0xFFB2B7C2) : const Color(0xFF5F6672);
  static Color get textMuted =>
      isDark ? const Color(0xFF8C93A3) : const Color(0xFF8B93A0);
  static Color get accent =>
      isDark ? const Color(0xFFF4F4F5) : const Color(0xFF111111);
  static Color get accentSoft =>
      isDark ? const Color(0xFF242730) : const Color(0xFFF3F4F6);
  static Color get success => textStrong;
  static Color get danger => textStrong;
  static Color get warning => textStrong;
  static Color get info => textStrong;

  static LinearGradient get shellGradient => LinearGradient(
    colors: [background, background],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static void syncWithContext(BuildContext context, {Color? activeAccent}) {
    currentBrightness = Theme.of(context).brightness;
  }

  static void update(bool isDarkVal) {
    currentBrightness = isDarkVal ? Brightness.dark : Brightness.light;
  }
}

class AppThemeShadows {
  static const soft = <BoxShadow>[];
  static const medium = <BoxShadow>[];
}

class AppTheme {
  static ThemeData build({required bool isDark, required Color accentColor}) {
    AppThemeColors.update(isDark);

    final scheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: AppThemeColors.accent,
      onPrimary: isDark ? Colors.black : Colors.white,
      secondary: AppThemeColors.accent,
      onSecondary: isDark ? Colors.black : Colors.white,
      error: AppThemeColors.textStrong,
      onError: isDark ? Colors.black : Colors.white,
      surface: AppThemeColors.surface,
      onSurface: AppThemeColors.textStrong,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      fontFamily: 'Geist Sans',
      colorScheme: scheme,
      scaffoldBackgroundColor: AppThemeColors.background,
    );

    return base.copyWith(
      textTheme: TextTheme(
        displaySmall: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -1,
          height: 1.05,
          color: AppThemeColors.textStrong,
        ),
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.7,
          height: 1.1,
          color: AppThemeColors.textStrong,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          height: 1.18,
          color: AppThemeColors.textStrong,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.25,
          color: AppThemeColors.textStrong,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.3,
          color: AppThemeColors.textStrong,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.6,
          color: AppThemeColors.textStrong,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.55,
          color: AppThemeColors.textStrong,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.45,
          color: AppThemeColors.textMuted,
        ),
        labelLarge: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
          color: AppThemeColors.textSoft,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppThemeColors.textStrong,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      dividerColor: AppThemeColors.stroke,
      cardTheme: CardThemeData(
        color: AppThemeColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppThemeColors.stroke),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppThemeColors.cardStrong,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppThemeColors.stroke),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppThemeColors.textStrong,
          foregroundColor: isDark ? Colors.black : Colors.white,
          disabledBackgroundColor: AppThemeColors.pill,
          disabledForegroundColor: AppThemeColors.textMuted,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppThemeColors.textStrong,
          side: BorderSide(color: AppThemeColors.stroke),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppThemeColors.surface,
        hintStyle: TextStyle(color: AppThemeColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: AppThemeColors.stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: AppThemeColors.stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: AppThemeColors.strokeStrong,
            width: 1.2,
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      iconTheme: IconThemeData(color: AppThemeColors.textStrong),
    );
  }

  static ThemeData light() =>
      build(isDark: false, accentColor: const Color(0xFF111111));
  static ThemeData dark() =>
      build(isDark: true, accentColor: const Color(0xFFF4F4F5));
}
