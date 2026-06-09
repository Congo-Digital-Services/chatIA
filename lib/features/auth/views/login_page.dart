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
    final isDark = theme.brightness == Brightness.dark;

    if (auth.isRestoring) {
      return Scaffold(
        backgroundColor: AppThemeColors.background,
        body: Center(
          child: CircularProgressIndicator(
            color: AppThemeColors.accent,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppThemeColors.background,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF161614), const Color(0xFF1C1C19)]
                : [const Color(0xFFF9F9F7), const Color(0xFFEFF0EB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 2),
                // Logo + nom
                const ConduitLogo(),
                const SizedBox(height: 20),
                Text(
                  'Conduit',
                  style: theme.textTheme.displaySmall?.copyWith(
                    letterSpacing: -1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Votre assistant IA, partout avec vous.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppThemeColors.textSoft,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 28),
                // Carte d'authentification
                ConduitCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // En-tête de la carte
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppThemeColors.pill,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              CupertinoIcons.lock_shield,
                              size: 18,
                              color: AppThemeColors.textSoft,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Authentification',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Statut
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppThemeColors.pill,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          KeycloakConfig.isConfigured
                              ? 'SSO Keycloak configuré — Authorization Code Flow + PKCE prêt.'
                              : 'Mode maquette actif. Renseignez les constantes Keycloak pour activer le vrai flux OIDC.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppThemeColors.textSoft,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Bouton connexion
                      ConduitPrimaryButton(
                        label: auth.isLoading
                            ? 'Connexion en cours…'
                            : 'Se connecter avec SSO',
                        icon: CupertinoIcons.arrow_right_circle_fill,
                        onPressed: auth.isLoading
                            ? null
                            : () => ref
                                .read(authControllerProvider)
                                .signInWithSso(),
                      ),
                      // Message d'erreur
                      if (auth.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF2F1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFD4D1)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                CupertinoIcons.exclamationmark_circle,
                                size: 16,
                                color: Color(0xFF9A2C23),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  auth.errorMessage!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF9A2C23),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Spacer(flex: 3),
                // Note de bas de page
                Center(
                  child: Text(
                    'keycloakBaseUrl · realm · clientId · redirectUri',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppThemeColors.textMuted,
                      letterSpacing: 0.2,
                    ),
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
