import 'package:flutter/material.dart';

/// Système de couleurs dynamique basé sur la luminosité courante.
/// Les getters lisent [currentBrightness] à chaque appel, garantissant
/// que les couleurs sont toujours cohérentes avec le thème actif.
class AppThemeColors {
  static Brightness currentBrightness = Brightness.light;

  static bool get isDark => currentBrightness == Brightness.dark;

  // ── Arrière-plans ─────────────────────────────────────────────────────────
  /// Fond principal du Scaffold
  static Color get background =>
      isDark ? const Color(0xFF0D0D0D) : const Color(0xFFFFFFFF);

  /// Fond des cartes (légèrement surélevé du fond)
  static Color get card =>
      isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF5F5F5);

  /// Fond des cartes très surélevées (dialogues, bottom sheets)
  static Color get cardStrong =>
      isDark ? const Color(0xFF282828) : const Color(0xFFEEEEEE);

  // ── Bordures / Contours ───────────────────────────────────────────────────
  /// Couleur de bordure standard
  static Color get stroke =>
      isDark ? const Color(0xFF333333) : const Color(0xFFDDDDDD);

  // ── Pastilles / Chips ─────────────────────────────────────────────────────
  /// Fond de pastille non-sélectionnée
  static Color get pill =>
      isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8E8E8);

  /// Fond de pastille sélectionnée
  static Color get pillSelected =>
      isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111111);

  // ── Textes ────────────────────────────────────────────────────────────────
  /// Texte principal (fort contraste)
  static Color get textStrong =>
      isDark ? const Color(0xFFF2F2F2) : const Color(0xFF111111);

  /// Texte secondaire (contraste modéré)
  static Color get textSoft =>
      isDark ? const Color(0xFFAAAAAA) : const Color(0xFF555555);

  /// Texte atténué (légende, placeholder)
  static Color get textMuted =>
      isDark ? const Color(0xFF666666) : const Color(0xFF999999);

  // ── Accent ────────────────────────────────────────────────────────────────
  /// Couleur d'accentuation monochrome
  static Color get accent =>
      isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);

  // ── Mise à jour / Synchronisation ─────────────────────────────────────────
  static void syncWithContext(BuildContext context, {Color? activeAccent}) {
    currentBrightness = Theme.of(context).brightness;
  }

  static void update(bool isDarkVal, Color activeAccent) {
    currentBrightness = isDarkVal ? Brightness.dark : Brightness.light;
  }
}

class AppThemeShadows {
  static const soft = <BoxShadow>[];
}

class AppTheme {
  static ThemeData build({required bool isDark, required Color accentColor}) {
    AppThemeColors.update(isDark, accentColor);

    // Couleurs locales pour construire le thème (getters déjà synchro)
    final bg = AppThemeColors.background;
    final cardColor = AppThemeColors.card;
    final strokeColor = AppThemeColors.stroke;
    final textStrongColor = AppThemeColors.textStrong;
    final textMutedColor = AppThemeColors.textMuted;
    final accentColor2 = AppThemeColors.accent;

    final base = ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentColor2,
        brightness: isDark ? Brightness.dark : Brightness.light,
        surface: cardColor,
        outline: strokeColor,
      ),
    );

    return base.copyWith(
      textTheme: TextTheme(
        displaySmall: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.0,
          height: 1.4,
          color: textStrongColor,
        ),
        headlineLarge: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          height: 1.4,
          color: textStrongColor,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          height: 1.4,
          color: textStrongColor,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          height: 1.4,
          color: textStrongColor,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.4,
          color: textStrongColor,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: textStrongColor,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: textStrongColor,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          height: 1.4,
          color: textMutedColor,
        ),
        labelLarge: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.4,
          color: textMutedColor,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        hintStyle: TextStyle(color: textMutedColor),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: strokeColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: strokeColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF555555) : const Color(0xFF888888),
            width: 2,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: strokeColor, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: strokeColor, width: 1),
        ),
      ),
      dividerColor: strokeColor,
      iconTheme: IconThemeData(color: textStrongColor),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: textStrongColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFF222222),
        contentTextStyle: const TextStyle(color: Colors.white),
        actionTextColor: const Color(0xFFAAAAAA),
      ),
    );
  }

  static ThemeData light() =>
      build(isDark: false, accentColor: const Color(0xFF000000));
  static ThemeData dark() =>
      build(isDark: true, accentColor: const Color(0xFFFFFFFF));
}
