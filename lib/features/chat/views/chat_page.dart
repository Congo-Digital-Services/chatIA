import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/auth/providers/auth_state_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final conversation = chat.selectedConversation;
    final messages = conversation.messages;
    final theme = Theme.of(context);

    return Scaffold(
      key: _scaffoldKey,
      drawer: ConduitConversationDrawer(
        onSettingsTap: () => context.push('/settings'),
      ),
      backgroundColor: AppThemeColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
              child: Row(
                children: [
                  _ChromeButton(
                    icon: CupertinoIcons.line_horizontal_3,
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.84),
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: AppThemeShadows.soft,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Kimi K2', style: theme.textTheme.headlineMedium),
                            const SizedBox(width: 10),
                            const Icon(CupertinoIcons.chevron_down, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _ChromeButton(
                    icon: CupertinoIcons.square_pencil,
                    onTap: () => ref.read(chatControllerProvider).createConversation(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                children: [
                  if (messages.isEmpty) ...[
                    const SizedBox(height: 72),
                    Text('Ask Conduit', style: theme.textTheme.headlineLarge),
                    const SizedBox(height: 12),
                    Text(
                      'The visual shell is ready. This screen now mirrors the Conduit chat rhythm much more closely and stays disconnected from OpenWebUI logic.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppThemeColors.textSoft,
                        height: 1.5,
                      ),
                    ),
                  ] else ...[
                    for (final message in messages) ...[
                      MessageBubble(message: message),
                      const SizedBox(height: 20),
                    ],
                    if (conversation.heroAssetLabel != null) ...[
                      ConduitCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 390,
                              decoration: const BoxDecoration(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(28),
                                ),
                                gradient: LinearGradient(
                                  colors: [Color(0xFF2A2411), Color(0xFFE7E3CA)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  CupertinoIcons.photo_fill_on_rectangle_fill,
                                  size: 72,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                              child: Text(
                                'Image created  ›',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: AppThemeColors.textMuted,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                              child: Text(
                                'Your image of a cat has been generated and is now displayed above—take a look!',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w400,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const _InlineActionRow(),
                      const SizedBox(height: 18),
                      const Center(child: _ScrollHandle()),
                    ],
                  ],
                ],
              ),
            ),
            ChatComposer(
              onSend: (value) => ref.read(chatControllerProvider).sendMessage(value),
              userName: auth.session?.userName ?? 'cogwheel',
            ),
          ],
        ),
      ),
    );
  }
}

class _ChromeButton extends StatelessWidget {
  const _ChromeButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.84),
      borderRadius: BorderRadius.circular(25),
      child: InkWell(
        borderRadius: BorderRadius.circular(25),
        onTap: onTap,
        child: SizedBox(
          width: 58,
          height: 58,
          child: Icon(icon, size: 29),
        ),
      ),
    );
  }
}

class _InlineActionRow extends StatelessWidget {
  const _InlineActionRow();

  @override
  Widget build(BuildContext context) {
    Widget buildAction(IconData icon) {
      return Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: Color(0xFFF5F5F2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFF393939)),
      );
    }

    return Row(
      children: [
        buildAction(CupertinoIcons.speaker_2_fill),
        const SizedBox(width: 10),
        buildAction(CupertinoIcons.doc_on_doc),
        const SizedBox(width: 10),
        buildAction(CupertinoIcons.info),
        const SizedBox(width: 10),
        buildAction(CupertinoIcons.arrow_clockwise),
      ],
    );
  }
}

class _ScrollHandle extends StatelessWidget {
  const _ScrollHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        shape: BoxShape.circle,
      ),
      child: const Icon(CupertinoIcons.chevron_down, size: 34),
    );
  }
}
