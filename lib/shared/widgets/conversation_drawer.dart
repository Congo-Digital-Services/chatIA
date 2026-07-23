import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_state_provider.dart';
import '../../features/chat/providers/chat_state_provider.dart';
import '../models/conversation.dart';
import '../theme/app_theme.dart';

class ConduitConversationDrawer extends ConsumerStatefulWidget {
  const ConduitConversationDrawer({super.key, required this.onSettingsTap});

  final VoidCallback onSettingsTap;

  @override
  ConsumerState<ConduitConversationDrawer> createState() =>
      _ConduitConversationDrawerState();
}

class _ConduitConversationDrawerState
    extends ConsumerState<ConduitConversationDrawer> {
  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final topInset = MediaQuery.of(context).viewPadding.top;

    // Nom affiché : session réelle ou fallback "Utilisateur"
    final displayName = auth.session?.userName ?? 'Utilisateur';
    final displayEmail = auth.session?.email ?? '';

    // Filtrer les conversations de type chat
    final pinned = chat.filter(chat.pinnedConversations);
    final theme = Theme.of(context);

    return Drawer(
      backgroundColor: AppThemeColors.backgroundSoft,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Container(
          decoration: BoxDecoration(
            color: AppThemeColors.backgroundSoft,
            border: Border(right: BorderSide(color: AppThemeColors.stroke)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(2, topInset + 10, 2, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppThemeColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppThemeColors.stroke),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 10),
                              Icon(
                                CupertinoIcons.search,
                                size: 14,
                                color: AppThemeColors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: TextField(
                                  onChanged: ref
                                      .read(chatControllerProvider)
                                      .updateSearch,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppThemeColors.textStrong,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Rechercher',
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 0,
                                    ),
                                    hintStyle: theme.textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppThemeColors.textMuted,
                                        ),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _DrawerIconBtn(
                        icon: CupertinoIcons.square_pencil,
                        tooltip: 'Nouvelle conversation',
                        onTap: () {
                          ref.read(chatControllerProvider).createConversation();
                          Navigator.of(context).maybePop();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: _ChatsContent(
                    isLoading: chat.isLoading,
                    pinned: pinned,
                    recent: const [],
                    expandedFolders: const {},
                    onFolderToggle: (_) {},
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppThemeColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppThemeColors.stroke),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppThemeColors.pill,
                        child: Text(
                          displayName.substring(0, 1).toUpperCase(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppThemeColors.textStrong,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              displayName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (displayEmail.isNotEmpty)
                              Text(
                                displayEmail,
                                style: theme.textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      _DrawerIconBtn(
                        icon: CupertinoIcons.gear_alt,
                        tooltip: 'Paramètres',
                        onTap: widget.onSettingsTap,
                      ),
                    ],
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

// ─── Contenu onglet Chats ────────────────────────────────────────────────────
class _ChatsContent extends ConsumerWidget {
  const _ChatsContent({
    required this.isLoading,
    required this.pinned,
    required this.recent,
    required this.expandedFolders,
    required this.onFolderToggle,
  });

  final bool isLoading;
  final List<Conversation> pinned;
  final List<Conversation> recent;
  final Map<String, bool> expandedFolders;
  final Function(String) onFolderToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatControllerProvider);
    if (isLoading && chat.conversations.isEmpty) {
      return const _DrawerLoadingState();
    }

    final grouped = _groupByPeriod(
      chat.filter(
        chat.conversations
            .where((c) => c.type == ConversationType.chat)
            .toList(),
      ),
    );

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (pinned.isNotEmpty) ...[
          _SectionHeader(label: 'Épinglées', count: pinned.length),
          const SizedBox(height: 6),
          for (final conv in pinned) _ConversationTile(conversation: conv),
          const SizedBox(height: 14),
        ],
        for (final entry in grouped.entries) ...[
          _SectionHeader(label: entry.key, count: entry.value.length),
          const SizedBox(height: 6),
          for (final conv in entry.value) _ConversationTile(conversation: conv),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Map<String, List<Conversation>> _groupByPeriod(
    List<Conversation> conversations,
  ) {
    final now = DateTime.now();
    final today = <Conversation>[];
    final last7Days = <Conversation>[];
    final thisMonth = <Conversation>[];

    for (final conversation in conversations) {
      final date = conversation.updatedAt ?? conversation.createdAt;
      if (date == null) {
        thisMonth.add(conversation);
        continue;
      }

      final difference = now.difference(date).inDays;
      final isSameDay =
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
      if (isSameDay) {
        today.add(conversation);
        continue;
      }
      if (difference <= 7) {
        last7Days.add(conversation);
        continue;
      }
      if (date.year == now.year && date.month == now.month) {
        thisMonth.add(conversation);
      }
    }

    final result = <String, List<Conversation>>{};
    if (today.isNotEmpty) {
      result['Aujourd\'hui'] = today;
    }
    if (last7Days.isNotEmpty) {
      result['7 derniers jours'] = last7Days;
    }
    if (thisMonth.isNotEmpty) {
      result['Ce mois-ci'] = thisMonth;
    }
    return result;
  }
}

class _DrawerLoadingState extends StatelessWidget {
  const _DrawerLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: const [
        _SectionHeader(label: 'Chargement'),
        SizedBox(height: 8),
        _DrawerSkeletonTile(),
        _DrawerSkeletonTile(),
        _DrawerSkeletonTile(),
        SizedBox(height: 16),
        _DrawerSkeletonTile(short: true),
        _DrawerSkeletonTile(),
      ],
    );
  }
}

class _DrawerSkeletonTile extends StatelessWidget {
  const _DrawerSkeletonTile({this.short = false});

  final bool short;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: AppThemeColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppThemeColors.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: short ? 120 : 170,
              height: 11,
              decoration: BoxDecoration(
                color: AppThemeColors.pill,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: short ? 70 : 110,
              height: 9,
              decoration: BoxDecoration(
                color: AppThemeColors.pill,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppThemeColors.textMuted,
              fontSize: 11,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppThemeColors.pill,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppThemeColors.textSoft,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Tuile de conversation ────────────────────────────────────────────────────
class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatControllerProvider);
    final isSelected = chat.selectedConversation.id == conversation.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isSelected ? AppThemeColors.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            ref.read(chatControllerProvider).selectConversation(conversation);
            Navigator.of(context).maybePop();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        conversation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? AppThemeColors.textStrong
                              : AppThemeColors.textSoft,
                        ),
                      ),
                      if (conversation.subtitle.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          conversation.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppThemeColors.textMuted),
                        ),
                      ],
                    ],
                  ),
                ),
                if (conversation.type == ConversationType.chat) ...[
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      ref.read(chatControllerProvider).togglePin(conversation);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Icon(
                        conversation.isPinned
                            ? CupertinoIcons.pin_fill
                            : CupertinoIcons.pin,
                        size: 14,
                        color: isSelected
                            ? AppThemeColors.accent
                            : (conversation.isPinned
                                  ? AppThemeColors.textStrong
                                  : AppThemeColors.textMuted.withValues(
                                      alpha: 0.5,
                                    )),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    ref
                        .read(chatControllerProvider)
                        .deleteConversation(conversation);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Icon(
                      CupertinoIcons.trash,
                      size: 13,
                      color: isSelected
                          ? AppThemeColors.textSoft
                          : AppThemeColors.textMuted.withValues(alpha: 0.4),
                    ),
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

// ─── Bouton icône drawer (44×44) ─────────────────────────────────────────────
class _DrawerIconBtn extends StatelessWidget {
  const _DrawerIconBtn({
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
      color: AppThemeColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
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
