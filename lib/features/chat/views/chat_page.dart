import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/auth/providers/auth_state_provider.dart';
import '../../../shared/models/conversation.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/conduit_card.dart';
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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatControllerProvider).loadConversations();
    });
  }

  @override
  void dispose() {
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
                // ── Header ──────────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: Row(
                    children: [
                      // Menu
                      _HeaderButton(
                        icon: CupertinoIcons.line_horizontal_3,
                        onTap: () => _scaffoldKey.currentState?.openDrawer(),
                        tooltip: 'Menu',
                      ),
                      const SizedBox(width: 10),
                      const Spacer(),
                      const SizedBox(width: 10),
                      // Nouvelle conversation / note
                      _HeaderButton(
                        icon: isNote
                            ? CupertinoIcons.doc_append
                            : CupertinoIcons.square_pencil,
                        onTap: () {
                          if (isNote) {
                            ref.read(chatControllerProvider).createNote();
                          } else {
                            ref
                                .read(chatControllerProvider)
                                .createConversation();
                          }
                        },
                        tooltip: isNote
                            ? 'Nouvelle note'
                            : 'Nouvelle conversation',
                      ),
                    ],
                  ),
                ),
                // ── Corps ────────────────────────────────────────────────────────
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
                        ),
                ),
                // ── Composer ─────────────────────────────────────────────────────
                if (!isNote)
                  ChatComposer(
                    onSend: (value) =>
                        ref.read(chatControllerProvider).sendMessage(value),
                    userName: auth.session?.userName ?? 'Utilisateur',
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

// ── État vide ────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppThemeColors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppThemeColors.stroke),
              ),
              child: Icon(
                CupertinoIcons.chat_bubble_2,
                color: AppThemeColors.textMuted,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Nouvelle conversation',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineLarge?.copyWith(
                fontSize: 28,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Aucun historique local. Envoyez un premier message pour démarrer.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppThemeColors.textSoft,
                height: 1.5,
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
  });

  final ChatController chat;
  final Conversation conversation;
  final ThemeData theme;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (chat.isSelectedConversationLoading &&
        conversation.messages.isEmpty &&
        !chat.hasLoadedSelectedConversation) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (chat.selectedConversationErrorMessage != null &&
        conversation.messages.isEmpty) {
      return _ConversationErrorState(
        message: chat.selectedConversationErrorMessage!,
      );
    }

    if (conversation.messages.isEmpty) {
      return _EmptyState(theme: theme);
    }

    final itemCount =
        conversation.messages.length +
        (conversation.heroAssetLabel != null ? 1 : 0) +
        (chat.isSelectedConversationLoadingMore ? 1 : 0);

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index < conversation.messages.length) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: MessageBubble(
              message: conversation.messages[index],
              conversation: conversation,
            ),
          );
        }

        if (chat.isSelectedConversationLoadingMore &&
            index == conversation.messages.length) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Center(child: CircularProgressIndicator.adaptive()),
          );
        }

        return Column(
          children: [
            _HeroCard(theme: theme),
            const SizedBox(height: 12),
            const _InlineActionRow(),
            const SizedBox(height: 24),
          ],
        );
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle,
              color: AppThemeColors.textMuted,
              size: 32,
            ),
            const SizedBox(height: 14),
            Text(
              'Impossible de charger la conversation',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppThemeColors.textSoft,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                ref.read(chatControllerProvider).retrySelectedConversation();
              },
              child: const Text('Réessayer'),
            ),
          ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              icon,
              size: 22,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hero card (image générée) ────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ConduitCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 360,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              gradient: LinearGradient(
                colors: [
                  Color(0xFF1A1A2E),
                  Color(0xFF16213E),
                  Color(0xFF0F3460),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Icon(
                CupertinoIcons.photo_fill_on_rectangle_fill,
                size: 64,
                color: Colors.white38,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
            child: Text(
              'Image générée  ›',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppThemeColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            child: Text(
              'Votre image a été créée avec succès — elle s\'affiche ci-dessus.',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ligne d'actions inline ───────────────────────────────────────────────────
class _InlineActionRow extends StatelessWidget {
  const _InlineActionRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionBtn(
          icon: CupertinoIcons.speaker_2_fill,
          label: 'Lire',
          onTap: () {},
        ),
        const SizedBox(width: 8),
        _ActionBtn(
          icon: CupertinoIcons.doc_on_doc,
          label: 'Copier',
          onTap: () {},
        ),
        const SizedBox(width: 8),
        _ActionBtn(
          icon: CupertinoIcons.arrow_clockwise,
          label: 'Régénérer',
          onTap: () {},
        ),
        const SizedBox(width: 8),
        _ActionBtn(icon: CupertinoIcons.share, label: 'Partager', onTap: () {}),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              icon,
              size: 20,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
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
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
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
      ),
    );
  }
}
