import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:http/http.dart' as http;

import '../constants/keycloak_config.dart';
import '../../shared/models/auth_session.dart';
import 'auth_service.dart';
import 'librechat_session_service.dart';
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
///   5. Le bearer OpenID est immédiatement échangé contre un token natif
///      LibreChat via `/api/mobile/auth/exchange`.
///   6. La session sauvegardée n'utilise ensuite plus que les tokens natifs
///      LibreChat pour toutes les requêtes backend.
class KeycloakAuthService implements AuthService {
  KeycloakAuthService({required this.storage, required this.libreChatSession});

  final TokenStorageService storage;
  final LibreChatSessionService libreChatSession;
  final FlutterAppAuth _appAuth = const FlutterAppAuth();

  static const _pkceVerifierKey = 'pkce_verifier';
  static const _oauthStateKey = 'oauth_state';
  static const _useSafariViewControllerOnIos = bool.fromEnvironment(
    'SSO_USE_SAFARI_VIEW_CONTROLLER',
    defaultValue: false,
  );

  void _logReceivedTokens({
    required String accessToken,
    String? refreshToken,
    String? idToken,
    required String source,
  }) {
    if (!kDebugMode) {
      return;
    }

    _logFullToken('[SSO][$source] accessToken', accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      _logFullToken('[SSO][$source] refreshToken', refreshToken);
    }
    if (idToken != null && idToken.isNotEmpty) {
      _logFullToken('[SSO][$source] idToken', idToken);
    }
  }

  void _logFullToken(String label, String token) {
    const chunkSize = 700;
    debugPrint('$label length=${token.length}');
    for (var index = 0; index < token.length; index += chunkSize) {
      final end = (index + chunkSize < token.length)
          ? index + chunkSize
          : token.length;
      debugPrint(
        '$label chunk ${index ~/ chunkSize + 1}: ${token.substring(index, end)}',
      );
    }
  }

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

    if (!kIsWeb) {
      return _signInWithMobileAppAuth();
    }

    // 1. Générer code_verifier, code_challenge et state CSRF
    final verifier = PkceUtils.generateCodeVerifier();
    final challenge = PkceUtils.generateCodeChallenge(verifier);
    final oauthState = PkceUtils.generateState();

    // 2. Persister verifier + state pour les relire au callback
    if (kIsWeb) {
      OAuthBrowserHelper.saveToSession(_pkceVerifierKey, verifier);
      OAuthBrowserHelper.saveToSession(_oauthStateKey, oauthState);
    }

    // 3. Construire l'URL d'autorisation Keycloak
    final authUri =
        Uri.parse(
          '${KeycloakConfig.issuer}/protocol/openid-connect/auth',
        ).replace(
          queryParameters: {
            'client_id': KeycloakConfig.clientId,
            'redirect_uri': KeycloakConfig.redirectUri,
            'response_type': 'code',
            'scope': KeycloakConfig.scopes.join(' '),
            'state': oauthState,
            'code_challenge': challenge,
            'code_challenge_method': 'S256',
          },
        );

    // 4. Redirection directe vers Keycloak (pas de popup)
    OAuthBrowserHelper.redirectTo(authUri.toString());

    return null;
  }

  Future<AuthSession> _signInWithMobileAppAuth() async {
    final externalUserAgent = _resolveExternalUserAgent();
    final request = AuthorizationTokenRequest(
      KeycloakConfig.clientId,
      KeycloakConfig.redirectUri,
      issuer: KeycloakConfig.issuer,
      discoveryUrl: KeycloakConfig.discoveryEndpoint,
      scopes: KeycloakConfig.scopes,
      clientSecret: KeycloakConfig.clientSecret.isNotEmpty
          ? KeycloakConfig.clientSecret
          : null,
      externalUserAgent: externalUserAgent,
    );

    try {
      _logMobileAuthorizationRequest(request);
      final result = await _appAuth.authorizeAndExchangeCode(request);
      if (result.accessToken == null || result.accessToken!.isEmpty) {
        throw Exception('Aucun token reçu depuis Keycloak.');
      }

      final openIdAccessToken = result.accessToken!;
      final refreshToken = result.refreshToken;
      final idToken = result.idToken;
      _logReceivedTokens(
        accessToken: openIdAccessToken,
        refreshToken: refreshToken,
        idToken: idToken,
        source: 'mobile_appauth',
      );

      final session = await libreChatSession.exchangeMobileSession(
        openIdAccessToken: openIdAccessToken,
        idToken: idToken,
      );
      return session;
    } on FlutterAppAuthUserCancelledException catch (error) {
      final details = _formatPlatformErrorDetails(error.platformErrorDetails);
      debugPrint('SSO AppAuth cancelled: $details');
      throw Exception(
        'Connexion SSO annulée côté iOS. '
        'Cela arrive si la feuille Safari est fermée ou si le retour '
        'vers ${KeycloakConfig.redirectUri} ne revient jamais dans l’app. '
        'Vérifiez surtout la redirect URI Keycloak et le schéma iOS. $details',
      );
    } on FlutterAppAuthPlatformException catch (error) {
      final details = _formatPlatformErrorDetails(error.platformErrorDetails);
      debugPrint('SSO AppAuth failure: $details');
      throw Exception('Erreur SSO Android/iOS. $details');
    }
  }

  void _logMobileAuthorizationRequest(AuthorizationTokenRequest request) {
    if (!kDebugMode) {
      return;
    }

    debugPrint(
      '[SSO][mobile] issuer=${request.issuer} '
      'discoveryUrl=${request.discoveryUrl} '
      'clientId=${request.clientId} '
      'redirectUri=${request.redirectUrl} '
      'scopes=${request.scopes?.join(' ')} '
      'externalUserAgent=${request.externalUserAgent?.name}',
    );
  }

  ExternalUserAgent _resolveExternalUserAgent() {
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        _useSafariViewControllerOnIos) {
      return ExternalUserAgent.sfSafariViewController;
    }

    return ExternalUserAgent.asWebAuthenticationSession;
  }

  // ── Traitement du callback OAuth2 (échange code → tokens) ────────────────
  @override
  Future<AuthSession> handleOAuthCallback(String code, String state) async {
    if (!kIsWeb) {
      throw Exception(
        'Le callback OAuth web ne doit pas être utilisé sur mobile.',
      );
    }

    // 1. Relire le verifier PKCE et le state stockés avant la redirection
    final verifier = OAuthBrowserHelper.readFromSession(_pkceVerifierKey);
    final savedState = OAuthBrowserHelper.readFromSession(_oauthStateKey);

    if (verifier == null || verifier.isEmpty) {
      throw Exception('Verifier PKCE introuvable. Veuillez réessayer.');
    }
    if (savedState != null && savedState.isNotEmpty && savedState != state) {
      throw Exception(
        'State OAuth invalide (risque CSRF). Veuillez réessayer.',
      );
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
        'grant_type': 'authorization_code',
        'client_id': KeycloakConfig.clientId,
        'client_secret': KeycloakConfig.clientSecret,
        'code': code,
        'redirect_uri': KeycloakConfig.redirectUri,
        'code_verifier': verifier,
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Erreur token Keycloak (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    // 4. Récupérer les tokens Keycloak puis échanger immédiatement le bearer
    // OpenID contre les tokens natifs LibreChat.
    final accessToken = json['access_token'] as String;
    final refreshToken = json['refresh_token'] as String?;
    final idToken = json['id_token'] as String?;

    _logReceivedTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      idToken: idToken,
      source: 'web_callback',
    );

    final session = await libreChatSession.exchangeMobileSession(
      openIdAccessToken: accessToken,
      idToken: idToken,
    );
    return session;
  }

  String _formatPlatformErrorDetails(
    FlutterAppAuthPlatformErrorDetails details,
  ) {
    final parts = <String>[
      if (details.error?.isNotEmpty ?? false) 'error=${details.error}',
      if (details.errorDescription?.isNotEmpty ?? false)
        'description=${details.errorDescription}',
      if (details.code?.isNotEmpty ?? false) 'code=${details.code}',
      if (details.type?.isNotEmpty ?? false) 'type=${details.type}',
      if (details.rootCauseDebugDescription?.isNotEmpty ?? false)
        'rootCause=${details.rootCauseDebugDescription}',
      if (details.errorDebugDescription?.isNotEmpty ?? false)
        'debug=${details.errorDebugDescription}',
    ];

    return parts.isEmpty
        ? 'Aucun détail fourni par AppAuth.'
        : parts.join(' | ');
  }

  // ── Déconnexion ──────────────────────────────────────────────────────────
  @override
  Future<void> signOut({String? idTokenHint}) async {
    try {
      if (kIsWeb) {
        final logoutUri =
            Uri.parse(
              '${KeycloakConfig.issuer}/protocol/openid-connect/logout',
            ).replace(
              queryParameters: {
                'client_id': KeycloakConfig.clientId,
                if (idTokenHint?.isNotEmpty ?? false)
                  'id_token_hint': idTokenHint!,
                'post_logout_redirect_uri': KeycloakConfig.logoutRedirectUri,
              },
            );
        OAuthBrowserHelper.redirectTo(logoutUri.toString());
      } else if (idTokenHint != null && idTokenHint.isNotEmpty) {
        await _appAuth.endSession(
          EndSessionRequest(
            idTokenHint: idTokenHint,
            postLogoutRedirectUrl: KeycloakConfig.logoutRedirectUri,
            issuer: KeycloakConfig.issuer,
            discoveryUrl: KeycloakConfig.discoveryEndpoint,
          ),
        );
      }
    } catch (_) {
    } finally {
      await storage.clear();
    }
  }
}
