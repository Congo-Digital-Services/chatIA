import 'dart:convert';

import 'package:chatia/core/services/chatia_api_service.dart';
import 'package:chatia/core/services/librechat_session_service.dart';
import 'package:chatia/core/services/token_storage_service.dart';
import 'package:chatia/shared/models/auth_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test(
    'startAgentChat posts to configured agents route with expected payload',
    () async {
      AuthSession? session = _session();

      final sessionService = _buildSessionService(
        readSession: () => session,
        writeSession: (value) async => session = value,
        clearSession: () async => session = null,
        onSend: (request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/agents/chat/agents');

          final body =
              jsonDecode((request as http.Request).body)
                  as Map<String, dynamic>;
          expect(body['text'], 'ok');
          expect(body['endpoint'], 'agents');
          expect(body['spec'], 'assistant-global');
          expect(body['agent_id'], 'agent_123');
          expect(body['conversationId'], 'convo-1');
          expect(body['parentMessageId'], 'parent-1');
          expect(body['messageId'], 'message-1');
          expect(body['sender'], 'User');

          return _jsonResponse({
            'streamId': 'stream-123',
            'conversationId': 'convo-1',
            'status': 'started',
          });
        },
      );

      final api = ChatiaApiService(
        baseUrl: 'http://localhost:3080',
        sessionService: sessionService,
      );

      final response = await api.startAgentChat(
        agentId: 'agent_123',
        parentMessageId: 'parent-1',
        messageId: 'message-1',
        text: 'ok',
        conversationId: 'convo-1',
      );

      expect(response.streamId, 'stream-123');
      expect(response.conversationId, 'convo-1');
    },
  );

  test('startAgentChat includes attached files in agent payload', () async {
    AuthSession? session = _session();

    final sessionService = _buildSessionService(
      readSession: () => session,
      writeSession: (value) async => session = value,
      clearSession: () async => session = null,
      onSend: (request) async {
        final body =
            jsonDecode((request as http.Request).body) as Map<String, dynamic>;
        final files = body['files'] as List<dynamic>;

        expect(request.url.path, '/api/agents/chat/agents');
        expect(files, hasLength(1));
        expect(files.single['file_id'], 'file-1');
        expect(files.single['filepath'], '/files/audio.webm');
        expect(files.single['type'], 'audio/webm');
        expect(files.single['filename'], 'voice-message.webm');

        return _jsonResponse({
          'streamId': 'stream-123',
          'conversationId': 'convo-1',
          'status': 'started',
        });
      },
    );

    final api = ChatiaApiService(
      baseUrl: 'http://localhost:3080',
      sessionService: sessionService,
    );

    await api.startAgentChat(
      agentId: 'agent_123',
      parentMessageId: 'parent-1',
      messageId: 'message-1',
      text: 'Analyse ce message vocal.',
      conversationId: 'convo-1',
      files: const [
        {
          'file_id': 'file-1',
          'filepath': '/files/audio.webm',
          'type': 'audio/webm',
          'filename': 'voice-message.webm',
        },
      ],
    );
  });

  test(
    'uploadMessageFile posts multipart payload for generic attachments',
    () async {
      AuthSession? session = _session();

      final sessionService = _buildSessionService(
        readSession: () => session,
        writeSession: (value) async => session = value,
        clearSession: () async => session = null,
        onSend: (request) async {
          final multipart = request as http.MultipartRequest;

          expect(multipart.method, 'POST');
          expect(multipart.url.path, '/api/files');
          expect(multipart.fields['endpoint'], 'openAI');
          expect(multipart.fields['file_id'], 'temp-audio-1');
          expect(multipart.fields['message_file'], 'true');
          expect(multipart.files, hasLength(1));
          expect(multipart.files.single.field, 'file');
          expect(multipart.files.single.filename, 'voice-message.webm');
          expect(multipart.files.single.contentType?.mimeType, 'video/webm');

          return _jsonResponse({
            'file_id': 'file-1',
            'temp_file_id': 'temp-audio-1',
            'filepath': '/files/audio.webm',
            'type': 'audio/webm',
            'source': 'local',
          });
        },
      );

      final api = ChatiaApiService(
        baseUrl: 'http://localhost:3080',
        sessionService: sessionService,
      );

      final uploaded = await api.uploadMessageFile(
        bytes: const [1, 2, 3],
        filename: 'voice-message.webm',
        tempFileId: 'temp-audio-1',
      );

      expect(uploaded.fileId, 'file-1');
      expect(uploaded.filepath, '/files/audio.webm');
      expect(uploaded.type, 'audio/webm');
    },
  );

  test('uploadImageFile posts multipart payload to image route with explicit mime type', () async {
    AuthSession? session = _session();

    final sessionService = _buildSessionService(
      readSession: () => session,
      writeSession: (value) async => session = value,
      clearSession: () async => session = null,
      onSend: (request) async {
        final multipart = request as http.MultipartRequest;

        expect(multipart.method, 'POST');
        expect(multipart.url.path, '/api/files/images');
        expect(multipart.fields['endpoint'], 'openAI');
        expect(multipart.fields['file_id'], 'temp-image-1');
        expect(multipart.fields['width'], '3024');
        expect(multipart.fields['height'], '4032');
        expect(multipart.files, hasLength(1));
        expect(multipart.files.single.field, 'file');
        expect(
          multipart.files.single.filename,
          'image_picker_C7BF6C0C-C08F-49DB-AFA1-0F8B9C889611.jpg',
        );
        expect(multipart.files.single.contentType?.mimeType, 'image/jpeg');

        return _jsonResponse({
          'file_id': 'file-image-1',
          'temp_file_id': 'temp-image-1',
          'filepath': '/files/image.jpg',
          'type': 'image/jpeg',
          'source': 'local',
          'width': 3024,
          'height': 4032,
        });
      },
    );

    final api = ChatiaApiService(
      baseUrl: 'http://localhost:3080',
      sessionService: sessionService,
    );

    final uploaded = await api.uploadImageFile(
      bytes: const [1, 2, 3],
      filename: 'image_picker_C7BF6C0C-C08F-49DB-AFA1-0F8B9C889611.jpg',
      tempFileId: 'temp-image-1',
      width: 3024,
      height: 4032,
    );

    expect(uploaded.fileId, 'file-image-1');
    expect(uploaded.filepath, '/files/image.jpg');
    expect(uploaded.type, 'image/jpeg');
    expect(uploaded.width, 3024);
    expect(uploaded.height, 4032);
  });

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

  test('streamChat retries once when SSE stream is not ready yet', () async {
    AuthSession? session = _session();
    var attempts = 0;

    final sessionService = _buildSessionService(
      readSession: () => session,
      writeSession: (value) async => session = value,
      clearSession: () async => session = null,
      onSend: (request) async {
        attempts += 1;
        if (attempts == 1) {
          return http.StreamedResponse(
            Stream<List<int>>.value(utf8.encode('not ready')),
            404,
            request: request,
          );
        }

        return _sseResponse(
          'event: message\n'
          'data: {"final":true,"responseMessage":{"text":"Analyse terminee"}}\n\n',
        );
      },
    );

    final api = ChatiaApiService(
      baseUrl: 'http://localhost:3080',
      sessionService: sessionService,
    );

    final events = await api.streamChat('stream-123').toList();

    expect(attempts, 2);
    expect(events, hasLength(1));
    expect(events.single.content, 'Analyse terminee');
    expect(events.single.done, isTrue);
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
