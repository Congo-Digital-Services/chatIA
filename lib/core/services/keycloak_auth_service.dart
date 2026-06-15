import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/keycloak_config.dart';
import '../../shared/models/auth_session.dart';
import 'auth_service.dart';
import 'oauth_browser_helper.dart';
import 'pkce_utils.dart';
import 'token_storage_service.dart';

/// Service d'authentification SSO — flux OAuth2 Authorization Code + PKCE.
///
/// Flux :
///   1. [signInWithSso] → construit l'URL Keycloak avec code_challenge PKCE
///      → redirige le navigateur vers Keycloak.
///   2. L'utilisateur s'authentifie sur Keycloak.
///   3. Keycloak redirige vers /oauth/openid/callback de ChatIA (cette app).
///   4. [handleOAuthCallback] → échange le code contre les tokens Keycloak.
///   5. La session est sauvegardée et l'app navigue vers /chat.
class KeycloakAuthService implements AuthService {
  KeycloakAuthService({required this.storage});

  final TokenStorageService storage;

  static const _pkceVerifierKey = 'pkce_verifier';
  static const _oauthStateKey   = 'oauth_state';

  // ── Restore session ──────────────────────────────────────────────────────
  @override
  Future<AuthSession?> restoreSession() => storage.readSession();

  // ── Lancement du flux SSO direct Keycloak (PKCE) ─────────────────────────
  @override
  Future<AuthSession?> signInWithSso({bool usePopup = false}) async {
    if (!KeycloakConfig.isConfigured) {
      final session = AuthSession.mock();
      await storage.saveSession(session);
      return session;
    }

    // 1. Générer code_verifier, code_challenge et state CSRF
    final verifier   = PkceUtils.generateCodeVerifier();
    final challenge  = PkceUtils.generateCodeChallenge(verifier);
    final oauthState = PkceUtils.generateState();

    // 2. Persister verifier + state pour les relire au callback
    if (kIsWeb) {
      OAuthBrowserHelper.saveToSession(_pkceVerifierKey, verifier);
      OAuthBrowserHelper.saveToSession(_oauthStateKey, oauthState);
    }

    // 3. Construire l'URL d'autorisation Keycloak
    final authUri = Uri.parse(
      '${KeycloakConfig.issuer}/protocol/openid-connect/auth',
    ).replace(queryParameters: {
      'client_id':             KeycloakConfig.clientId,
      'redirect_uri':          KeycloakConfig.redirectUri,
      'response_type':         'code',
      'scope':                 KeycloakConfig.scopes.join(' '),
      'state':                 oauthState,
      'code_challenge':        challenge,
      'code_challenge_method': 'S256',
    });

    // 4. Redirection directe vers Keycloak (pas de popup)
    OAuthBrowserHelper.redirectTo(authUri.toString());

    return null;
  }

  // ── Traitement du callback OAuth2 (échange code → tokens) ────────────────
  @override
  Future<AuthSession> handleOAuthCallback(String code, String state) async {
    // 1. Relire le verifier PKCE et le state stockés avant la redirection
    final verifier   = OAuthBrowserHelper.readFromSession(_pkceVerifierKey);
    final savedState = OAuthBrowserHelper.readFromSession(_oauthStateKey);

    if (verifier == null || verifier.isEmpty) {
      throw Exception('Verifier PKCE introuvable. Veuillez réessayer.');
    }
    if (savedState != null && savedState.isNotEmpty && savedState != state) {
      throw Exception('State OAuth invalide (risque CSRF). Veuillez réessayer.');
    }

    // 2. Nettoyer le sessionStorage
    OAuthBrowserHelper.removeFromSession(_pkceVerifierKey);
    OAuthBrowserHelper.removeFromSession(_oauthStateKey);

    // 3. Échanger le code contre les tokens via le token endpoint Keycloak
    final tokenEndpoint = Uri.parse(
      '${KeycloakConfig.issuer}/protocol/openid-connect/token',
    );

    final response = await http.post(
      tokenEndpoint,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type':    'authorization_code',
        'client_id':     KeycloakConfig.clientId,
        'client_secret': KeycloakConfig.clientSecret,
        'code':          code,
        'redirect_uri':  KeycloakConfig.redirectUri,
        'code_verifier': verifier,
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Erreur token Keycloak (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    // 4. Décoder le JWT access_token pour extraire les infos utilisateur
    final accessToken  = json['access_token']  as String;
    final refreshToken = json['refresh_token'] as String?;
    final idToken      = json['id_token']      as String?;
    final expiresIn    = json['expires_in']    as int? ?? 3600;

    final userInfo = _decodeJwtPayload(accessToken);
    final userName = (userInfo['preferred_username']
                  ?? userInfo['name']
                  ?? userInfo['email']
                  ?? 'Utilisateur') as String;
    final email    = (userInfo['email'] ?? '') as String;

    // 5. Construire et sauvegarder la session
    final session = AuthSession(
      accessToken:  accessToken,
      refreshToken: refreshToken,
      idToken:      idToken,
      userName:     userName,
      email:        email,
      expiresAt:    DateTime.now().add(Duration(seconds: expiresIn)),
      isMock:       false,
    );

    await storage.saveSession(session);
    return session;
  }

  /// Décode la partie payload d'un JWT (base64url, pas de vérification sig).
  Map<String, dynamic> _decodeJwtPayload(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length < 2) return {};
      var payload = parts[1];
      // Padding base64
      payload += '=' * ((4 - payload.length % 4) % 4);
      final decoded = utf8.decode(base64Url.decode(payload));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  // ── Déconnexion ──────────────────────────────────────────────────────────
  @override
  Future<void> signOut({String? idTokenHint}) async {
    try {
      final logoutUri = Uri.parse(
        '${KeycloakConfig.issuer}/protocol/openid-connect/logout',
      ).replace(queryParameters: {
        'client_id':             KeycloakConfig.clientId,
        if (idTokenHint != null) 'id_token_hint': idTokenHint,
        'post_logout_redirect_uri': KeycloakConfig.logoutRedirectUri,
      });

      if (kIsWeb) {
        OAuthBrowserHelper.redirectTo(logoutUri.toString());
      }
    } catch (_) {
    } finally {
      await storage.clear();
    }
  }
}
