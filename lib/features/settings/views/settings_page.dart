import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_state_provider.dart';
import '../../../shared/data/mock_data.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/conduit_card.dart';
import '../../../shared/widgets/settings_tile.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.session;

    return Scaffold(
      backgroundColor: AppThemeColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          children: [
            Row(
              children: [
                _TopButton(
                  icon: CupertinoIcons.back,
                  onTap: () => context.pop(),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 15),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.84),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: AppThemeShadows.soft,
                  ),
                  child: Text(
                    'Customization',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 28),
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 54),
              ],
            ),
            const SizedBox(height: 42),
            Text('Display', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 29)),
            const SizedBox(height: 18),
            const SettingsTile(
              icon: CupertinoIcons.moon_stars,
              title: 'Dark Mode',
              subtitle: 'Currently using Light theme',
              trailing: CupertinoIcons.chevron_down,
            ),
            const SizedBox(height: 16),
            const SettingsTile(
              icon: CupertinoIcons.square_stack,
              title: 'Accent palette',
              subtitle: 'Conduit',
              palette: [Color(0xFF000000), Color(0xFF18B489), Color(0xFFF1F1EE)],
            ),
            const SizedBox(height: 16),
            const SettingsTile(
              icon: CupertinoIcons.bolt,
              title: 'Quickpills in chat',
              subtitle: 'No actions selected',
              trailing: CupertinoIcons.chevron_down,
            ),
            const SizedBox(height: 36),
            Text('App Language', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 29)),
            const SizedBox(height: 18),
            const SettingsTile(
              icon: CupertinoIcons.globe,
              title: 'App Language',
              subtitle: 'System',
              trailing: CupertinoIcons.chevron_right,
            ),
            const SizedBox(height: 36),
            Text('Speech to Text', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 29)),
            const SizedBox(height: 18),
            const SettingsTile(
              icon: CupertinoIcons.mic,
              title: 'Recognition engine',
              subtitle: 'On device',
              segmentedValues: ['On device', 'Server'],
            ),
            const SizedBox(height: 36),
            Text('Profile', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 29)),
            const SizedBox(height: 18),
            ConduitCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: const Color(0xFFE2E3DE),
                    child: Text(
                      (user?.userName ?? 'U').substring(0, 1).toUpperCase(),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.userName ?? MockData.profileName,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? MockData.profileEmail,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppThemeColors.textSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ConduitCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Session', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 10),
                  Text(
                    user?.isMock == true
                        ? 'Mock sign-in active. Replace Keycloak constants to connect the real SSO flow.'
                        : 'Connected with Keycloak.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppThemeColors.textSoft,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: () async {
                        await ref.read(authControllerProvider).signOut();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF7E8E6),
                        foregroundColor: const Color(0xFF8E2A22),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text('Déconnexion'),
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

class _TopButton extends StatelessWidget {
  const _TopButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.84),
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: SizedBox(
          width: 54,
          height: 54,
          child: Icon(icon, size: 30),
        ),
      ),
    );
  }
}
