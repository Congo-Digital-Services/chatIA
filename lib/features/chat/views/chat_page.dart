import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/auth/providers/auth_state_provider.dart';
import '../../../shared/models/agent_option.dart';
import '../../../shared/models/conversation.dart';
import '../../../shared/theme/app_motion.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/conversation_drawer.dart';
import '../providers/chat_state_provider.dart';
import '../widgets/chat_composer.dart';
import '../widgets/message_bubble.dart';
import '../../../shared/widgets/maloba_glyph.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  bool _isVoiceCallActive = false;
  // Un échange Santé a commencé : la vue Santé affiche la conversation.
  bool _healthThreadActive = false;
  ChatMode _mode = ChatMode.discussion;
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
      resizeToAvoidBottomInset: true,
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
                  padding: const EdgeInsets.fromLTRB(6, 2, 6, 4),
                  child: _TopBar(
                    showAgentSelector: !isNote && _mode == ChatMode.discussion,
                    mode: isNote ? null : _mode,
                    onModeChanged: (mode) => setState(() => _mode = mode),
                    onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
                    onComposeTap: () {
                      if (isNote) {
                        ref.read(chatControllerProvider).createNote();
                        return;
                      }
                      setState(() => _healthThreadActive = false);
                      ref.read(chatControllerProvider).createConversation();
                    },
                  ),
                ),
                Expanded(
                  child: Container(
                    color: AppThemeColors.background,
                    child: Column(
                      children: [
                        Expanded(
                          child: AnimatedSwitcher(
                            // Fondu enchaîné séquentiel : l'ancienne vue sort
                            // pendant la 1re moitié, la nouvelle entre pendant
                            // la 2de. Sans chevauchement au centre de l'écran.
                            duration: AppMotion.duration(
                              context,
                              const Duration(milliseconds: 260),
                            ),
                            switchInCurve: Curves.linear,
                            switchOutCurve: Curves.linear,
                            layoutBuilder: (current, previous) => Stack(
                              fit: StackFit.expand,
                              children: [...previous, ?current],
                            ),
                            transitionBuilder: (child, animation) {
                              final visible = CurvedAnimation(
                                parent: animation,
                                curve: const Interval(
                                  0.5,
                                  1,
                                  curve: AppMotion.easeOut,
                                ),
                              );
                              return FadeTransition(
                                opacity: visible,
                                child: AnimatedBuilder(
                                  animation: visible,
                                  child: child,
                                  builder: (context, child) =>
                                      Transform.translate(
                                        offset: Offset(
                                          0,
                                          8 * (1 - visible.value),
                                        ),
                                        child: child,
                                      ),
                                ),
                              );
                            },
                            child: isNote
                                ? _NoteEditor(
                                    key: ValueKey('note-${conversation.id}'),
                                    conversation: conversation,
                                  )
                                : _mode == ChatMode.health &&
                                      !(_healthThreadActive &&
                                          messages.isNotEmpty)
                                ? const _HealthView(key: ValueKey('health'))
                                : _ConversationBody(
                                    key: const ValueKey('discussion'),
                                    chat: chat,
                                    conversation: conversation,
                                    theme: theme,
                                    scrollController: _scrollController,
                                    userName:
                                        auth.session?.userName ?? 'Sylvia',
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!isNote)
                  ChatComposer(
                    mode: _mode,
                    onHealthSend: () {
                      // Premier message Santé : nouvelle conversation, séparée
                      // de la discussion ouverte.
                      if (!_healthThreadActive) {
                        ref.read(chatControllerProvider).createConversation();
                        setState(() => _healthThreadActive = true);
                      }
                    },
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

// ─── Barre du haut minimaliste ───────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onMenuTap,
    required this.onComposeTap,
    this.showAgentSelector = false,
    this.mode,
    this.onModeChanged,
  });

  final VoidCallback onMenuTap;
  final VoidCallback onComposeTap;
  final bool showAgentSelector;
  final ChatMode? mode;
  final ValueChanged<ChatMode>? onModeChanged;

  @override
  Widget build(BuildContext context) {
    final currentMode = mode;
    return Row(
      children: [
        _HeaderButton(
          icon: CupertinoIcons.line_horizontal_3,
          onTap: onMenuTap,
          tooltip: 'Menu',
        ),
        Expanded(
          child: Center(
            child: currentMode != null && onModeChanged != null
                ? _HeaderPill(
                    mode: currentMode,
                    onModeChanged: onModeChanged!,
                    showAgentSelector: showAgentSelector,
                  )
                : showAgentSelector
                ? const _AgentSelector()
                : const SizedBox.shrink(),
          ),
        ),
        _HeaderButton(
          icon: CupertinoIcons.square_pencil,
          onTap: onComposeTap,
          tooltip: 'Nouvelle conversation',
        ),
      ],
    );
  }
}

// ─── Sélecteur d'agent (entrées du menu LibreChat) ─────────────────────────
class _AgentSelector extends ConsumerStatefulWidget {
  const _AgentSelector({super.key, this.embedded = false});

  /// Dans la pastille d'en-tête : pas de cadre propre, la pastille en a un.
  final bool embedded;

  @override
  ConsumerState<_AgentSelector> createState() => _AgentSelectorState();
}

class _AgentSelectorState extends ConsumerState<_AgentSelector> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(chatControllerProvider).loadAgentOptions();
      }
    });
  }

  Future<void> _openPicker(ChatController chat) async {
    final active = chat.activeAgent;
    final chosen = await showModalBottomSheet<AgentOption>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppThemeColors.background,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          children: [
            for (final option in chat.agentOptions)
              ListTile(
                title: Text(
                  option.label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: option.description.isEmpty
                    ? null
                    : Text(option.description),
                trailing: option.agentId == active.agentId
                    ? Icon(
                        CupertinoIcons.checkmark_alt,
                        color: AppThemeColors.accent,
                      )
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
          ],
        ),
      ),
    );
    if (chosen != null && chosen.agentId != active.agentId) {
      chat.selectAgent(chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider);
    final label = chat.activeAgent.label;
    final canPick = chat.agentOptions.length > 1 && !chat.isStreaming;
    final content = InkWell(
      customBorder: const StadiumBorder(),
      onTap: canPick ? () => _openPicker(chat) : null,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: widget.embedded ? 12 : 14,
          vertical: 9,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppThemeColors.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: AnimatedSwitcher(
                duration: AppMotion.duration(context, AppMotion.fast),
                switchInCurve: AppMotion.easeOut,
                switchOutCurve: AppMotion.easeOut,
                child: Text(
                  label,
                  key: ValueKey(label),
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppThemeColors.textStrong,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (canPick) ...[
              const SizedBox(width: 6),
              Icon(
                CupertinoIcons.chevron_down,
                size: 13,
                color: AppThemeColors.textMuted,
              ),
            ],
          ],
        ),
      ),
    );
    if (widget.embedded) {
      return Tooltip(
        message: 'Choisir l’agent',
        excludeFromSemantics: true,
        child: content,
      );
    }
    return Tooltip(
      message: 'Choisir l’agent',
      excludeFromSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          boxShadow: AppThemeShadows.soft,
        ),
        child: Material(
          color: AppThemeColors.surface,
          shape: StadiumBorder(side: BorderSide(color: AppThemeColors.stroke)),
          child: content,
        ),
      ),
    );
  }
}

// ─── Pastille d'en-tête : agent + mode, dans un seul conteneur ───────────────
class _HeaderPill extends StatelessWidget {
  const _HeaderPill({
    required this.mode,
    required this.onModeChanged,
    required this.showAgentSelector,
  });

  final ChatMode mode;
  final ValueChanged<ChatMode> onModeChanged;
  final bool showAgentSelector;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: AppThemeShadows.soft,
      ),
      child: Material(
        color: AppThemeColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: StadiumBorder(side: BorderSide(color: AppThemeColors.stroke)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: AnimatedSwitcher(
                duration: AppMotion.duration(context, AppMotion.fast),
                switchInCurve: AppMotion.easeOut,
                switchOutCurve: AppMotion.easeOut,
                child: showAgentSelector
                    ? const _AgentSelector(
                        key: ValueKey('agent'),
                        embedded: true,
                      )
                    : Padding(
                        key: const ValueKey('sante'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        child: Text(
                          'Santé',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppThemeColors.textStrong,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
              ),
            ),
            Container(width: 1, height: 22, color: AppThemeColors.stroke),
            _ModeSegmentedControl(
              mode: mode,
              onChanged: onModeChanged,
              embedded: true,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sélecteur de mode (Discussion / Santé) ────────────────────────────────
class _ModeSegmentedControl extends StatelessWidget {
  const _ModeSegmentedControl({
    required this.mode,
    required this.onChanged,
    this.embedded = false,
  });

  final ChatMode mode;
  final ValueChanged<ChatMode> onChanged;

  /// Dans la pastille d'en-tête : fond discret, la pastille porte le cadre.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: embedded ? Colors.transparent : AppThemeColors.pill,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Stack(
          children: [
            // Pastille active : glisse d'un onglet à l'autre (état + origine).
            Positioned.fill(
              child: AnimatedAlign(
                alignment: mode == ChatMode.discussion
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                duration: AppMotion.duration(context, AppMotion.base),
                curve: AppMotion.easeOut,
                child: Container(
                  width: 38,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppThemeColors.surface,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: AppThemeShadows.soft,
                  ),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ModeTab(
                  icon: CupertinoIcons.bubble_left_bubble_right_fill,
                  label: 'Discussion',
                  selected: mode == ChatMode.discussion,
                  onTap: () => onChanged(ChatMode.discussion),
                ),
                _ModeTab(
                  icon: Icons.monitor_heart_rounded,
                  label: 'Santé',
                  selected: mode == ChatMode.health,
                  onTap: () => onChanged(ChatMode.health),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppThemeColors.accent : AppThemeColors.textMuted;

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 38,
            height: 32,
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }
}

// ─── Vue dédiée au mode Santé (contenu séparé) ───────────────────────────────
class _HealthView extends StatelessWidget {
  const _HealthView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 36),
          child: Center(child: _HealthHero(theme: theme)),
        ),
      ),
    );
  }
}

/// Accueil de l'espace Santé : un seul bloc (au lieu de deux cartes qui
/// répétaient la même consigne que le bouton micro).
class _HealthHero extends StatelessWidget {
  const _HealthHero({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: AppThemeColors.accentSoft,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.monitor_heart_rounded,
            size: 42,
            color: AppThemeColors.accent,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Espace Santé',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Text(
            'Décrivez vos symptômes à voix haute. Vous relisez le texte '
            'avant de l’envoyer.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppThemeColors.textSoft,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 22),
        const Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _HealthStep(number: 1, label: 'Parlez'),
            _HealthStep(number: 2, label: 'Relisez'),
            _HealthStep(number: 3, label: 'Envoyez'),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.lock_fill,
              size: 13,
              color: AppThemeColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              'Échanges séparés de vos discussions',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _HealthStep extends StatelessWidget {
  const _HealthStep({required this.number, required this.label});

  final int number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
      decoration: BoxDecoration(
        color: AppThemeColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppThemeColors.stroke),
        boxShadow: AppThemeShadows.soft,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppThemeColors.accent,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppThemeColors.onAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
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
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppThemeColors.accentSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.bubble_left_bubble_right_fill,
                size: 26,
                color: AppThemeColors.accent,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Bonjour $userName, que souhaitez-vous créer aujourd\'hui ?',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
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

class _ConversationBody extends StatefulWidget {
  const _ConversationBody({
    super.key,
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
  State<_ConversationBody> createState() => _ConversationBodyState();
}

class _ConversationBodyState extends State<_ConversationBody> {
  // Seuls les messages arrivés APRÈS l'ouverture de la conversation, en fin de
  // liste, s'animent : pas d'historique qui entre d'un bloc, pas d'animation
  // sur les anciens messages chargés en remontant.
  String? _baselineConversationId;
  final Set<String> _baseline = <String>{};
  final Set<String> _animated = <String>{};

  bool _shouldAnimate(String messageId, int index, int count) {
    if (_baseline.contains(messageId) || _animated.contains(messageId)) {
      return false;
    }
    if (index < count - 2) {
      return false;
    }
    _animated.add(messageId);
    return true;
  }

  void _syncBaseline() {
    final id = widget.conversation.id;
    if (_baselineConversationId == id) {
      return;
    }
    // Brouillon -> conversation serveur : même messages, on ne rejoue rien.
    final wasDraft = _baselineConversationId != null && _animated.isNotEmpty;
    _baselineConversationId = id;
    if (wasDraft) {
      _baseline.addAll(widget.conversation.messages.map((m) => m.id));
      return;
    }
    _baseline
      ..clear()
      ..addAll(
        widget.chat.isSelectedConversationDraft
            ? const <String>[]
            : widget.conversation.messages.map((m) => m.id),
      );
    _animated.clear();
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    final conversation = widget.conversation;
    final theme = widget.theme;
    final scrollController = widget.scrollController;
    final userName = widget.userName;
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

    _syncBaseline();
    final itemCount =
        conversation.messages.length +
        (chat.isSelectedConversationLoadingMore ? 1 : 0);

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 120),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index < conversation.messages.length) {
          final message = conversation.messages[index];
          return EnterOnce(
            key: ValueKey('entree-${message.id}'),
            animate: _shouldAnimate(
              message.id,
              index,
              conversation.messages.length,
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: MessageBubble(
                message: message,
                conversation: conversation,
              ),
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
                child: const MalobaLoader(size: 20),
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
                    ? const MalobaLoader(size: 22)
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
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 22, color: AppThemeColors.textStrong),
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
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

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
          padding: EdgeInsets.symmetric(
            horizontal: isLandscape ? 16 : 24,
            vertical: isLandscape ? 12 : 32,
          ),
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
                            color: AppThemeColors.brandGreen.withValues(
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
                            color: AppThemeColors.brandGreen.withValues(
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
                      color: AppThemeColors.brandGreen,
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
              SizedBox(height: isLandscape ? 14 : 36),

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
                  color: AppThemeColors.brandGreen,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: isLandscape ? 12 : 32),

              // Waveform representation
              SizedBox(
                height: isLandscape ? 24 : 40,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(isLandscape ? 16 : 24, (index) {
                    final double height =
                        4.0 +
                        (index % 4 == 0
                            ? 24.0
                            : index % 3 == 0
                            ? 16.0
                            : 8.0);
                    return Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: isLandscape ? 1.5 : 2.5,
                      ),
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
