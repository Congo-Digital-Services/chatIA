import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/keycloak_config.dart';
import '../../shared/models/auth_session.dart';
import 'auth_service.dart';
import 'oauth_browser_helper.dart';
import 'pkce_utils.dart';
import 'token_storage_service.dart';

/// Service d'authentification SSO Keycloak — Web natif.
///
/// Flux : Authorization Code + PKCE (RFC 7636), sans flutter_appauth.
///
/// 1. [signInWithSso]        → génère PKCE, redirige vers Keycloak.
/// 2. [handleOAuthCallback]  → échange le code contre les tokens via HTTP.
///
/// Compatible Flutter Web (dart:html via import conditionnel).
class KeycloakAuthService implements AuthService {
  KeycloakAuthService({required this.storage});

  final TokenStorageService storage;

  static const _kVerifierKey = '_pkce_verifier';
  static const _kStateKey = '_oauth_state';

  // ── Restore session depuis le stockage sécurisé ───────────────────────────
  @override
  Future<AuthSession?> restoreSession() => storage.readSession();

  // ── Lancement du flux SSO ─────────────────────────────────────────────────
  /// Retourne [null] sur le Web (redirection navigateur vers Keycloak).
  /// Retourne une [AuthSession] de maquette si Keycloak n'est pas configuré.
  @override
  Future<AuthSession?> signInWithSso({bool usePopup = false}) async {
    // Mode maquette si Keycloak n'est pas configuré (ex : dev sans serveur).
    if (!KeycloakConfig.isConfigured) {
      final session = AuthSession.mock();
      await storage.saveSession(session);
      return session;
    }

    // Génère PKCE.
    final verifier = PkceUtils.generateCodeVerifier();
    final challenge = PkceUtils.generateCodeChallenge(verifier);
    final state = PkceUtils.generateState();

    // Sauvegarde dans sessionStorage pour récupération au callback.
    OAuthBrowserHelper.saveToSession(_kVerifierKey, verifier);
    OAuthBrowserHelper.saveToSession(_kStateKey, state);

    // Construit l'URL d'autorisation Keycloak.
    final authUrl = Uri.parse(
      '${KeycloakConfig.issuer}/protocol/openid-connect/auth',
    ).replace(
      queryParameters: {
        'response_type': 'code',
        'client_id': KeycloakConfig.clientId,
        'redirect_uri': KeycloakConfig.redirectUri,
        'scope': KeycloakConfig.scopes.join(' '),
        'state': state,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
      },
    );

    if (kIsWeb && usePopup) {
      OAuthBrowserHelper.openPopup(authUrl.toString());
    } else {
      OAuthBrowserHelper.redirectTo(authUrl.toString());
    }

    // Retourne null : la session sera créée dans [handleOAuthCallback].
    return null;
  }

  // ── Traitement du callback OAuth2 ─────────────────────────────────────────
  /// Appelé depuis [OAuthCallbackPage] après le retour de Keycloak.
  @override
  Future<AuthSession> handleOAuthCallback(String code, String state) async {
    // Vérifie l'état anti-CSRF.
    final savedState = OAuthBrowserHelper.readFromSession(_kStateKey);
    final verifier = OAuthBrowserHelper.readFromSession(_kVerifierKey);

    // Nettoie immédiatement sessionStorage.
    OAuthBrowserHelper.removeFromSession(_kStateKey);
    OAuthBrowserHelper.removeFromSession(_kVerifierKey);

    if (savedState == null || savedState != state) {
      throw Exception('État OAuth invalide — possible attaque CSRF.');
    }
    if (verifier == null || verifier.isEmpty) {
      throw Exception('Code verifier PKCE manquant.');
    }

    // Échange le code contre les tokens.
    final tokenResponse = await http.post(
      Uri.parse(
        '${KeycloakConfig.issuer}/protocol/openid-connect/token',
      ),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'client_id': KeycloakConfig.clientId,
        if (KeycloakConfig.clientSecret.isNotEmpty)
          'client_secret': KeycloakConfig.clientSecret,
        'code': code,
        'redirect_uri': KeycloakConfig.redirectUri,
        'code_verifier': verifier,
      },
    );

    if (tokenResponse.statusCode != 200) {
      throw Exception(
        'Erreur Keycloak (${tokenResponse.statusCode}) : ${tokenResponse.body}',
      );
    }

    final tokenData =
        jsonDecode(tokenResponse.body) as Map<String, dynamic>;
    final accessToken = tokenData['access_token'] as String?;

    if (accessToken == null) {
      throw Exception('Token d\'accès absent dans la réponse Keycloak.');
    }

    final idToken = tokenData['id_token'] as String?;
    final refreshToken = tokenData['refresh_token'] as String?;
    final expiresIn = tokenData['expires_in'] as int? ?? 3600;

    // Décode le JWT pour extraire les claims utilisateur.
    final claims = _decodeJwtClaims(idToken ?? accessToken);

    final userName =
        (claims['name'] as String?) ??
        (claims['preferred_username'] as String?) ??
        (claims['given_name'] as String?) ??
        'Utilisateur SSO';

    final email =
        (claims['email'] as String?) ??
        (claims['sub'] as String?) ??
        'sso.user@conduit.local';

    final session = AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      idToken: idToken,
      userName: userName,
      email: email,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      isMock: false,
    );

    await storage.saveSession(session);
    return session;
  }

  // ── Sign out + end_session Keycloak ───────────────────────────────────────
  @override
  Future<void> signOut({String? idTokenHint}) async {
    try {
      if (idTokenHint != null && KeycloakConfig.isConfigured) {
        // Redirige vers l'endpoint de déconnexion Keycloak.
        final logoutUrl = Uri.parse(
          '${KeycloakConfig.issuer}/protocol/openid-connect/logout',
        ).replace(
          queryParameters: {
            'id_token_hint': idTokenHint,
            'post_logout_redirect_uri': KeycloakConfig.logoutRedirectUri,
          },
        );
        OAuthBrowserHelper.redirectTo(logoutUrl.toString());
      }
    } catch (_) {
      // Si la redirection échoue, on nettoie quand même le stockage local.
    } finally {
      await storage.clear();
    }
  }

  // ── Helper : décodage JWT payload (base64url) ─────────────────────────────
  static Map<String, dynamic> _decodeJwtClaims(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return {};
      String payload = parts[1];
      // Normalise base64url → base64 standard.
      payload = payload.replaceAll('-', '+').replaceAll('_', '/');
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final decoded = utf8.decode(base64Decode(payload));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}
