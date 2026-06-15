import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../constants/backend_config.dart';
import '../../features/auth/providers/auth_state_provider.dart';
import '../../shared/models/chat_message.dart';
import '../../shared/models/conversation.dart';

final libreChatApiProvider = Provider<LibreChatApiService>((ref) {
  final accessToken = ref.watch(
    authControllerProvider.select((auth) => auth.session?.accessToken),
  );
  return LibreChatApiService(
    baseUrl: BackendConfig.baseUrl,
    accessToken: accessToken,
  );
});

final libreChatConfigProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(libreChatApiProvider).fetchConfig();
});

class LibreChatApiService {
  LibreChatApiService({required this.baseUrl, this.accessToken});

  final String baseUrl;
  final String? accessToken;

  bool get isAvailable => accessToken != null && accessToken!.isNotEmpty;

  Map<String, String> get _baseHeaders {
    final headers = <String, String>{'Accept': 'application/json'};
    if (!kIsWeb) {
      headers['User-Agent'] = BackendConfig.userAgent;
    }
    if (accessToken != null && accessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    return headers;
  }

  Map<String, String> get _jsonHeaders => {
    ..._baseHeaders,
    'Content-Type': 'application/json',
  };

  Uri _uri(String path, [Map<String, String>? queryParameters]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: queryParameters);
  }

  Future<Map<String, dynamic>> fetchConfig() async {
    final uri = _uri('/api/config');
    final response = await http
        .get(uri, headers: _jsonHeaders)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception(
        'Impossible de charger la configuration : ${response.statusCode}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> logout() async {
    final response = await http.post(
      _uri('/api/auth/logout'),
      headers: _jsonHeaders,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Impossible de fermer la session LibreChat : ${response.statusCode}',
      );
    }
  }

  Future<Map<String, dynamic>> refreshAuth() async {
    final response = await http.post(
      _uri('/api/auth/refresh'),
      headers: _jsonHeaders,
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Impossible de rafraichir la session LibreChat : ${response.statusCode}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Conversation>> fetchConversations({
    String sortBy = 'updatedAt',
    String sortDirection = 'desc',
    int pageSize = 10,
  }) async {
    final uri = _uri('/api/convos', {
      'sortBy': sortBy,
      'sortDirection': sortDirection,
      'pageSize': '$pageSize',
    });

    final response = await http.get(uri, headers: _jsonHeaders);
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

  Future<List<ChatMessage>> fetchMessages(String conversationId) async {
    final uri = _uri('/api/messages/$conversationId');
    final response = await http.get(uri, headers: _jsonHeaders);
    if (response.statusCode != 200) {
      throw Exception(
        'Impossible de charger les messages : ${response.statusCode}',
      );
    }

    final jsonBody = jsonDecode(response.body);
    final items = jsonBody is Map<String, dynamic>
        ? (jsonBody['messages'] as List<dynamic>?) ?? []
        : (jsonBody as List<dynamic>);

    return items.cast<Map<String, dynamic>>().map(_mapApiMessage).toList();
  }

  Future<OpenAIChatResponse> startOpenAIChat({
    required String parentMessageId,
    required String messageId,
    required String text,
    String? conversationId,
    String model = 'gpt-4o-mini',
  }) async {
    final uri = _uri('/api/agents/chat/openAI');
    final body = jsonEncode({
      'endpoint': 'openAI',
      'model': model,
      'conversationId': conversationId,
      'parentMessageId': parentMessageId,
      'messageId': messageId,
      'text': text,
    });

    final response = await http.post(uri, headers: _jsonHeaders, body: body);
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

  Future<UploadedFileInfo> uploadImageFile({
    required List<int> bytes,
    required String filename,
    required String tempFileId,
    required int width,
    required int height,
    String endpoint = 'openAI',
  }) async {
    if (width <= 0 || height <= 0) {
      throw Exception('Dimensions image manquantes pour LibreChat.');
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

    final request = http.MultipartRequest('POST', _uri(path));
    request.headers.addAll(_baseHeaders);
    request.fields.addAll(fields);
    request.files.add(
      http.MultipartFile.fromBytes(fileField, bytes, filename: filename),
    );

    final streamedResponse = await request.send();
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
    String model = 'gpt-4o-mini',
  }) async* {
    final startResponse = await startOpenAIChat(
      conversationId: conversationId,
      parentMessageId: parentMessageId,
      messageId: messageId,
      text: text,
      model: model,
    );

    final streamId = startResponse.streamId;
    if (streamId.isEmpty) {
      throw Exception('StreamId manquant depuis le backend.');
    }

    await for (final partial in streamChat(streamId)) {
      yield ChatStreamEvent(
        conversationId: startResponse.conversationId,
        content: partial,
        done: false,
      );
    }

    yield ChatStreamEvent(
      conversationId: startResponse.conversationId,
      content: '',
      done: true,
    );
  }

  Stream<String> streamChat(String streamId) async* {
    final uri = _uri('/api/agents/chat/stream/$streamId');
    final request = http.Request('GET', uri);
    request.headers.addAll(_baseHeaders);
    request.headers['Accept'] = 'text/event-stream';

    final response = await request.send();
    if (response.statusCode != 200) {
      throw Exception(
        'Échec de connexion au flux SSE : ${response.statusCode}',
      );
    }

    final decoded = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    final buffer = StringBuffer();

    await for (final rawLine in decoded) {
      final line = rawLine.trimRight();
      if (line.isEmpty) {
        if (buffer.isNotEmpty) {
          final chunk = _extractSseText(buffer.toString());
          buffer.clear();
          if (chunk.isNotEmpty) {
            yield chunk;
          }
        }
        continue;
      }

      if (line.startsWith('data:')) {
        buffer.write(line.substring(5).trim());
      } else if (line.startsWith('data')) {
        buffer.write(line.substring(4).trim());
      }
    }

    if (buffer.isNotEmpty) {
      final chunk = _extractSseText(buffer.toString());
      if (chunk.isNotEmpty) {
        yield chunk;
      }
    }
  }

  String _extractSseText(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed == '[DONE]' || trimmed.toLowerCase() == 'done') {
      return '';
    }

    try {
      final jsonBody = jsonDecode(trimmed);
      if (jsonBody is Map<String, dynamic>) {
        if (jsonBody.containsKey('delta')) {
          return jsonBody['delta']?.toString() ?? '';
        }
        if (jsonBody.containsKey('text')) {
          return jsonBody['text']?.toString() ?? '';
        }
        if (jsonBody.containsKey('message')) {
          return jsonBody['message']?.toString() ?? '';
        }
      }
    } catch (_) {
      // Not JSON, continue with raw text.
    }

    return trimmed;
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

class ChatStreamEvent {
  ChatStreamEvent({
    required this.conversationId,
    required this.content,
    required this.done,
  });

  final String? conversationId;
  final String content;
  final bool done;
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
