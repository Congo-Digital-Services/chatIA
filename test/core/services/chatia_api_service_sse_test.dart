import 'dart:convert';

import 'package:chatia/core/services/chatia_api_service.dart';
import 'package:chatia/core/services/librechat_session_service.dart';
import 'package:chatia/core/services/token_storage_service.dart';
import 'package:chatia/shared/models/auth_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test(
    'streamChat rebuilds final text from responseMessage.content blocks',
    () async {
      AuthSession? session = _session();

      final sessionService = _buildSessionService(
        readSession: () => session,
        writeSession: (value) async => session = value,
        clearSession: () async => session = null,
        onSend: (request) async {
          expect(
            request.headers['Authorization'],
            'Bearer ${session?.accessToken}',
          );
          expect(request.headers['Accept'], 'text/event-stream');
          expect(request.url.path, '/api/agents/chat/stream/stream-123');

          return _sseResponse(
            'event: message\n'
            'data: {"final":true,"conversation":{"conversationId":"convo-1"},"responseMessage":{"text":"","content":[{"type":"text","text":"Bonjour "},{"type":"text","text":"depuis le modele"}]}}\n\n',
          );
        },
      );

      final api = ChatiaApiService(
        baseUrl: 'http://localhost:3080',
        sessionService: sessionService,
      );

      final events = await api.streamChat('stream-123').toList();

      expect(events, hasLength(1));
      expect(events.single.content, 'Bonjour depuis le modele');
      expect(events.single.done, isTrue);
      expect(events.single.conversationId, 'convo-1');
    },
  );

  test(
    'streamChat extracts assistant deltas from payload data.delta.content',
    () async {
      AuthSession? session = _session();

      final sessionService = _buildSessionService(
        readSession: () => session,
        writeSession: (value) async => session = value,
        clearSession: () async => session = null,
        onSend: (request) async {
          return _sseResponse(
            'event: message\n'
            'data: {"event":"on_message_delta","data":{"delta":{"content":[{"type":"text","text":"Great"},{"type":"text","text":"!"}]}}}\n\n'
            'event: message\n'
            'data: {"final":true,"responseMessage":{"text":"","content":[{"type":"text","text":"Great! How can I assist you further?"}]}}\n\n',
          );
        },
      );

      final api = ChatiaApiService(
        baseUrl: 'http://localhost:3080',
        sessionService: sessionService,
      );

      final events = await api.streamChat('stream-123').toList();

      expect(events, hasLength(2));
      expect(events.first.event, 'on_message_delta');
      expect(events.first.content, 'Great!');
      expect(events.first.done, isFalse);
      expect(events.last.content, 'Great! How can I assist you further?');
      expect(events.last.done, isTrue);
    },
  );

  test(
    'streamChat maps created user messages without polluting assistant content',
    () async {
      AuthSession? session = _session();

      final sessionService = _buildSessionService(
        readSession: () => session,
        writeSession: (value) async => session = value,
        clearSession: () async => session = null,
        onSend: (request) async {
          return _sseResponse(
            'event: message\n'
            'data: {"event":"on_message_created","created":true,"message":{"text":"Bonjour modele"}}\n\n'
            'event: message\n'
            'data: {"final":true,"responseMessage":{"text":"Salut"}}\n\n',
          );
        },
      );

      final api = ChatiaApiService(
        baseUrl: 'http://localhost:3080',
        sessionService: sessionService,
      );

      final events = await api.streamChat('stream-123').toList();

      expect(events, hasLength(2));
      expect(events.first.event, 'on_message_created');
      expect(events.first.isCreated, isTrue);
      expect(events.first.content, isEmpty);
      expect(events.first.requestMessage?['text'], 'Bonjour modele');
      expect(events.last.content, 'Salut');
    },
  );

  test('streamChat surfaces event error payloads', () async {
    AuthSession? session = _session();

    final sessionService = _buildSessionService(
      readSession: () => session,
      writeSession: (value) async => session = value,
      clearSession: () async => session = null,
      onSend: (request) async {
        return _sseResponse(
          'event: error\n'
          'data: {"error":"Generation failed"}\n\n',
        );
      },
    );

    final api = ChatiaApiService(
      baseUrl: 'http://localhost:3080',
      sessionService: sessionService,
    );

    final events = await api.streamChat('stream-123').toList();

    expect(events, hasLength(1));
    expect(events.single.error, 'Generation failed');
    expect(events.single.done, isTrue);
    expect(events.single.event, 'error');
  });

  test('streamChat supports resume=true query parameter', () async {
    AuthSession? session = _session();

    final sessionService = _buildSessionService(
      readSession: () => session,
      writeSession: (value) async => session = value,
      clearSession: () async => session = null,
      onSend: (request) async {
        expect(request.url.queryParameters['resume'], 'true');
        return _sseResponse(
          'event: message\n'
          'data: {"sync":true,"resumeState":{"conversationId":"convo-resume","aggregatedContent":["Bon","jour"]},"pendingEvents":[]}\n\n',
        );
      },
    );

    final api = ChatiaApiService(
      baseUrl: 'http://localhost:3080',
      sessionService: sessionService,
    );

    final events = await api.streamChat('stream-123', resume: true).toList();

    expect(events, hasLength(1));
    expect(events.single.isSync, isTrue);
    expect(events.single.conversationId, 'convo-resume');
    expect(events.single.content, 'Bonjour');
  });

  test(
    'fetchMessages maps assistant history content blocks from responseMessage',
    () async {
      AuthSession? session = _session();

      final sessionService = _buildSessionService(
        readSession: () => session,
        writeSession: (value) async => session = value,
        clearSession: () async => session = null,
        onSend: (request) async {
          expect(request.url.path, '/api/messages');
          return _jsonResponse({
            'messages': [
              {
                'message': {'sender': 'User', 'text': 'Bonjour'},
              },
              {
                'responseMessage': {
                  'sender': 'Assistant',
                  'content': [
                    {'type': 'text', 'text': 'Salut '},
                    {'type': 'text', 'text': 'depuis le modele'},
                  ],
                },
              },
            ],
            'nextCursor': null,
          });
        },
      );

      final api = ChatiaApiService(
        baseUrl: 'http://localhost:3080',
        sessionService: sessionService,
      );

      final page = await api.fetchMessages('convo-1');

      expect(page.messages, hasLength(2));
      expect(page.messages[0].role.name, 'user');
      expect(page.messages[0].text, 'Bonjour');
      expect(page.messages[1].role.name, 'assistant');
      expect(page.messages[1].text, 'Salut depuis le modele');
    },
  );
}

LibreChatSessionService _buildSessionService({
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

AuthSession _session() {
  return AuthSession(
    accessToken: _jwt(DateTime.now().add(const Duration(minutes: 10))),
    refreshToken: 'refresh-token',
    idToken: 'id-token',
    userName: 'user',
    email: 'user@example.com',
    expiresAt: DateTime.now().add(const Duration(minutes: 10)),
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

http.StreamedResponse _sseResponse(String body) {
  final bytes = utf8.encode(body);
  return http.StreamedResponse(
    Stream<List<int>>.value(bytes),
    200,
    headers: {'content-type': 'text/event-stream'},
  );
}

http.StreamedResponse _jsonResponse(Map<String, dynamic> body) {
  final bytes = utf8.encode(jsonEncode(body));
  return http.StreamedResponse(
    Stream<List<int>>.value(bytes),
    200,
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
