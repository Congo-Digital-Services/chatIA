import 'dart:math';

import 'package:flutter_appauth/flutter_appauth.dart';

import '../constants/keycloak_config.dart';
import '../../shared/models/auth_session.dart';
import 'auth_service.dart';
import 'token_storage_service.dart';

class KeycloakAuthService implements AuthService {
  KeycloakAuthService({required this.storage});

  final TokenStorageService storage;
  final FlutterAppAuth _appAuth = const FlutterAppAuth();

  @override
  Future<AuthSession?> restoreSession() {
    return storage.readSession();
  }

  @override
  Future<AuthSession> signInWithSso() async {
    if (!KeycloakConfig.isConfigured) {
      final session = AuthSession.mock();
      await storage.saveSession(session);
      return session;
    }

    final result = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        KeycloakConfig.clientId,
        KeycloakConfig.redirectUri,
        issuer: KeycloakConfig.issuer,
        scopes: const ['openid', 'profile', 'email', 'offline_access'],
        promptValues: const ['login'],
      ),
    );

    final authResult = result;
    final accessToken = authResult.accessToken;

    if (accessToken == null) {
      throw Exception('Connexion SSO annulée ou incomplète.');
    }

    final session = AuthSession(
      accessToken: accessToken,
      refreshToken: authResult.refreshToken,
      idToken: authResult.idToken,
      userName: accessToken.isNotEmpty
          ? 'Utilisateur SSO'
          : 'Utilisateur',
      email: 'sso.user@conduit.local',
      expiresAt: DateTime.now().add(
        Duration(seconds: authResult.accessTokenExpirationDateTime == null
            ? 3600
            : max(
                60,
                authResult.accessTokenExpirationDateTime!
                    .difference(DateTime.now())
                    .inSeconds,
              )),
      ),
      isMock: false,
    );

    await storage.saveSession(session);
    return session;
  }

  @override
  Future<void> signOut({String? idTokenHint}) async {
    await storage.clear();
  }
}
