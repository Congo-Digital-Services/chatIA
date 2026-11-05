import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/audio_recorder.dart';
import '../../../core/services/tts_service.dart';
import '../../../shared/models/chat_message.dart';
import '../../../shared/models/conversation.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/app_toast.dart';
import '../providers/chat_state_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../../shared/widgets/maloba_glyph.dart';

class MessageBubble extends ConsumerWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.conversation,
  });

  final ChatMessage message;
  final Conversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.role == ChatRole.user;
    final theme = Theme.of(context);
    final ttsEnabled = ref.watch(settingsControllerProvider).ttsEnabled;

    return GestureDetector(
      onLongPress: () => _showMessageActions(context, ref),
      child: _buildBubble(context, theme, isUser, ttsEnabled),
    );
  }

  void _showMessageActions(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    final chat = ref.read(chatControllerProvider);
    final conversationId = conversation.id;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDarkSheet = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDarkSheet
                ? const Color(0xFF1C1C1C)
                : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppThemeColors.stroke,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(CupertinoIcons.doc_on_doc),
                title: const Text('Copier'),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: message.text));
                  showAppToast(
                    context,
                    message: 'Message copié.',
                    type: AppToastType.success,
                    iconOnly: true,
                  );
                },
              ),
              if (message.role == ChatRole.user)
                ListTile(
                  leading: const Icon(CupertinoIcons.pencil),
                  title: const Text('Modifier'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditDialog(context, ref, chat, conversationId);
                  },
                ),
              ListTile(
                leading: Icon(
                  CupertinoIcons.delete,
                  color: Colors.red.shade400,
                ),
                title: Text(
                  'Supprimer',
                  style: TextStyle(color: Colors.red.shade400),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  chat.deleteMessageFromServer(conversationId, message.id);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    ChatController chat,
    String conversationId,
  ) {
    final controller = TextEditingController(text: message.text);
    final index = conversation.messages.indexWhere((m) => m.id == message.id);
    final afterCount =
        index < 0 ? 0 : conversation.messages.length - index - 1;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier le message'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              maxLines: null,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Nouveau texte…',
                border: OutlineInputBorder(),
              ),
            ),
            if (afterCount > 0) ...[
              const SizedBox(height: 12),
              // Annoncé avant d'appuyer : renvoyer efface la suite, et
              // l'apprendre après coup serait une mauvaise surprise.
              Text(
                'Renvoyer retirera $afterCount message'
                '${afterCount > 1 ? 's' : ''} qui suiv'
                '${afterCount > 1 ? 'ent' : 't'} — '
                'ils répondaient à l\'ancienne question.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: AppThemeColors.textSoft,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          // Corriger une faute sans refaire répondre le modèle reste
          // possible : c'est une demande différente, et la fusionner avec le
          // renvoi obligerait à régénérer pour changer une virgule.
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final newText = controller.text.trim();
              if (newText.isNotEmpty && newText != message.text) {
                chat.updateMessageOnServer(
                  conversationId,
                  message.id,
                  newText: newText,
                );
              }
            },
            child: const Text('Corriger seulement'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              final newText = controller.text.trim();
              if (newText.isEmpty) return;
              chat.editAndResend(
                conversationId,
                message.id,
                newText: newText,
              );
            },
            child: const Text('Modifier et renvoyer'),
          ),
        ],
      ),
    );
  }

  bool _shouldShowAttachmentCaption() {
    final text = message.text.trim();
    if (text.isEmpty) {
      return false;
    }
    if (message.fileUrl != null && text.startsWith('Fichier envoyé : ')) {
      return false;
    }
    if (message.audioUrl != null &&
        RegExp(r'^Message vocal \(.+\)$').hasMatch(text)) {
      return false;
    }
    return true;
  }

  Widget _buildBubble(
    BuildContext context,
    ThemeData theme,
    bool isUser,
    bool ttsEnabled,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleColor = isUser
        ? (isDark ? const Color(0xFF1E2330) : const Color(0xFFF2F4F8))
        : Colors.transparent;
    final textColor = AppThemeColors.textStrong;
    final isPendingAssistant =
        !isUser &&
        message.text.trim().isEmpty &&
        message.fileUrl == null &&
        message.audioUrl == null;

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppThemeColors.stroke),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.audioUrl != null)
                      _VoiceMessagePlayer(
                        audioUrl: message.audioUrl!,
                        isUser: true,
                      )
                    else if (message.fileUrl != null)
                      _FileMessageBlock(
                        fileUrl: message.fileUrl!,
                        fileName: message.fileName ?? 'Fichier',
                        fileSize: message.fileSize ?? '',
                        isImage: message.isImage ?? false,
                        isUser: true,
                      )
                    else
                      Text(
                        message.text,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: textColor,
                          height: 1.45,
                        ),
                      ),
                    if ((message.audioUrl != null || message.fileUrl != null) &&
                        _shouldShowAttachmentCaption()) ...[
                      const SizedBox(height: 10),
                      Text(
                        message.text,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: textColor,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pendant l'attente, pas de glyphe : le loader anime déjà les mêmes
        // quatre barres juste à côté, et les afficher deux fois donne à lire
        // deux logos au lieu d'un état. La place est gardée pour que le texte
        // ne saute pas quand la réponse arrive.
        if (isPendingAssistant)
          const SizedBox(width: 44, height: 34)
        else
          Container(
            width: 34,
            height: 34,
            margin: const EdgeInsets.only(top: 2, right: 10),
            decoration: BoxDecoration(
              color: AppThemeColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: MalobaGlyph(size: 20)),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4, right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.audioUrl != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppThemeColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppThemeColors.stroke),
                    ),
                    child: _VoiceMessagePlayer(
                      audioUrl: message.audioUrl!,
                      isUser: false,
                    ),
                  )
                else if (isPendingAssistant)
                  const _AssistantPendingState()
                else
                  Text(
                    message.text,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppThemeColors.textStrong,
                      height: 1.55,
                    ),
                  ),
                if (!isPendingAssistant) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (ttsEnabled) ...[
                        ValueListenableBuilder<bool>(
                          valueListenable: ttsService.isSpeaking,
                          builder: (context, isSpeaking, _) {
                            return _AssistantAction(
                              icon: isSpeaking
                                  ? CupertinoIcons.stop_circle
                                  : CupertinoIcons.volume_up,
                              label: isSpeaking ? 'Arrêter' : 'Lire',
                              onTap: () => ttsService.toggle(message.text),
                            );
                          },
                        ),
                        const SizedBox(width: 6),
                      ],
                      _AssistantAction(
                        icon: CupertinoIcons.doc_on_doc,
                        label: 'Copier',
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: message.text));
                          showAppToast(
                            context,
                            message: 'Réponse copiée.',
                            type: AppToastType.success,
                            iconOnly: true,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AssistantPendingState extends StatelessWidget {
  const _AssistantPendingState();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MalobaLoader(size: 22, semanticLabel: 'Réponse en préparation'),
        const SizedBox(width: 10),
        // Le libellé lu à voix haute reste stable : un lecteur d'écran qui
        // annoncerait un mot différent toutes les deux secondes rendrait
        // l'attente pénible au lieu de l'illustrer.
        Semantics(
          label: 'Réponse en préparation',
          liveRegion: false,
          child: ExcludeSemantics(
            child: MalobaThinkingText(
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ],
    );
  }
}

class _AssistantAction extends StatelessWidget {
  const _AssistantAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppThemeColors.textMuted),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppThemeColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceMessagePlayer extends StatefulWidget {
  const _VoiceMessagePlayer({required this.audioUrl, required this.isUser});

  final String audioUrl;
  final bool isUser;

  @override
  State<_VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<_VoiceMessagePlayer> {
  bool _isPlaying = false;
  double _progress = 0.0;

  @override
  void dispose() {
    if (_isPlaying) {
      audioRecorder.stopPlaying();
    }
    super.dispose();
  }

  void _togglePlay() {
    if (_isPlaying) {
      audioRecorder.stopPlaying();
      setState(() {
        _isPlaying = false;
      });
    } else {
      setState(() {
        _isPlaying = true;
        _progress = 0.0;
      });
      audioRecorder.play(
        widget.audioUrl,
        onPositionChanged: (p) {
          setState(() {
            _progress = p;
          });
        },
        onComplete: () {
          setState(() {
            _isPlaying = false;
            _progress = 0.0;
          });
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final btnBgColor = widget.isUser
        ? (isDark ? Colors.black : Colors.white)
        : AppThemeColors.pillSelected;
    final iconColor = widget.isUser
        ? (isDark ? Colors.white : Colors.black)
        : (isDark ? Colors.black : Colors.white);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: btnBgColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? Colors.white : Colors.black,
                width: 1,
              ),
            ),
            child: Icon(
              _isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
              size: 16,
              color: iconColor,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 16,
              child: Row(
                children: List.generate(18, (index) {
                  final filled = (index / 18) <= _progress;
                  final double barHeight =
                      4.0 +
                      (index % 3 == 0
                          ? 8.0
                          : index % 2 == 0
                          ? 4.0
                          : 0.0);
                  final waveFilledColor = widget.isUser
                      ? (isDark ? Colors.white70 : Colors.black87)
                      : AppThemeColors.accent;
                  final waveUnfillColor = widget.isUser
                      ? (isDark
                            ? Colors.white.withValues(alpha: 0.25)
                            : Colors.black.withValues(alpha: 0.20))
                      : AppThemeColors.textMuted.withValues(alpha: 0.4);
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    width: 2.5,
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: filled ? waveFilledColor : waveUnfillColor,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _isPlaying ? 'Lecture…' : 'Message vocal',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: widget.isUser
                    ? (isDark ? Colors.white54 : Colors.black54)
                    : AppThemeColors.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FileMessageBlock extends StatelessWidget {
  const _FileMessageBlock({
    required this.fileUrl,
    required this.fileName,
    required this.fileSize,
    required this.isImage,
    required this.isUser,
  });

  final String fileUrl;
  final String fileName;
  final String fileSize;
  final bool isImage;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(
              fileUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stackTrace) => Container(
                height: 180,
                color: AppThemeColors.surface,
                alignment: Alignment.center,
                child: const Icon(CupertinoIcons.photo),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppThemeColors.textStrong,
              ),
            ),
            if (fileSize.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                fileSize,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppThemeColors.textMuted,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppThemeColors.stroke),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.doc, color: AppThemeColors.textSoft, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppThemeColors.textStrong,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (fileSize.isNotEmpty)
                  Text(
                    fileSize,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppThemeColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
