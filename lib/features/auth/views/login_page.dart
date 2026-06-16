import 'package:flutter/cupertino.dart';
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ── Titre ──────────────────────────────────────────────
                      Text(
                        'ChatIA',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.displaySmall?.copyWith(
                          letterSpacing: -1.5,
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

                      const SizedBox(height: 24),

                      // ── Carte d'authentification ───────────────────────────
                      _AuthCard(auth: auth, isDark: isDark),
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
  });

  final AuthController auth;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppThemeColors.card
            : const Color.fromARGB(255, 9, 8, 8).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppThemeColors.stroke),
        boxShadow: AppThemeShadows.soft,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _KeycloakButton(
            isLoading: auth.isLoading,
            onTap: auth.isLoading
                ? null
                : () => ref.read(authControllerProvider).signInWithSso(),
          ),
          if (auth.errorMessage != null) ...[
            const SizedBox(height: 12),
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
        ],
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isLoading
                ? [
                    const Color(0xFF111111).withValues(alpha: 0.55),
                    const Color(0xFF111111).withValues(alpha: 0.55),
                  ]
                : [const Color(0xFF111111), const Color(0xFF111111)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: isLoading
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
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
                  color: Color.fromARGB(255, 234, 34, 34),
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
              isLoading ? 'Connexion en cours…' : 'Continue',
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
