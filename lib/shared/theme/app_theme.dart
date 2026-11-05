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
      isDark ? const Color(0xFF262932) : const Color(0xFFECEEF1);
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

  /// Vert de la marque MALOBA (logo 3D, ~/PNUD-AI/ChatAI/LISEZMOI.md) :
  /// un vert pour fond clair, un vert éclairci pour fond sombre.
  static const brandGreen = Color(0xFF1F7A4B);
  static const brandGreenDark = Color(0xFF4FB07B);

  /// Couleur d'accent choisie dans les réglages (vert MALOBA par défaut),
  /// ajustée pour rester lisible sur le fond (contraste >= 3:1).
  static Color _accentChoice = brandGreen;
  static Color get accent => _accentChoice == brandGreen
      ? (isDark ? brandGreenDark : brandGreen)
      : _readable(_accentChoice, background, 3.0);
  static Color get accentSoft => accent.withValues(alpha: isDark ? 0.18 : 0.10);

  /// Couleur du contenu posé SUR l'accent (icône d'un bouton plein).
  static Color get onAccent => _contrast(Colors.white, accent) >= 3.0
      ? Colors.white
      : const Color(0xFF0B1F18);
  static Color get success =>
      isDark ? const Color(0xFF34D399) : const Color(0xFF0F9D6E);
  static Color get danger =>
      isDark ? const Color(0xFFFF7B7B) : const Color(0xFFD13F3F);
  static Color get dangerSoft => danger.withValues(alpha: isDark ? 0.16 : 0.08);
  static Color get warning =>
      isDark ? const Color(0xFFFBBF5E) : const Color(0xFFB7791F);
  static Color get info => textStrong;

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  /// Assombrit (fond clair) ou éclaircit (fond sombre) la teinte choisie
  /// jusqu'au contraste demandé, sans en changer la couleur.
  static Color _readable(Color color, Color bg, double target) {
    var hsl = HSLColor.fromColor(color);
    final darken = bg.computeLuminance() > 0.5;
    for (var i = 0; i < 20 && _contrast(hsl.toColor(), bg) < target; i++) {
      final l = (hsl.lightness + (darken ? -0.03 : 0.03)).clamp(0.0, 1.0);
      hsl = hsl.withLightness(l);
    }
    return hsl.toColor();
  }

  static LinearGradient get shellGradient => LinearGradient(
    colors: [background, background],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static void syncWithContext(BuildContext context, {Color? activeAccent}) {
    currentBrightness = Theme.of(context).brightness;
  }

  static void update(bool isDarkVal, {Color? accentColor}) {
    currentBrightness = isDarkVal ? Brightness.dark : Brightness.light;
    if (accentColor != null) {
      _accentChoice = accentColor;
    }
  }
}

class AppThemeShadows {
  static List<BoxShadow> get soft => AppThemeColors.isDark
      ? const <BoxShadow>[]
      : const [
          BoxShadow(
            color: Color(0x0D101828),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
          BoxShadow(
            color: Color(0x08101828),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ];
  static List<BoxShadow> get medium => AppThemeColors.isDark
      ? const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x14101828),
            blurRadius: 32,
            offset: Offset(0, 12),
          ),
          BoxShadow(
            color: Color(0x0A101828),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ];
}

class AppTheme {
  static ThemeData build({required bool isDark, required Color accentColor}) {
    AppThemeColors.update(isDark, accentColor: accentColor);

    final scheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: AppThemeColors.accent,
      onPrimary: AppThemeColors.onAccent,
      secondary: AppThemeColors.accent,
      onSecondary: AppThemeColors.onAccent,
      error: AppThemeColors.danger,
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
          backgroundColor: AppThemeColors.accent,
          foregroundColor: AppThemeColors.onAccent,
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
          borderSide: BorderSide(color: AppThemeColors.accent, width: 1.4),
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
