import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_state_provider.dart';
import '../../../shared/data/mock_data.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/conduit_card.dart';
import '../../../shared/widgets/settings_tile.dart';
import '../providers/settings_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  // Helper method to show standard selection dialog
  void _showSelectionDialog<T>({
    required BuildContext context,
    required String title,
    required List<T> values,
    required List<String> displayNames,
    required List<IconData>? icons,
    required T currentValue,
    required ValueChanged<T> onSelected,
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppThemeColors.card : const Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(title,
              style: theme.textTheme.titleLarge
                  ?.copyWith(color: AppThemeColors.textStrong)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(values.length, (index) {
              final val = values[index];
              final isSelected = val == currentValue;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    onSelected(val);
                    Navigator.of(ctx).pop();
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppThemeColors.accent.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: isSelected
                          ? Border.all(
                              color: AppThemeColors.accent.withValues(alpha: 0.4))
                          : null,
                    ),
                    child: Row(
                      children: [
                        if (icons != null) ...[
                          Icon(icons[index],
                              size: 20,
                              color: isSelected
                                  ? AppThemeColors.accent
                                  : AppThemeColors.textSoft),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Text(
                            displayNames[index],
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected
                                  ? AppThemeColors.accent
                                  : AppThemeColors.textStrong,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle_rounded,
                              color: AppThemeColors.accent, size: 20),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

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
    final accentLabel = settings.translate('accent_palette');
    final shortcutsLabel = settings.translate('shortcuts');
    final languageSection = settings.translate('language');
    final appLanguageLabel = settings.translate('app_language');
    final voiceSection = settings.translate('voice_dictation');
    final engineLabel = settings.translate('recognition_engine');
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

    String getShortcutSubtitle() {
      switch (settings.shortcutAction) {
        case 'none':
          return settings.translate('shortcut_none');
        case 'voice_call':
          return settings.translate('shortcut_voice_call');
        case 'file_picker':
          return settings.translate('shortcut_file_picker');
        case 'create_note':
          return settings.translate('shortcut_create_note');
        case 'new_chat':
          return settings.translate('shortcut_new_chat');
        default:
          return settings.translate('shortcut_none');
      }
    }

    IconData getShortcutIcon() {
      switch (settings.shortcutAction) {
        case 'voice_call':
          return CupertinoIcons.phone_fill;
        case 'file_picker':
          return CupertinoIcons.folder_fill;
        case 'create_note':
          return CupertinoIcons.doc_fill;
        case 'new_chat':
          return CupertinoIcons.chat_bubble_fill;
        default:
          return CupertinoIcons.bolt;
      }
    }

    String getLanguageSubtitle() {
      return SettingsController.languageName(settings.language);
    }

    final paletteColors = [
      const Color(0xFF18B489), // Green (Conduit default)
      const Color(0xFF1976D2), // Blue
      const Color(0xFF9C27B0), // Purple
      const Color(0xFFE65100), // Orange
      const Color(0xFF0E0E0E), // Dark/Black
    ];

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
                    color: isDark
                        ? AppThemeColors.card
                        : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppThemeColors.stroke),
                    boxShadow: AppThemeShadows.soft,
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

            const SizedBox(height: 12),
            SettingsTile(
              icon: CupertinoIcons.square_stack,
              title: accentLabel,
              subtitle: getLanguageSubtitle() == 'Français'
                  ? 'Palette active'
                  : getLanguageSubtitle() == 'Español'
                      ? 'Paleta activa'
                      : 'Active palette',
              palette: paletteColors,
              selectedColor: settings.accentColor,
              onPaletteColorSelected: (color) => settings.setAccentColor(color),
            ),
            const SizedBox(height: 12),
            SettingsTile(
              icon: getShortcutIcon(),
              title: shortcutsLabel,
              subtitle: getShortcutSubtitle(),
              trailing: CupertinoIcons.chevron_down,
              onTap: () {
                _showSelectionDialog<String>(
                  context: context,
                  title: settings.translate('select_shortcut'),
                  values: [
                    'none',
                    'voice_call',
                    'file_picker',
                    'create_note',
                    'new_chat'
                  ],
                  displayNames: [
                    settings.translate('shortcut_none'),
                    settings.translate('shortcut_voice_call'),
                    settings.translate('shortcut_file_picker'),
                    settings.translate('shortcut_create_note'),
                    settings.translate('shortcut_new_chat'),
                  ],
                  icons: [
                    CupertinoIcons.minus_circle,
                    CupertinoIcons.phone_fill,
                    CupertinoIcons.folder_fill,
                    CupertinoIcons.doc_fill,
                    CupertinoIcons.chat_bubble_fill,
                  ],
                  currentValue: settings.shortcutAction,
                  onSelected: (action) => settings.setShortcutAction(action),
                );
              },
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

            // ── Voix ─────────────────────────────────────────────────────────
            _SectionTitle(theme: theme, label: voiceSection),
            const SizedBox(height: 14),
            SettingsTile(
              icon: CupertinoIcons.mic,
              title: engineLabel,
              subtitle: settings.voiceEngine == 'local'
                  ? settings.translate('local_device')
                  : settings.translate('server'),
              segmentedValues: [
                settings.translate('local_device'),
                settings.translate('server')
              ],
              selectedSegmentIndex: settings.voiceEngine == 'local' ? 0 : 1,
              onSegmentChanged: (idx) {
                settings.setVoiceEngine(idx == 0 ? 'local' : 'server');
              },
              note: settings.translate('voice_note'),
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
                    backgroundColor: isDark
                        ? AppThemeColors.pillSelected
                        : const Color(0xFFE2E3DE),
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
                    child: FilledButton(
                      onPressed: () async {
                        await ref.read(authControllerProvider).signOut();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFBECEB),
                        foregroundColor: const Color(0xFF8E2A22),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Text(signOutLabel),
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
        color: isDark
            ? Colors.black.withValues(alpha: 0.24)
            : Colors.white,
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
                  color: isDark
                      ? AppThemeColors.pillSelected
                      : const Color(0xFFEEEEEB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(CupertinoIcons.moon_stars,
                    size: 20, color: AppThemeColors.textStrong),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppThemeColors.textStrong,
                        )),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppThemeColors.textSoft,
                        )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? AppThemeColors.pill : const Color(0xFFDFE0DC),
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
                            ? (isDark ? AppThemeColors.pillSelected : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: isSelected && !isDark
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
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
                                ? AppThemeColors.accent
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
                                  ? AppThemeColors.accent
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
        color: isDark ? Colors.black.withValues(alpha: 0.24) : Colors.white,
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
              color: isDark
                  ? AppThemeColors.pillSelected
                  : const Color(0xFFF4F4F4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(CupertinoIcons.globe,
                size: 20, color: AppThemeColors.textStrong),
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
                    icon: Icon(CupertinoIcons.chevron_down, size: 16, color: AppThemeColors.textSoft),
                    dropdownColor: isDark ? AppThemeColors.card : Colors.white,
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
                            color: settings.language == code ? AppThemeColors.accent : AppThemeColors.textStrong,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: isDark
            ? AppThemeColors.card
            : Colors.white.withValues(alpha: 0.88),
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
      ),
    );
  }
}
