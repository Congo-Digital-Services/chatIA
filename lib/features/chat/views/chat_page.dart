import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/auth/providers/auth_state_provider.dart';
import '../../../shared/models/conversation.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/conversation_drawer.dart';
import '../providers/chat_state_provider.dart';
import '../widgets/chat_composer.dart';
import '../widgets/message_bubble.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  bool _isVoiceCallActive = false;
  String? _lastConversationId;
  int _lastMessageCount = 0;
  ProviderSubscription<AuthController>? _authSubscription;
  ProviderSubscription<ChatController>? _chatSubscription;
  String? _lastChatErrorToast;
  String? _lastChatInfoToast;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _authSubscription = ref.listenManual<AuthController>(
      authControllerProvider,
      (previous, next) {
        final previousToken = previous?.session?.accessToken;
        final nextToken = next.session?.accessToken;
        final chatController = ref.read(chatControllerProvider);
        if (nextToken == null || nextToken.isEmpty) {
          chatController.resetForFreshStart();
          return;
        }
        if (nextToken.isNotEmpty && previousToken != nextToken) {
          chatController.resetForFreshStart();
          chatController.loadConversations();
        }
      },
    );
    _chatSubscription = ref.listenManual<ChatController>(
      chatControllerProvider,
      (_, next) {
        final hasNewError =
            next.errorMessage != null &&
            next.errorMessage!.isNotEmpty &&
            _lastChatErrorToast != next.errorMessage;
        if (hasNewError && mounted) {
          _lastChatErrorToast = next.errorMessage;
          showAppToast(
            context,
            message: next.errorMessage!,
            type: AppToastType.error,
          );
          next.clearTransientMessages();
        }

        final hasNewInfo =
            next.infoMessage != null &&
            next.infoMessage!.isNotEmpty &&
            _lastChatInfoToast != next.infoMessage;
        if (hasNewInfo && mounted) {
          _lastChatInfoToast = next.infoMessage;
          showAppToast(
            context,
            message: next.infoMessage!,
            type: AppToastType.success,
          );
          next.clearTransientMessages();
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatController = ref.read(chatControllerProvider);
      chatController.loadConversations();
    });
  }

  @override
  void dispose() {
    _authSubscription?.close();
    _chatSubscription?.close();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    if (position.extentAfter < 240) {
      ref.read(chatControllerProvider).loadMoreSelectedConversationMessages();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final conversation = chat.selectedConversation;
    final messages = conversation.messages;
    final theme = Theme.of(context);

    if (chat.errorMessage == null) {
      _lastChatErrorToast = null;
    }
    if (chat.infoMessage == null) {
      _lastChatInfoToast = null;
    }

    final isNote = conversation.type == ConversationType.note;

    final shouldScrollToBottom =
        conversation.id != _lastConversationId ||
        messages.length > _lastMessageCount;
    _lastConversationId = conversation.id;
    _lastMessageCount = messages.length;
    if (shouldScrollToBottom && !isNote) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: ConduitConversationDrawer(
        onSettingsTap: () => context.push('/settings'),
      ),
      backgroundColor: AppThemeColors.background,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: _TopShellBar(
                    onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
                    onComposeTap: () {
                      if (isNote) {
                        ref.read(chatControllerProvider).createNote();
                        return;
                      }
                      ref.read(chatControllerProvider).createConversation();
                    },
                    isBusy: chat.isLoading || chat.isStreaming,
                  ),
                ),
                Expanded(
                  child: Container(
                    color: AppThemeColors.background,
                    child: Column(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 160),
                          child: chat.isLoading
                              ? Container(
                                  key: const ValueKey('top-progress'),
                                  margin: const EdgeInsets.fromLTRB(
                                    20,
                                    6,
                                    20,
                                    0,
                                  ),
                                  height: 2,
                                  color: AppThemeColors.strokeStrong,
                                )
                              : const SizedBox.shrink(),
                        ),
                        Expanded(
                          child: isNote
                              ? _NoteEditor(
                                  key: ValueKey(conversation.id),
                                  conversation: conversation,
                                )
                              : _ConversationBody(
                                  chat: chat,
                                  conversation: conversation,
                                  theme: theme,
                                  scrollController: _scrollController,
                                  userName: auth.session?.userName ?? 'Sylvia',
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!isNote)
                  ChatComposer(
                    onSend: (value) =>
                        ref.read(chatControllerProvider).sendMessage(value),
                    userName: auth.session?.userName ?? 'Utilisateur',
                    isAwaitingResponse: chat.isAwaitingResponse,
                    isRenderingResponse: chat.isRenderingResponse,
                  ),
              ],
            ),
          ),
          if (_isVoiceCallActive)
            Positioned.fill(
              child: _VoiceCallOverlay(
                onHangUp: () {
                  setState(() {
                    _isVoiceCallActive = false;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _TopShellBar extends StatelessWidget {
  const _TopShellBar({
    required this.onMenuTap,
    required this.onComposeTap,
    required this.isBusy,
  });

  final VoidCallback onMenuTap;
  final VoidCallback onComposeTap;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        _HeaderButton(
          icon: CupertinoIcons.line_horizontal_3,
          onTap: onMenuTap,
          tooltip: 'Menu',
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppThemeColors.backgroundSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppThemeColors.surface,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Image.asset(
                    'assets/icons/congo_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'LoBa IA',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        _HeaderButton(
          icon: CupertinoIcons.square_pencil,
          onTap: onComposeTap,
          tooltip: 'Nouvelle conversation',
        ),
      ],
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.theme, required this.userName});

  final ThemeData theme;
  final String userName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppThemeColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppThemeColors.stroke),
              ),
              child: Image.asset(
                'assets/icons/congo_logo.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Bonjour $userName, que souhaitez-vous créer aujourd\'hui ?',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(height: 1.2),
            ),
            const SizedBox(height: 10),
            Text(
              'Commencez votre message ci-dessous.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppThemeColors.textSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationBody extends StatelessWidget {
  const _ConversationBody({
    required this.chat,
    required this.conversation,
    required this.theme,
    required this.scrollController,
    required this.userName,
  });

  final ChatController chat;
  final Conversation conversation;
  final ThemeData theme;
  final ScrollController scrollController;
  final String userName;

  @override
  Widget build(BuildContext context) {
    if (chat.isSelectedConversationLoading &&
        conversation.messages.isEmpty &&
        !chat.hasLoadedSelectedConversation) {
      return const _ConversationSkeleton();
    }

    if (chat.selectedConversationErrorMessage != null &&
        conversation.messages.isEmpty) {
      return _ConversationErrorState(
        message: chat.selectedConversationErrorMessage!,
      );
    }

    if (conversation.messages.isEmpty) {
      return _EmptyState(theme: theme, userName: userName);
    }

    final itemCount =
        conversation.messages.length +
        (chat.isSelectedConversationLoadingMore ? 1 : 0);

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 120),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index < conversation.messages.length) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: MessageBubble(
              message: conversation.messages[index],
              conversation: conversation,
            ),
          );
        }

        if (chat.isSelectedConversationLoadingMore &&
            index == conversation.messages.length) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppThemeColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppThemeColors.stroke),
                ),
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AppThemeColors.accent,
                ),
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

class _ConversationErrorState extends ConsumerWidget {
  const _ConversationErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final chat = ref.watch(chatControllerProvider);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppThemeColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppThemeColors.stroke),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppThemeColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  CupertinoIcons.exclamationmark_triangle_fill,
                  color: AppThemeColors.danger,
                  size: 24,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Impossible de charger la conversation',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppThemeColors.textSoft,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: chat.isSelectedConversationLoading
                    ? null
                    : () {
                        ref
                            .read(chatControllerProvider)
                            .retrySelectedConversation();
                      },
                child: chat.isSelectedConversationLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bouton header uniforme (44×44) ───────────────────────────────────────────
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.onTap,
    this.tooltip = '',
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: AppThemeColors.backgroundSoft,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 18, color: AppThemeColors.textStrong),
        ),
      ),
    );

    if (tooltip.isEmpty) {
      return button;
    }

    return Tooltip(message: tooltip, excludeFromSemantics: true, child: button);
  }
}

class _ConversationSkeleton extends StatelessWidget {
  const _ConversationSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 12),
      children: const [
        _SkeletonBubble(isUser: false, lines: [180, 220, 140]),
        SizedBox(height: 18),
        _SkeletonBubble(isUser: true, lines: [150]),
        SizedBox(height: 18),
        _SkeletonBubble(isUser: false, lines: [210, 170, 190, 120]),
      ],
    );
  }
}

class _SkeletonBubble extends StatelessWidget {
  const _SkeletonBubble({required this.isUser, required this.lines});

  final bool isUser;
  final List<double> lines;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppThemeColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppThemeColors.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lines
              .map(
                (width) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    width: width,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppThemeColors.pill,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

// ─── Éditeur de note interactif ──────────────────────────────────────────────
class _NoteEditor extends ConsumerStatefulWidget {
  const _NoteEditor({required this.conversation, super.key});

  final Conversation conversation;

  @override
  ConsumerState<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends ConsumerState<_NoteEditor> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final initialText = widget.conversation.messages.isNotEmpty
        ? widget.conversation.messages.first.text
        : '';
    _controller = TextEditingController(text: initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark
              ? AppThemeColors.card
              : AppThemeColors.card.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppThemeColors.stroke),
          boxShadow: AppThemeShadows.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  CupertinoIcons.doc_text,
                  size: 20,
                  color: AppThemeColors.textSoft,
                ),
                const SizedBox(width: 8),
                Text(
                  'Bloc-notes interactif',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppThemeColors.textSoft,
                  ),
                ),
              ],
            ),
            Divider(height: 24, color: AppThemeColors.stroke),
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                decoration: const InputDecoration(
                  hintText:
                      'Écrivez vos notes ici. La première ligne sera le titre...',
                  border: InputBorder.none,
                ),
                onChanged: (text) {
                  ref
                      .read(chatControllerProvider)
                      .updateNoteContent(widget.conversation.id, text);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Écran d'appel vocal IA ──────────────────────────────────────────────────
class _VoiceCallOverlay extends StatefulWidget {
  const _VoiceCallOverlay({required this.onHangUp});

  final VoidCallback onHangUp;

  @override
  State<_VoiceCallOverlay> createState() => _VoiceCallOverlayState();
}

class _VoiceCallOverlayState extends State<_VoiceCallOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  int _callDuration = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _callDuration++;
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F0F1A), Color(0xFF1B1B3A), Color(0xFF0C1033)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    CupertinoIcons.lock_shield_fill,
                    size: 14,
                    color: Colors.white60,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Appel sécurisé Conduit Voice',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white60,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Spacer(),

              // IA pulsing circle representation
              Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glowing wave
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF18B489).withValues(
                              alpha: 0.18 * (2 - _pulseAnimation.value),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 1.0 + (_pulseAnimation.value - 1.0) * 0.5,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF18B489).withValues(
                              alpha: 0.25 * (2 - _pulseAnimation.value),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Inner avatar circle
                  Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF18B489),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 44,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),

              // Title and state
              Text(
                'ChatIA Voice',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _callDuration < 3
                    ? 'Connexion…'
                    : 'À l\'écoute (durée : ${_formatDuration(_callDuration)})',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF18B489),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),

              // Waveform representation
              SizedBox(
                height: 40,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(24, (index) {
                    final double height =
                        4.0 +
                        (index % 4 == 0
                            ? 24.0
                            : index % 3 == 0
                            ? 16.0
                            : 8.0);
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      width: 3,
                      height: _callDuration < 3 ? 4.0 : height,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    );
                  }),
                ),
              ),
              const Spacer(),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Mic Mute Button
                  _CallControlBtn(
                    icon: _isMuted
                        ? CupertinoIcons.mic_slash
                        : CupertinoIcons.mic,
                    active: _isMuted,
                    onTap: () {
                      setState(() {
                        _isMuted = !_isMuted;
                      });
                    },
                    tooltip: 'Couper micro',
                  ),
                  const SizedBox(width: 24),
                  // Hang Up Button (Red, 64x64)
                  GestureDetector(
                    onTap: widget.onHangUp,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEA4335),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        CupertinoIcons.phone_down_fill,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Speaker Button
                  _CallControlBtn(
                    icon: _isSpeakerOn
                        ? CupertinoIcons.volume_up
                        : CupertinoIcons.volume_off,
                    active: !_isSpeakerOn,
                    onTap: () {
                      setState(() {
                        _isSpeakerOn = !_isSpeakerOn;
                      });
                    },
                    tooltip: 'Haut-parleur',
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallControlBtn extends StatelessWidget {
  const _CallControlBtn({
    required this.icon,
    required this.active,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? Colors.white24 : Colors.white10,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );

    if (tooltip.isEmpty) {
      return button;
    }

    return Tooltip(message: tooltip, excludeFromSemantics: true, child: button);
  }
}
