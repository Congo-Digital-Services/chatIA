import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/mock_data.dart';
import '../../../shared/models/chat_message.dart';
import '../../../shared/models/conversation.dart';

final chatControllerProvider = ChangeNotifierProvider<ChatController>((ref) {
  return ChatController();
});

class ChatController extends ChangeNotifier {
  ChatController() {
    _conversations = MockData.conversations;
    _selectedConversation = _conversations.first;
  }

  late List<Conversation> _conversations;
  late Conversation _selectedConversation;
  String searchQuery = '';

  List<Conversation> get conversations => List.unmodifiable(_conversations);
  Conversation get selectedConversation => _selectedConversation;

  List<Conversation> get pinnedConversations => _conversations
      .where((conversation) =>
          conversation.isPinned && conversation.type == ConversationType.chat)
      .toList();

  List<Conversation> get recentConversations => _conversations
      .where((conversation) =>
          !conversation.isPinned && conversation.type == ConversationType.chat)
      .toList();

  List<Conversation> get notes => _conversations
      .where((conversation) => conversation.type == ConversationType.note)
      .toList();

  List<Conversation> get channels => _conversations
      .where((conversation) => conversation.type == ConversationType.channel)
      .toList();

  void selectConversation(Conversation conversation) {
    _selectedConversation = conversation;
    notifyListeners();
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
        .where((conversation) =>
            conversation.title.toLowerCase().contains(query))
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
      _selectedConversation =
          _conversations.firstWhere((c) => c.id == conversation.id);
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

        final userMessage = ChatMessage.user(
          id: 'note_content',
          text: newText,
        );
        return c.copyWith(
          title: displayTitle.isEmpty ? 'Nouvelle Note' : displayTitle,
          subtitle: lines.length > 1 ? lines[1] : 'Pas de description',
          messages: [userMessage],
        );
      }
      return c;
    }).toList();
    if (_selectedConversation.id == noteId) {
      _selectedConversation =
          _conversations.firstWhere((c) => c.id == noteId);
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
      _selectedConversation =
          _conversations.firstWhere((c) => c.id == conversation.id);
    }
    notifyListeners();
  }

  void deleteConversation(Conversation conversation) {
    final index = _conversations.indexWhere((c) => c.id == conversation.id);
    _conversations =
        _conversations.where((c) => c.id != conversation.id).toList();
    if (_selectedConversation.id == conversation.id) {
      if (_conversations.isNotEmpty) {
        final nextIndex =
            index >= _conversations.length ? _conversations.length - 1 : index;
        _selectedConversation = _conversations[nextIndex];
      } else {
        createConversation();
      }
    }
    notifyListeners();
  }

  void createConversation() {
    final conversation = Conversation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Nouvelle conversation',
      subtitle: 'Commence un échange',
      folder: 'Brouillons',
      isPinned: false,
      messages: const [],
    );
    _conversations = [conversation, ..._conversations];
    _selectedConversation = conversation;
    notifyListeners();
  }

  void createNote() {
    final note = Conversation(
      id: 'note_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Nouvelle Note',
      subtitle: 'Contenu vide',
      folder: '',
      isPinned: false,
      type: ConversationType.note,
      messages: [
        const ChatMessage.user(id: 'note_content', text: ''),
      ],
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

  void sendMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final userMessage = ChatMessage.user(
      id: 'u_${DateTime.now().microsecondsSinceEpoch}',
      text: trimmed,
    );
    
    // For channels, we want to simulate some messages from other users/AI
    final isChannel = _selectedConversation.type == ConversationType.channel;
    final assistantText = isChannel
        ? 'Réponse simulée dans ${_selectedConversation.title}. Les autres membres peuvent lire vos messages.'
        : 'Réponse mockée Conduit. Cette couche UI est prête à être branchée plus tard sur un backend réel ou sur des appels outils.';

    final assistantMessage = ChatMessage.assistant(
      id: 'a_${DateTime.now().microsecondsSinceEpoch}',
      text: assistantText,
    );

    _appendMessages(userMessage, assistantMessage);
  }

  void sendFileMessage(String text, {
    required String url,
    required String name,
    required String size,
    required bool isImage,
  }) {
    final userMessage = ChatMessage.user(
      id: 'u_${DateTime.now().microsecondsSinceEpoch}',
      text: text.trim().isEmpty ? 'Fichier envoyé : $name' : text,
      fileUrl: url,
      fileName: name,
      fileSize: size,
      isImage: isImage,
    );
    final assistantMessage = ChatMessage.assistant(
      id: 'a_${DateTime.now().microsecondsSinceEpoch}',
      text: isImage 
          ? 'Merci pour l\'image. Je l\'ai bien reçue et analysée.' 
          : 'J\'ai bien reçu votre fichier : $name ($size). Je l\'analyse.',
    );
    _appendMessages(userMessage, assistantMessage);
  }

  void sendVoiceMessage(String audioUrl, String durationText) {
    final userMessage = ChatMessage.user(
      id: 'u_${DateTime.now().microsecondsSinceEpoch}',
      text: 'Message vocal ($durationText)',
      audioUrl: audioUrl,
    );
    final assistantMessage = ChatMessage.assistant(
      id: 'a_${DateTime.now().microsecondsSinceEpoch}',
      text: 'J\'ai bien écouté votre message vocal de $durationText. Voici ma réponse.',
    );
    _appendMessages(userMessage, assistantMessage);
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
        assistantMessage
      ],
    );

    _conversations = _conversations
        .map((conversation) =>
            conversation.id == updated.id ? updated : conversation)
        .toList();
    _selectedConversation = updated;
    notifyListeners();
  }
}
