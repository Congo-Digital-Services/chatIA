import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/audio_recorder.dart';
import '../../../core/services/file_picker.dart';
import '../../../shared/models/chat_message.dart';
import '../../../shared/theme/app_theme.dart';

class MessageBubble extends ConsumerWidget {
  const MessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.role == ChatRole.user;
    final theme = Theme.of(context);

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
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppThemeColors.cardStrong
                      : AppThemeColors.pill,
                  borderRadius: BorderRadius.circular(22),
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
                          color: AppThemeColors.textStrong,
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
            color: AppThemeColors.textStrong,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 14,
              color: Colors.white,
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
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppThemeColors.cardStrong
                          : AppThemeColors.card.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppThemeColors.stroke),
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
    final btnBgColor = widget.isUser
        ? Colors.black87
        : AppThemeColors.pillSelected;

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
            ),
            child: Icon(
              _isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
              size: 16,
              color: widget.isUser ? Colors.white : AppThemeColors.textStrong,
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
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    width: 2.5,
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: filled
                          ? (widget.isUser
                                ? Colors.black87
                                : AppThemeColors.accent)
                          : (widget.isUser ? Colors.black26 : Colors.black12),
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
                    ? Colors.black54
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
                      color: Colors.black12,
                      child: const Center(
                        child: Icon(
                          CupertinoIcons.photo,
                          size: 36,
                          color: Colors.grey,
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
