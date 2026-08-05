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
    defaultValue: 'assistant-global',
  );

  static const chatAgentId = String.fromEnvironment(
    'CHATIA_CHAT_AGENT_ID',
    defaultValue: 'agent_0WYc05eqWR1b3aJCqmizj',
  );

  static const healthAgentId = String.fromEnvironment(
    'CHATIA_HEALTH_AGENT_ID',
    defaultValue: 'agent_0WYc05eqWR1b3aJCqmizj',
  );

  static const userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
}
