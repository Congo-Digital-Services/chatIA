import '../models/chat_message.dart';
import '../models/conversation.dart';

class MockData {
  static const profileName = 'cogwheel';
  static const profileEmail = 'cogwheel@conduit.dev';

  static final conversations = [
    Conversation(
      id: '1',
      title: 'Cat Image Generation',
      subtitle: 'Your image of a cat has been generated',
      folder: 'cogwheel0',
      isPinned: true,
      heroAssetLabel: 'cat',
      messages: [
        ChatMessage.user(id: '1_u', text: 'Image of a cat'),
        ChatMessage.assistant(
          id: '1_a',
          text: 'Your image of a cat has been generated and is now displayed above.',
        ),
      ],
    ),
    Conversation(
      id: '2',
      title: 'Friendly Greeting Exchange',
      subtitle: 'Warm intro and exchange',
      folder: 'Pinned',
      isPinned: true,
      messages: [
        ChatMessage.user(id: '2_u', text: 'Say hello in a warm tone'),
        ChatMessage.assistant(
          id: '2_a',
          text: 'Hello there. I can help structure the Conduit mobile interface, its states, and the navigation patterns.',
        ),
      ],
    ),
    Conversation(
      id: '3',
      title: 'Cow Facts and Poetry',
      subtitle: 'Short factual poem',
      folder: 'Test',
      isPinned: true,
      messages: [
        ChatMessage.user(id: '3_u', text: 'Écris un poème sur les vaches'),
        ChatMessage.assistant(
          id: '3_a',
          text: 'Sous la lumière douce du matin, la prairie prend une voix lente...',
        ),
      ],
    ),
    Conversation(
      id: '4',
      title: 'Friendly Greeting Exchange',
      subtitle: 'Recent pinned clone',
      folder: 'Recent',
      isPinned: false,
      messages: const [],
    ),
    Conversation(
      id: '5',
      title: 'Echoes of the Void',
      subtitle: 'Science fiction ideation',
      folder: 'Recent',
      isPinned: false,
      messages: const [],
    ),
    Conversation(
      id: '6',
      title: 'Quick UI audit',
      subtitle: 'Layout review',
      folder: 'Recent',
      isPinned: false,
      messages: const [],
    ),
    Conversation(
      id: '7',
      title: 'Lighthouse Melody Story',
      subtitle: 'Atmospheric story prompt',
      folder: 'Recent',
      isPinned: false,
      messages: const [],
    ),
  ];
}
