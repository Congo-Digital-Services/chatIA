import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

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

  static const agentsEndpoint = 'agents';
  static const uploadsEndpoint = 'openAI';
  static const _sseRetryableStatusCodes = {404};
  // Le flux est créé AVANT la réponse au démarrage : un 404 ensuite veut
  // presque toujours dire que la réponse est déjà finie (agents rapides,
  // ex. traduction en 0,5 s). Un seul nouvel essai, puis relecture de la
  // réponse enregistrée (voir sendAgentChat) — au lieu de 2,5 s d'attente.
  static const _sseMaxConnectionAttempts = 2;

  final String baseUrl;
  final LibreChatSessionService sessionService;

  bool get isAvailable => sessionService.currentSession != null;

  String? _authCookieHeader() {
    final refreshToken = sessionService.currentSession?.refreshToken;
    if (refreshToken == null ||
        refreshToken.isEmpty ||
        refreshToken == 'cookie') {
      return null;
    }
    return 'token_provider=librechat; refreshToken=$refreshToken';
  }

  Map<String, String> _baseHeaders([String? accessToken]) {
    final headers = <String, String>{'Accept': 'application/json'};
    if (!kIsWeb) {
      headers['User-Agent'] = BackendConfig.userAgent;
    }
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    final authCookie = _authCookieHeader();
    if (authCookie != null) {
      headers['Cookie'] = authCookie;
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

    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(_mapApiConversation)
        .toList();
  }

  Future<Conversation> fetchConversation(String conversationId) async {
    final response = await _sendJson('GET', '/api/convos/$conversationId');
    if (response.statusCode != 200) {
      throw Exception(
        'Impossible de charger la conversation : ${response.statusCode}',
      );
    }

    final jsonBody = jsonDecode(response.body);
    final payload = jsonBody is Map<String, dynamic>
        ? (jsonBody['conversation'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(
                  jsonBody['conversation'] as Map<String, dynamic>,
                )
              : jsonBody)
        : null;
    if (payload == null) {
      throw Exception('Réponse conversation inattendue.');
    }

    return _mapApiConversation(payload);
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
    final items = _extractMessagesList(jsonBody);
    final nextCursor = jsonBody is Map<String, dynamic>
        ? jsonBody['nextCursor']?.toString()
        : null;

    return PaginatedMessagesResponse(
      messages: items
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map(_mapApiMessage)
          .toList(),
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

  Future<OpenAIChatResponse> startAgentChat({
    required String agentId,
    required String parentMessageId,
    required String messageId,
    required String text,
    String? conversationId,
    List<Map<String, dynamic>>? files,
    String spec = 'assistant-global',
    bool isTemporary = false,
  }) async {
    _logAuthDebug('POST /api/agents/chat/$agentsEndpoint');
    _logRequestDebug(
      'POST /api/agents/chat/$agentsEndpoint',
      _uri('/api/agents/chat/$agentsEndpoint'),
    );
    final body = jsonEncode({
      'text': text,
      'sender': 'User',
      'clientTimestamp': DateTime.now().toIso8601String(),
      'isCreatedByUser': true,
      'parentMessageId': parentMessageId,
      'conversationId': conversationId,
      'messageId': messageId,
      'error': false,
      'endpoint': agentsEndpoint,
      'spec': spec,
      'agent_id': agentId,
      'key': DateTime.now().toUtc().toIso8601String(),
      'isTemporary': isTemporary,
      'isRegenerate': false,
      'isContinued': false,
      'ephemeralAgent': {
        'mcp': const [],
        'web_search': false,
        'file_search': false,
        'execute_code': false,
        'artifacts': '',
      },
      if (files != null && files.isNotEmpty) 'files': files,
    });
    _logFullDebug('POST /api/agents/chat/$agentsEndpoint body', body);

    final response = await _sendJson(
      'POST',
      '/api/agents/chat/$agentsEndpoint',
      body: body,
    );
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
    List<Map<String, dynamic>>? files,
    String spec = 'assistant-global',
    bool isTemporary = false,
  }) async* {
    final startResponse = await startAgentChat(
      agentId: agentId,
      conversationId: conversationId,
      parentMessageId: parentMessageId,
      messageId: messageId,
      text: text,
      files: files,
      spec: spec,
      isTemporary: isTemporary,
    );

    final streamId = startResponse.streamId;
    if (streamId.isEmpty) {
      throw Exception('StreamId manquant depuis le backend (agent).');
    }

    try {
      await for (final event in streamChat(
        streamId,
        resume: resume,
        fallbackConversationId: startResponse.conversationId,
      )) {
        yield event;
      }
    } on SseStreamNotFoundException {
      // Réponse plus rapide que la connexion au flux : LibreChat a déjà clos
      // le flux (404), mais la réponse est enregistrée. On la relit.
      final convoId = [startResponse.conversationId, conversationId]
          .whereType<String>()
          .where((id) => id.isNotEmpty && id != 'new')
          .firstOrNull;
      if (convoId == null) {
        throw Exception(
          'Échec de connexion au flux SSE : 404 (conversation inconnue)',
        );
      }
      ChatStreamEvent? saved;
      try {
        saved = await _fetchSavedReply(
          convoId,
          messageId,
          sentParentMessageId: parentMessageId,
          sentText: text,
        );
      } catch (error) {
        debugPrint('[ChatIA] relecture de la réponse impossible : $error');
      }
      // Réponse introuvable : un événement final sans texte, mais avec la
      // conversation, fait recharger l'historique par l'écran de discussion,
      // qui affichera la réponse dès qu'elle est enregistrée.
      yield saved ??
          ChatStreamEvent(
            conversationId: convoId,
            content: '',
            done: true,
            event: 'final',
          );
    }
  }

  /// Réponse enregistrée au message envoyé, ou null.
  /// Quelques essais : l'enregistrement peut suivre de peu la fin du flux.
  ///
  /// LibreChat IGNORE le `messageId` envoyé : il donne au message utilisateur
  /// son propre identifiant (BaseClient.setMessageOptions : seul
  /// `overrideUserMessageId` est repris), que le client apprend par l'événement
  /// `created` du flux. Flux perdu (404), on ne le connaît pas : on retrouve le
  /// message envoyé par son parent et son texte, puis la réponse dont il est le
  /// parent. Chercher la réponse par [userMessageId] seul ne trouvait jamais
  /// rien (29/10/2026 : réponse en base, six relectures vides).
  Future<ChatStreamEvent?> _fetchSavedReply(
    String conversationId,
    String userMessageId, {
    String? sentParentMessageId,
    String? sentText,
  }) async {
    for (var attempt = 1; attempt <= 6; attempt++) {
      final response = await _sendJson(
        'GET',
        '/api/messages',
        queryParameters: {
          'conversationId': conversationId,
          'pageSize': '50',
          'sortBy': 'createdAt',
          'sortDirection': 'desc',
        },
      );
      if (response.statusCode == 200) {
        final messages = _extractMessagesList(jsonDecode(response.body))
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .map((m) => _asMap(m['responseMessage']) ?? m)
            .toList();
        // Identifiants possibles du message envoyé : celui du client (si le
        // serveur l'a repris) puis celui que le serveur lui a donné.
        final sentIds = <String>{userMessageId};
        final wanted = sentText?.trim();
        if (sentParentMessageId != null &&
            wanted != null &&
            wanted.isNotEmpty) {
          for (final m in messages) {
            if (m['isCreatedByUser'] == true &&
                m['parentMessageId']?.toString() == sentParentMessageId &&
                (m['text']?.toString().trim() ?? '') == wanted) {
              final id = m['messageId']?.toString();
              if (id != null && id.isNotEmpty) sentIds.add(id);
            }
          }
        }
        // Liste du plus récent au plus ancien : la première réponse trouvée
        // est celle du dernier envoi.
        final reply = messages
            .where(
              (m) =>
                  sentIds.contains(m['parentMessageId']?.toString()) &&
                  m['isCreatedByUser'] != true,
            )
            .firstOrNull;
        if (reply != null) {
          var text = _extractTextFromContent(reply['content']);
          if (text.isEmpty) text = reply['text']?.toString() ?? '';
          if (reply['error'] == true) {
            return ChatStreamEvent.error(
              error: _cleanStreamError(text),
              rawEvent: 'final',
              rawPayload: reply,
              conversationId: conversationId,
            );
          }
          if (text.isNotEmpty) {
            return ChatStreamEvent(
              conversationId: conversationId,
              content: text,
              done: true,
              event: 'final',
              rawPayload: reply,
              responseMessage: reply,
            );
          }
        }
      }
      await Future<void>.delayed(Duration(milliseconds: attempt * 400));
    }
    return null;
  }

  Future<UploadedFileInfo> uploadImageFile({
    required List<int> bytes,
    required String filename,
    required String tempFileId,
    required int width,
    required int height,
    String endpoint = agentsEndpoint,
    String endpointType = agentsEndpoint,
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
        'endpointType': endpointType,
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
    String endpoint = agentsEndpoint,
    String endpointType = agentsEndpoint,
  }) async {
    final data = await _sendMultipartJson(
      path: '/api/files',
      fileField: 'file',
      bytes: bytes,
      filename: filename,
      fields: {
        'endpoint': endpoint,
        'endpointType': endpointType,
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
    final body = await _sendMultipartBody(
      path: '/api/files/speech/stt',
      fileField: 'audio',
      bytes: bytes,
      filename: filename,
      fields: const {},
    );

    final transcription = _extractTranscription(body);
    if (transcription.trim().isNotEmpty) {
      return transcription.trim();
    }

    throw Exception(
      'Réponse API inattendue pour /api/files/speech/stt : '
      '${body.isEmpty ? '(vide)' : body}',
    );
  }

  String _extractTranscription(String body) {
    var candidate = body.trim();
    if (candidate.isEmpty) {
      return '';
    }

    if (candidate.startsWith('event:') || candidate.contains('\ndata:')) {
      final buffer = StringBuffer();
      for (final line in const LineSplitter().convert(candidate)) {
        final trimmed = line.trim();
        if (trimmed.startsWith('data:')) {
          buffer.writeln(trimmed.substring(5).trim());
        }
      }
      candidate = buffer.toString().trim();
      if (candidate.isEmpty) {
        return '';
      }
    }

    Object? decoded;
    try {
      decoded = jsonDecode(candidate);
    } catch (_) {
      return candidate;
    }

    if (decoded is Map) {
      for (final key in const [
        'text',
        'transcript',
        'transcription',
        'message',
        'result',
      ]) {
        final value = decoded[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
        if (value != null) {
          return value.toString().trim();
        }
      }
      return '';
    }

    if (decoded is String) {
      return decoded.trim();
    }

    return '';
  }

  Future<Map<String, dynamic>> _sendMultipartJson({
    required String path,
    required String fileField,
    required List<int> bytes,
    required String filename,
    required Map<String, String> fields,
  }) async {
    final body = await _sendMultipartBody(
      path: path,
      fileField: fileField,
      bytes: bytes,
      filename: filename,
      fields: fields,
    );

    final normalizedBody = body.trim();
    final sseError = _extractSseErrorMessage(normalizedBody);
    if (sseError != null) {
      throw Exception('Echec API $path : $sseError');
    }

    final decoded = _tryDecodeJsonMap(normalizedBody);
    if (decoded == null) {
      throw Exception('Réponse API inattendue pour $path : $normalizedBody');
    }

    return decoded;
  }

  Future<String> _sendMultipartBody({
    required String path,
    required String fileField,
    required List<int> bytes,
    required String filename,
    required Map<String, String> fields,
  }) async {
    if (bytes.isEmpty) {
      throw Exception('Fichier vide ou non lisible.');
    }

    final uri = _uri(path);
    _logAuthDebug('POST $path');
    _logRequestDebug('POST $path', uri);
    _logFullDebug(
      'POST $path multipart',
      jsonEncode({
        'fileField': fileField,
        'filename': filename,
        'bytesLength': bytes.length,
        'fields': fields,
      }),
    );

    final streamedResponse = await sessionService.sendAuthorized((accessToken) {
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(_baseHeaders(accessToken));
      request.fields.addAll(fields);
      final contentType = _mediaTypeFromFilename(filename);
      request.files.add(
        http.MultipartFile.fromBytes(
          fileField,
          bytes,
          filename: filename,
          contentType: contentType,
        ),
      );
      return request;
    });
    final response = await http.Response.fromStream(streamedResponse);

    if (kDebugMode) {
      debugPrint('[ChatIA][POST $path] status=${response.statusCode}');
    }
    _logFullDebug('POST $path response', response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Echec API $path : ${response.statusCode} ${response.body}',
      );
    }

    return response.body;
  }

  Map<String, dynamic>? _tryDecodeJsonMap(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Handled by caller.
    }
    return null;
  }

  String? _extractSseErrorMessage(String body) {
    if (!body.startsWith('event:')) {
      return null;
    }

    final lines = const LineSplitter().convert(body);
    String? eventName;
    final dataLines = <String>[];

    for (final line in lines) {
      if (line.startsWith('event:')) {
        eventName = line.substring(6).trim();
        continue;
      }
      if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trim());
      }
    }

    if (eventName != 'error' && eventName != 'message') {
      return body;
    }

    final rawData = dataLines.join('\n').trim();
    final payload = _tryDecodeJsonMap(rawData);
    if (payload == null) {
      return rawData.isNotEmpty ? rawData : body;
    }

    return payload['error']?.toString() ??
        payload['message']?.toString() ??
        rawData;
  }

  MediaType? _mediaTypeFromFilename(String filename) {
    final mimeType = lookupMimeType(filename);
    if (mimeType == null || !mimeType.contains('/')) {
      return null;
    }

    final parts = mimeType.split('/');
    if (parts.length != 2) {
      return null;
    }

    return MediaType(parts[0], parts[1]);
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
      http.StreamedResponse? response;

      for (var attempt = 1; attempt <= _sseMaxConnectionAttempts; attempt++) {
        connection = await sessionService.openAuthorizedStream((accessToken) {
          final request = http.Request('GET', uri);
          request.headers.addAll(_baseHeaders(accessToken));
          request.headers['Accept'] = 'text/event-stream';
          return request;
        });
        response = connection!.response;
        if (kDebugMode) {
          debugPrint(
            '[ChatIA][GET /api/agents/chat/stream/$streamId] connect attempt=$attempt status=${response.statusCode}',
          );
        }
        if (response.statusCode == 200) {
          break;
        }

        final shouldRetry =
            _sseRetryableStatusCodes.contains(response.statusCode) &&
            attempt < _sseMaxConnectionAttempts;
        await connection!.close();
        connection = null;
        if (!shouldRetry) {
          controller.addError(
            response.statusCode == 404
                ? SseStreamNotFoundException(streamId)
                : Exception(
                    'Échec de connexion au flux SSE : ${response.statusCode}',
                  ),
          );
          await controller.close();
          return;
        }

        await Future<void>.delayed(Duration(milliseconds: attempt * 250));
      }

      final currentResponse = response;
      if (currentResponse == null) {
        controller.addError(
          Exception('Échec de connexion au flux SSE : aucune réponse'),
        );
        await controller.close();
        return;
      }

      final decoded = currentResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      final blockLines = <String>[];
      var receivedAnyLine = false;

      Future<void> terminate() async {
        await subscription?.cancel();
        await connection?.close();
        if (!controller.isClosed) {
          await controller.close();
        }
      }

      subscription = decoded.listen(
        (rawLine) {
          receivedAnyLine = true;
          if (kDebugMode) {
            debugPrint(
              '[ChatIA][GET /api/agents/chat/stream/$streamId raw] $rawLine',
            );
          }
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
          if (kDebugMode) {
            debugPrint(
              '[ChatIA][GET /api/agents/chat/stream/$streamId] stream error=$error',
            );
          }
          controller.addError(error, stackTrace);
          terminate();
        },
        onDone: () async {
          if (kDebugMode) {
            debugPrint(
              '[ChatIA][GET /api/agents/chat/stream/$streamId] stream done receivedAnyLine=$receivedAnyLine bufferedLines=${blockLines.length}',
            );
          }
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

    _logFullDebug('SSE block', blockLines.join('\n'));

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
        error: _cleanStreamError(
          payload['error']?.toString() ??
              payload['message']?.toString() ??
              'Erreur SSE inconnue',
        ),
        rawEvent: resolvedEvent,
        rawPayload: payload,
        conversationId:
            _extractConversationId(payload) ?? fallbackConversationId,
      );
    }

    final contentError = _extractStreamError(payload);
    if (contentError != null) {
      return ChatStreamEvent.error(
        error: contentError,
        rawEvent: resolvedEvent,
        rawPayload: payload,
        conversationId:
            _extractConversationId(payload) ?? fallbackConversationId,
      );
    }

    var content = _extractMessageText(payload, resolvedEvent: resolvedEvent);
    // Une erreur serveur peut arriver comme texte de réponse (message final) :
    // on la reformule plutôt que d'afficher la trace brute de LiteLLM.
    if (content.isNotEmpty && _looksLikeBackendError(content)) {
      content = _cleanStreamError(content);
    }
    final isFinal =
        payload['final'] == true ||
        _hasChoiceFinishReason(payload) ||
        resolvedEvent == 'done';
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
    final choicesContent = _extractChoicesText(payload['choices']);
    if (choicesContent.isNotEmpty) {
      return choicesContent;
    }

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

    final content = _extractStringOrContent(payload['content']);
    if (content.isNotEmpty) {
      return content;
    }

    final message = _asMap(payload['message']);
    final messageText = message?['text']?.toString();
    if (messageText != null && messageText.isNotEmpty) {
      return messageText;
    }

    final stringMessageContent = _extractStringOrContent(message?['content']);
    if (stringMessageContent.isNotEmpty) {
      return stringMessageContent;
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

  bool _hasChoiceFinishReason(Map<String, dynamic> payload) {
    final choices = payload['choices'];
    if (choices is! List || choices.isEmpty) {
      return false;
    }

    for (final choice in choices) {
      final map = _asMap(choice);
      final finishReason = map?['finish_reason']?.toString();
      if (finishReason != null &&
          finishReason.isNotEmpty &&
          finishReason.toLowerCase() != 'null') {
        return true;
      }
    }

    return false;
  }

  String _extractChoicesText(Object? rawChoices) {
    if (rawChoices is! List) {
      return '';
    }

    final buffer = StringBuffer();
    for (final choice in rawChoices) {
      final map = _asMap(choice);
      if (map == null) {
        continue;
      }

      final delta = _asMap(map['delta']);
      final deltaContent = _extractStringOrContent(delta?['content']);
      if (deltaContent.isNotEmpty) {
        buffer.write(deltaContent);
        continue;
      }

      final message = _asMap(map['message']);
      final messageContent = _extractStringOrContent(message?['content']);
      if (messageContent.isNotEmpty) {
        buffer.write(messageContent);
        continue;
      }

      final text = map['text']?.toString();
      if (text != null && text.isNotEmpty) {
        buffer.write(text);
      }
    }

    return buffer.toString();
  }

  String _extractStringOrContent(Object? value) {
    if (value is String) {
      return value;
    }

    return _extractTextFromContent(value);
  }

  String _firstNonEmptyString(List<String?> values) {
    for (final value in values) {
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  String _extractTextFromContent(Object? content) {
    if (content is String) {
      return content;
    }

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
      if (type == 'error') {
        final directError = block['error']?.toString();
        if (directError != null && directError.isNotEmpty) {
          buffer.write(directError);
        }
        continue;
      }

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

  /// Cherche une erreur renvoyée par le backend dans les blocs de contenu
  /// (`type: "error"`) ou dans le champ `error` du payload.
  String? _extractStreamError(Map<String, dynamic> payload) {
    final candidates = <Object?>[
      payload['error'],
      payload['content'],
      _asMap(payload['message'])?['content'],
      _asMap(payload['responseMessage'])?['content'],
    ];
    for (final candidate in candidates) {
      if (candidate == null) {
        continue;
      }
      final error = _extractErrorFromContent(candidate);
      if (error != null) {
        return error;
      }
    }
    return null;
  }

  String? _extractErrorFromContent(Object? content) {
    if (content is String) {
      final text = content.trim();
      if (text.isNotEmpty && _looksLikeBackendError(text)) {
        return _cleanStreamError(text);
      }
      return null;
    }

    if (content is! List) {
      return null;
    }

    for (final item in content) {
      final block = _asMap(item);
      if (block == null) {
        continue;
      }
      if (block['type']?.toString() != 'error') {
        continue;
      }
      final message = block['error']?.toString() ?? block['text']?.toString();
      if (message != null && message.trim().isNotEmpty) {
        return _cleanStreamError(message);
      }
    }
    return null;
  }

  bool _looksLikeBackendError(String text) {
    if (text.toLowerCase().contains('an error occurred while processing')) {
      return true;
    }
    if (text.contains('<html') || text.contains('<title')) {
      return true;
    }
    return false;
  }

  /// Nettoie un message d'erreur serveur : retire les balises HTML et
  /// reformule les erreurs HTTP (502 Bad Gateway, etc.).
  String _cleanStreamError(String raw) {
    // Modèle hors ligne (serveur des modèles éteint ou injoignable).
    if (RegExp(
      r'NotFoundError|No deployments available|Connection error|'
      r'Hosted_vllmException|ServiceUnavailable|APIConnectionError',
    ).hasMatch(raw)) {
      return 'Le modèle de cet agent est indisponible pour le moment '
          '(serveur des modèles hors ligne). Réessayez plus tard.';
    }
    final statusMatch = RegExp(r'\b([45]\d{2})\b').firstMatch(raw);
    if (statusMatch != null) {
      final status = statusMatch.group(1)!;
      final label = _httpStatusLabel(status);
      if (label.isNotEmpty) {
        return 'Le serveur a renvoyé une erreur ($status — $label). Veuillez réessayer.';
      }
      return 'Le serveur a renvoyé une erreur ($status). Veuillez réessayer.';
    }

    var text = raw.replaceAll(RegExp(r'<[^>]*>'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.isEmpty ? 'Erreur inconnue' : text;
  }

  String _httpStatusLabel(String status) {
    switch (status) {
      case '400':
        return 'Requête invalide';
      case '401':
        return 'Non autorisé';
      case '403':
        return 'Accès refusé';
      case '404':
        return 'Introuvable';
      case '408':
        return 'Délai d\'attente';
      case '429':
        return 'Trop de requêtes';
      case '500':
        return 'Erreur interne';
      case '502':
        return 'Bad Gateway';
      case '503':
        return 'Service indisponible';
      case '504':
        return 'Délai dépassé';
      default:
        return '';
    }
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

    final rawMessages = json['messages'];
    return Conversation(
      id: id,
      title: title,
      subtitle: subtitle,
      folder: folder,
      isPinned: false,
      agentId: json['agent_id']?.toString(),
      heroAssetLabel: null,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      type: type == 'note'
          ? ConversationType.note
          : type == 'channel'
          ? ConversationType.channel
          : ConversationType.chat,
      messages: rawMessages is List && rawMessages.isNotEmpty
          ? rawMessages
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .map(_mapApiMessage)
                .toList()
          : const [],
    );
  }

  ChatMessage _mapApiMessage(Map<String, dynamic> json) {
    final nestedMessage = _asMap(json['message']);
    final responseMessage = _asMap(json['responseMessage']);
    final id =
        json['id']?.toString() ??
        nestedMessage?['id']?.toString() ??
        responseMessage?['id']?.toString() ??
        json['messageId']?.toString() ??
        DateTime.now().microsecondsSinceEpoch.toString();
    final sender =
        json['sender']?.toString().toLowerCase() ??
        nestedMessage?['sender']?.toString().toLowerCase() ??
        responseMessage?['sender']?.toString().toLowerCase() ??
        json['role']?.toString().toLowerCase() ??
        nestedMessage?['role']?.toString().toLowerCase() ??
        responseMessage?['role']?.toString().toLowerCase() ??
        ((json['isCreatedByUser'] == true ||
                nestedMessage?['isCreatedByUser'] == true)
            ? 'user'
            : null) ??
        'assistant';
    final text = _firstNonEmptyString([
      json['text']?.toString(),
      nestedMessage?['text']?.toString(),
      responseMessage?['text']?.toString(),
      _extractStringOrContent(json['content']),
      _extractStringOrContent(nestedMessage?['content']),
      _extractStringOrContent(responseMessage?['content']),
    ]);
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

  List<dynamic> _extractMessagesList(dynamic jsonBody) {
    if (jsonBody is List<dynamic>) {
      return jsonBody;
    }

    if (jsonBody is! Map<String, dynamic>) {
      return const [];
    }

    final directMessages = jsonBody['messages'];
    if (directMessages is List<dynamic>) {
      return directMessages;
    }

    final history = jsonBody['history'];
    if (history is List<dynamic>) {
      return history;
    }

    final conversation = _asMap(jsonBody['conversation']);
    final nestedMessages = conversation?['messages'];
    if (nestedMessages is List<dynamic>) {
      return nestedMessages;
    }

    final data = jsonBody['data'];
    if (data is List<dynamic>) {
      return data;
    }
    if (data is Map<String, dynamic>) {
      final dataMessages = data['messages'];
      if (dataMessages is List<dynamic>) {
        return dataMessages;
      }
    }

    return const [];
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

/// Flux SSE introuvable (404) : le plus souvent, la réponse est déjà terminée.
class SseStreamNotFoundException implements Exception {
  SseStreamNotFoundException(this.streamId);

  final String streamId;

  @override
  String toString() => 'Exception: Échec de connexion au flux SSE : 404';
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
