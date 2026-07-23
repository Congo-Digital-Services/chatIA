import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/chatia_api_service.dart';
import '../../../shared/data/mock_data.dart';
import '../../../shared/theme/app_theme.dart';
import '../../auth/providers/auth_state_provider.dart';
import '../providers/settings_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.session;
    final settings = ref.watch(settingsControllerProvider);
    final theme = Theme.of(context);

    final profileName = user?.userName ?? MockData.profileName;
    final profileEmail = user?.email ?? MockData.profileEmail;

    return Scaffold(
      backgroundColor: AppThemeColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6, top: 8),
                    child: Text(
                      'Paramètres',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
                _HeaderButton(
                  icon: CupertinoIcons.xmark,
                  onTap: () => context.pop(),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _ProfileSummary(
              initials: _initialsFrom(profileName),
              name: profileName,
              email: profileEmail,
            ),
            const SizedBox(height: 26),
            const _SectionTitle('Personnaliser ChatIA'),
            const SizedBox(height: 10),
            _SettingsGroup(
              children: [
                _SettingsRow(
                  icon: CupertinoIcons.sparkles,
                  title: 'Personnalisation',
                  subtitle: 'Nom, mémoire et comportement de l’assistant',
                ),
                _SettingsRow(
                  icon: CupertinoIcons.book,
                  title: 'Mémoire',
                  subtitle: 'Gestion du contexte et des préférences',
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Apparence'),
            const SizedBox(height: 10),
            _SettingsGroup(
              children: [
                _SettingsRow(
                  icon: CupertinoIcons.moon,
                  title: 'Thème',
                  value: _themeLabel(settings.themeMode),
                  onTap: () => _showThemeSheet(context, ref, settings),
                ),
                _SettingsRow(
                  icon: CupertinoIcons.globe,
                  title: 'Langue',
                  value: SettingsController.languageName(settings.language),
                  onTap: () => _showLanguageSheet(context, ref, settings),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Application'),
            const SizedBox(height: 10),
            _SettingsGroup(
              children: [
                _SettingsRow(
                  icon: CupertinoIcons.mic,
                  title: 'Voix et dictée',
                  subtitle: settings.voiceEngine == 'server'
                      ? 'Traitement serveur'
                      : 'Traitement sur l’appareil',
                  onTap: () => _showVoiceSheet(context, ref, settings),
                ),
                const _SettingsRow(
                  icon: CupertinoIcons.bell,
                  title: 'Notifications',
                  subtitle: 'Paramètres système',
                ),
                const _SettingsRow(
                  icon: CupertinoIcons.archivebox,
                  title: 'Stockage',
                  subtitle: 'Fichiers, images et cache local',
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Compte'),
            const SizedBox(height: 10),
            _SettingsGroup(
              children: [
                _SettingsRow(
                  icon: CupertinoIcons.mail,
                  title: 'Adresse e-mail',
                  subtitle: profileEmail,
                ),
                _SettingsRow(
                  icon: CupertinoIcons.person_crop_circle,
                  title: 'Session',
                  subtitle: user?.isMock == true
                      ? 'Connexion locale active'
                      : 'Session active',
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Aide'),
            const SizedBox(height: 10),
            const _SettingsGroup(
              children: [
                _SettingsRow(
                  icon: CupertinoIcons.flag,
                  title: 'Signaler un problème',
                  subtitle: 'Retour visuel ou anomalie de l’application',
                ),
                _SettingsRow(
                  icon: CupertinoIcons.question_circle,
                  title: 'Centre d’assistance',
                  subtitle: 'Documentation et support',
                ),
                _SettingsRow(
                  icon: CupertinoIcons.info_circle,
                  title: 'À propos',
                  subtitle: 'Informations de l’application',
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SignOutButton(
              isLoading: auth.isLoading,
              onTap: auth.isLoading
                  ? null
                  : () async {
                      try {
                        final api = ref.read(chatiaApiProvider);
                        if (api.isAvailable) {
                          await api.logout();
                        }
                      } catch (_) {}
                      await ref.read(authControllerProvider).signOut();
                    },
            ),
          ],
        ),
      ),
    );
  }

  static String _initialsFrom(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return 'U';
    }
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }

  static String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Clair';
      case ThemeMode.dark:
        return 'Sombre';
      case ThemeMode.system:
        return 'Système';
    }
  }

  static Future<void> _showThemeSheet(
    BuildContext context,
    WidgetRef ref,
    SettingsController settings,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SheetShell(
          title: 'Thème',
          child: _ChoiceGroup<ThemeMode>(
            value: settings.themeMode,
            items: const [
              _ChoiceItem(
                value: ThemeMode.system,
                title: 'Système',
                subtitle: 'Suit le réglage de l’appareil',
              ),
              _ChoiceItem(
                value: ThemeMode.dark,
                title: 'Sombre',
                subtitle: 'Mode sombre permanent',
              ),
              _ChoiceItem(
                value: ThemeMode.light,
                title: 'Clair',
                subtitle: 'Mode clair permanent',
              ),
            ],
            onSelected: (value) {
              ref.read(settingsControllerProvider).setThemeMode(value);
              Navigator.of(context).pop();
            },
          ),
        );
      },
    );
  }

  static Future<void> _showLanguageSheet(
    BuildContext context,
    WidgetRef ref,
    SettingsController settings,
  ) {
    final entries = supportedLanguages.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _SheetShell(
          title: 'Langue',
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.58,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: entries.length,
              separatorBuilder: (_, index) =>
                  Divider(height: 1, color: AppThemeColors.stroke),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _SelectableRow(
                  title: entry.value,
                  selected: entry.key == settings.language,
                  onTap: () {
                    ref.read(settingsControllerProvider).setLanguage(entry.key);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  static Future<void> _showVoiceSheet(
    BuildContext context,
    WidgetRef ref,
    SettingsController settings,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SheetShell(
          title: 'Voix et dictée',
          child: _ChoiceGroup<String>(
            value: settings.voiceEngine,
            items: const [
              _ChoiceItem(
                value: 'local',
                title: 'Sur l’appareil',
                subtitle: 'Plus direct et plus privé',
              ),
              _ChoiceItem(
                value: 'server',
                title: 'Serveur',
                subtitle: 'Traitement distant quand nécessaire',
              ),
            ],
            onSelected: (value) {
              ref.read(settingsControllerProvider).setVoiceEngine(value);
              Navigator.of(context).pop();
            },
          ),
        );
      },
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({
    required this.initials,
    required this.name,
    required this.email,
  });

  final String initials;
  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppThemeColors.pill,
            border: Border.all(color: AppThemeColors.stroke),
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          name,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          email,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppThemeColors.textSoft,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppThemeColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppThemeColors.stroke),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;

  bool get _isLastRowWithoutDivider =>
      title == 'Mémoire' ||
      title == 'Langue' ||
      title == 'Stockage' ||
      title == 'Session' ||
      title == 'À propos';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: AppThemeColors.textSoft),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppThemeColors.textSoft,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (value != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        value!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppThemeColors.textSoft,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const SizedBox(width: 10),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 15,
                    color: AppThemeColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!_isLastRowWithoutDivider)
          Padding(
            padding: const EdgeInsets.only(left: 50),
            child: Divider(height: 1, color: AppThemeColors.stroke),
          ),
      ],
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.isLoading, required this.onTap});

  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          height: 58,
          decoration: BoxDecoration(
            color: AppThemeColors.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppThemeColors.stroke),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading) ...[
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFFF453A),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ] else ...[
                const Icon(
                  CupertinoIcons.square_arrow_right,
                  size: 18,
                  color: Color(0xFFFF453A),
                ),
                const SizedBox(width: 12),
              ],
              Text(
                isLoading ? 'Déconnexion…' : 'Se déconnecter',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFFFF453A),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppThemeColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppThemeColors.stroke),
          ),
          child: Icon(icon, size: 18, color: AppThemeColors.textStrong),
        ),
      ),
    );
  }
}

class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          decoration: BoxDecoration(
            color: AppThemeColors.cardStrong,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppThemeColors.stroke),
          ),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppThemeColors.strokeStrong,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _HeaderButton(
                    icon: CupertinoIcons.xmark,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceGroup<T> extends StatelessWidget {
  const _ChoiceGroup({
    required this.value,
    required this.items,
    required this.onSelected,
  });

  final T value;
  final List<_ChoiceItem<T>> items;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppThemeColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppThemeColors.stroke),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _SelectableRow(
              title: items[i].title,
              subtitle: items[i].subtitle,
              selected: items[i].value == value,
              onTap: () => onSelected(items[i].value),
            ),
            if (i != items.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Divider(height: 1, color: AppThemeColors.stroke),
              ),
          ],
        ],
      ),
    );
  }
}

class _ChoiceItem<T> {
  const _ChoiceItem({
    required this.value,
    required this.title,
    required this.subtitle,
  });

  final T value;
  final String title;
  final String subtitle;
}

class _SelectableRow extends StatelessWidget {
  const _SelectableRow({
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppThemeColors.textSoft,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? AppThemeColors.textStrong
                      : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? AppThemeColors.textStrong
                        : AppThemeColors.strokeStrong,
                  ),
                ),
                child: selected
                    ? Icon(
                        CupertinoIcons.check_mark,
                        size: 12,
                        color: AppThemeColors.background,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
