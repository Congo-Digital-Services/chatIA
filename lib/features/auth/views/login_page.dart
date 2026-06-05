import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/keycloak_config.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/conduit_button.dart';
import '../../../shared/widgets/conduit_card.dart';
import '../../../shared/widgets/conduit_logo.dart';
import '../providers/auth_state_provider.dart';

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    if (auth.isRestoring) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF9F9F7), Color(0xFFF1F2EE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                const ConduitLogo(),
                const SizedBox(height: 24),
                Text(
                  'Conduit Mobile',
                  style: theme.textTheme.displaySmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'Reproduction UI fidèle de Conduit/OpenWebUI, prête pour un SSO Keycloak.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppThemeColors.textSoft,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                ConduitCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(CupertinoIcons.lock_shield),
                          const SizedBox(width: 10),
                          Text(
                            'Authentification',
                            style: theme.textTheme.titleLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        KeycloakConfig.isConfigured
                            ? 'SSO Keycloak configuré, prêt pour Authorization Code Flow + PKCE.'
                            : 'Mode maquette actif. Ajoute les constantes Keycloak pour basculer sur un vrai flux OIDC.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppThemeColors.textSoft,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ConduitPrimaryButton(
                        label: auth.isLoading
                            ? 'Connexion en cours...'
                            : 'Se connecter avec SSO',
                        icon: CupertinoIcons.arrow_right_circle_fill,
                        onPressed: auth.isLoading
                            ? null
                            : () => ref
                                .read(authControllerProvider)
                                .signInWithSso(),
                      ),
                      if (auth.errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF2F1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFFFD4D1)),
                          ),
                          child: Text(
                            auth.errorMessage!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF9A2C23),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  'Constantes prévues : keycloakBaseUrl, realm, clientId, redirectUri.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppThemeColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
