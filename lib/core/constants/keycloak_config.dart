import 'package:flutter/foundation.dart';

/// Configuration Keycloak SSO — OpenID Connect
///
/// Realm : OpenWebUI
/// URL   : https://auth.congo-digital.com/realms/OpenWebUI
/// Client: chatAi
///
/// L'app Flutter fait l'OAuth direct avec Keycloak (pas via LibreChat).
/// Le bearer OpenID obtenu est ensuite echange via `/api/mobile/auth/exchange`
/// pour obtenir les tokens natifs LibreChat utilises par l'app.
///
/// IMPORTANT — Le client "chatAi" dans Keycloak doit avoir ces
///             Valid Redirect URIs pour que l'app fonctionne :
///   - http://localhost:*               (dev web)
///   - https://ton-domaine.com/...      (prod web)
///   - chatia://oauth/openid/callback   (mobile)
///
///   Sinon erreur "Invalid parameter: redirect_uri"
class KeycloakConfig {
  const KeycloakConfig._();

  // ---------------------------------------------------------------------------
  // KEYCLOAK
  // ---------------------------------------------------------------------------

  static const keycloakBaseUrl = 'https://auth.congo-digital.com';

  static const realm = 'OpenWebUI';

  static const clientId = 'chatAi';

  /// En production, injecter via --dart-define=KEYCLOAK_CLIENT_SECRET=...
  /// Valeur fournie par le SSO (issue du client Keycloak chatAi).
  static const clientSecret = String.fromEnvironment(
    'KEYCLOAK_CLIENT_SECRET',
    defaultValue: 'rhKY0RZ9dnXqnJLHnHhGidu2AnrQCv1I',
  );

  static const registrationUrl = String.fromEnvironment(
    'KEYCLOAK_REGISTRATION_URL',
    defaultValue: '',
  );

  static const forgotPasswordUrl = String.fromEnvironment(
    'KEYCLOAK_FORGOT_PASSWORD_URL',
    defaultValue: '',
  );

  // ---------------------------------------------------------------------------
  // OIDC
  // ---------------------------------------------------------------------------

  static const scopes = ['openid', 'profile', 'email'];

  static const callbackPath = '/oauth/openid/callback';

  /// L'app Flutter utilise sa PROPRE URL comme redirect_uri.
  /// Keycloak doit l'avoir dans ses Valid Redirect URIs pour le client chatAi.
  ///
  /// Web   → http://localhost/oauth/openid/callback (port variable)
  /// Mobile → chatia://oauth/openid/callback
  static String get redirectUri {
    if (kIsWeb) {
      return '${Uri.base.origin}$callbackPath';
    }
    return 'chatia://oauth/openid/callback';
  }

  /// Redirection après logout — revient dans l'app Flutter.
  static String get logoutRedirectUri {
    if (kIsWeb) {
      return '${Uri.base.origin}/login';
    }
    return 'chatia://login';
  }

  static String get issuer => '$keycloakBaseUrl/realms/$realm';

  static String get discoveryEndpoint =>
      '$issuer/.well-known/openid-configuration';

  /// URL de réinitialisation de mot de passe Keycloak.
  /// Ouvre la page "Mot de passe oublié" native de Keycloak.
  static Uri get passwordResetUri =>
      Uri.parse('$issuer/login-actions/reset-credentials').replace(
        queryParameters: {'client_id': clientId, 'redirect_uri': redirectUri},
      );

  /// URL d'inscription Keycloak (création de compte).
  static Uri get registrationUri =>
      Uri.parse('$issuer/login-actions/register').replace(
        queryParameters: {'client_id': clientId, 'redirect_uri': redirectUri},
      );

  /// URL du compte utilisateur Keycloak (changer email, mot de passe, etc.).
  static Uri get accountUri =>
      Uri.parse('$keycloakBaseUrl/realms/$realm/account');

  static bool get isConfigured =>
      keycloakBaseUrl.isNotEmpty && realm.isNotEmpty && clientId.isNotEmpty;
}

/// ---------------------------------------------------------------------------
/// Référence des variables LibreChat / Keycloak
/// ---------------------------------------------------------------------------

/*

── Référence configuration LibreChat (backend .env) ──────────────────────────
DOMAIN_CLIENT=http://135.125.102.165:3080
DOMAIN_SERVER=http://135.125.102.165:3080

ALLOW_EMAIL_LOGIN=false
ALLOW_REGISTRATION=false
ALLOW_PASSWORD_RESET=false

ALLOW_SOCIAL_LOGIN=true
ALLOW_SOCIAL_REGISTRATION=true

OPENID_ISSUER=https://auth.congo-digital.com/realms/OpenWebUI
OPENID_CLIENT_ID=chatAi
OPENID_CLIENT_SECRET=rhKY0RZ9dnXqnJLHnHhGidu2AnrQCv1I
OPENID_CALLBACK_URL=/oauth/openid/callback
OPENID_SCOPE="openid profile email"
OPENID_BUTTON_LABEL="Continuer avec Keycloak"
OPENID_SESSION_SECRET=<chaîne aléatoire>
OPENID_GENERATE_NONCE=true
OPENID_USE_END_SESSION_ENDPOINT=true

Si LibreChat est en HTTP → ajouter SESSION_COOKIE_SECURE=false
Si derrière un reverse proxy HTTPS → ne PAS mettre SESSION_COOKIE_SECURE=false

── Config Keycloak côté admin (client chatAi) ────────────────────────────────
Valid Redirect URIs :
  - http://localhost:*        (dev web)
  - https://ton-domaine.com/... (prod web)
  - chatia://oauth/openid/callback (mobile)

Web Origins : +

*/
