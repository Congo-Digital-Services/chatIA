import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/audio_recorder.dart';
import '../../../core/services/file_picker.dart';
import '../../../shared/models/chat_message.dart';
import '../../../shared/models/conversation.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/app_toast.dart';
import '../providers/chat_state_provider.dart';

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

    return GestureDetector(
      onLongPress: () => _showMessageActions(context, ref),
      child: _buildBubble(context, theme, isUser),
    );
  }

  /// Affiche le menu contextuel pour modifier ou supprimer le message.
  /// Utilise les routes : PUT et DELETE /api/messages/:conversationId/:messageId
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
            color: isDarkSheet ? const Color(0xFF1C1C1C) : const Color(0xFFF5F5F5),
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
              // Copier
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
                  );
                },
              ),
              // Modifier (uniquement si l'utilisateur peut éditer)
              if (message.role == ChatRole.user)
                ListTile(
                  leading: const Icon(CupertinoIcons.pencil),
                  title: const Text('Modifier'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditDialog(context, ref, chat, conversationId);
                  },
                ),
              // Supprimer — DELETE /api/messages/:conversationId/:messageId
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

  /// Boîte de dialogue pour modifier le texte du message.
  /// Utilise PUT /api/messages/:conversationId/:messageId
  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    ChatController chat,
    String conversationId,
  ) {
    final controller = TextEditingController(text: message.text);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier le message'),
        content: TextField(
          controller: controller,
          maxLines: null,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nouveau texte…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
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
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(BuildContext context, ThemeData theme, bool isUser) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleColor = isUser
        ? (isDark ? Colors.white : Colors.black)
        : Colors.transparent;
    final textColor = isUser
        ? (isDark ? Colors.black : Colors.white)
        : (isDark ? Colors.white : Colors.black);

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
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white : Colors.black, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Audio Message
                    if (message.audioUrl != null)
                      _VoiceMessagePlayer(
                        audioUrl: message.audioUrl!,
                        isUser: true,
                      )
                    // File Message
                    else if (message.fileUrl != null)
                      _FileMessageBlock(
                        fileUrl: message.fileUrl!,
                        fileName: message.fileName ?? 'Fichier',
                        fileSize: message.fileSize ?? '',
                        isImage: message.isImage ?? false,
                        isUser: true,
                      )
                    // Regular Text Message
                    else
                      Text(
                        message.text,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: textColor,
                          height: 1.45,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Bulle assistant
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar IA
        Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(top: 2, right: 10),
          decoration: BoxDecoration(
            color: isDark ? Colors.white : Colors.black,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 14,
              color: isDark ? Colors.black : Colors.white,
            ),
          ),
        ),
        // Contenu assistant
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Audio assistant (si l'assistant répond par la voix)
                if (message.audioUrl != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppThemeColors.stroke, width: 1),
                    ),
                    child: _VoiceMessagePlayer(
                      audioUrl: message.audioUrl!,
                      isUser: false,
                    ),
                  )
                else
                  Text(
                    message.text,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppThemeColors.textStrong,
                      height: 1.55,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Lecteur de message vocal ─────────────────────────────────────────────────
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
              border: Border.all(color: isDark ? Colors.white : Colors.black, width: 1),
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
            // Waveform interactif
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
                  // Couleur waveform thème-aware
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

// ─── Bloc de fichier / image ──────────────────────────────────────────────────
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
      return GestureDetector(
        onTap: () => filePicker.openFile(fileUrl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 220),
                child: Image.network(
                  fileUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 200,
                      height: 150,
                      color: AppThemeColors.pill,
                      child: Center(
                        child: Icon(
                          CupertinoIcons.photo,
                          size: 36,
                          color: AppThemeColors.textMuted,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppThemeColors.textStrong,
              ),
            ),
            if (fileSize.isNotEmpty)
              Text(
                fileSize,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: AppThemeColors.textMuted,
                ),
              ),
          ],
        ),
      );
    }

    // Fichier régulier
    return GestureDetector(
      onTap: () => filePicker.openFile(fileUrl),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppThemeColors.cardStrong
              : AppThemeColors.card.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppThemeColors.stroke),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.doc_text_fill,
              size: 28,
              color: AppThemeColors.textSoft,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (fileSize.isNotEmpty)
                    Text(
                      fileSize,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: AppThemeColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              CupertinoIcons.arrow_down_to_line,
              size: 16,
              color: AppThemeColors.textSoft,
            ),
          ],
        ),
      ),
    );
  }
}
