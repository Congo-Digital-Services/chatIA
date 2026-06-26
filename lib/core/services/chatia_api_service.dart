import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../constants/backend_config.dart';
import 'jwt_debug_helper.dart';
import 'librechat_session_service.dart';
import '../../shared/models/chat_message.dart';
import '../../shared/models/conversation.dart';

final chatiaApiProvider = Provider<ChatiaApiService>((ref) {
  final sessionService = ref.watch(libreChatSessionServiceProvider);
  return ChatiaApiService(
    baseUrl: BackendConfig.baseUrl,
    sessionService: sessionService,
  );
});

final chatiaConfigProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(chatiaApiProvider).fetchConfig();
});

class ChatiaApiService {
  ChatiaApiService({required this.baseUrl, required this.sessionService});

  static const defaultOpenAiModel = 'gpt-4';

  final String baseUrl;
  final LibreChatSessionService sessionService;

  bool get isAvailable => sessionService.currentSession != null;

  Map<String, String> _baseHeaders([String? accessToken]) {
    final headers = <String, String>{'Accept': 'application/json'};
    if (!kIsWeb) {
      headers['User-Agent'] = BackendConfig.userAgent;
    }
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    return headers;
  }

  Map<String, String> _jsonHeaders([String? accessToken]) => {
    ..._baseHeaders(accessToken),
    'Content-Type': 'application/json',
  };

  void _logAuthDebug(String context) {
    if (!kDebugMode) {
      return;
    }

    final session = sessionService.currentSession;
    final access = JwtDebugHelper.inspect(session?.accessToken);
    final id = JwtDebugHelper.inspect(session?.idToken);
    final selected = session?.accessToken.isNotEmpty == true
        ? 'accessToken'
        : 'none';
    debugPrint('[ChatIA][$context] selectedBearer=$selected');
    if (access != null) {
      debugPrint('[ChatIA][$context] accessToken $access');
    }
    if (id != null) {
      debugPrint('[ChatIA][$context] idToken $id');
    }
  }

  void _logRequestDebug(String method, Uri uri) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('[ChatIA][$method] baseUrl=$baseUrl');
    debugPrint('[ChatIA][$method] url=$uri');
  }

  void _logFullDebug(String context, String value) {
    if (!kDebugMode) {
      return;
    }

    const chunkSize = 800;
    debugPrint('[ChatIA][$context] length=${value.length}');
    for (var index = 0; index < value.length; index += chunkSize) {
      final end = (index + chunkSize < value.length)
          ? index + chunkSize
          : value.length;
      debugPrint(
        '[ChatIA][$context] chunk ${index ~/ chunkSize + 1}: ${value.substring(index, end)}',
      );
    }
  }

  Uri _uri(String path, [Map<String, String>? queryParameters]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: queryParameters);
  }

  Future<http.Response> _sendJson(
    String method,
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    String? body,
    Duration? timeout,
  }) async {
    final operation = sessionService.sendAuthorized((accessToken) {
      final request = http.Request(method, _uri(path, queryParameters));
      request.headers.addAll(_jsonHeaders(accessToken));
      if (headers != null) {
        request.headers.addAll(headers);
      }
      if (body != null) {
        request.body = body;
      }
      return request;
    });

    final streamed = timeout != null
        ? await operation.timeout(timeout)
        : await operation;
    return http.Response.fromStream(streamed);
  }

  Future<Map<String, dynamic>> fetchConfig() async {
    final response = await _sendJson(
      'GET',
      '/api/config',
      timeout: const Duration(seconds: 10),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Impossible de charger la configuration : ${response.statusCode}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> logout() async {
    final streamed = await sessionService.sendAuthorized((accessToken) {
      final request = http.Request('POST', _uri('/api/auth/logout'));
      request.headers.addAll(_jsonHeaders(accessToken));
      return request;
    });
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Impossible de fermer la session backend : ${response.statusCode}',
      );
    }
  }

  Future<Map<String, dynamic>> refreshAuth() async {
    final session = await sessionService.refreshAccessToken(force: true);
    return <String, dynamic>{
      'token': session.accessToken,
      'user': {'email': session.email, 'username': session.userName},
    };
  }

  Future<List<Conversation>> fetchConversations({
    String sortBy = 'updatedAt',
    String sortDirection = 'desc',
    int limit = 25,
    String? cursor,
    String? search,
  }) async {
    final response = await _sendJson(
      'GET',
      '/api/convos',
      queryParameters: {
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        if (search != null && search.isNotEmpty) 'search': search,
        'limit': '$limit',
        'sortBy': sortBy,
        'sortDirection': sortDirection,
      },
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Impossible de charger les conversations : ${response.statusCode}',
      );
    }

    final jsonBody = jsonDecode(response.body);
    final items = jsonBody is Map<String, dynamic>
        ? (jsonBody['conversations'] as List<dynamic>?) ?? []
        : (jsonBody as List<dynamic>);

    return items.cast<Map<String, dynamic>>().map(_mapApiConversation).toList();
  }

  Future<Conversation> fetchConversation(String conversationId) async {
    final response = await _sendJson('GET', '/api/convos/$conversationId');
    if (response.statusCode != 200) {
      throw Exception(
        'Impossible de charger la conversation : ${response.statusCode}',
      );
    }

    final jsonBody = jsonDecode(response.body);
    if (jsonBody is! Map<String, dynamic>) {
      throw Exception('Réponse conversation inattendue.');
    }

    return _mapApiConversation(jsonBody);
  }

  Future<List<String>> fetchModels() async {
    final response = await _sendJson('GET', '/api/models');
    if (response.statusCode != 200) {
      throw Exception(
        'Impossible de charger les modèles : ${response.statusCode}',
      );
    }

    final jsonBody = jsonDecode(response.body);
    final items = jsonBody is Map<String, dynamic>
        ? (jsonBody['models'] as List<dynamic>?) ?? []
        : (jsonBody as List<dynamic>);

    return items
        .map((item) {
          if (item is String) {
            return item;
          }
          if (item is Map<String, dynamic>) {
            return item['name']?.toString() ??
                item['id']?.toString() ??
                item['model']?.toString() ??
                '';
          }
          return '';
        })
        .where((model) => model.isNotEmpty)
        .toList();
  }

  Future<PaginatedMessagesResponse> fetchMessages(
    String conversationId, {
    int pageSize = 25,
    String? cursor,
  }) async {
    final response = await _sendJson(
      'GET',
      '/api/messages',
      queryParameters: {
        'conversationId': conversationId,
        'pageSize': '$pageSize',
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'sortBy': 'createdAt',
        'sortDirection': 'asc',
      },
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Impossible de charger les messages : ${response.statusCode}',
      );
    }

    final jsonBody = jsonDecode(response.body);
    // Route recommandée : {messages: [...]} ; fallback sur tableau direct.
    final items = jsonBody is Map<String, dynamic>
        ? (jsonBody['messages'] as List<dynamic>?) ?? []
        : (jsonBody as List<dynamic>);
    final nextCursor = jsonBody is Map<String, dynamic>
        ? jsonBody['nextCursor']?.toString()
        : null;

    return PaginatedMessagesResponse(
      messages: items.cast<Map<String, dynamic>>().map(_mapApiMessage).toList(),
      nextCursor: nextCursor,
    );
  }

  /// GET /api/messages/:conversationId/:messageId
  /// Récupère un message précis dans une conversation.
  Future<ChatMessage> fetchSingleMessage(
    String conversationId,
    String messageId,
  ) async {
    final response = await _sendJson(
      'GET',
      '/api/messages/$conversationId/$messageId',
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Message introuvable ($conversationId/$messageId) : ${response.statusCode}',
      );
    }

    final jsonBody = jsonDecode(response.body);
    final data = jsonBody is Map<String, dynamic>
        ? jsonBody
        : (jsonBody as List<dynamic>).first as Map<String, dynamic>;
    return _mapApiMessage(data);
  }

  /// POST /api/messages/:conversationId
  /// Sauvegarde un message dans une conversation existante.
  /// Retourne le message tel que persisté par le backend.
  Future<ChatMessage> saveMessage(
    String conversationId, {
    required String messageId,
    required String parentMessageId,
    required String sender,
    required String text,
    bool isCreatedByUser = true,
    bool error = false,
  }) async {
    final body = jsonEncode({
      'messageId': messageId,
      'parentMessageId': parentMessageId,
      'sender': sender,
      'text': text,
      'isCreatedByUser': isCreatedByUser,
      'error': error,
    });

    final response = await _sendJson(
      'POST',
      '/api/messages/$conversationId',
      body: body,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Impossible de sauvegarder le message : ${response.statusCode} ${response.body}',
      );
    }

    final jsonBody = jsonDecode(response.body);
    if (jsonBody is Map<String, dynamic>) {
      return _mapApiMessage(jsonBody);
    }
    // Certaines versions de LibreChat retournent le message directement
    return ChatMessage(
      id: messageId,
      role: isCreatedByUser ? ChatRole.user : ChatRole.assistant,
      text: text,
    );
  }

  /// PUT /api/messages/:conversationId/:messageId
  /// Modifie le contenu d'un message existant.
  Future<ChatMessage> updateMessage(
    String conversationId,
    String messageId, {
    required String text,
  }) async {
    final body = jsonEncode({'text': text});

    final response = await _sendJson(
      'PUT',
      '/api/messages/$conversationId/$messageId',
      body: body,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Impossible de modifier le message : ${response.statusCode} ${response.body}',
      );
    }

    final jsonBody = jsonDecode(response.body);
    if (jsonBody is Map<String, dynamic>) {
      return _mapApiMessage(jsonBody);
    }
    return ChatMessage(id: messageId, role: ChatRole.assistant, text: text);
  }

  /// DELETE /api/messages/:conversationId/:messageId
  /// Supprime un message précis d'une conversation.
  Future<void> deleteMessage(String conversationId, String messageId) async {
    final response = await _sendJson(
      'DELETE',
      '/api/messages/$conversationId/$messageId',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Impossible de supprimer le message : ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<OpenAIChatResponse> startOpenAIChat({
    required String parentMessageId,
    required String messageId,
    required String text,
    String? conversationId,
    String model = defaultOpenAiModel,
    List<Map<String, dynamic>>? files,
  }) async {
    _logAuthDebug('POST /api/agents/chat/openAI');
    _logRequestDebug(
      'POST /api/agents/chat/openAI',
      _uri('/api/agents/chat/openAI'),
    );
    final bodyMap = <String, dynamic>{
      'endpoint': 'openAI',
      'model': model,
      'conversationId': conversationId,
      'parentMessageId': parentMessageId,
      'messageId': messageId,
      'text': text,
    };
    if (files != null && files.isNotEmpty) {
      bodyMap['files'] = files;
    }
    final body = jsonEncode(bodyMap);
    _logFullDebug('POST /api/agents/chat/openAI body', body);

    final response = await _sendJson(
      'POST',
      '/api/agents/chat/openAI',
      body: body,
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Échec démarrage OpenAI: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return OpenAIChatResponse(
      streamId: data['streamId']?.toString() ?? '',
      conversationId: data['conversationId']?.toString(),
    );
  }

  /// POST /api/agents/chat
  /// Démarre une conversation avec un agent LibreChat spécifique.
  /// Nécessite un [agentId] valide configuré sur l'instance LibreChat.
  /// Retourne un [OpenAIChatResponse] avec le streamId pour le flux SSE.
  Future<OpenAIChatResponse> startAgentChat({
    required String agentId,
    required String parentMessageId,
    required String messageId,
    required String text,
    String? conversationId,
  }) async {
    _logAuthDebug('POST /api/agents/chat');
    _logRequestDebug('POST /api/agents/chat', _uri('/api/agents/chat'));
    final body = jsonEncode({
      'agent_id': agentId,
      'conversationId': conversationId,
      'parentMessageId': parentMessageId,
      'messageId': messageId,
      'text': text,
    });
    _logFullDebug('POST /api/agents/chat body', body);

    final response = await _sendJson('POST', '/api/agents/chat', body: body);
    if (response.statusCode != 200) {
      throw Exception(
        'Échec démarrage chat agent ($agentId): ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return OpenAIChatResponse(
      streamId: data['streamId']?.toString() ?? '',
      conversationId: data['conversationId']?.toString(),
    );
  }

  /// Stream complet via un agent LibreChat (POST /api/agents/chat + SSE stream).
  Stream<ChatStreamEvent> sendAgentChat({
    required String agentId,
    required String parentMessageId,
    required String messageId,
    required String text,
    String? conversationId,
    bool resume = false,
  }) async* {
    final startResponse = await startAgentChat(
      agentId: agentId,
      conversationId: conversationId,
      parentMessageId: parentMessageId,
      messageId: messageId,
      text: text,
    );

    final streamId = startResponse.streamId;
    if (streamId.isEmpty) {
      throw Exception('StreamId manquant depuis le backend (agent).');
    }

    await for (final event in streamChat(
      streamId,
      resume: resume,
      fallbackConversationId: startResponse.conversationId,
    )) {
      yield event;
    }
  }

  Future<UploadedFileInfo> uploadImageFile({
    required List<int> bytes,
    required String filename,
    required String tempFileId,
    required int width,
    required int height,
    String endpoint = 'openAI',
  }) async {
    if (width <= 0 || height <= 0) {
      throw Exception('Dimensions image manquantes pour le backend ChatIA.');
    }

    final data = await _sendMultipartJson(
      path: '/api/files/images',
      fileField: 'file',
      bytes: bytes,
      filename: filename,
      fields: {
        'endpoint': endpoint,
        'file_id': tempFileId,
        'width': '$width',
        'height': '$height',
      },
    );

    return UploadedFileInfo.fromJson(data, baseUrl: baseUrl);
  }

  Future<UploadedFileInfo> uploadMessageFile({
    required List<int> bytes,
    required String filename,
    required String tempFileId,
    String endpoint = 'openAI',
  }) async {
    final data = await _sendMultipartJson(
      path: '/api/files',
      fileField: 'file',
      bytes: bytes,
      filename: filename,
      fields: {
        'endpoint': endpoint,
        'file_id': tempFileId,
        'message_file': 'true',
      },
    );

    return UploadedFileInfo.fromJson(data, baseUrl: baseUrl);
  }

  Future<String> transcribeSpeech({
    required List<int> bytes,
    required String filename,
  }) async {
    final data = await _sendMultipartJson(
      path: '/api/files/speech/stt',
      fileField: 'audio',
      bytes: bytes,
      filename: filename,
      fields: const {},
    );

    return data['text']?.toString() ??
        data['transcript']?.toString() ??
        data['message']?.toString() ??
        '';
  }

  Future<Map<String, dynamic>> _sendMultipartJson({
    required String path,
    required String fileField,
    required List<int> bytes,
    required String filename,
    required Map<String, String> fields,
  }) async {
    if (bytes.isEmpty) {
      throw Exception('Fichier vide ou non lisible.');
    }

    final streamedResponse = await sessionService.sendAuthorized((accessToken) {
      final request = http.MultipartRequest('POST', _uri(path));
      request.headers.addAll(_baseHeaders(accessToken));
      request.fields.addAll(fields);
      request.files.add(
        http.MultipartFile.fromBytes(fileField, bytes, filename: filename),
      );
      return request;
    });
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Echec API $path : ${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Réponse API inattendue pour $path.');
    }

    return decoded;
  }

  Stream<ChatStreamEvent> sendOpenAIChat({
    required String parentMessageId,
    required String messageId,
    required String text,
    String? conversationId,
    String model = defaultOpenAiModel,
    bool resume = false,
    List<Map<String, dynamic>>? files,
  }) async* {
    final startResponse = await startOpenAIChat(
      conversationId: conversationId,
      parentMessageId: parentMessageId,
      messageId: messageId,
      text: text,
      model: model,
      files: files,
    );

    final streamId = startResponse.streamId;
    if (streamId.isEmpty) {
      throw Exception('StreamId manquant depuis le backend.');
    }

    await for (final event in streamChat(
      streamId,
      resume: resume,
      fallbackConversationId: startResponse.conversationId,
    )) {
      yield event;
    }
  }

  Stream<ChatStreamEvent> streamChat(
    String streamId, {
    bool resume = false,
    String? fallbackConversationId,
  }) {
    AuthorizedStreamConnection? connection;
    StreamSubscription<String>? subscription;
    final controller = StreamController<ChatStreamEvent>();

    controller.onCancel = () async {
      await subscription?.cancel();
      await connection?.close();
    };

    () async {
      _logAuthDebug('GET /api/agents/chat/stream/$streamId');
      final uri = _uri('/api/agents/chat/stream/$streamId', {
        if (resume) 'resume': 'true',
      });
      _logRequestDebug('GET /api/agents/chat/stream/$streamId', uri);
      connection = await sessionService.openAuthorizedStream((accessToken) {
        final request = http.Request('GET', uri);
        request.headers.addAll(_baseHeaders(accessToken));
        request.headers['Accept'] = 'text/event-stream';
        return request;
      });
      final response = connection!.response;
      if (response.statusCode != 200) {
        await connection!.close();
        controller.addError(
          Exception('Échec de connexion au flux SSE : ${response.statusCode}'),
        );
        await controller.close();
        return;
      }

      final decoded = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      final blockLines = <String>[];

      Future<void> terminate() async {
        await subscription?.cancel();
        await connection?.close();
        if (!controller.isClosed) {
          await controller.close();
        }
      }

      subscription = decoded.listen(
        (rawLine) {
          final line = rawLine.trimRight();
          if (line.isEmpty) {
            final event = _parseSseEventBlock(
              blockLines,
              fallbackConversationId: fallbackConversationId,
            );
            blockLines.clear();
            if (event == null) {
              return;
            }
            controller.add(event);
            if (event.error != null || event.done) {
              terminate();
            }
            return;
          }

          blockLines.add(line);
        },
        onError: (error, stackTrace) {
          controller.addError(error, stackTrace);
          terminate();
        },
        onDone: () async {
          if (blockLines.isNotEmpty) {
            final event = _parseSseEventBlock(
              blockLines,
              fallbackConversationId: fallbackConversationId,
            );
            blockLines.clear();
            if (event != null) {
              controller.add(event);
            }
          }
          await terminate();
        },
        cancelOnError: true,
      );
    }();

    return controller.stream;
  }

  ChatStreamEvent? _parseSseEventBlock(
    List<String> blockLines, {
    String? fallbackConversationId,
  }) {
    if (blockLines.isEmpty) {
      return null;
    }

    String? eventName;
    final dataLines = <String>[];

    for (final line in blockLines) {
      if (line.startsWith('event:')) {
        eventName = line.substring(6).trim();
        continue;
      }
      if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trimLeft());
        continue;
      }
      if (line.startsWith('data')) {
        dataLines.add(line.substring(4).trimLeft());
      }
    }

    final rawData = dataLines.join('\n').trim();
    if (rawData.isEmpty ||
        rawData == '[DONE]' ||
        rawData.toLowerCase() == 'done') {
      return null;
    }

    final parsedJson = _tryParseJsonObject(rawData);
    final payload = parsedJson ?? <String, dynamic>{'message': rawData};
    final normalizedEvent = eventName?.isNotEmpty == true
        ? eventName!
        : 'message';
    final payloadEvent = payload['event']?.toString();
    final resolvedEvent = payloadEvent != null && payloadEvent.isNotEmpty
        ? payloadEvent
        : normalizedEvent;

    if (normalizedEvent == 'error' || resolvedEvent == 'error') {
      return ChatStreamEvent.error(
        error:
            payload['error']?.toString() ??
            payload['message']?.toString() ??
            'Erreur SSE inconnue',
        rawEvent: resolvedEvent,
        rawPayload: payload,
        conversationId:
            _extractConversationId(payload) ?? fallbackConversationId,
      );
    }

    final content = _extractMessageText(payload, resolvedEvent: resolvedEvent);
    final isFinal = payload['final'] == true;
    final isSync = payload['sync'] == true;
    final isCreated = payload['created'] == true;

    return ChatStreamEvent(
      conversationId: _extractConversationId(payload) ?? fallbackConversationId,
      content: content,
      done: isFinal,
      event: resolvedEvent,
      title:
          payload['title']?.toString() ??
          (payload['titleEvent'] is Map<String, dynamic>
              ? (payload['titleEvent'] as Map<String, dynamic>)['data']
                        is Map<String, dynamic>
                    ? ((payload['titleEvent'] as Map<String, dynamic>)['data']
                              as Map<String, dynamic>)['title']
                          ?.toString()
                    : null
              : null),
      isSync: isSync,
      isCreated: isCreated,
      rawPayload: payload,
      requestMessage:
          _asMap(payload['requestMessage']) ??
          (isCreated ? _asMap(payload['message']) : null),
      responseMessage: _asMap(payload['responseMessage']),
      resumeState: _asMap(payload['resumeState']),
      pendingEvents: _asListOfMaps(payload['pendingEvents']),
    );
  }

  Map<String, dynamic>? _tryParseJsonObject(String rawData) {
    try {
      final decoded = jsonDecode(rawData);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Fall through to raw text.
    }
    return null;
  }

  String? _extractConversationId(Map<String, dynamic> payload) {
    final direct = payload['conversationId']?.toString();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    final conversation = _asMap(payload['conversation']);
    final fromConversation = conversation?['conversationId']?.toString();
    if (fromConversation != null && fromConversation.isNotEmpty) {
      return fromConversation;
    }

    final responseMessage = _asMap(payload['responseMessage']);
    final fromResponse = responseMessage?['conversationId']?.toString();
    if (fromResponse != null && fromResponse.isNotEmpty) {
      return fromResponse;
    }

    final resumeState = _asMap(payload['resumeState']);
    return resumeState?['conversationId']?.toString();
  }

  String _extractMessageText(
    Map<String, dynamic> payload, {
    required String resolvedEvent,
  }) {
    if (payload['final'] == true) {
      final responseMessage = _asMap(payload['responseMessage']);
      final finalContent = _extractTextFromContent(responseMessage?['content']);
      if (finalContent.isNotEmpty) {
        return finalContent;
      }

      final responseText = responseMessage?['text']?.toString();
      if (responseText != null && responseText.isNotEmpty) {
        return responseText;
      }
    }

    if (resolvedEvent == 'on_message_delta') {
      final data = _asMap(payload['data']);
      final delta = _asMap(data?['delta']);
      final deltaContent = _extractTextFromContent(delta?['content']);
      if (deltaContent.isNotEmpty) {
        return deltaContent;
      }
    }

    if (payload['created'] == true) {
      return '';
    }

    final delta = payload['delta']?.toString();
    if (delta != null && delta.isNotEmpty) {
      return delta;
    }

    final text = payload['text']?.toString();
    if (text != null && text.isNotEmpty) {
      return text;
    }

    final message = _asMap(payload['message']);
    final messageText = message?['text']?.toString();
    if (messageText != null && messageText.isNotEmpty) {
      return messageText;
    }

    final messageContent = _extractTextFromContent(message?['content']);
    if (messageContent.isNotEmpty) {
      return messageContent;
    }

    final messageString = payload['message']?.toString();
    if (messageString != null && messageString.isNotEmpty) {
      return messageString;
    }

    final responseMessage = _asMap(payload['responseMessage']);
    final responseContent = _extractTextFromContent(
      responseMessage?['content'],
    );
    if (responseContent.isNotEmpty) {
      return responseContent;
    }

    final responseText = responseMessage?['text']?.toString();
    if (responseText != null && responseText.isNotEmpty) {
      return responseText;
    }

    final resumeState = _asMap(payload['resumeState']);
    final aggregatedContent = resumeState?['aggregatedContent'];
    if (aggregatedContent is List && aggregatedContent.isNotEmpty) {
      return aggregatedContent.map((item) => item.toString()).join();
    }

    return '';
  }

  String _extractTextFromContent(Object? content) {
    if (content is! List) {
      return '';
    }

    final buffer = StringBuffer();
    for (final item in content) {
      final block = _asMap(item);
      if (block == null) {
        continue;
      }

      final type = block['type']?.toString();
      if (type != null && type != 'text') {
        continue;
      }

      final directText = block['text']?.toString();
      if (directText != null && directText.isNotEmpty) {
        buffer.write(directText);
        continue;
      }

      final nestedText = _asMap(block['text'])?['value']?.toString();
      if (nestedText != null && nestedText.isNotEmpty) {
        buffer.write(nestedText);
      }
    }

    return buffer.toString();
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  List<Map<String, dynamic>> _asListOfMaps(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Conversation _mapApiConversation(Map<String, dynamic> json) {
    final id =
        json['id']?.toString() ?? json['conversationId']?.toString() ?? '';
    final title =
        json['title']?.toString() ?? json['name']?.toString() ?? 'Conversation';
    final subtitle =
        json['subtitle']?.toString() ?? json['description']?.toString() ?? '';
    final folder = json['folder']?.toString() ?? '';
    final type = json['type']?.toString();

    return Conversation(
      id: id,
      title: title,
      subtitle: subtitle,
      folder: folder,
      isPinned: false,
      heroAssetLabel: null,
      type: type == 'note'
          ? ConversationType.note
          : type == 'channel'
          ? ConversationType.channel
          : ConversationType.chat,
      messages:
          (json['messages'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>()
              .map(_mapApiMessage)
              .toList() ??
          [],
    );
  }

  ChatMessage _mapApiMessage(Map<String, dynamic> json) {
    final id =
        json['id']?.toString() ??
        json['messageId']?.toString() ??
        DateTime.now().microsecondsSinceEpoch.toString();
    final sender =
        json['sender']?.toString().toLowerCase() ??
        json['role']?.toString().toLowerCase() ??
        'assistant';
    final text = json['text']?.toString() ?? json['content']?.toString() ?? '';
    final file = _firstFile(json);
    final fileType = file?['type']?.toString() ?? file?['mimeType']?.toString();

    return ChatMessage(
      id: id,
      role: sender.contains('user') || sender.contains('human')
          ? ChatRole.user
          : ChatRole.assistant,
      text: text,
      fileUrl:
          json['fileUrl']?.toString() ??
          json['url']?.toString() ??
          _resolveFileUrl(
            file?['filepath']?.toString() ?? file?['url']?.toString(),
          ),
      fileName:
          json['fileName']?.toString() ??
          file?['filename']?.toString() ??
          file?['name']?.toString(),
      fileSize: json['fileSize']?.toString() ?? file?['size']?.toString(),
      isImage: json['isImage'] as bool? ?? fileType?.startsWith('image/'),
      audioUrl: json['audioUrl']?.toString(),
    );
  }

  Map<String, dynamic>? _firstFile(Map<String, dynamic> json) {
    final files = json['files'];
    if (files is List && files.isNotEmpty && files.first is Map) {
      return Map<String, dynamic>.from(files.first as Map);
    }
    if (json['file'] is Map) {
      return Map<String, dynamic>.from(json['file'] as Map);
    }
    return null;
  }

  String? _resolveFileUrl(String? pathOrUrl) {
    if (pathOrUrl == null || pathOrUrl.isEmpty) return null;
    final uri = Uri.tryParse(pathOrUrl);
    if (uri != null && uri.hasScheme) return pathOrUrl;
    return Uri.parse(baseUrl).resolve(pathOrUrl).toString();
  }
}

class OpenAIChatResponse {
  OpenAIChatResponse({required this.streamId, this.conversationId});

  final String streamId;
  final String? conversationId;
}

class PaginatedMessagesResponse {
  const PaginatedMessagesResponse({
    required this.messages,
    required this.nextCursor,
  });

  final List<ChatMessage> messages;
  final String? nextCursor;
}

class ChatStreamEvent {
  ChatStreamEvent({
    required this.conversationId,
    required this.content,
    required this.done,
    required this.event,
    this.title,
    this.isSync = false,
    this.isCreated = false,
    this.error,
    this.rawPayload = const {},
    this.requestMessage,
    this.responseMessage,
    this.resumeState,
    this.pendingEvents = const [],
  });

  factory ChatStreamEvent.error({
    required String error,
    required String rawEvent,
    required Map<String, dynamic> rawPayload,
    String? conversationId,
  }) {
    return ChatStreamEvent(
      conversationId: conversationId,
      content: '',
      done: true,
      event: rawEvent,
      error: error,
      rawPayload: rawPayload,
    );
  }

  final String? conversationId;
  final String content;
  final bool done;
  final String event;
  final String? title;
  final bool isSync;
  final bool isCreated;
  final String? error;
  final Map<String, dynamic> rawPayload;
  final Map<String, dynamic>? requestMessage;
  final Map<String, dynamic>? responseMessage;
  final Map<String, dynamic>? resumeState;
  final List<Map<String, dynamic>> pendingEvents;
}

class UploadedFileInfo {
  UploadedFileInfo({
    required this.fileId,
    required this.tempFileId,
    required this.filepath,
    required this.url,
    required this.type,
    required this.source,
    this.width,
    this.height,
  });

  final String fileId;
  final String tempFileId;
  final String filepath;
  final String url;
  final String type;
  final String source;
  final int? width;
  final int? height;

  factory UploadedFileInfo.fromJson(
    Map<String, dynamic> json, {
    required String baseUrl,
  }) {
    final filepath = json['filepath']?.toString() ?? '';
    final explicitUrl = json['url']?.toString() ?? json['fileUrl']?.toString();
    return UploadedFileInfo(
      fileId: json['file_id']?.toString() ?? '',
      tempFileId: json['temp_file_id']?.toString() ?? '',
      filepath: filepath,
      url: explicitUrl ?? _resolveUrl(baseUrl, filepath),
      type: json['type']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      width: _readInt(json['width']),
      height: _readInt(json['height']),
    );
  }

  static String _resolveUrl(String baseUrl, String filepath) {
    if (filepath.isEmpty) return '';
    final uri = Uri.tryParse(filepath);
    if (uri != null && uri.hasScheme) return filepath;
    return Uri.parse(baseUrl).resolve(filepath).toString();
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }
}
