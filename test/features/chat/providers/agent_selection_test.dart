import 'package:chatia/core/constants/backend_config.dart';
import 'package:chatia/core/services/chatia_api_service.dart';
import 'package:chatia/core/services/librechat_session_service.dart';
import 'package:chatia/core/services/token_storage_service.dart';
import 'package:chatia/features/chat/providers/chat_state_provider.dart';
import 'package:chatia/shared/models/agent_option.dart';
import 'package:chatia/shared/models/auth_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Extrait de `/api/config` tel que renvoyé par LoBAI (session authentifiée).
const _config = <String, dynamic>{
  'modelSpecs': {
    'enforce': true,
    'list': [
      {
        'name': 'assistant-global',
        'label': 'Assistant',
        'default': true,
        'preset': {'endpoint': 'agents', 'agent_id': 'agent_loba'},
      },
      {
        'name': 'maloba-passerelle',
        'label': 'MALOBA Passerelle',
        'description': 'Image ou voix → texte reconnu → traduction.',
        'preset': {'endpoint': 'agents', 'agent_id': 'agent_passerelle'},
      },
      {
        'name': 'sans-agent',
        'label': 'Entrée sans agent',
        'preset': {'endpoint': 'openAI', 'model': 'gpt'},
      },
      {
        'name': 'maloba-traduction',
        'preset': {'endpoint': 'agents', 'agent_id': 'agent_trad'},
      },
    ],
  },
};

void main() {
  group('AgentOption.fromConfig', () {
    test('lit les entrées qui pointent vers un agent, dans l’ordre', () {
      final options = AgentOption.fromConfig(_config);

      expect(options.map((o) => o.specName), [
        'assistant-global',
        'maloba-passerelle',
        'maloba-traduction',
      ]);
      expect(options.first.isDefault, isTrue);
      expect(options[1].agentId, 'agent_passerelle');
      expect(options[1].description, startsWith('Image ou voix'));
      // Sans libellé, le nom de la spec sert de libellé.
      expect(options[2].label, 'maloba-traduction');
    });

    test('revient à l’agent historique sans modelSpecs exploitables', () {
      for (final config in <Map<String, dynamic>?>[
        null,
        {},
        {
          'modelSpecs': {'list': []},
        },
        {'modelSpecs': 'inattendu'},
      ]) {
        final options = AgentOption.fromConfig(config);
        expect(options, hasLength(1));
        expect(options.single.agentId, BackendConfig.chatAgentId);
        expect(options.single.specName, BackendConfig.chatSpec);
      }
    });
  });

  group('ChatController — agent actif', () {
    test(
      'sans configuration chargée, garde l’agent et la spec historiques',
      () async {
        final service = _FakeApi();
        final controller = ChatController(service);

        await controller.sendMessage('Mbote');

        expect(service.sent.single, (
          BackendConfig.chatAgentId,
          BackendConfig.chatSpec,
        ));
      },
    );

    test('charge les agents et choisit l’entrée par défaut', () async {
      final service = _FakeApi(config: _config);
      final controller = ChatController(service);

      await controller.loadAgentOptions();

      expect(controller.agentOptions, hasLength(3));
      expect(controller.activeAgent.agentId, 'agent_loba');
    });

    test('un agent choisi envoie SON couple agent / spec', () async {
      final service = _FakeApi(config: _config);
      final controller = ChatController(service);
      await controller.loadAgentOptions();

      controller.selectAgent(controller.agentOptions[1]);
      await controller.sendMessage('[pas de traduction] Mbote');

      expect(controller.activeAgent.specName, 'maloba-passerelle');
      expect(service.sent.single, ('agent_passerelle', 'maloba-passerelle'));
    });

    test('une configuration illisible laisse l’agent historique', () async {
      final service = _FakeApi(configError: Exception('HTTP 500'));
      final controller = ChatController(service);

      await controller.loadAgentOptions();

      expect(controller.agentOptions.single.agentId, BackendConfig.chatAgentId);
      expect(controller.activeAgent.agentId, BackendConfig.chatAgentId);
    });
  });

  group('ChatController.transcribeVoice', () {
    test(
      'refuse un enregistrement quasi vide sans appeler le serveur',
      () async {
        final service = _FakeApi();
        final controller = ChatController(service);

        await expectLater(
          controller.transcribeVoice(
            bytes: List.filled(1243, 0),
            filename: 'a.webm',
          ),
          throwsA(isA<VoiceTranscriptionException>()),
        );
        expect(service.transcriptionCalls, 0);
      },
    );

    test('rend le texte reconnu sans rien envoyer', () async {
      final service = _FakeApi(transcript: '  Mbote na bino  ');
      final controller = ChatController(service);

      final text = await controller.transcribeVoice(
        bytes: List.filled(ChatController.minVoiceBytes, 1),
        filename: 'a.webm',
      );

      expect(text, 'Mbote na bino');
      expect(service.sent, isEmpty);
    });

    test('traduit une panne du modèle vocal en message clair', () async {
      final service = _FakeApi(
        transcriptionError: Exception(
          'Echec API /api/files/speech/stt : 429 {"error":"No deployments available"}',
        ),
      );
      final controller = ChatController(service);

      await expectLater(
        controller.transcribeVoice(
          bytes: List.filled(ChatController.minVoiceBytes, 1),
          filename: 'a.webm',
        ),
        throwsA(
          isA<VoiceTranscriptionException>().having(
            (e) => e.message,
            'message',
            contains('indisponible'),
          ),
        ),
      );
    });
  });

  group('translateText', () {
    test('passe par l’agent Traduction, en conversation temporaire', () async {
      final service = _FakeApi(config: _config, reply: ' Bonjour à tous ');
      final controller = ChatController(service);
      await controller.loadAgentOptions();

      final fr = await controller.translateText('Mbote na bino');

      expect(fr, 'Bonjour à tous');
      expect(service.sent.single, ('agent_trad', 'maloba-traduction'));
      expect(service.sentTexts.single, '[ln→fr] Mbote na bino');
      expect(service.temporaryFlags.single, isTrue);
    });

    test('sens fr → ln, et agent par défaut sans configuration', () async {
      final service = _FakeApi(reply: 'Mbote');
      final controller = ChatController(service);

      await controller.translateText('Bonjour', lingalaToFrench: false);

      expect(service.sent.single, (
        BackendConfig.translationAgentId,
        BackendConfig.translationSpec,
      ));
      expect(service.sentTexts.single, '[fr→ln] Bonjour');
    });

    test('n’appelle pas le serveur pour un texte vide', () async {
      final service = _FakeApi(reply: 'x');
      final controller = ChatController(service);

      expect(await controller.translateText('   '), '');
      expect(service.sent, isEmpty);
    });
  });

  test('describeVoiceError distingue session, taille et panne', () {
    String d(String s) => ChatController.describeVoiceError(Exception(s));
    expect(
      d('Echec API /api/files/speech/stt : 401 x'),
      contains('Session expirée'),
    );
    expect(d('Echec API /api/files/speech/stt : 413 x'), contains('trop long'));
    expect(
      d('Echec API /api/files/speech/stt : 502 x'),
      contains('indisponible'),
    );
    expect(d('Réseau coupé'), 'Réseau coupé');
  });
}

class _FakeApi extends ChatiaApiService {
  _FakeApi({
    this.config,
    this.configError,
    this.transcript = 'texte',
    this.transcriptionError,
    this.reply,
  }) : super(baseUrl: 'http://localhost:3081', sessionService: _session());

  final Map<String, dynamic>? config;
  final Object? configError;
  final String transcript;
  final Object? transcriptionError;
  final String? reply;

  final List<(String, String)> sent = [];
  final List<String> sentTexts = [];
  final List<bool> temporaryFlags = [];
  int transcriptionCalls = 0;

  @override
  bool get isAvailable => true;

  @override
  Future<Map<String, dynamic>> fetchConfig() async {
    if (configError != null) throw configError!;
    return config ?? const {};
  }

  @override
  Future<String> transcribeSpeech({
    required List<int> bytes,
    required String filename,
  }) async {
    transcriptionCalls++;
    if (transcriptionError != null) throw transcriptionError!;
    return transcript;
  }

  @override
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
    sent.add((agentId, spec));
    sentTexts.add(text);
    temporaryFlags.add(isTemporary);
    if (reply != null) {
      yield ChatStreamEvent(
        conversationId: 'convo-temp',
        content: reply!,
        done: true,
        event: 'final',
      );
    }
  }
}

LibreChatSessionService _session() {
  return LibreChatSessionService(
    storage: _MemoryStorage(),
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

class _MemoryStorage extends TokenStorageService {
  AuthSession? _session;

  @override
  Future<void> saveSession(AuthSession session) async => _session = session;

  @override
  Future<AuthSession?> readSession() async => _session;

  @override
  Future<void> clear() async => _session = null;
}
