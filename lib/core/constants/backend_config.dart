class BackendConfig {
  const BackendConfig._();

  static const baseUrl = String.fromEnvironment(
    'CHATIA_API_BASE_URL',
    defaultValue: 'http://localhost:3080',
  );

  static const userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
}
