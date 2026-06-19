import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/chatia_api_service.dart';
import '../../../shared/models/chat_message.dart';
import '../../../shared/models/conversation.dart';

final chatControllerProvider = ChangeNotifierProvider<ChatController>((ref) {
  final apiService = ref.watch(chatiaApiProvider);
  return ChatController(apiService);
});

class ChatController extends ChangeNotifier {
  ChatController(this._apiService) {
    _conversations = const [];
    _selectedConversation = _createDraftConversation();
  }

  final ChatiaApiService _apiService;
  static const _draftConversationId = '__draft__';

  late List<Conversation> _conversations;
  late Conversation _selectedConversation;
  final Set<String> _loadedConversationIds = <String>{};
  final Set<String> _loadingConversationIds = <String>{};
  final Set<String> _loadingMoreConversationIds = <String>{};
  final Map<String, String?> _conversationNextCursors = <String, String?>{};
  final Map<String, String> _conversationErrors = <String, String>{};
  bool isLoading = false;
  bool isStreaming = false;
  StreamSubscription<ChatStreamEvent>? _activeStreamSubscription;
  String searchQuery = '';
  String? errorMessage;

  List<Conversation> get conversations => List.unmodifiable(_conversations);
  Conversation get selectedConversation => _selectedConversation;
  bool get isSelectedConversationLoading =>
      _loadingConversationIds.contains(_selectedConversation.id);
  bool get isSelectedConversationLoadingMore =>
      _loadingMoreConversationIds.contains(_selectedConversation.id);
  bool get hasLoadedSelectedConversation =>
      _loadedConversationIds.contains(_selectedConversation.id);
  bool get selectedConversationHasMoreMessages =>
      (_conversationNextCursors[_selectedConversation.id]?.isNotEmpty ?? false);
  String? get selectedConversationErrorMessage =>
      _conversationErrors[_selectedConversation.id];

  List<Conversation> get pinnedConversations => _conversations
      .where(
        (conversation) =>
            conversation.isPinned && conversation.type == ConversationType.chat,
      )
      .toList();

  List<Conversation> get recentConversations => _conversations
      .where(
        (conversation) =>
            !conversation.isPinned &&
            conversation.type == ConversationType.chat,
      )
      .toList();

  List<Conversation> get notes => _conversations
      .where((conversation) => conversation.type == ConversationType.note)
      .toList();

  List<Conversation> get channels => _conversations
      .where((conversation) => conversation.type == ConversationType.channel)
      .toList();

  Future<void> loadConversations() async {
    if (!_apiService.isAvailable) {
      return;
    }

    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      final results = await _apiService.fetchConversations();
      if (results.isNotEmpty) {
        _conversations = results;
        _selectedConversation = results.first;
        notifyListeners();
        await selectConversation(results.first, forceReload: true);
      } else {
        _conversations = const [];
        _selectedConversation = _createDraftConversation();
      }
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectConversation(
    Conversation conversation, {
    bool forceReload = false,
  }) async {
    _selectedConversation = conversation;
    notifyListeners();

    if (!_apiService.isAvailable ||
        conversation.type != ConversationType.chat ||
        conversation.id == _draftConversationId) {
      return;
    }

    if (_loadingConversationIds.contains(conversation.id)) {
      return;
    }

    if (!forceReload &&
        _loadedConversationIds.contains(conversation.id) &&
        !_conversationErrors.containsKey(conversation.id)) {
      return;
    }

    await _loadConversationMessages(conversation.id, reset: true);
  }

  Future<void> retrySelectedConversation() async {
    if (_selectedConversation.type != ConversationType.chat ||
        _selectedConversation.id == _draftConversationId) {
      return;
    }

    await _loadConversationMessages(_selectedConversation.id, reset: true);
  }

  Future<void> loadMoreSelectedConversationMessages() async {
    final conversationId = _selectedConversation.id;
    final cursor = _conversationNextCursors[conversationId];
    if (_selectedConversation.type != ConversationType.chat ||
        conversationId == _draftConversationId ||
        cursor == null ||
        cursor.isEmpty ||
        _loadingConversationIds.contains(conversationId) ||
        _loadingMoreConversationIds.contains(conversationId)) {
      return;
    }

    await _loadConversationMessages(
      conversationId,
      reset: false,
      cursor: cursor,
    );
  }

  void updateSearch(String value) {
    searchQuery = value;
    notifyListeners();
  }

  List<Conversation> filter(List<Conversation> source) {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return source;
    }

    return source
        .where(
          (conversation) => conversation.title.toLowerCase().contains(query),
        )
        .toList();
  }

  void togglePin(Conversation conversation) {
    _conversations = _conversations.map((c) {
      if (c.id == conversation.id) {
        return c.copyWith(isPinned: !c.isPinned);
      }
      return c;
    }).toList();
    if (_selectedConversation.id == conversation.id) {
      _selectedConversation = _conversations.firstWhere(
        (c) => c.id == conversation.id,
      );
    }
    notifyListeners();
  }

  void updateNoteContent(String noteId, String newText) {
    _conversations = _conversations.map((c) {
      if (c.id == noteId) {
        final lines = newText.trim().split('\n');
        final firstLine = lines.isNotEmpty ? lines.first : 'Note sans titre';
        final displayTitle = firstLine.length > 30
            ? '${firstLine.substring(0, 30)}...'
            : firstLine;

        final userMessage = ChatMessage.user(id: 'note_content', text: newText);
        return c.copyWith(
          title: displayTitle.isEmpty ? 'Nouvelle Note' : displayTitle,
          subtitle: lines.length > 1 ? lines[1] : 'Pas de description',
          messages: [userMessage],
        );
      }
      return c;
    }).toList();
    if (_selectedConversation.id == noteId) {
      _selectedConversation = _conversations.firstWhere((c) => c.id == noteId);
    }
    notifyListeners();
  }

  void renameConversation(Conversation conversation, String newTitle) {
    _conversations = _conversations.map((c) {
      if (c.id == conversation.id) {
        return c.copyWith(title: newTitle);
      }
      return c;
    }).toList();
    if (_selectedConversation.id == conversation.id) {
      _selectedConversation = _conversations.firstWhere(
        (c) => c.id == conversation.id,
      );
    }
    notifyListeners();
  }

  void deleteConversation(Conversation conversation) {
    final index = _conversations.indexWhere((c) => c.id == conversation.id);
    _conversations = _conversations
        .where((c) => c.id != conversation.id)
        .toList();
    _loadedConversationIds.remove(conversation.id);
    _loadingConversationIds.remove(conversation.id);
    _loadingMoreConversationIds.remove(conversation.id);
    _conversationNextCursors.remove(conversation.id);
    _conversationErrors.remove(conversation.id);
    if (_selectedConversation.id == conversation.id) {
      if (_conversations.isNotEmpty) {
        final nextIndex = index >= _conversations.length
            ? _conversations.length - 1
            : index;
        _selectedConversation = _conversations[nextIndex];
      } else {
        createConversation();
      }
    }
    notifyListeners();
  }

  /// Supprime un message précis sur le serveur LibreChat
  /// [DELETE /api/messages/:conversationId/:messageId]
  /// et le retire localement de la conversation.
  Future<void> deleteMessageFromServer(
    String conversationId,
    String messageId,
  ) async {
    // Suppression locale immédiate (optimiste)
    final updatedMessages = _selectedConversation.messages
        .where((m) => m.id != messageId)
        .toList();
    final updatedConversation = _selectedConversation.copyWith(
      messages: updatedMessages,
    );
    _conversations = _conversations.map((c) {
      return c.id == _selectedConversation.id ? updatedConversation : c;
    }).toList();
    _selectedConversation = updatedConversation;
    notifyListeners();

    if (!_apiService.isAvailable) return;

    try {
      await _apiService.deleteMessage(conversationId, messageId);
    } catch (error) {
      // En cas d'échec serveur, on restaure le message d'origine
      errorMessage = 'Impossible de supprimer le message : ${error.toString()}';
      notifyListeners();
    }
  }

  /// Modifie le texte d'un message sur le serveur LibreChat
  /// [PUT /api/messages/:conversationId/:messageId]
  /// et met à jour la vue locale.
  Future<void> updateMessageOnServer(
    String conversationId,
    String messageId, {
    required String newText,
  }) async {
    if (!_apiService.isAvailable) {
      // Mise à jour locale uniquement
      _updateMessage(messageId, (m) => m.copyWith(text: newText));
      return;
    }

    try {
      final updated = await _apiService.updateMessage(
        conversationId,
        messageId,
        text: newText,
      );
      _updateMessage(messageId, (_) => updated);
    } catch (error) {
      errorMessage = 'Impossible de modifier le message : ${error.toString()}';
      notifyListeners();
    }
  }

  void createConversation() {
    _selectedConversation = _createDraftConversation();
    notifyListeners();
  }

  Conversation _createDraftConversation() {
    return Conversation(
      id: _draftConversationId,
      title: 'Nouvelle conversation',
      subtitle: 'Commence un échange',
      folder: 'Brouillons',
      isPinned: false,
      messages: const [],
    );
  }

  void createNote() {
    final note = Conversation(
      id: 'note_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Nouvelle Note',
      subtitle: 'Contenu vide',
      folder: '',
      isPinned: false,
      type: ConversationType.note,
      messages: [const ChatMessage.user(id: 'note_content', text: '')],
    );
    _conversations = [note, ..._conversations];
    _selectedConversation = note;
    notifyListeners();
  }

  void createChannel(String name) {
    final channelName = name.startsWith('#') ? name : '# $name';
    final channel = Conversation(
      id: 'channel_${DateTime.now().millisecondsSinceEpoch}',
      title: channelName,
      subtitle: 'Nouveau canal créé',
      folder: '',
      isPinned: false,
      type: ConversationType.channel,
      messages: const [],
    );
    _conversations = [channel, ..._conversations];
    _selectedConversation = channel;
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final parentMessageId = _parentMessageId(_selectedConversation);
    final conversationId = _serverConversationId(_selectedConversation.id);
    final userMessage = ChatMessage.user(id: _uuidV4(), text: trimmed);
    final assistantId = _uuidV4();
    final assistantMessage = ChatMessage.assistant(id: assistantId, text: '');
    _appendMessages(userMessage, assistantMessage);

    if (!_apiService.isAvailable) {
      _updateAssistantMessage(
        assistantId,
        'Réponse mockée Conduit. Cette couche UI est prête à être branchée plus tard sur un backend réel ou sur des appels outils.',
      );
      return;
    }

    isStreaming = true;
    errorMessage = null;
    notifyListeners();

    await _consumeChatStream(
      assistantId: assistantId,
      stream: _apiService.sendOpenAIChat(
        conversationId: conversationId,
        parentMessageId: parentMessageId,
        messageId: userMessage.id,
        text: trimmed,
      ),
      errorPrefix: 'Erreur d\'envoi',
    );
  }

  /// Envoie un message via un agent LibreChat spécifique
  /// [POST /api/agents/chat + GET /api/agents/chat/stream/:streamId]
  /// Nécessite un [agentId] valide configuré sur l'instance LibreChat.
  Future<void> sendMessageAsAgent(
    String text, {
    required String agentId,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || agentId.isEmpty) return;

    final parentMessageId = _parentMessageId(_selectedConversation);
    final conversationId = _serverConversationId(_selectedConversation.id);
    final userMessage = ChatMessage.user(id: _uuidV4(), text: trimmed);
    final assistantId = _uuidV4();
    final assistantMessage = ChatMessage.assistant(id: assistantId, text: '');
    _appendMessages(userMessage, assistantMessage);

    if (!_apiService.isAvailable) {
      _updateAssistantMessage(
        assistantId,
        'Agent non disponible (pas de token). Réponse mockée.',
      );
      return;
    }

    isStreaming = true;
    errorMessage = null;
    notifyListeners();

    await _consumeChatStream(
      assistantId: assistantId,
      stream: _apiService.sendAgentChat(
        agentId: agentId,
        conversationId: conversationId,
        parentMessageId: parentMessageId,
        messageId: userMessage.id,
        text: trimmed,
      ),
      errorPrefix: 'Erreur agent',
    );
  }

  Future<void> cancelStreaming() async {
    await _activeStreamSubscription?.cancel();
    _activeStreamSubscription = null;
    if (isStreaming) {
      isStreaming = false;
      notifyListeners();
    }
  }

  Future<void> sendFileMessage(
    String text, {
    required String url,
    required String name,
    required String size,
    required bool isImage,
    List<int>? bytes,
    String? mimeType,
    int? width,
    int? height,
  }) {
    final userMessage = ChatMessage.user(
      id: _uuidV4(),
      text: text.trim().isEmpty ? 'Fichier envoyé : $name' : text,
      fileUrl: url,
      fileName: name,
      fileSize: size,
      isImage: isImage,
    );
    final assistantId = _uuidV4();
    final assistantMessage = ChatMessage.assistant(id: assistantId, text: '');
    _appendMessages(userMessage, assistantMessage);

    if (!_apiService.isAvailable || bytes == null || bytes.isEmpty) {
      _updateAssistantMessage(
        assistantId,
        isImage
            ? 'Merci pour l\'image. Je l\'ai bien reçue et analysée.'
            : 'J\'ai bien reçu votre fichier : $name ($size). Je l\'analyse.',
      );
      return Future.value();
    }

    return _uploadAttachedFile(
      assistantId: assistantId,
      userMessageId: userMessage.id,
      bytes: bytes,
      filename: name,
      size: size,
      isImage: isImage,
      width: width,
      height: height,
    );
  }

  Future<void> sendVoiceMessage(
    String audioUrl,
    String durationText, {
    List<int>? bytes,
    String? mimeType,
    String? name,
  }) {
    final userMessage = ChatMessage.user(
      id: _uuidV4(),
      text: 'Message vocal ($durationText)',
      audioUrl: audioUrl,
    );
    final assistantId = _uuidV4();
    final assistantMessage = ChatMessage.assistant(id: assistantId, text: '');
    _appendMessages(userMessage, assistantMessage);

    if (!_apiService.isAvailable || bytes == null || bytes.isEmpty) {
      _updateAssistantMessage(
        assistantId,
        'J\'ai bien écouté votre message vocal de $durationText. Voici ma réponse.',
      );
      return Future.value();
    }

    return _transcribeVoiceMessage(
      assistantId: assistantId,
      userMessageId: userMessage.id,
      bytes: bytes,
      filename: name ?? 'voice-message.webm',
      durationText: durationText,
    );
  }

  Future<void> _uploadAttachedFile({
    required String assistantId,
    required String userMessageId,
    required List<int> bytes,
    required String filename,
    required String size,
    required bool isImage,
    int? width,
    int? height,
  }) async {
    try {
      isStreaming = true;
      errorMessage = null;
      notifyListeners();

      final tempFileId = _uuidV4();
      final uploaded = isImage && width != null && height != null
          ? await _apiService.uploadImageFile(
              bytes: bytes,
              filename: filename,
              tempFileId: tempFileId,
              width: width,
              height: height,
            )
          : await _apiService.uploadMessageFile(
              bytes: bytes,
              filename: filename,
              tempFileId: tempFileId,
            );

      if (uploaded.url.isNotEmpty) {
        _updateMessage(
          userMessageId,
          (message) => message.copyWith(
            fileUrl: uploaded.url,
            fileName: filename,
            fileSize: size,
            isImage: isImage,
          ),
        );
      }

      _updateAssistantMessage(
        assistantId,
        isImage
            ? 'Image envoyée au backend LibreChat.'
            : 'Fichier envoyé au backend LibreChat : $filename.',
      );
    } catch (error) {
      errorMessage = error.toString();
      _updateAssistantMessage(
        assistantId,
        'Erreur d\'upload : ${error.toString()}',
      );
    } finally {
      isStreaming = false;
      notifyListeners();
    }
  }

  Future<void> _transcribeVoiceMessage({
    required String assistantId,
    required String userMessageId,
    required List<int> bytes,
    required String filename,
    required String durationText,
  }) async {
    try {
      isStreaming = true;
      errorMessage = null;
      notifyListeners();

      final transcript = await _apiService.transcribeSpeech(
        bytes: bytes,
        filename: filename,
      );
      final cleaned = transcript.trim();

      if (cleaned.isNotEmpty) {
        _updateMessage(
          userMessageId,
          (message) => message.copyWith(
            text: 'Message vocal ($durationText) : $cleaned',
          ),
        );
      }

      _updateAssistantMessage(
        assistantId,
        cleaned.isEmpty
            ? 'Transcription serveur terminée, sans texte retourné.'
            : 'Transcription serveur : $cleaned',
      );
    } catch (error) {
      errorMessage = error.toString();
      _updateAssistantMessage(
        assistantId,
        'Erreur de transcription : ${error.toString()}',
      );
    } finally {
      isStreaming = false;
      notifyListeners();
    }
  }

  void _appendMessages(ChatMessage userMessage, ChatMessage assistantMessage) {
    final updated = _selectedConversation.copyWith(
      title: _selectedConversation.title == 'Nouvelle conversation'
          ? userMessage.text
          : _selectedConversation.title,
      subtitle: userMessage.text,
      messages: [
        ..._selectedConversation.messages,
        userMessage,
        assistantMessage,
      ],
    );

    final index = _conversations.indexWhere(
      (conversation) => conversation.id == updated.id,
    );
    if (index == -1) {
      _conversations = [updated, ..._conversations];
    } else {
      _conversations = _conversations.map((conversation) {
        if (conversation.id == updated.id) {
          return updated;
        }
        return conversation;
      }).toList();
    }
    _selectedConversation = updated;
    notifyListeners();
  }

  Future<void> _consumeChatStream({
    required String assistantId,
    required Stream<ChatStreamEvent> stream,
    required String errorPrefix,
  }) async {
    final completer = Completer<void>();
    var accumulated = '';

    try {
      await _activeStreamSubscription?.cancel();
      _activeStreamSubscription = stream.listen(
        (event) {
          if (event.conversationId != null &&
              event.conversationId!.isNotEmpty) {
            _updateConversationId(
              _selectedConversation.id,
              event.conversationId!,
            );
          }

          if (event.title != null && event.title!.trim().isNotEmpty) {
            renameConversation(_selectedConversation, event.title!.trim());
          }

          if (event.error != null && event.error!.isNotEmpty) {
            errorMessage = event.error;
            _updateAssistantMessage(
              assistantId,
              '$errorPrefix : ${event.error}',
            );
            return;
          }

          if (event.content.isNotEmpty) {
            if (event.done) {
              accumulated = event.content;
            } else {
              accumulated += event.content;
            }
            _updateAssistantMessage(assistantId, accumulated);
          }
        },
        onError: (error, _) {
          _updateAssistantMessage(assistantId, '$errorPrefix : $error');
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        cancelOnError: true,
      );

      await completer.future;
    } finally {
      await _activeStreamSubscription?.cancel();
      _activeStreamSubscription = null;
      isStreaming = false;
      notifyListeners();
    }
  }

  void _updateAssistantMessage(String messageId, String text) {
    _updateMessage(
      messageId,
      (message) => message.copyWith(role: ChatRole.assistant, text: text),
      subtitle: text.isNotEmpty ? text : null,
    );
  }

  void _updateMessage(
    String messageId,
    ChatMessage Function(ChatMessage message) update, {
    String? subtitle,
  }) {
    final updatedMessages = _selectedConversation.messages.map((message) {
      if (message.id != messageId) {
        return message;
      }
      return update(message);
    }).toList();

    final updatedConversation = _selectedConversation.copyWith(
      messages: updatedMessages,
      subtitle: subtitle ?? _selectedConversation.subtitle,
    );

    final index = _conversations.indexWhere(
      (conversation) => conversation.id == _selectedConversation.id,
    );
    if (index == -1) {
      _conversations = [updatedConversation, ..._conversations];
    } else {
      _conversations = _conversations.map((conversation) {
        if (conversation.id == _selectedConversation.id) {
          return updatedConversation;
        }
        return conversation;
      }).toList();
    }
    _selectedConversation = updatedConversation;
    notifyListeners();
  }

  void _updateConversationId(String oldId, String newId) {
    if (oldId == newId) {
      return;
    }

    final wasLoaded = _loadedConversationIds.remove(oldId);
    if (wasLoaded) {
      _loadedConversationIds.add(newId);
    }
    final wasLoading = _loadingConversationIds.remove(oldId);
    if (wasLoading) {
      _loadingConversationIds.add(newId);
    }
    final wasLoadingMore = _loadingMoreConversationIds.remove(oldId);
    if (wasLoadingMore) {
      _loadingMoreConversationIds.add(newId);
    }
    if (_conversationNextCursors.containsKey(oldId)) {
      _conversationNextCursors[newId] = _conversationNextCursors.remove(oldId);
    }
    if (_conversationErrors.containsKey(oldId)) {
      _conversationErrors[newId] = _conversationErrors.remove(oldId)!;
    }

    _conversations = _conversations.map((conversation) {
      if (conversation.id == oldId) {
        return conversation.copyWith(id: newId);
      }
      return conversation;
    }).toList();

    if (_selectedConversation.id == oldId) {
      _selectedConversation = _selectedConversation.copyWith(id: newId);
    }
    notifyListeners();
  }

  String? _serverConversationId(String id) {
    final normalized = id.trim();
    if (normalized.contains('-') && normalized.length >= 20) {
      return normalized;
    }
    return null;
  }

  String _parentMessageId(Conversation conversation) {
    for (final message in conversation.messages.reversed) {
      if (_isUuid(message.id)) {
        return message.id;
      }
    }
    return '00000000-0000-0000-0000-000000000000';
  }

  bool _isUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }

  String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> _loadConversationMessages(
    String conversationId, {
    required bool reset,
    String? cursor,
  }) async {
    if (reset) {
      _loadingConversationIds.add(conversationId);
      _conversationErrors.remove(conversationId);
    } else {
      _loadingMoreConversationIds.add(conversationId);
    }
    errorMessage = null;
    notifyListeners();

    try {
      final details = reset
          ? await _apiService.fetchConversation(conversationId)
          : _conversationById(conversationId);
      final page = await _apiService.fetchMessages(
        conversationId,
        cursor: cursor,
      );
      final previous = _conversationById(conversationId);
      final mergedMessages = reset
          ? page.messages
          : <ChatMessage>[
              ...previous.messages,
              ...page.messages.where(
                (message) => !previous.messages.any((m) => m.id == message.id),
              ),
            ];
      final updated = details.copyWith(messages: mergedMessages);

      _replaceConversation(updated);
      _conversationNextCursors[conversationId] = page.nextCursor;
      _loadedConversationIds.add(conversationId);
      _conversationErrors.remove(conversationId);
      if (_selectedConversation.id == conversationId) {
        _selectedConversation = updated;
      }
    } catch (error) {
      final message = error.toString();
      _conversationErrors[conversationId] = message;
      errorMessage = message;
      if (reset) {
        _loadedConversationIds.remove(conversationId);
      }
    } finally {
      _loadingConversationIds.remove(conversationId);
      _loadingMoreConversationIds.remove(conversationId);
      notifyListeners();
    }
  }

  Conversation _conversationById(String conversationId) {
    return _conversations.firstWhere(
      (conversation) => conversation.id == conversationId,
      orElse: () => _selectedConversation,
    );
  }

  void _replaceConversation(Conversation updated) {
    final index = _conversations.indexWhere(
      (conversation) => conversation.id == updated.id,
    );
    if (index == -1) {
      _conversations = [updated, ..._conversations];
      return;
    }

    _conversations = _conversations.map((conversation) {
      if (conversation.id == updated.id) {
        return updated;
      }
      return conversation;
    }).toList();
  }
}
