import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/chatia_api_service.dart';
import '../../auth/providers/auth_state_provider.dart';
import '../../../shared/data/mock_data.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/conduit_card.dart';

import '../providers/settings_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.session;
    final theme = Theme.of(context);
    final settings = ref.watch(settingsControllerProvider);
    final isDark = theme.brightness == Brightness.dark;

    // Localized labels
    final titleLabel = settings.translate('settings_title');
    final displaySection = settings.translate('display');
    final darkModeLabel = settings.translate('dark_mode');
    final languageSection = settings.translate('language');
    final appLanguageLabel = settings.translate('app_language');
    final profileSection = settings.translate('profile');
    final sessionLabel = settings.translate('session');
    final signOutLabel = settings.translate('sign_out');

    // Subtitle maps
    String getThemeSubtitle() {
      switch (settings.themeMode) {
        case ThemeMode.light:
          return settings.translate('theme_light');
        case ThemeMode.dark:
          return settings.translate('theme_dark');
        case ThemeMode.system:
          return settings.translate('theme_system');
      }
    }

    return Scaffold(
      backgroundColor: AppThemeColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              children: [
                _SettingsHeaderBtn(
                  icon: CupertinoIcons.chevron_left,
                  tooltip: settings.translate('back'),
                  onTap: () => context.pop(),
                ),
                const Spacer(),
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppThemeColors.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppThemeColors.stroke),
                  ),
                  child: Center(
                    child: Text(
                      titleLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppThemeColors.textStrong,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 44),
              ],
            ),
            const SizedBox(height: 36),

            // ── Affichage ────────────────────────────────────────────────────
            _SectionTitle(theme: theme, label: displaySection),
            const SizedBox(height: 14),

            // Theme toggle — 3 segments visuels
            _ThemeSegmentTile(
              settings: settings,
              isDark: isDark,
              theme: theme,
              label: darkModeLabel,
              subtitle: getThemeSubtitle(),
            ),

            const SizedBox(height: 32),

            // ── Langue ───────────────────────────────────────────────────────
            _SectionTitle(theme: theme, label: languageSection),
            const SizedBox(height: 14),

            // Liste déroulante de langue
            _LanguageDropdownTile(
              settings: settings,
              isDark: isDark,
              theme: theme,
              label: appLanguageLabel,
            ),

            const SizedBox(height: 32),

            // ── Profil ────────────────────────────────────────────────────────
            _SectionTitle(theme: theme, label: profileSection),
            const SizedBox(height: 14),
            ConduitCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppThemeColors.pill,
                    child: Text(
                      (user?.userName ?? 'U').substring(0, 1).toUpperCase(),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppThemeColors.textStrong,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.userName ?? MockData.profileName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppThemeColors.textStrong,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          user?.email ?? MockData.profileEmail,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppThemeColors.textSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ConduitCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sessionLabel,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppThemeColors.textStrong,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user?.isMock == true
                        ? settings.translate('session_mock')
                        : settings.translate('session_keycloak'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppThemeColors.textSoft,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton(
                      onPressed: auth.isLoading
                          ? null
                          : () async {
                        try {
                          final api = ref.read(chatiaApiProvider);
                          if (api.isAvailable) await api.logout();
                        } catch (_) {}
                        await ref.read(authControllerProvider).signOut();
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppThemeColors.card,
                        side: BorderSide(
                          color: AppThemeColors.stroke,
                          width: 1,
                        ),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (auth.isLoading) ...[
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppThemeColors.textStrong,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Text(
                            auth.isLoading ? 'Déconnexion…' : signOutLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppThemeColors.textStrong,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/icons/congo_logo.png',
                    height: 70,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ministère des Postes, des Télécommunications\net de l\'Économie Numérique',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppThemeColors.textSoft,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'République du Congo',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppThemeColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sélecteur de thème en 3 segments ─────────────────────────────────────────
class _ThemeSegmentTile extends StatelessWidget {
  const _ThemeSegmentTile({
    required this.settings,
    required this.isDark,
    required this.theme,
    required this.label,
    required this.subtitle,
  });

  final SettingsController settings;
  final bool isDark;
  final ThemeData theme;
  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final options = [ThemeMode.light, ThemeMode.dark, ThemeMode.system];
    final labels = [
      settings.translate('light'),
      settings.translate('dark'),
      settings.translate('system'),
    ];
    final icons = [
      CupertinoIcons.sun_max,
      CupertinoIcons.moon_stars,
      CupertinoIcons.gear,
    ];
    final selectedIndex = options.indexOf(settings.themeMode);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppThemeColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppThemeColors.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppThemeColors.pill,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  CupertinoIcons.moon_stars,
                  size: 20,
                  color: AppThemeColors.textStrong,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppThemeColors.textStrong,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppThemeColors.textSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppThemeColors.pill,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: List.generate(3, (i) {
                final isSelected = selectedIndex == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => settings.setThemeMode(options[i]),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark
                                  ? AppThemeColors.pillSelected
                                  : AppThemeColors.card)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: isSelected && !isDark
                            ? [
                                BoxShadow(
                                  color: AppThemeColors.textStrong.withValues(
                                    alpha: 0.06,
                                  ),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icons[i],
                            size: 14,
                            color: isSelected
                                ? (isDark
                                      ? Colors.black
                                      : AppThemeColors.textStrong)
                                : AppThemeColors.textSoft,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            labels[i],
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected
                                  ? (isDark
                                        ? Colors.black
                                        : AppThemeColors.textStrong)
                                  : AppThemeColors.textSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sélecteur de langue (vraie liste déroulante — 15 langues) ────────────────
class _LanguageDropdownTile extends StatelessWidget {
  const _LanguageDropdownTile({
    required this.settings,
    required this.isDark,
    required this.theme,
    required this.label,
  });

  final SettingsController settings;
  final bool isDark;
  final ThemeData theme;
  final String label;

  @override
  Widget build(BuildContext context) {
    final langs = supportedLanguages.keys.toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppThemeColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppThemeColors.stroke),
      ),
      child: Row(
        children: [
          // Icône
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppThemeColors.pill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              CupertinoIcons.globe,
              size: 20,
              color: AppThemeColors.textStrong,
            ),
          ),
          const SizedBox(width: 16),
          // Label + Dropdown
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppThemeColors.textStrong,
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: settings.language,
                    isExpanded: true,
                    icon: Icon(
                      CupertinoIcons.chevron_down,
                      size: 16,
                      color: AppThemeColors.textSoft,
                    ),
                    dropdownColor: AppThemeColors.card,
                    borderRadius: BorderRadius.circular(14),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppThemeColors.accent,
                      fontWeight: FontWeight.w500,
                    ),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        settings.setLanguage(newValue);
                      }
                    },
                    items: langs.map<DropdownMenuItem<String>>((String code) {
                      return DropdownMenuItem<String>(
                        value: code,
                        child: Text(
                          supportedLanguages[code]!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: settings.language == code
                                ? AppThemeColors.accent
                                : AppThemeColors.textStrong,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Titre de section ──────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.theme, required this.label});

  final ThemeData theme;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppThemeColors.textStrong,
      ),
    );
  }
}

// ── Bouton header uniforme (44×44) ─────────────────────────────────────────
class _SettingsHeaderBtn extends StatelessWidget {
  const _SettingsHeaderBtn({
    required this.icon,
    required this.onTap,
    this.tooltip = '',
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: AppThemeColors.card,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 20, color: AppThemeColors.textStrong),
        ),
      ),
    );

    if (tooltip.isEmpty) {
      return button;
    }

    return Tooltip(message: tooltip, excludeFromSemantics: true, child: button);
  }
}
