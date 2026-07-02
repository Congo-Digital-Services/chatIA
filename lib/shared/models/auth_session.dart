enum AuthSessionProvider { mock, local, openid, librechat }

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.idToken,
    required this.userName,
    required this.email,
    required this.expiresAt,
    required this.isMock,
    required this.provider,
  });

  final String accessToken;
  final String? refreshToken;
  final String? idToken;
  final String userName;
  final String email;
  final DateTime expiresAt;
  final bool isMock;
  final AuthSessionProvider provider;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get supportsAutomaticRefresh =>
      (provider == AuthSessionProvider.librechat ||
          provider == AuthSessionProvider.local) &&
      refreshToken != null &&
      refreshToken!.isNotEmpty;

  bool willExpireWithin(Duration threshold) {
    return DateTime.now().add(threshold).isAfter(expiresAt);
  }

  AuthSession copyWith({
    String? accessToken,
    String? refreshToken,
    bool clearRefreshToken = false,
    String? idToken,
    bool clearIdToken = false,
    String? userName,
    String? email,
    DateTime? expiresAt,
    bool? isMock,
    AuthSessionProvider? provider,
  }) {
    return AuthSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: clearRefreshToken
          ? null
          : (refreshToken ?? this.refreshToken),
      idToken: clearIdToken ? null : (idToken ?? this.idToken),
      userName: userName ?? this.userName,
      email: email ?? this.email,
      expiresAt: expiresAt ?? this.expiresAt,
      isMock: isMock ?? this.isMock,
      provider: provider ?? this.provider,
    );
  }

  factory AuthSession.mock() {
    return AuthSession(
      accessToken: 'mock_access_token',
      refreshToken: 'mock_refresh_token',
      idToken: 'mock_id_token',
      userName: 'Utilisateur',
      email: 'utilisateur@conduit.dev',
      expiresAt: DateTime.now().add(const Duration(hours: 8)),
      isMock: true,
      provider: AuthSessionProvider.mock,
    );
  }

  factory AuthSession.local() {
    return AuthSession(
      accessToken: 'local_access_token',
      refreshToken: null,
      idToken: null,
      userName: 'Utilisateur',
      email: 'utilisateur@chatia.local',
      expiresAt: DateTime.now().add(const Duration(hours: 8)),
      isMock: false,
      provider: AuthSessionProvider.local,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'idToken': idToken,
      'userName': userName,
      'email': email,
      'expiresAt': expiresAt.toIso8601String(),
      'isMock': isMock,
      'provider': provider.name,
    };
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final providerName = json['provider'] as String?;
    return AuthSession(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
      idToken: json['idToken'] as String?,
      userName: json['userName'] as String,
      email: json['email'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      isMock: json['isMock'] as bool? ?? false,
      provider: AuthSessionProvider.values.firstWhere(
        (value) => value.name == providerName,
        orElse: () => (json['isMock'] as bool? ?? false)
            ? AuthSessionProvider.mock
            : AuthSessionProvider.local,
      ),
    );
  }
}
