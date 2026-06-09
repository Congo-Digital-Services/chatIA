import 'package:flutter/material.dart';

class AppThemeColors {
  static Color background = const Color(0xFFF2EEE6);
  static Color card = const Color(0xFFFBF7F0);
  static Color cardStrong = const Color(0xFFEEE6D8);
  static Color stroke = const Color(0xFFD8CEBF);
  static Color pill = const Color(0xFFE7DDCF);
  static Color pillSelected = const Color(0xFFD9CDBB);
  static Color textStrong = const Color(0xFF0E0E0E);
  static Color textSoft = const Color(0xFF5C574E);
  static Color textMuted = const Color(0xFF847C70);
  static Color accent = const Color(0xFF19B38D);

  static bool _isDark(Brightness brightness) => brightness == Brightness.dark;

  static void syncWithContext(BuildContext context, {Color? activeAccent}) {
    update(_isDark(Theme.of(context).brightness), activeAccent ?? accent);
  }

  static void update(bool isDark, Color activeAccent) {
    accent = activeAccent;
    if (isDark) {
      background = const Color(0xFF121210);
      card = const Color(0xFF1C1C19);
      cardStrong = const Color(0xFF262623);
      stroke = const Color(0xFF2C2D29);
      pill = const Color(0xFF22221F);
      pillSelected = const Color(0xFF383935);
      textStrong = const Color(0xFFF5F5F0);
      textSoft = const Color(0xFFACAFAB);
      textMuted = const Color(0xFF767975);
    } else {
      background = const Color(0xFFF2EEE6);
      card = const Color(0xFFFBF7F0);
      cardStrong = const Color(0xFFEEE6D8);
      stroke = const Color(0xFFD8CEBF);
      pill = const Color(0xFFE7DDCF);
      pillSelected = const Color(0xFFD9CDBB);
      textStrong = const Color(0xFF0E0E0E);
      textSoft = const Color(0xFF5C574E);
      textMuted = const Color(0xFF847C70);
    }
  }
}

class AppThemeShadows {
  static const soft = [
    BoxShadow(color: Color(0x14000000), blurRadius: 28, offset: Offset(0, 10)),
  ];
}

class AppTheme {
  static ThemeData build({required bool isDark, required Color accentColor}) {
    AppThemeColors.update(isDark, accentColor);

    final base = ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      fontFamily: 'Geist Sans',
      scaffoldBackgroundColor: AppThemeColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppThemeColors.accent,
        brightness: isDark ? Brightness.dark : Brightness.light,
        surface: AppThemeColors.card,
        outline: AppThemeColors.stroke,
      ),
    );

    return base.copyWith(
      textTheme: TextTheme(
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
        fillColor: isDark
            ? Colors.black.withValues(alpha: 0.5)
            : AppThemeColors.card.withValues(alpha: 0.96),
        hintStyle: TextStyle(color: AppThemeColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: AppThemeColors.stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: AppThemeColors.stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: AppThemeColors.accent, width: 1.4),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppThemeColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: AppThemeColors.stroke),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppThemeColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      dividerColor: AppThemeColors.stroke,
    );
  }

  static ThemeData light() =>
      build(isDark: false, accentColor: const Color(0xFF19B38D));
  static ThemeData dark() =>
      build(isDark: true, accentColor: const Color(0xFF19B38D));
}
