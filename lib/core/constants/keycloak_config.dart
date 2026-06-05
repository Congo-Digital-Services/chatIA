class KeycloakConfig {
  const KeycloakConfig._();

  static const keycloakBaseUrl = '';
  static const realm = '';
  static const clientId = '';
  static const redirectUri = '';

  static bool get isConfigured =>
      keycloakBaseUrl.isNotEmpty &&
      realm.isNotEmpty &&
      clientId.isNotEmpty &&
      redirectUri.isNotEmpty;

  static String get issuer =>
      '$keycloakBaseUrl/realms/$realm';
}
