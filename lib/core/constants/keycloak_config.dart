import 'package:flutter/foundation.dart';

/// Configuration Keycloak SSO — OpenID Connect
///
/// Realm : OpenWebUI
/// URL   : https://auth.congo-digital.com/realms/OpenWebUI
/// Client: librechat

class KeycloakConfig {
  const KeycloakConfig._();

  // ---------------------------------------------------------------------------
  // KEYCLOAK
  // ---------------------------------------------------------------------------

  static const keycloakBaseUrl = 'https://auth.congo-digital.com';

  static const realm = 'OpenWebUI';

  static const clientId = 'librechat';

  /// Pour les tests uniquement.
  /// En production, injecter via --dart-define.
  static const clientSecret = String.fromEnvironment(
    'KEYCLOAK_CLIENT_SECRET',
    defaultValue: '',
  );

  // ---------------------------------------------------------------------------
  // OIDC
  // ---------------------------------------------------------------------------

  static const scopes = [
    'openid',
    'profile',
    'email',
  ];

  static const callbackPath = '/oauth/openid/callback';

  static String get redirectUri {
    if (kIsWeb) {
      return '${Uri.base.origin}$callbackPath';
    }

    return 'chatia://oauth/openid/callback';
  }

  static String get logoutRedirectUri {
    if (kIsWeb) {
      return '${Uri.base.origin}/login';
    }

    return 'chatia://login';
  }

  static String get issuer =>
      '$keycloakBaseUrl/realms/$realm';

  static String get discoveryEndpoint =>
      '$issuer/.well-known/openid-configuration';

  static bool get isConfigured =>
      keycloakBaseUrl.isNotEmpty &&
      realm.isNotEmpty &&
      clientId.isNotEmpty;
}

/// ---------------------------------------------------------------------------
/// Référence des variables LibreChat actuellement utilisées
/// ---------------------------------------------------------------------------

/*

ALLOW_EMAIL_LOGIN=false
ALLOW_REGISTRATION=false
ALLOW_PASSWORD_RESET=false

ALLOW_SOCIAL_LOGIN=true
ALLOW_SOCIAL_REGISTRATION=true

OPENID_ISSUER=https://auth.congo-digital.com/realms/OpenWebUI

OPENID_CLIENT_ID=librechat

OPENID_CLIENT_SECRET=

OPENID_CALLBACK_URL=/oauth/openid/callback

OPENID_SCOPE=openid profile email

OPENID_SESSION_SECRET=3f5d1d0072ae4e1596e72c9e4d7116a0

OPENID_USE_END_SESSION_ENDPOINT=true

*/
