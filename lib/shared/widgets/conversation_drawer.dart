import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_state_provider.dart';
import '../../features/chat/providers/chat_state_provider.dart';
import '../models/conversation.dart';
import '../theme/app_theme.dart';

// ─── Enum pour les onglets ────────────────────────────────────────────────────
enum _DrawerTab { chats, notes, canaux }

class ConduitConversationDrawer extends ConsumerStatefulWidget {
  const ConduitConversationDrawer({super.key, required this.onSettingsTap});

  final VoidCallback onSettingsTap;

  @override
  ConsumerState<ConduitConversationDrawer> createState() =>
      _ConduitConversationDrawerState();
}

class _ConduitConversationDrawerState
    extends ConsumerState<ConduitConversationDrawer> {
  _DrawerTab _activeTab = _DrawerTab.chats;
  final Map<String, bool> _expandedFolders = {};

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider);
    final auth = ref.watch(authControllerProvider);

    // Nom affiché : session réelle ou fallback "Utilisateur"
    final displayName = auth.session?.userName ?? 'Utilisateur';
    final displayEmail = auth.session?.email ?? '';

    // Filtrer les conversations de type chat
    final pinned = chat.filter(chat.pinnedConversations);
    final recent = chat.filter(chat.recentConversations);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Drawer(
      backgroundColor: AppThemeColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: Column(
            children: [
              // ── Onglets ──────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppThemeColors.card
                      : AppThemeColors.card.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppThemeColors.stroke),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _TopTab(
                        label: 'Chats',
                        selected: _activeTab == _DrawerTab.chats,
                        onTap: () =>
                            setState(() => _activeTab = _DrawerTab.chats),
                      ),
                    ),
                    Expanded(
                      child: _TopTab(
                        label: 'Notes',
                        selected: _activeTab == _DrawerTab.notes,
                        onTap: () =>
                            setState(() => _activeTab = _DrawerTab.notes),
                      ),
                    ),
                    Expanded(
                      child: _TopTab(
                        label: 'Canaux',
                        selected: _activeTab == _DrawerTab.canaux,
                        onTap: () =>
                            setState(() => _activeTab = _DrawerTab.canaux),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Barre de recherche + Nouvelle conv ───────────────────────
              if (_activeTab == _DrawerTab.chats) ...[
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppThemeColors.cardStrong
                              : AppThemeColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppThemeColors.stroke),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            Icon(
                              CupertinoIcons.search,
                              size: 16,
                              color: AppThemeColors.textMuted,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                onChanged: ref
                                    .read(chatControllerProvider)
                                    .updateSearch,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppThemeColors.textStrong,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Rechercher une conversation…',
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
                const SizedBox(height: 14),
              ],

              // ── Contenu selon l'onglet actif ─────────────────────────────
              Expanded(
                child: _activeTab == _DrawerTab.chats
                    ? _ChatsContent(
                        pinned: pinned,
                        recent: recent,
                        expandedFolders: _expandedFolders,
                        onFolderToggle: (folder) => setState(() {
                          final current = _expandedFolders[folder] ?? false;
                          _expandedFolders[folder] = !current;
                        }),
                      )
                    : _activeTab == _DrawerTab.notes
                    ? const _NotesContent()
                    : const _ChannelsContent(),
              ),

              // ── Profil ───────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppThemeColors.card
                      : AppThemeColors.card.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppThemeColors.stroke),
                  boxShadow: AppThemeShadows.soft,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isDark
                          ? AppThemeColors.pillSelected
                          : AppThemeColors.pill,
                      child: Text(
                        displayName.substring(0, 1).toUpperCase(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
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
                              fontWeight: FontWeight.w600,
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
    );
  }
}

// ─── Contenu onglet Chats ────────────────────────────────────────────────────
class _ChatsContent extends ConsumerWidget {
  const _ChatsContent({
    required this.pinned,
    required this.recent,
    required this.expandedFolders,
    required this.onFolderToggle,
  });

  final List<Conversation> pinned;
  final List<Conversation> recent;
  final Map<String, bool> expandedFolders;
  final Function(String) onFolderToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatControllerProvider);

    // Get all unique folder names from the chat conversations (type = chat, non-empty folder)
    final folders = chat.conversations
        .where((c) => c.type == ConversationType.chat && c.folder.isNotEmpty)
        .map((c) => c.folder)
        .toSet()
        .toList();

    // Filter recent conversations: chats, not pinned, no folder
    final recentNoFolder = recent.where((c) => c.folder.isEmpty).toList();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Épinglées
        if (pinned.isNotEmpty) ...[
          _SectionHeader(label: 'Épinglées', count: pinned.length),
          const SizedBox(height: 6),
          for (final conv in pinned) _ConversationTile(conversation: conv),
          const SizedBox(height: 14),
        ],

        // Dossiers
        if (folders.isNotEmpty) ...[
          _SectionHeader(label: 'Dossiers', count: folders.length),
          const SizedBox(height: 8),
          for (final folder in folders) ...[
            _FolderTile(
              label: folder,
              count: chat.conversations
                  .where(
                    (c) =>
                        c.type == ConversationType.chat && c.folder == folder,
                  )
                  .length,
              expanded: expandedFolders[folder] ?? false,
              onTap: () => onFolderToggle(folder),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: (expandedFolders[folder] ?? false)
                  ? Padding(
                      padding: const EdgeInsets.only(
                        left: 14,
                        top: 4,
                        bottom: 8,
                      ),
                      child: Column(
                        children: [
                          for (final conv in chat.conversations.where(
                            (c) =>
                                c.type == ConversationType.chat &&
                                c.folder == folder,
                          ))
                            _ConversationTile(conversation: conv),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity, height: 0),
            ),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: 14),
        ],

        // Récentes
        if (recentNoFolder.isNotEmpty) ...[
          _SectionHeader(label: 'Récentes', count: recentNoFolder.length),
          const SizedBox(height: 6),
          for (final conv in recentNoFolder)
            _ConversationTile(conversation: conv),
        ],
      ],
    );
  }
}

// ─── Contenu onglet Notes ────────────────────────────────────────────────────
class _NotesContent extends ConsumerWidget {
  const _NotesContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatControllerProvider);
    final notes = chat.filter(chat.notes);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  ref.read(chatControllerProvider).createNote();
                  Navigator.of(context).maybePop();
                },
                icon: const Icon(CupertinoIcons.plus, size: 16),
                label: const Text('Nouvelle Note'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? AppThemeColors.cardStrong
                      : AppThemeColors.card,
                  foregroundColor: AppThemeColors.textStrong,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: AppThemeColors.stroke),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: notes.isEmpty
              ? const _EmptyTabContent(
                  icon: CupertinoIcons.doc_text,
                  label: 'Aucune note disponible',
                )
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return _ConversationTile(conversation: note);
                  },
                ),
        ),
      ],
    );
  }
}

// ─── Contenu onglet Canaux ───────────────────────────────────────────────────
class _ChannelsContent extends ConsumerWidget {
  const _ChannelsContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatControllerProvider);
    final channels = chat.filter(chat.channels);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showCreateChannelDialog(context, ref),
                icon: const Icon(CupertinoIcons.plus, size: 16),
                label: const Text('Nouveau Canal'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? AppThemeColors.cardStrong
                      : AppThemeColors.card,
                  foregroundColor: AppThemeColors.textStrong,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: AppThemeColors.stroke),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: channels.isEmpty
              ? const _EmptyTabContent(
                  icon: CupertinoIcons.antenna_radiowaves_left_right,
                  label: 'Aucun canal disponible',
                )
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: channels.length,
                  itemBuilder: (context, index) {
                    final channel = channels[index];
                    return _ConversationTile(conversation: channel);
                  },
                ),
        ),
      ],
    );
  }

  void _showCreateChannelDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Créer un canal'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Nom du canal (ex: design)',
            prefixText: '# ',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                ref.read(chatControllerProvider).createChannel(text);
                Navigator.of(context).pop();
                Navigator.of(context).maybePop();
              }
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }
}

// ─── Contenu vide pour Notes / Canaux ────────────────────────────────────────
class _EmptyTabContent extends StatelessWidget {
  const _EmptyTabContent({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppThemeColors.pill,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 26, color: AppThemeColors.textMuted),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppThemeColors.textSoft),
          ),
        ],
      ),
    );
  }
}

// ─── Onglet en-tête ──────────────────────────────────────────────────────────
class _TopTab extends StatelessWidget {
  const _TopTab({
    required this.label,
    this.selected = false,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppThemeColors.pillSelected : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? AppThemeColors.textStrong
                : AppThemeColors.textSoft,
          ),
        ),
      ),
    );
  }
}

// ─── En-tête de section ───────────────────────────────────────────────────────
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
          Icon(
            CupertinoIcons.chevron_down,
            size: 12,
            color: AppThemeColors.textMuted,
          ),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppThemeColors.textMuted,
              letterSpacing: 0.6,
              fontSize: 10,
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

// ─── Tuile de dossier (cliquable) ────────────────────────────────────────────
class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.label,
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark
          ? AppThemeColors.card
          : AppThemeColors.card.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppThemeColors.stroke),
          ),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.folder,
                size: 18,
                color: AppThemeColors.textSoft,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppThemeColors.pill,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '$count',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppThemeColors.textSoft,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: expanded ? 0.25 : 0.0,
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: AppThemeColors.textMuted,
                ),
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: isSelected ? AppThemeColors.pillSelected : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            ref.read(chatControllerProvider).selectConversation(conversation);
            Navigator.of(context).maybePop();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
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
                        color: conversation.isPinned
                            ? Colors.black87
                            : AppThemeColors.textMuted.withValues(alpha: 0.5),
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
                      color: AppThemeColors.textMuted.withValues(alpha: 0.4),
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
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppThemeColors.pill,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 20, color: AppThemeColors.textStrong),
          ),
        ),
      ),
    );
  }
}
