import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/keycloak_config.dart';
import '../../../core/services/oauth_browser_helper.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/conduit_logo.dart';
import '../providers/auth_state_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  @override
  void initState() {
    super.initState();
    OAuthBrowserHelper.addPopupMessageListener(_handlePopupMessage);
  }

  @override
  void dispose() {
    OAuthBrowserHelper.removePopupMessageListener();
    super.dispose();
  }

  void _handlePopupMessage(Map<String, dynamic> message) {
    if (message['type'] != 'oauth_popup_result') return;

    if (message['success'] == true) {
      ref.read(authControllerProvider).restore();
      return;
    }

    final error =
        message['error']?.toString() ??
        'Connexion annulée ou impossible. Veuillez réessayer.';
    ref.read(authControllerProvider).setErrorMessage(error);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Écran de restauration de session
    if (auth.isRestoring) {
      return Scaffold(
        backgroundColor: AppThemeColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: AppThemeColors.accent,
                strokeWidth: 2.5,
              ),
              const SizedBox(height: 16),
              Text(
                'Restauration de session…',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppThemeColors.textMuted,
                ),
              ),
            ],
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
                ? [const Color(0xFF0F0F0D), const Color(0xFF1C1C19)]
                : [const Color(0xFFF0EAE0), const Color(0xFFE5DAC8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: constraints.maxHeight * 0.06),

                      // ── Logo + nom ─────────────────────────────────────────
                      const ConduitLogo(),
                      const SizedBox(height: 20),
                      Text(
                        'ChatIA',
                        style: theme.textTheme.displaySmall?.copyWith(
                          letterSpacing: -1.5,
                          color: AppThemeColors.textStrong,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Votre assistant IA sécurisé,\npowered by Congo Digital Services.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppThemeColors.textSoft,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Carte d'authentification ───────────────────────────
                      _AuthCard(auth: auth, isDark: isDark, theme: theme),

                      SizedBox(height: constraints.maxHeight * 0.08),

                      // ── Pied de page ───────────────────────────────────────
                      Center(
                        child: Column(
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.lock_shield_fill,
                                  size: 12,
                                  color: AppThemeColors.textMuted,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    'Authentification sécurisée via Keycloak SSO',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppThemeColors.textMuted,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              KeycloakConfig.realm,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppThemeColors.textMuted.withValues(
                                  alpha: 0.6,
                                ),
                                fontSize: 10,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Carte principale d'auth ─────────────────────────────────────────────────
class _AuthCard extends ConsumerWidget {
  const _AuthCard({
    required this.auth,
    required this.isDark,
    required this.theme,
  });

  final AuthController auth;
  final bool isDark;
  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? AppThemeColors.card
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppThemeColors.stroke),
        boxShadow: AppThemeShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête ───────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppThemeColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  CupertinoIcons.shield_lefthalf_fill,
                  size: 20,
                  color: AppThemeColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connexion SSO',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppThemeColors.textStrong,
                      ),
                    ),
                    Text(
                      KeycloakConfig.isConfigured
                          ? 'Keycloak · OpenID Connect · PKCE'
                          : 'Mode maquette actif',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppThemeColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              // Badge statut
              _StatusBadge(isConfigured: KeycloakConfig.isConfigured),
            ],
          ),

          const SizedBox(height: 16),
          Divider(color: AppThemeColors.stroke, height: 1),
          const SizedBox(height: 16),

          // ── Infos realm ───────────────────────────────────────────────────
          _InfoRow(
            icon: CupertinoIcons.globe,
            label: 'Issuer',
            value: KeycloakConfig.issuer,
          ),
          const SizedBox(height: 6),
          _InfoRow(
            icon: CupertinoIcons.person_2,
            label: 'Scopes',
            value: KeycloakConfig.scopes.join(' · '),
          ),

          const SizedBox(height: 20),

          // ── Bouton Keycloak ───────────────────────────────────────────────
          _KeycloakButton(
            isLoading: auth.isLoading,
            onTap: auth.isLoading
                ? null
                : () => ref.read(authControllerProvider).signInWithSso(),
          ),

          // ── Liens d'aide Keycloak ─────────────────────────────────────────
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _HelpLink(
                label: 'Mot de passe oublié ?',
                uri: KeycloakConfig.passwordResetUri,
              ),
              const SizedBox(width: 8),
              Text('·', style: TextStyle(color: AppThemeColors.textMuted)),
              const SizedBox(width: 8),
              _HelpLink(
                label: 'Créer un compte',
                uri: KeycloakConfig.registrationUri,
              ),
            ],
          ),

          // ── Erreur ────────────────────────────────────────────────────────
          if (auth.errorMessage != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: auth.errorMessage!, theme: theme),
          ],
        ],
      ),
    );
  }
}

// ── Badge statut (configuré / maquette) ────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isConfigured});
  final bool isConfigured;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isConfigured
            ? const Color(0xFF19B38D).withValues(alpha: 0.12)
            : const Color(0xFFE6A817).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isConfigured
                  ? const Color(0xFF19B38D)
                  : const Color(0xFFE6A817),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isConfigured ? 'Live' : 'Mock',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isConfigured
                  ? const Color(0xFF19B38D)
                  : const Color(0xFFE6A817),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ligne d'info ────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppThemeColors.textMuted),
        const SizedBox(width: 8),
        Text(
          '$label · ',
          style: TextStyle(
            fontSize: 12,
            color: AppThemeColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 12, color: AppThemeColors.textSoft),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Bouton Keycloak ─────────────────────────────────────────────────────────
class _KeycloakButton extends StatelessWidget {
  const _KeycloakButton({required this.isLoading, required this.onTap});

  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isLoading
                ? [
                    AppThemeColors.accent.withValues(alpha: 0.5),
                    AppThemeColors.accent.withValues(alpha: 0.5),
                  ]
                : [AppThemeColors.accent, const Color(0xFF138F6F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isLoading
              ? null
              : [
                  BoxShadow(
                    color: AppThemeColors.accent.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            else
              const Icon(
                CupertinoIcons.lock_fill,
                color: Colors.white,
                size: 16,
              ),
            const SizedBox(width: 10),
            Text(
              isLoading ? 'Connexion en cours…' : 'Continuer avec Keycloak',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Lien d'aide Keycloak ────────────────────────────────────────────────────
class _HelpLink extends StatelessWidget {
  const _HelpLink({required this.label, required this.uri});

  final String label;
  final Uri uri;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => OAuthBrowserHelper.openPopup(uri.toString()),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: AppThemeColors.accent,
          decoration: TextDecoration.underline,
          decorationColor: AppThemeColors.accent.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

// ── Bannière d'erreur ───────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.theme});

  final String message;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCDC9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            size: 15,
            color: Color(0xFF9A2C23),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF9A2C23),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
