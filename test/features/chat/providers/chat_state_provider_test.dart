import 'package:chatia/core/services/chatia_api_service.dart';
import 'package:chatia/core/services/librechat_session_service.dart';
import 'package:chatia/core/services/token_storage_service.dart';
import 'package:chatia/features/chat/providers/chat_state_provider.dart';
import 'package:chatia/shared/models/auth_session.dart';
import 'package:chatia/shared/models/chat_message.dart';
import 'package:chatia/shared/models/conversation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test(
    'loadConversations keeps a fresh draft selected while loading history',
    () async {
      final service = _FakeChatiaApiService(
        conversations: [
          _conversation('convo-1', title: 'Conversation 1'),
          _conversation('convo-2', title: 'Conversation 2'),
        ],
        conversationDetails: {
          'convo-1': _conversation('convo-1', title: 'Conversation 1 detail'),
          'convo-2': _conversation('convo-2', title: 'Conversation 2 detail'),
        },
        messagePages: {
          'convo-1': [
            const PaginatedMessagesResponse(
              messages: [
                ChatMessage.user(id: 'm1', text: 'Bonjour'),
                ChatMessage.assistant(id: 'm2', text: 'Salut'),
              ],
              nextCursor: 'cursor-2',
            ),
          ],
        },
      );
      final controller = ChatController(service);

      await controller.loadConversations();

      expect(controller.selectedConversation.id, '__draft__');
      expect(controller.selectedConversation.messages, isEmpty);
      expect(controller.conversations.map((conversation) => conversation.id), [
        'convo-1',
        'convo-2',
      ]);
      expect(service.fetchConversationCalls, isEmpty);
      expect(service.fetchMessagesCalls, isEmpty);
    },
  );

  test('selectConversation loads clicked conversation content', () async {
    final service = _FakeChatiaApiService(
      conversations: [
        _conversation('convo-1', title: 'Conversation 1'),
        _conversation('convo-2', title: 'Conversation 2'),
      ],
      conversationDetails: {
        'convo-1': _conversation('convo-1', title: 'Conversation 1 detail'),
        'convo-2': _conversation('convo-2', title: 'Conversation 2 detail'),
      },
      messagePages: {
        'convo-1': [
          const PaginatedMessagesResponse(
            messages: [ChatMessage.user(id: 'm1', text: 'Bonjour')],
            nextCursor: null,
          ),
        ],
        'convo-2': [
          const PaginatedMessagesResponse(
            messages: [ChatMessage.assistant(id: 'm2', text: 'Reponse 2')],
            nextCursor: null,
          ),
        ],
      },
    );
      final controller = ChatController(service);

      await controller.loadConversations();
      await controller.selectConversation(controller.conversations[1]);

      expect(controller.selectedConversation.id, 'convo-2');
      expect(controller.selectedConversation.messages.single.text, 'Reponse 2');
      expect(service.fetchConversationCalls, ['convo-2']);
      expect(service.fetchMessagesCalls, [('convo-2', null)]);
  });

  test(
    'loadMoreSelectedConversationMessages appends next page and stops at null cursor',
    () async {
      final service = _FakeChatiaApiService(
        conversations: [_conversation('convo-1', title: 'Conversation 1')],
        conversationDetails: {
          'convo-1': _conversation('convo-1', title: 'Conversation 1 detail'),
        },
        messagePages: {
          'convo-1': [
            const PaginatedMessagesResponse(
              messages: [ChatMessage.user(id: 'm1', text: 'Page 1')],
              nextCursor: 'cursor-2',
            ),
            const PaginatedMessagesResponse(
              messages: [ChatMessage.assistant(id: 'm2', text: 'Page 2')],
              nextCursor: null,
            ),
          ],
        },
      );
      final controller = ChatController(service);

      await controller.loadConversations();
      await controller.selectConversation(controller.conversations.first);
      await controller.loadMoreSelectedConversationMessages();
      await controller.loadMoreSelectedConversationMessages();

      expect(
        controller.selectedConversation.messages.map((message) => message.text),
        ['Page 1', 'Page 2'],
      );
      expect(controller.selectedConversationHasMoreMessages, isFalse);
      expect(service.fetchMessagesCalls, [
        ('convo-1', null),
        ('convo-1', 'cursor-2'),
      ]);
    },
  );

  test(
    'selectConversation exposes error state when messages fail to load',
    () async {
      final service = _FakeChatiaApiService(
        conversations: [_conversation('convo-404', title: 'Conversation HS')],
        conversationDetails: {
          'convo-404': _conversation('convo-404', title: 'Conversation HS'),
        },
        messagePages: const {},
        messageErrors: {'convo-404': Exception('404 not found')},
      );
      final controller = ChatController(service);

      await controller.loadConversations();
      await controller.selectConversation(controller.conversations.first);

      expect(controller.selectedConversation.id, 'convo-404');
      expect(controller.selectedConversation.messages, isEmpty);
      expect(
        controller.selectedConversationErrorMessage,
        contains('404 not found'),
      );
      expect(controller.hasLoadedSelectedConversation, isFalse);
    },
  );

  test(
    'loadConversations hides empty backend placeholders but keeps real history',
    () async {
      final service = _FakeChatiaApiService(
        conversations: [
          _conversation('empty-new-chat', title: 'New Chat'),
          _conversation('filled-new-chat', title: 'New Chat'),
          _conversation('named-chat', title: 'Projet API'),
        ],
        conversationDetails: {
          'filled-new-chat': _conversation(
            'filled-new-chat',
            title: 'New Chat detail',
          ),
          'named-chat': _conversation('named-chat', title: 'Projet API detail'),
        },
        messagePages: {
          'filled-new-chat': [
            const PaginatedMessagesResponse(
              messages: [
                ChatMessage.user(id: 'm1', text: 'Bonjour'),
                ChatMessage.user(
                  id: 'm2',
                  text: 'Configurer la connexion a l API LibreChat',
                ),
              ],
              nextCursor: null,
            ),
          ],
          'named-chat': [
            const PaginatedMessagesResponse(
              messages: [ChatMessage.assistant(id: 'm2', text: 'Salut')],
              nextCursor: null,
            ),
          ],
        },
      );
      final controller = ChatController(service);

      await controller.loadConversations();

      expect(
        controller.conversations.map((conversation) => conversation.id),
        ['filled-new-chat', 'named-chat'],
      );
      expect(
        controller.conversations.first.title,
        'Configurer la connexion a l API LibreChat',
      );
      expect(controller.selectedConversation.id, '__draft__');
      expect(service.fetchMessagesCalls, [
        ('empty-new-chat', null),
        ('filled-new-chat', null),
      ]);
    },
  );
}

class _FakeChatiaApiService extends ChatiaApiService {
  _FakeChatiaApiService({
    required this.conversations,
    required this.conversationDetails,
    required this.messagePages,
    this.messageErrors = const {},
  }) : super(
         baseUrl: 'http://localhost:3081',
         sessionService: _buildSessionService(),
       );

  final List<Conversation> conversations;
  final Map<String, Conversation> conversationDetails;
  final Map<String, List<PaginatedMessagesResponse>> messagePages;
  final Map<String, Object> messageErrors;

  final List<String> fetchConversationCalls = <String>[];
  final List<(String, String?)> fetchMessagesCalls = <(String, String?)>[];
  final Map<String, int> _pageIndexes = <String, int>{};

  @override
  bool get isAvailable => true;

  @override
  Future<List<Conversation>> fetchConversations({
    String sortBy = 'updatedAt',
    String sortDirection = 'desc',
    int limit = 25,
    String? cursor,
    String? search,
  }) async {
    return conversations;
  }

  @override
  Future<Conversation> fetchConversation(String conversationId) async {
    fetchConversationCalls.add(conversationId);
    final conversation = conversationDetails[conversationId];
    if (conversation == null) {
      throw Exception('Conversation introuvable: $conversationId');
    }
    return conversation;
  }

  @override
  Future<PaginatedMessagesResponse> fetchMessages(
    String conversationId, {
    int pageSize = 25,
    String? cursor,
  }) async {
    fetchMessagesCalls.add((conversationId, cursor));

    final error = messageErrors[conversationId];
    if (error != null) {
      throw error;
    }

    final pages = messagePages[conversationId] ?? const [];
    final index = _pageIndexes[conversationId] ?? 0;
    if (index >= pages.length) {
      return const PaginatedMessagesResponse(messages: [], nextCursor: null);
    }

    _pageIndexes[conversationId] = index + 1;
    return pages[index];
  }
}

Conversation _conversation(String id, {required String title}) {
  return Conversation(
    id: id,
    title: title,
    subtitle: '',
    folder: '',
    isPinned: false,
    messages: const [],
  );
}

LibreChatSessionService _buildSessionService() {
  return LibreChatSessionService(
    storage: _MemoryTokenStorageService(),
    baseUrl: 'http://localhost:3081',
    mobileAuthExchangeKey: 'test-key',
    userAgent: 'chatia-test',
    clientFactory: () => http.Client(),
  )..hydrateSession(
    AuthSession(
      accessToken: 'access',
      refreshToken: 'refresh',
      idToken: null,
      userName: 'Tester',
      email: 'tester@example.com',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      isMock: false,
      provider: AuthSessionProvider.librechat,
    ),
  );
}

class _MemoryTokenStorageService extends TokenStorageService {
  _MemoryTokenStorageService();

  AuthSession? _session;

  @override
  Future<void> saveSession(AuthSession session) async {
    _session = session;
  }

  @override
  Future<AuthSession?> readSession() async => _session;

  @override
  Future<void> clear() async {
    _session = null;
  }
}
