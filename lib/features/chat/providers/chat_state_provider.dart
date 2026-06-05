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

  List<Conversation> get pinnedConversations =>
      _conversations.where((conversation) => conversation.isPinned).toList();

  List<Conversation> get recentConversations => _conversations
      .where((conversation) => !conversation.isPinned)
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
        .where((conversation) => conversation.title.toLowerCase().contains(query))
        .toList();
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

  void sendMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final userMessage = ChatMessage.user(
      id: 'u_${DateTime.now().microsecondsSinceEpoch}',
      text: trimmed,
    );
    final assistantMessage = ChatMessage.assistant(
      id: 'a_${DateTime.now().microsecondsSinceEpoch}',
      text:
          'Réponse mockée Conduit. Cette couche UI est prête à être branchée plus tard sur un backend réel ou sur des appels outils.',
    );

    final updated = _selectedConversation.copyWith(
      title: _selectedConversation.title == 'Nouvelle conversation'
          ? trimmed
          : _selectedConversation.title,
      subtitle: trimmed,
      messages: [..._selectedConversation.messages, userMessage, assistantMessage],
    );

    _conversations = _conversations
        .map((conversation) => conversation.id == updated.id ? updated : conversation)
        .toList();
    _selectedConversation = updated;
    notifyListeners();
  }
}
