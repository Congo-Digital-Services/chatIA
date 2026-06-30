import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/oauth_browser_helper.dart';
import '../../../shared/theme/app_theme.dart';
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [

              // ── Offset supérieur : ancre le contenu dans le tiers haut ──
              const SizedBox(height: 60),

              // ── Logo officiel ─────────────────────────────────────────
              Image.asset(
                'assets/icons/congo_logo.png',
                height: 100,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 100),

              // ── Titre ──────────────────────────────────────────────────
              Text(
                'ChatIA',
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall?.copyWith(
                  color: AppThemeColors.textStrong,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Votre assistant IA sécurisé,\npowered by Congo Digital Services.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppThemeColors.textSoft,
                  height: 1.5,
                ),
              ),

              // ── Espace flexible → pousse le bouton vers le bas ─────────
              const Spacer(),

              // ── Bouton d'authentification ──────────────────────────────
              SizedBox(
                width: double.infinity,
                child: _KeycloakButton(
                  isLoading: auth.isLoading,
                  onTap: auth.isLoading
                      ? null
                      : () => ref.read(authControllerProvider).signInWithSso(),
                ),
              ),
              if (auth.errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  auth.errorMessage!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              // ── Marge de sécurité en bas ───────────────────────────────
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : Colors.black;
    final secondaryColor = isDark ? Colors.black : Colors.white;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: isLoading ? null : onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: primaryColor,
          side: BorderSide(color: primaryColor, width: 1),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: secondaryColor,
                  strokeWidth: 2,
                ),
              )
            else ...[
              Text(
                'Continuer',
                style: TextStyle(
                  color: secondaryColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_rounded,
                color: secondaryColor,
                size: 18,
              ),
            ],
            if (isLoading) ...[
              const SizedBox(width: 10),
              Text(
                'Connexion en cours…',
                style: TextStyle(
                  color: secondaryColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
