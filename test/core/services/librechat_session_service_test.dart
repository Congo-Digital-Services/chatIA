import 'dart:async';
import 'dart:convert';

import 'package:chatia/core/services/librechat_session_service.dart';
import 'package:chatia/core/services/token_storage_service.dart';
import 'package:chatia/shared/models/auth_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  group('LibreChatSessionService', () {
    test('does not refresh when the token is still valid', () async {
      final now = DateTime.now();
      AuthSession? session = _session(
        accessToken: _jwt(now.add(const Duration(minutes: 10))),
        refreshToken: 'refresh-token',
        expiresAt: now.add(const Duration(minutes: 10)),
      );
      var refreshCalls = 0;
      var protectedCalls = 0;

      final service = _buildService(
        readSession: () => session,
        writeSession: (value) async => session = value,
        clearSession: () async => session = null,
        onSend: (request) async {
          if (request.url.path == '/api/auth/refresh') {
            refreshCalls += 1;
            return _jsonResponse(200, {
              'token': _jwt(now.add(const Duration(minutes: 15))),
            });
          }

          protectedCalls += 1;
          expect(
            request.headers['Authorization'],
            'Bearer ${session?.accessToken}',
          );
          return _jsonResponse(200, {'ok': true});
        },
      );

      final response = await service.sendAuthorized((accessToken) {
        final request = http.Request('GET', service.uri('/api/convos'));
        request.headers['Authorization'] = 'Bearer $accessToken';
        return request;
      });

      expect(response.statusCode, 200);
      expect(refreshCalls, 0);
      expect(protectedCalls, 1);
    });

    test('refreshes proactively when the token is close to expiring', () async {
      final now = DateTime.now();
      final expiringToken = _jwt(now.add(const Duration(seconds: 60)));
      final refreshedToken = _jwt(now.add(const Duration(minutes: 15)));
      AuthSession? session = _session(
        accessToken: expiringToken,
        refreshToken: 'refresh-token',
        expiresAt: now.add(const Duration(seconds: 60)),
      );
      var refreshCalls = 0;
      String? protectedAuthorization;

      final service = _buildService(
        readSession: () => session,
        writeSession: (value) async => session = value,
        clearSession: () async => session = null,
        onSend: (request) async {
          if (request.url.path == '/api/auth/refresh') {
            refreshCalls += 1;
            return _jsonResponse(200, {
              'token': refreshedToken,
              'user': {'email': 'user@example.com', 'username': 'user'},
            });
          }

          protectedAuthorization = request.headers['Authorization'];
          return _jsonResponse(200, {'ok': true});
        },
      );

      final response = await service.sendAuthorized((accessToken) {
        final request = http.Request('GET', service.uri('/api/messages/test'));
        request.headers['Authorization'] = 'Bearer $accessToken';
        return request;
      });

      expect(response.statusCode, 200);
      expect(refreshCalls, 1);
      expect(protectedAuthorization, 'Bearer $refreshedToken');
      expect(session?.accessToken, refreshedToken);
    });

    test('refreshAccessToken updates the session on success', () async {
      final now = DateTime.now();
      final refreshedToken = _jwt(now.add(const Duration(minutes: 15)));
      AuthSession? session = _session(
        accessToken: _jwt(now.add(const Duration(seconds: 30))),
        refreshToken: 'refresh-token',
        expiresAt: now.add(const Duration(seconds: 30)),
      );

      final service = _buildService(
        readSession: () => session,
        writeSession: (value) async => session = value,
        clearSession: () async => session = null,
        onSend: (request) async {
          expect(request.url.path, '/api/auth/refresh');
          return _jsonResponse(200, {
            'token': refreshedToken,
            'user': {'email': 'user@example.com', 'username': 'user'},
          });
        },
      );

      final refreshed = await service.refreshAccessToken(force: true);

      expect(refreshed.accessToken, refreshedToken);
      expect(session?.accessToken, refreshedToken);
      expect(session?.email, 'user@example.com');
    });

    test('clears the session when refresh fails', () async {
      final now = DateTime.now();
      AuthSession? session = _session(
        accessToken: _jwt(now.add(const Duration(seconds: 30))),
        refreshToken: 'refresh-token',
        expiresAt: now.add(const Duration(seconds: 30)),
      );
      var clearCalls = 0;

      final service = _buildService(
        readSession: () => session,
        writeSession: (value) async => session = value,
        clearSession: () async {
          clearCalls += 1;
          session = null;
        },
        onSend: (request) async {
          return _jsonResponse(401, {'message': 'expired'});
        },
      );

      await expectLater(
        service.refreshAccessToken(force: true),
        throwsA(isA<TokenRefreshException>()),
      );
      expect(clearCalls, 1);
      expect(session, isNull);
    });

    test('serializes concurrent refresh attempts', () async {
      final now = DateTime.now();
      final refreshedToken = _jwt(now.add(const Duration(minutes: 20)));
      AuthSession? session = _session(
        accessToken: _jwt(now.add(const Duration(seconds: 10))),
        refreshToken: 'refresh-token',
        expiresAt: now.add(const Duration(seconds: 10)),
      );
      var refreshCalls = 0;
      var protectedCalls = 0;
      final refreshGate = Completer<void>();

      final service = _buildService(
        readSession: () => session,
        writeSession: (value) async => session = value,
        clearSession: () async => session = null,
        onSend: (request) async {
          if (request.url.path == '/api/auth/refresh') {
            refreshCalls += 1;
            await refreshGate.future;
            return _jsonResponse(200, {
              'token': refreshedToken,
              'user': {'email': 'user@example.com', 'username': 'user'},
            });
          }

          protectedCalls += 1;
          expect(request.headers['Authorization'], 'Bearer $refreshedToken');
          return _jsonResponse(200, {'ok': true});
        },
      );

      final first = service.sendAuthorized((accessToken) {
        final request = http.Request('GET', service.uri('/api/convos'));
        request.headers['Authorization'] = 'Bearer $accessToken';
        return request;
      });
      final second = service.sendAuthorized((accessToken) {
        final request = http.Request('GET', service.uri('/api/messages/demo'));
        request.headers['Authorization'] = 'Bearer $accessToken';
        return request;
      });

      await Future<void>.delayed(const Duration(milliseconds: 10));
      refreshGate.complete();

      final responses = await Future.wait([first, second]);
      expect(responses.every((response) => response.statusCode == 200), isTrue);
      expect(refreshCalls, 1);
      expect(protectedCalls, 2);
    });

    test('retries exactly once after a 401 response', () async {
      final now = DateTime.now();
      final initialToken = _jwt(now.add(const Duration(minutes: 10)));
      final refreshedToken = _jwt(now.add(const Duration(minutes: 25)));
      AuthSession? session = _session(
        accessToken: initialToken,
        refreshToken: 'refresh-token',
        expiresAt: now.add(const Duration(minutes: 10)),
      );
      var refreshCalls = 0;
      var protectedCalls = 0;

      final service = _buildService(
        readSession: () => session,
        writeSession: (value) async => session = value,
        clearSession: () async => session = null,
        onSend: (request) async {
          if (request.url.path == '/api/auth/refresh') {
            refreshCalls += 1;
            return _jsonResponse(200, {
              'token': refreshedToken,
              'user': {'email': 'user@example.com', 'username': 'user'},
            });
          }

          protectedCalls += 1;
          final authHeader = request.headers['Authorization'];
          if (authHeader == 'Bearer $initialToken') {
            return _jsonResponse(401, {'message': 'expired'});
          }

          expect(authHeader, 'Bearer $refreshedToken');
          return _jsonResponse(200, {'ok': true});
        },
      );

      final response = await service.sendAuthorized((accessToken) {
        final request = http.Request(
          'POST',
          service.uri('/api/agents/chat/openAI'),
        );
        request.headers['Authorization'] = 'Bearer $accessToken';
        return request;
      });

      expect(response.statusCode, 200);
      expect(refreshCalls, 1);
      expect(protectedCalls, 2);
      expect(session?.accessToken, refreshedToken);
    });
  });
}

LibreChatSessionService _buildService({
  required AuthSession? Function() readSession,
  required Future<void> Function(AuthSession session) writeSession,
  required Future<void> Function() clearSession,
  required Future<http.StreamedResponse> Function(http.BaseRequest request)
  onSend,
}) {
  final storage = _MemoryTokenStorageService(
    onSave: writeSession,
    onClear: clearSession,
    onRead: () async => readSession(),
  );
  final service = LibreChatSessionService(
    storage: storage,
    baseUrl: 'http://localhost:3080',
    mobileAuthExchangeKey: 'mobile-key',
    userAgent: 'test-agent',
    clientFactory: () => _FakeClient(onSend),
  );
  service.hydrateSession(readSession());
  return service;
}

AuthSession _session({
  required String accessToken,
  required String refreshToken,
  required DateTime expiresAt,
}) {
  return AuthSession(
    accessToken: accessToken,
    refreshToken: refreshToken,
    idToken: 'id-token',
    userName: 'user',
    email: 'user@example.com',
    expiresAt: expiresAt,
    isMock: false,
    provider: AuthSessionProvider.librechat,
  );
}

String _jwt(DateTime expiresAt) {
  final header = base64Url.encode(utf8.encode('{"alg":"none","typ":"JWT"}'));
  final payload = base64Url.encode(
    utf8.encode('{"exp":${expiresAt.toUtc().millisecondsSinceEpoch ~/ 1000}}'),
  );
  return '${header.replaceAll('=', '')}.${payload.replaceAll('=', '')}.sig';
}

http.StreamedResponse _jsonResponse(int statusCode, Map<String, dynamic> body) {
  final bytes = utf8.encode(jsonEncode(body));
  return http.StreamedResponse(
    Stream<List<int>>.value(bytes),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}

class _FakeClient extends http.BaseClient {
  _FakeClient(this._onSend);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  _onSend;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _onSend(request);
  }
}

class _MemoryTokenStorageService extends TokenStorageService {
  _MemoryTokenStorageService({
    required this.onSave,
    required this.onClear,
    required this.onRead,
  });

  final Future<void> Function(AuthSession session) onSave;
  final Future<void> Function() onClear;
  final Future<AuthSession?> Function() onRead;

  @override
  Future<void> saveSession(AuthSession session) => onSave(session);

  @override
  Future<AuthSession?> readSession() => onRead();

  @override
  Future<void> clear() => onClear();
}
