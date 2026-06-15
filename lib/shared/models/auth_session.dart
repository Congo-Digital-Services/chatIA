class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.idToken,
    required this.userName,
    required this.email,
    required this.expiresAt,
    required this.isMock,
  });

  final String accessToken;
  final String? refreshToken;
  final String? idToken;
  final String userName;
  final String email;
  final DateTime expiresAt;
  final bool isMock;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory AuthSession.mock() {
    return AuthSession(
      accessToken: 'mock_access_token',
      refreshToken: 'mock_refresh_token',
      idToken: 'mock_id_token',
      userName: 'Utilisateur',
      email: 'utilisateur@conduit.dev',
      expiresAt: DateTime.now().add(const Duration(hours: 8)),
      isMock: true,
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
    };
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
      idToken: json['idToken'] as String?,
      userName: json['userName'] as String,
      email: json['email'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      isMock: json['isMock'] as bool? ?? false,
    );
  }
}
