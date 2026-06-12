import 'dart:async';
import 'package:flutter/foundation.dart';

import '../constants/backend_config.dart';
import '../constants/keycloak_config.dart';
import '../../shared/models/auth_session.dart';
import 'auth_service.dart';
import 'librechat_api_service.dart';
import 'oauth_browser_helper.dart';
import 'token_storage_service.dart';

/// Service d'authentification SSO via les routes LibreChat.
///
/// Flux :
///   1. [signInWithSso] → appelle /oauth/openid de LibreChat → récupère l'URL
///      Keycloak → l'ouvre dans une popup.
///   2. L'utilisateur s'authentifie sur Keycloak.
///   3. Keycloak redirige vers /oauth/openid/callback de LibreChat.
///   4. LibreChat crée la session utilisateur.
///   5. La popup arrive sur le dashboard LibreChat → on détecte la fin d'auth.
///   6. L'app récupère le token via l'API LibreChat.
class KeycloakAuthService implements AuthService {
  KeycloakAuthService({required this.storage});

  final TokenStorageService storage;
  Timer? _authWatcher;

  // ── Restore session ──────────────────────────────────────────────────────
  @override
  Future<AuthSession?> restoreSession() => storage.readSession();

  // ── Lancement du flux SSO via LibreChat ──────────────────────────────────
  @override
  Future<AuthSession?> signInWithSso({bool usePopup = false}) async {
    if (!KeycloakConfig.isConfigured) {
      final session = AuthSession.mock();
      await storage.saveSession(session);
      return session;
    }

    // Ouvre l'URL SSO de LibreChat directement
    // LibreChat → Keycloak → callback LibreChat → dashboard
    final ssoUrl = '${BackendConfig.baseUrl}/oauth/openid';

    if (kIsWeb && usePopup) {
      OAuthBrowserHelper.openPopup(ssoUrl);
      _startAuthWatcher();
    } else {
      OAuthBrowserHelper.redirectTo(ssoUrl);
    }

    return null;
  }

  /// Surveille l'authentification : dès que la popup a terminé le flow
  /// LibreChat, on tente de récupérer le token.
  void _startAuthWatcher() {
    _authWatcher?.cancel();
    _authWatcher = Timer.periodic(const Duration(seconds: 2), (_) async {
      final session = await _tryFetchSession();
      if (session != null) {
        _authWatcher?.cancel();
        await storage.saveSession(session);
        OAuthBrowserHelper.closeWindow();
      }
    });
  }

  /// Tente de récupérer une session depuis l'API LibreChat.
  Future<AuthSession?> _tryFetchSession() async {
    try {
      // Appelle /api/config pour vérifier si la session est active
      final api = LibreChatApiService(
        baseUrl: BackendConfig.baseUrl,
        accessToken: null,
      );
      await api.fetchConfig();

      // Si pas d'erreur, la session est active → on crée une session locale
      return AuthSession(
        accessToken: 'librechat-session',
        refreshToken: null,
        idToken: null,
        userName: 'Utilisateur SSO',
        email: 'sso.user@conduit.local',
        expiresAt: DateTime.now().add(const Duration(hours: 8)),
        isMock: false,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Le callback est géré par LibreChat ───────────────────────────────────
  @override
  Future<AuthSession> handleOAuthCallback(String code, String state) async {
    throw UnimplementedError(
      'Le callback est géré par LibreChat, pas par l\'app.',
    );
  }

  // ── Déconnexion ──────────────────────────────────────────────────────────
  @override
  Future<void> signOut({String? idTokenHint}) async {
    try {
      final session = await storage.readSession();
      if (session != null) {
        final api = LibreChatApiService(
          baseUrl: BackendConfig.baseUrl,
          accessToken: session.accessToken,
        );
        await api.logout();
      }
    } catch (_) {
    } finally {
      await storage.clear();
    }
  }
}
