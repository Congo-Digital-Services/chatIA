import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/audio_recorder.dart';
import '../../../core/services/file_picker.dart';
import '../../../shared/theme/app_theme.dart';
import '../providers/chat_state_provider.dart';

class ChatComposer extends ConsumerStatefulWidget {
  const ChatComposer({super.key, required this.onSend, required this.userName});

  final ValueChanged<String> onSend;
  final String userName;

  @override
  ConsumerState<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends ConsumerState<ChatComposer>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  late final AnimationController _sendAnim;
  late final Animation<double> _sendScale;
  late final Animation<double> _micOpacity;

  bool _hasText = false;
  bool _isRecording = false;
  int _recordDurationSeconds = 0;
  Timer? _recordTimer;
  PickedFileInfo? _attachedFile;

  @override
  void initState() {
    super.initState();
    _sendAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _sendScale = CurvedAnimation(parent: _sendAnim, curve: Curves.easeOutBack);
    _micOpacity = Tween<double>(
      begin: 1,
      end: 0,
    ).animate(CurvedAnimation(parent: _sendAnim, curve: Curves.easeIn));
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
      if (hasText) {
        _sendAnim.forward();
      } else {
        _sendAnim.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _sendAnim.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _controller.text.trim();
    if (value.isEmpty && _attachedFile == null) return;

    _controller.clear();

    if (_attachedFile != null) {
      final file = _attachedFile!;
      setState(() {
        _attachedFile = null;
      });
      await ref
          .read(chatControllerProvider)
          .sendFileMessage(
            value,
            url: file.url,
            name: file.name,
            size: file.size,
            isImage: file.isImage,
            bytes: file.bytes,
            mimeType: file.mimeType,
            width: file.width,
            height: file.height,
          );
    } else {
      widget.onSend(value);
    }
  }

  Future<void> _pickFile() async {
    final info = await filePicker.pickFile();
    if (info != null) {
      setState(() {
        _attachedFile = info;
      });
    }
  }

  void _startRecordingTimer() {
    _recordDurationSeconds = 0;
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordDurationSeconds++;
      });
    });
  }

  void _stopRecordingTimer() {
    _recordTimer?.cancel();
    _recordTimer = null;
  }

  String _formatDuration(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _startRecording() async {
    await audioRecorder.startRecording();
    setState(() {
      _isRecording = true;
    });
    _startRecordingTimer();
  }

  Future<void> _cancelRecording() async {
    await audioRecorder.stopRecording();
    _stopRecordingTimer();
    setState(() {
      _isRecording = false;
      _recordDurationSeconds = 0;
    });
  }

  Future<void> _sendRecording() async {
    final durationText = _formatDuration(_recordDurationSeconds);
    final audio = await audioRecorder.stopRecording();
    _stopRecordingTimer();
    setState(() {
      _isRecording = false;
      _recordDurationSeconds = 0;
    });
    if (audio != null) {
      await ref
          .read(chatControllerProvider)
          .sendVoiceMessage(
            audio.url,
            durationText,
            bytes: audio.bytes,
            mimeType: audio.mimeType,
            name: audio.name,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Utilisateur en-tête
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 8),
            child: Text(
              widget.userName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppThemeColors.textMuted,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
          ),

          // Pièce jointe aperçu
          if (_attachedFile != null && !_isRecording)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppThemeColors.cardStrong
                      : AppThemeColors.pill,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppThemeColors.stroke),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _attachedFile!.isImage
                          ? CupertinoIcons.photo
                          : CupertinoIcons.doc,
                      size: 16,
                      color: AppThemeColors.textSoft,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _attachedFile!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppThemeColors.textStrong,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _attachedFile!.size,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: AppThemeColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _attachedFile = null;
                        });
                      },
                      child: Icon(
                        CupertinoIcons.multiply,
                        size: 14,
                        color: AppThemeColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: isDark ? AppThemeColors.card : AppThemeColors.card,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppThemeColors.stroke, width: 1),
            ),
            child: _isRecording
                ? Row(
                    children: [
                      const SizedBox(width: 16),
                      const _BlinkingRedDot(),
                      const SizedBox(width: 8),
                      Text(
                        _formatDuration(_recordDurationSeconds),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Expanded(child: Center(child: _BouncingWaveform())),
                      _ComposerIconBtn(
                        icon: CupertinoIcons.trash,
                        onTap: _cancelRecording,
                        tooltip: 'Annuler',
                      ),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(
                          right: 6,
                          bottom: 6,
                          top: 6,
                        ),
                        child: Material(
                          color: AppThemeColors.textStrong,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _sendRecording,
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Icon(
                                CupertinoIcons.arrow_up,
                                // L'icone doit contraster avec textStrong:
                                // mode clair: textStrong=noir => icone blanche
                                // mode sombre: textStrong=blanc => icone noire
                                color: isDark ? Colors.black : Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Bouton + (attacher fichier)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 6,
                          bottom: 6,
                          top: 6,
                        ),
                        child: _ComposerIconBtn(
                          icon: CupertinoIcons.add,
                          onTap: _pickFile,
                          tooltip: 'Joindre un fichier',
                        ),
                      ),
                      // Champ de texte
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 5,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: 'Message…',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 14,
                            ),
                            hintStyle: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: AppThemeColors.textMuted,
                                  fontWeight: FontWeight.w400,
                                ),
                          ),
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: AppThemeColors.textStrong,
                                height: 1.45,
                              ),
                        ),
                      ),
                      // Bouton micro — se cache quand on tape ou qu'il y a un fichier
                      if (_controller.text.trim().isEmpty &&
                          _attachedFile == null)
                        FadeTransition(
                          opacity: _micOpacity,
                          child: IgnorePointer(
                            ignoring: _hasText || _attachedFile != null,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                right: 4,
                                bottom: 6,
                                top: 6,
                              ),
                              child: _ComposerIconBtn(
                                icon: CupertinoIcons.mic,
                                onTap: _startRecording,
                                tooltip: 'Dicter',
                              ),
                            ),
                          ),
                        ),
                      // Bouton Envoyer — apparaît quand on tape ou qu'il y a un fichier
                      if (_controller.text.trim().isNotEmpty ||
                          _attachedFile != null)
                        ScaleTransition(
                          scale: _sendScale,
                          child: Padding(
                            padding: const EdgeInsets.only(
                              right: 6,
                              bottom: 6,
                              top: 6,
                            ),
                            child: _SendButton(onTap: _submit),
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

// ─── Bouton icône uniforme (44×44) dans le composer ──────────────────────────
class _ComposerIconBtn extends StatelessWidget {
  const _ComposerIconBtn({
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
    final button = Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
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
    );

    if (tooltip.isEmpty) {
      return button;
    }

    return Tooltip(message: tooltip, excludeFromSemantics: true, child: button);
  }
}

// ─── Bouton Envoyer (flèche vers le haut, fond noir) ─────────────────────────
class _SendButton extends StatelessWidget {
  const _SendButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // L'icone doit contraster avec la couleur de fond textStrong
    final iconColor = isDark ? Colors.black : Colors.white;
    return Material(
      color: AppThemeColors.textStrong,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(CupertinoIcons.arrow_up, color: iconColor, size: 20),
        ),
      ),
    );
  }
}

// ─── Point rouge clignotant pour l'enregistrement ───────────────────────────
class _BlinkingRedDot extends StatefulWidget {
  const _BlinkingRedDot();

  @override
  State<_BlinkingRedDot> createState() => _BlinkingRedDotState();
}

class _BlinkingRedDotState extends State<_BlinkingRedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─── Onde vocale qui rebondit pour l'enregistrement ─────────────────────────
class _BouncingWaveform extends StatefulWidget {
  const _BouncingWaveform();

  @override
  State<_BouncingWaveform> createState() => _BouncingWaveformState();
}

class _BouncingWaveformState extends State<_BouncingWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  final List<double> _heights = [12, 24, 16, 30, 20, 26, 14, 18, 22, 10];

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_heights.length, (index) {
            final double value = _anim.value;
            final double h = _heights[index] * (0.4 + 0.6 * value);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 3,
              height: h,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(1.5),
              ),
            );
          }),
        );
      },
    );
  }
}
