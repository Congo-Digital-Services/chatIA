import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_state_provider.dart';
import '../../features/auth/views/login_page.dart';
import '../../features/auth/views/password_reset_page.dart';
import '../../features/auth/views/register_page.dart';
import '../../features/auth/views/verify_email_page.dart';
import '../../features/chat/views/chat_page.dart';
import '../../features/settings/views/settings_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // GoRouter écoute déjà les changements via refreshListenable. Le reconstruire
  // à chaque notifyListeners réinitialise la route courante et interrompt les
  // formulaires d’authentification.
  final auth = ref.read(authControllerProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: auth,
    redirect: (context, state) {
      final isLoggedIn = auth.isAuthenticated;
      final isRestoring = auth.isRestoring;
      final location = state.matchedLocation;

      final onLogin = location == '/login';
      final onPublicAuthRoute =
          location == '/verify' ||
          location == '/reset-password' ||
          location == '/forgot-password' ||
          location == '/register';

      // En cours de restauration : ne pas rediriger.
      if (isRestoring) return null;

      // Non authentifié et pas sur /login → retour au login.
      if (!isLoggedIn && !onLogin && !onPublicAuthRoute) return '/login';

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
        path: '/verify',
        builder: (context, state) => VerifyEmailPage(
          email: state.uri.queryParameters['email'] ?? '',
          token: state.uri.queryParameters['token'] ?? '',
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => ResetPasswordPage(
          userId: state.uri.queryParameters['userId'] ?? '',
          token: state.uri.queryParameters['token'] ?? '',
        ),
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
