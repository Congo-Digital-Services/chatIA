class BackendConfig {
  const BackendConfig._();

  static const baseUrl = String.fromEnvironment(
    'CHATIA_API_BASE_URL',
    defaultValue: 'https://loba-ia.congo-digital.com',
  );

  static const mobileAuthExchangeKey = String.fromEnvironment(
    'MOBILE_AUTH_EXCHANGE_KEY',
    defaultValue: '5e1f6e0030ffa45659e401ce502ed9bd',
  );

  static const authEmail = String.fromEnvironment(
    'CHATIA_AUTH_EMAIL',
    defaultValue: '',
  );

  static const authPassword = String.fromEnvironment(
    'CHATIA_AUTH_PASSWORD',
    defaultValue: '',
  );

  static const chatEndpoint = String.fromEnvironment(
    'CHATIA_CHAT_ENDPOINT',
    defaultValue: 'agents',
  );

  static const chatSpec = String.fromEnvironment(
    'CHATIA_CHAT_SPEC',
    defaultValue: 'maloba-traduction',
  );

  static const chatAgentId = String.fromEnvironment(
    'CHATIA_CHAT_AGENT_ID',
    defaultValue: 'agent_L7UzZjsPMTuE_WX3-ZYon', // MALOBA Traduction
  );

  static const healthAgentId = String.fromEnvironment(
    'CHATIA_HEALTH_AGENT_ID',
    defaultValue: 'agent_L7UzZjsPMTuE_WX3-ZYon', // MALOBA Traduction
  );

  /// Agent « MALOBA Traduction » (spec `maloba-traduction`), utilisé si
  /// `/api/config` ne peut pas être lu : traduction fr <-> ln du mode Santé.
  static const translationAgentId = String.fromEnvironment(
    'CHATIA_TRANSLATION_AGENT_ID',
    defaultValue: 'agent_L7UzZjsPMTuE_WX3-ZYon',
  );

  static const translationSpec = String.fromEnvironment(
    'CHATIA_TRANSLATION_SPEC',
    defaultValue: 'maloba-traduction',
  );

  static const userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
}
