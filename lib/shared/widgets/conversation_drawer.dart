import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_state_provider.dart';
import '../../features/chat/providers/chat_state_provider.dart';
import '../theme/app_theme.dart';

class ConduitConversationDrawer extends ConsumerWidget {
  const ConduitConversationDrawer({
    super.key,
    required this.onSettingsTap,
  });

  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final pinned = chat.filter(chat.pinnedConversations);
    final recent = chat.filter(chat.recentConversations);

    return Drawer(
      backgroundColor: AppThemeColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Row(
                  children: [
                    Expanded(child: _TopTab(label: 'Chats', selected: true)),
                    Expanded(child: _TopTab(label: 'Notes')),
                    Expanded(child: _TopTab(label: 'Channels')),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: ref.read(chatControllerProvider).updateSearch,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(CupertinoIcons.search),
                          hintText: 'Search conversations...',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Material(
                      color: Colors.white.withValues(alpha: 0.84),
                      borderRadius: BorderRadius.circular(26),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(26),
                        onTap: ref.read(chatControllerProvider).createConversation,
                        child: const SizedBox(
                          width: 60,
                          height: 60,
                          child: Icon(CupertinoIcons.add, size: 30),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  children: [
                    _SectionHeader(label: 'Pinned', count: 5),
                    const SizedBox(height: 8),
                    for (final conversation in pinned) _ConversationTile(conversation: conversation),
                    const SizedBox(height: 18),
                    const _SectionHeader(label: 'Folders'),
                    const SizedBox(height: 10),
                    const _FolderTile(label: 'cogwheel0', count: 0, expanded: true),
                    const SizedBox(height: 10),
                    const _FolderTile(label: 'Test', count: 14, expanded: false),
                    const SizedBox(height: 18),
                    _SectionHeader(label: 'Recent', count: recent.isEmpty ? 696 : 696),
                    const SizedBox(height: 8),
                    for (final conversation in recent) _ConversationTile(conversation: conversation),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'cogwheel0 Conduit Developer',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppThemeColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: AppThemeShadows.soft,
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 25,
                            backgroundColor: Color(0xFFE2E3DE),
                            child: Icon(CupertinoIcons.person_fill, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              auth.session?.userName ?? 'cogwheel',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontSize: 18,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: onSettingsTap,
                            icon: const Icon(CupertinoIcons.gear_alt, size: 28),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopTab extends StatelessWidget {
  const _TopTab({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: selected ? AppThemeColors.pillSelected : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 18),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.count});

  final String label;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(CupertinoIcons.chevron_down, size: 18, color: AppThemeColors.textSoft),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.headlineMedium),
        if (count != null) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEDEEE9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppThemeColors.textSoft,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.label,
    required this.count,
    required this.expanded,
  });

  final String label;
  final int count;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppThemeColors.stroke),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.folder, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Text(label, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDEEE9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$count'),
                ),
              ],
            ),
          ),
          const Icon(CupertinoIcons.add_circled, size: 30),
          const SizedBox(width: 12),
          Icon(expanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down, size: 28),
        ],
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.conversation});

  final dynamic conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatControllerProvider);
    final isSelected = chat.selectedConversation.id == conversation.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isSelected ? AppThemeColors.pillSelected : Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            ref.read(chatControllerProvider).selectConversation(conversation);
            Navigator.of(context).maybePop();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conversation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontSize: 17,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      if (!conversation.isPinned && isSelected) ...[
                        const SizedBox(height: 6),
                        Text(
                          'cogwheel0 Conduit Developer',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppThemeColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (conversation.isPinned)
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDEEE9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      CupertinoIcons.pin_fill,
                      size: 14,
                      color: AppThemeColors.textSoft,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
