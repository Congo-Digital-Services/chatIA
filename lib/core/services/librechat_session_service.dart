import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../shared/models/auth_session.dart';
import '../constants/backend_config.dart';
import 'http_client_factory.dart';
import 'token_storage_service.dart';

final libreChatSessionServiceProvider = Provider<LibreChatSessionService>((
  ref,
) {
  final storage = ref.watch(tokenStorageServiceProvider);
  return LibreChatSessionService(
    storage: storage,
    baseUrl: BackendConfig.baseUrl,
    mobileAuthExchangeKey: BackendConfig.mobileAuthExchangeKey,
    userAgent: BackendConfig.userAgent,
    clientFactory: createCredentialedClient,
  );
});

class SessionUnavailableException implements Exception {
  const SessionUnavailableException(this.message);

  final String message;

  @override
  String toString() => 'Exception: $message';
}

class TokenRefreshException implements Exception {
  const TokenRefreshException(this.message);

  final String message;

  @override
  String toString() => 'Exception: $message';
}

class AuthorizedStreamConnection {
  AuthorizedStreamConnection({required this.response, required this.close});

  final http.StreamedResponse response;
  final Future<void> Function() close;
}

class LibreChatSessionService {
  LibreChatSessionService({
    required this.storage,
    required this.baseUrl,
    required this.mobileAuthExchangeKey,
    required this.userAgent,
    required this.clientFactory,
  });

  static const refreshThreshold = Duration(seconds: 120);

  final TokenStorageService storage;
  final String baseUrl;
  final String mobileAuthExchangeKey;
  final String userAgent;
  final http.Client Function() clientFactory;

  AuthSession? _currentSession;
  Future<AuthSession>? _refreshFuture;

  /// Invoqué quand la session est invalidée côté serveur (401 non récupérable),
  /// pour permettre à la couche d'auth de rediriger vers la connexion.
  void Function()? onSessionInvalidated;

  AuthSession? get currentSession => _currentSession;

  void hydrateSession(AuthSession? session) {
    _currentSession = session;
  }

  Uri uri(String path, [Map<String, String>? queryParameters]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: queryParameters);
  }

  Future<AuthSession> exchangeMobileSession({
    required String openIdAccessToken,
    String? idToken,
  }) async {
    if (mobileAuthExchangeKey.isEmpty) {
      throw const SessionUnavailableException(
        'MOBILE_AUTH_EXCHANGE_KEY manquant pour l’echange mobile LibreChat.',
      );
    }

    final request = http.Request('POST', uri('/api/mobile/auth/exchange'));
    request.headers.addAll({
      'Accept': 'application/json',
      'Authorization': 'Bearer $openIdAccessToken',
      'x-mobile-auth-key': mobileAuthExchangeKey,
      'User-Agent': userAgent,
    });

    final response = await _sendWithClient(request);
    final body = await http.Response.fromStream(response);

    if (body.statusCode != 200) {
      throw SessionUnavailableException(
        'Echec de l’echange mobile LibreChat : ${body.statusCode} ${body.body}',
      );
    }

    final decoded = jsonDecode(body.body);
    if (decoded is! Map<String, dynamic>) {
      throw const SessionUnavailableException(
        'Reponse d’echange mobile LibreChat invalide.',
      );
    }

    final token = decoded['token']?.toString();
    final refreshToken = decoded['refreshToken']?.toString();
    final user = decoded['user'] as Map<String, dynamic>? ?? const {};

    if (token == null ||
        token.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      throw const SessionUnavailableException(
        'Tokens natifs LibreChat absents dans la reponse mobile.',
      );
    }

    final session = AuthSession(
      accessToken: token,
      refreshToken: refreshToken,
      idToken: idToken,
      userName:
          user['username']?.toString() ??
          user['email']?.toString() ??
          'Utilisateur',
      email: user['email']?.toString() ?? '',
      expiresAt: _readTokenExpiry(token),
      isMock: false,
      provider: AuthSessionProvider.librechat,
    );

    _currentSession = session;
    await storage.saveSession(session);
    return session;
  }

  Future<AuthSession> ensureValidAccessToken() async {
    final session = currentSession;
    if (session == null) {
      throw const SessionUnavailableException('Session locale introuvable.');
    }

    if (!session.willExpireWithin(refreshThreshold)) {
      return session;
    }

    return refreshAccessToken();
  }

  Future<AuthSession> refreshAccessToken({bool force = false}) async {
    final session = currentSession;
    if (session == null) {
      throw const SessionUnavailableException('Session locale introuvable.');
    }

    if (!force && !session.willExpireWithin(refreshThreshold)) {
      return session;
    }

    final existingRefresh = _refreshFuture;
    if (existingRefresh != null) {
      return existingRefresh;
    }

    final refreshOperation = refreshSession(session, persist: true);
    _refreshFuture = refreshOperation;

    try {
      return await refreshOperation;
    } finally {
      _refreshFuture = null;
    }
  }

  Future<AuthSession> refreshSession(
    AuthSession session, {
    bool persist = true,
  }) async {
    if (!session.supportsAutomaticRefresh) {
      await clearPersistedSession();
      throw const TokenRefreshException(
        'Cette session ne supporte pas le refresh automatique.',
      );
    }

    final refreshed = await _performRefresh(session);
    if (persist) {
      _currentSession = refreshed;
      await storage.saveSession(refreshed);
    }
    return refreshed;
  }

  Future<http.StreamedResponse> sendAuthorized(
    http.BaseRequest Function(String accessToken) buildRequest,
  ) async {
    var session = await ensureValidAccessToken();
    var response = await _sendWithClient(buildRequest(session.accessToken));

    if (response.statusCode != 401) {
      return response;
    }

    session = await refreshAccessToken(force: true);
    response = await _sendWithClient(buildRequest(session.accessToken));

    if (response.statusCode == 401) {
      await clearPersistedSession();
    }

    return response;
  }

  Future<AuthorizedStreamConnection> openAuthorizedStream(
    http.BaseRequest Function(String accessToken) buildRequest,
  ) async {
    var session = await ensureValidAccessToken();
    var client = clientFactory();
    var response = await client.send(buildRequest(session.accessToken));

    if (response.statusCode == 401) {
      client.close();
      session = await refreshAccessToken(force: true);
      client = clientFactory();
      response = await client.send(buildRequest(session.accessToken));
    }

    if (response.statusCode == 401) {
      await clearPersistedSession();
    }

    return AuthorizedStreamConnection(
      response: response,
      close: () async {
        client.close();
      },
    );
  }

  Future<AuthSession> _performRefresh(AuthSession session) async {
    final refreshToken = session.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      await clearPersistedSession();
      throw const TokenRefreshException(
        'Refresh token LibreChat absent, session invalidee.',
      );
    }

    final request = http.Request('POST', uri('/api/auth/refresh'));
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'User-Agent': userAgent,
    };
    if (refreshToken != 'cookie') {
      headers['Cookie'] = 'refreshToken=$refreshToken; token_provider=librechat';
    }
    request.headers.addAll(headers);

    final response = await _sendWithClient(request);
    final body = await http.Response.fromStream(response);

    if (body.statusCode != 200) {
      await clearPersistedSession();
      throw TokenRefreshException(
        'Echec du refresh LibreChat : ${body.statusCode} ${body.body}',
      );
    }

    final decoded = jsonDecode(body.body);
    if (decoded is! Map<String, dynamic>) {
      await clearPersistedSession();
      throw const TokenRefreshException(
        'Reponse de refresh LibreChat invalide.',
      );
    }

    final token = decoded['token']?.toString();
    if (token == null || token.isEmpty) {
      await clearPersistedSession();
      throw TokenRefreshException('Refresh LibreChat incomplet : ${body.body}');
    }

    final user = decoded['user'] as Map<String, dynamic>? ?? const {};
    final nextRefreshToken =
        _extractCookieValue(body.headers['set-cookie'], 'refreshToken') ??
        session.refreshToken;
    return session.copyWith(
      accessToken: token,
      refreshToken: nextRefreshToken,
      userName: user['username']?.toString() ?? session.userName,
      email: user['email']?.toString() ?? session.email,
      expiresAt: _readTokenExpiry(token),
    );
  }

  Future<http.StreamedResponse> _sendWithClient(
    http.BaseRequest request,
  ) async {
    final client = clientFactory();
    try {
      return await client.send(request);
    } finally {
      client.close();
    }
  }

  Future<void> clearPersistedSession() async {
    _currentSession = null;
    await storage.clear();
    onSessionInvalidated?.call();
  }

  DateTime _readTokenExpiry(String token) {
    final payload = _decodeJwtPayload(token);
    final exp = payload['exp'];
    if (exp is int) {
      return DateTime.fromMillisecondsSinceEpoch(
        exp * 1000,
        isUtc: true,
      ).toLocal();
    }
    if (exp is String) {
      final parsed = int.tryParse(exp);
      if (parsed != null) {
        return DateTime.fromMillisecondsSinceEpoch(
          parsed * 1000,
          isUtc: true,
        ).toLocal();
      }
    }

    return DateTime.now().add(const Duration(minutes: 15));
  }

  Map<String, dynamic> _decodeJwtPayload(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length < 2) {
        return const {};
      }

      var payload = parts[1];
      payload += '=' * ((4 - payload.length % 4) % 4);
      final decoded = utf8.decode(base64Url.decode(payload));
      final json = jsonDecode(decoded);
      if (json is Map<String, dynamic>) {
        return json;
      }
      return const {};
    } catch (_) {
      return const {};
    }
  }

  String? _extractCookieValue(String? raw, String name) {
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final match = RegExp('$name=([^;,\\s]+)').firstMatch(raw);
    return match?.group(1);
  }
}
