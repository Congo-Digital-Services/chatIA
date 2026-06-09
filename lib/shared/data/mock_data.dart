import '../models/chat_message.dart';
import '../models/conversation.dart';

class MockData {
  static const profileName = 'Utilisateur';
  static const profileEmail = 'utilisateur@conduit.dev';

  static final conversations = [
    Conversation(
      id: '1',
      title: 'Cat Image Generation',
      subtitle: 'Your image of a cat has been generated',
      folder: 'Personnel',
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
    Conversation(
      id: 'n1',
      title: 'Idées de pitch Conduit',
      subtitle: 'Conduit est un framework...',
      folder: '',
      isPinned: true,
      type: ConversationType.note,
      messages: [
        ChatMessage.user(
          id: 'n1_u1',
          text: 'Conduit est un framework mobile révolutionnaire qui accélère le développement UI/UX avec une cohérence parfaite et des micro-animations prêtes à l\'emploi.\n\nPoints clés à présenter :\n- Gain de temps de 40% sur le frontend\n- Composants uniformes pré-stylisés\n- Intégration Keycloak SSO intégrée',
        ),
      ],
    ),
    Conversation(
      id: 'n2',
      title: 'Rappels réunion design',
      subtitle: '- Rendre tous les boutons...',
      folder: '',
      isPinned: false,
      type: ConversationType.note,
      messages: [
        ChatMessage.user(
          id: 'n2_u1',
          text: '- Rendre tous les boutons uniformes (44px)\n- Ajuster la taille des polices selon l\'appareil\n- Rendre les dossiers interactifs et pliables\n- Nettoyer le design de la barre de recherche',
        ),
      ],
    ),
    Conversation(
      id: 'c1',
      title: '# général',
      subtitle: 'Salon de discussion principal',
      folder: '',
      isPinned: true,
      type: ConversationType.channel,
      messages: [
        ChatMessage.user(
          id: 'c1_u1',
          text: 'Bonjour tout le monde ! Bienvenue dans le canal général de discussion.',
        ),
        ChatMessage.assistant(
          id: 'c1_a1',
          text: 'Bonjour ! Je suis l\'assistant IA de Conduit. Comment puis-je vous aider aujourd\'hui ?',
        ),
      ],
    ),
    Conversation(
      id: 'c2',
      title: '# design-système',
      subtitle: 'Règles et guides UI',
      folder: '',
      isPinned: false,
      type: ConversationType.channel,
      messages: [
        ChatMessage.user(
          id: 'c2_u1',
          text: 'Quelles sont les dimensions recommandées pour les boutons dans notre charte ?',
        ),
        ChatMessage.assistant(
          id: 'c2_a1',
          text: 'La dimension standard est de 44x44 pixels pour assurer une excellente accessibilité tactile (normes d\'accessibilité mobiles).',
        ),
      ],
    ),
  ];
}
