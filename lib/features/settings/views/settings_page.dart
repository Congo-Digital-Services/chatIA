import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/chatia_api_service.dart';
import '../../../core/services/tts_service.dart';
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
            const _SectionTitle('Apparence'),
            const SizedBox(height: 10),
            _SettingsGroup(
              children: [
                _SettingsRow(
                  icon: CupertinoIcons.moon,
                  title: 'Thème',
                  value: _themeLabel(settings.themeMode),
                  onTap: () => _showThemeSheet(context, ref, settings),
                  showDivider: false,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Voix & Lecture'),
            const SizedBox(height: 10),
            _SettingsGroup(
              children: [
                _SettingsToggleRow(
                  icon: CupertinoIcons.volume_up,
                  title: 'Lecture vocale des réponses',
                  subtitle: 'Lire les réponses de LoBa IA à voix haute',
                  value: settings.ttsEnabled,
                  onChanged: (value) {
                    if (!value) {
                      ttsService.stop();
                    }
                    ref.read(settingsControllerProvider).setTtsEnabled(value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Aide'),
            const SizedBox(height: 10),
            _SettingsGroup(
              children: [
                _SettingsRow(
                  icon: CupertinoIcons.book,
                  title: 'Guides d’utilisation',
                  subtitle: 'Découvrir les modes Discussion et Santé',
                  onTap: () => _showGuidesDialog(context),
                ),
                _SettingsRow(
                  icon: CupertinoIcons.lock_shield,
                  title: 'Confidentialité et données',
                  subtitle: 'Vos conversations de santé restent privées',
                  onTap: () => _showConfidentialityDialog(context),
                ),
                _SettingsRow(
                  icon: CupertinoIcons.flag,
                  title: 'Signaler un problème',
                  subtitle: 'Une anomalie ou un retour sur l’application',
                  onTap: () => _showReportDialog(context),
                ),
                _SettingsRow(
                  icon: CupertinoIcons.info_circle,
                  title: 'À propos de LoBa IA',
                  subtitle: 'Version et informations de l’application',
                  onTap: () => _showAboutDialog(context),
                  showDivider: false,
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
      isScrollControlled: true,
      builder: (context) => AnimatedPadding(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: _SheetShell(
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
        ),
      ),
    );
  }

  static Future<void> _showGuidesDialog(BuildContext context) {
    return _showHelpDialog(
      context,
      icon: CupertinoIcons.book,
      title: 'Guides d’utilisation',
      paragraphs: const [
        'Mode Discussion : échangez avec LoBa IA par écrit, en français ou en lingala, sur n’importe quel sujet.',
        'Mode Santé : appuyez sur le micro, dictez vos symptômes ou vos préoccupations de santé, puis envoyez. LoBa IA vous écoute et vous répond.',
        'Vos conversations sont conservées dans l’historique et restent accessibles à tout moment.',
      ],
    );
  }

  static void _showConfidentialityDialog(BuildContext context) {
    _showHelpDialog(
      context,
      icon: CupertinoIcons.lock_shield,
      title: 'Confidentialité et données',
      paragraphs: const [
        'Vos conversations et vos enregistrements vocaux sont traités de manière confidentielle.',
        'Ils sont stockés sur le serveur de LoBa IA et ne sont jamais partagés avec d’autres personnes.',
        'Vous pouvez vous déconnecter à tout moment pour protéger l’accès à votre compte.',
      ],
    );
  }

  static void _showReportDialog(BuildContext context) {
    _showHelpDialog(
      context,
      icon: CupertinoIcons.flag,
      title: 'Signaler un problème',
      paragraphs: const [
        'Si une réponse est erronée, si l’audio n’est pas transcrit correctement ou si l’application se bloque, nous voulons le savoir.',
        'Précisez le mode utilisé (Discussion ou Santé), la date et ce qui s’est passé.',
        'Envoyez votre retour à votre administrateur ou via le canal d’assistance de votre plateforme.',
      ],
    );
  }

  static void _showAboutDialog(BuildContext context) {
    _showHelpDialog(
      context,
      icon: CupertinoIcons.info_circle,
      title: 'À propos de LoBa IA',
      paragraphs: const [
        'LoBa IA est votre assistant de santé conversationnel, en français et en lingala.',
        'Il vous écoute, comprend vos symptômes et vous guide en toute confidentialité.',
      ],
      note: 'Version 1.0.0',
    );
  }

  static Future<void> _showHelpDialog(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<String> paragraphs,
    String? note,
  }) {
    final theme = Theme.of(context);
    return showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * .82,
              maxWidth: 520,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    child: Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        color: AppThemeColors.accentSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 30, color: AppThemeColors.accent),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 14),
                  for (final paragraph in paragraphs) ...[
                    Text(
                      paragraph,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppThemeColors.textSoft,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (note != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppThemeColors.backgroundSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        note,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppThemeColors.textMuted,
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Compris'),
                    ),
                  ),
                ],
              ),
            ),
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
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;
  final bool showDivider;

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
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 50),
            child: Divider(height: 1, color: AppThemeColors.stroke),
          ),
      ],
    );
  }
}

class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onChanged(!value),
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
                  const SizedBox(width: 10),
                  CupertinoSwitch(
                    value: value,
                    activeTrackColor: AppThemeColors.accent,
                    onChanged: onChanged,
                  ),
                ],
              ),
            ),
          ),
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
