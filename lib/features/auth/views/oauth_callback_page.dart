import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/oauth_browser_helper.dart';
import '../../../shared/theme/app_theme.dart';
import '../providers/auth_state_provider.dart';

/// Page de callback OAuth.
///
/// Keycloak redirige vers l'app Flutter après auth.
/// GoRouter parse le code et le state depuis l'URL.
/// Cette page échange le code contre les tokens Keycloak.
class OAuthCallbackPage extends ConsumerStatefulWidget {
  const OAuthCallbackPage({
    super.key,
    required this.code,
    required this.state,
  });

  final String code;
  final String state;

  @override
  ConsumerState<OAuthCallbackPage> createState() => _OAuthCallbackPageState();
}

class _OAuthCallbackPageState extends ConsumerState<OAuthCallbackPage> {
  @override
  void initState() {
    super.initState();
    // Lance l'échange dès le premier frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _exchange());
  }

  Future<void> _exchange() async {
    if (widget.code.isEmpty || widget.state.isEmpty) {
      if (mounted) context.go('/login');
      return;
    }

    await ref
        .read(authControllerProvider)
        .handleOAuthCallback(widget.code, widget.state);

    if (!mounted) return;

    final auth = ref.read(authControllerProvider);
    if (OAuthBrowserHelper.hasOpener()) {
      OAuthBrowserHelper.postMessageToOpener(
        {
          'type': 'oauth_popup_result',
          'success': auth.isAuthenticated,
          if (!auth.isAuthenticated && auth.errorMessage != null)
            'error': auth.errorMessage,
        },
      );
      OAuthBrowserHelper.closeWindow();
      return;
    }

    if (auth.isAuthenticated) {
      context.go('/chat');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);

    // En cas d'erreur pendant l'échange.
    if (!auth.isLoading && auth.errorMessage != null) {
      return Scaffold(
        backgroundColor: AppThemeColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.exclamationmark_triangle_fill,
                  size: 48,
                  color: Color(0xFFEA4335),
                ),
                const SizedBox(height: 20),
                Text(
                  'Échec de la connexion',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppThemeColors.textStrong,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  auth.errorMessage!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppThemeColors.textSoft,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                GestureDetector(
                  onTap: () => context.go('/login'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppThemeColors.accent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Réessayer',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // État de chargement (échange en cours).
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
            const SizedBox(height: 20),
            Text(
              'Connexion SSO en cours…',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppThemeColors.textSoft,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Vérification des tokens Keycloak',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppThemeColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
