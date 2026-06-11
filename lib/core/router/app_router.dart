import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/keycloak_config.dart';
import '../../features/auth/providers/auth_state_provider.dart';
import '../../features/auth/views/login_page.dart';
import '../../features/auth/views/oauth_callback_page.dart';
import '../../features/chat/views/chat_page.dart';
import '../../features/settings/views/settings_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: auth,
    redirect: (context, state) {
      final isLoggedIn = auth.isAuthenticated;
      final isRestoring = auth.isRestoring;
      final location = state.matchedLocation;

      final onLogin = location == '/login';
      final onCallback = location == KeycloakConfig.callbackPath;

      // En cours de restauration : ne pas rediriger.
      if (isRestoring) return null;

      // La page callback gère elle-même la navigation — ne pas interférer.
      if (onCallback) return null;

      // Non authentifié et pas sur /login → retour au login.
      if (!isLoggedIn && !onLogin) return '/login';

      // Déjà authentifié sur /login → aller au chat.
      if (isLoggedIn && onLogin) return '/chat';

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: KeycloakConfig.callbackPath,
        name: 'oauthCallback',
        builder: (context, state) {
          final code = state.uri.queryParameters['code'] ?? '';
          final oauthState = state.uri.queryParameters['state'] ?? '';
          return OAuthCallbackPage(code: code, state: oauthState);
        },
      ),
      GoRoute(
        path: '/chat',
        name: 'chat',
        builder: (context, state) => const ChatPage(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
});
