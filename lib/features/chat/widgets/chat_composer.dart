import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/audio_recorder.dart';
import '../../../core/services/file_picker.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/app_toast.dart';
import '../providers/chat_state_provider.dart';
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        
class ChatComposer extends ConsumerStatefulWidget {
  const ChatComposer({
    super.key, 
    required this.onSend,
    required this.userName,
    required this.isAwaitingResponse,
    required this.isRenderingResponse,
  });

  final ValueChanged<String> onSend;
  final String userName;
  final bool isAwaitingResponse;
  final bool isRenderingResponse;

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
    if (hasText == _hasText) {
      return;
    }
    setState(() => _hasText = hasText);
    if (hasText) {
      _sendAnim.forward();
      return;
    }
    _sendAnim.reverse();
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
    if (value.isEmpty && _attachedFile == null) {
      return;
    }
    final chat = ref.read(chatControllerProvider);
    if (chat.isStreaming) {
      return;
    }

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
      return;
    }

    widget.onSend(value);
  }

  Future<void> _pickFile() async {
    try {
      final info = await filePicker.pickFile();
      if (info == null) {
        return;
      }
      setState(() {
        _attachedFile = info;
      });
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: 'Fichier prêt à être envoyé.',
        type: AppToastType.info,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: 'Impossible de joindre le fichier.',
        type: AppToastType.error,
      );
    }
  }

  void _startRecordingTimer() {
    _recordDurationSeconds = 0;
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
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
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _startRecording() async {
    try {
      await audioRecorder.startRecording();
      setState(() {
        _isRecording = true;
      });
      _startRecordingTimer();
    } catch (_) {
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: 'Impossible de démarrer l’enregistrement.',
        type: AppToastType.error,
      );
    }
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
    try {
      final audio = await audioRecorder.stopRecording();
      _stopRecordingTimer();
      setState(() {
        _isRecording = false;
        _recordDurationSeconds = 0;
      });
      if (audio == null) {
        return;
      }
      await ref
          .read(chatControllerProvider)
          .sendVoiceMessage(
            audio.url,
            durationText,
            bytes: audio.bytes,
            mimeType: audio.mimeType,
            name: audio.name,
          );
    } catch (_) {
      _stopRecordingTimer();
      setState(() {
        _isRecording = false;
        _recordDurationSeconds = 0;
      });
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: 'Impossible d’envoyer le message vocal.',
        type: AppToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider);
    final isBusy = chat.isStreaming;
    final hasAction =
        _controller.text.trim().isNotEmpty || _attachedFile != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppThemeColors.background,
          border: Border(top: BorderSide(color: AppThemeColors.stroke)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_attachedFile != null && !_isRecording)
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 8, bottom: 10),
                  child: _AttachmentPreview(
                    file: _attachedFile!,
                    onRemove: () {
                      setState(() {
                        _attachedFile = null;
                      });
                    },
                  ),
                ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: widget.isAwaitingResponse || widget.isRenderingResponse
                    ? Padding(
                        key: ValueKey(
                          widget.isAwaitingResponse
                              ? 'awaiting-status'
                              : 'rendering-status',
                        ),
                        padding: const EdgeInsets.only(
                          left: 8,
                          right: 8,
                          bottom: 10,
                        ),
                        child: _ComposerStatus(
                          label: widget.isAwaitingResponse
                              ? 'En attente de la réponse…'
                              : 'LoBa rédige sa réponse…',
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                decoration: BoxDecoration(
                  color: AppThemeColors.cardStrong,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppThemeColors.stroke),
                ),
                child: _isRecording
                    ? Row(
                        children: [
                          const SizedBox(width: 16),
                          const _BlinkingRedDot(),
                          const SizedBox(width: 10),
                          Text(
                            _formatDuration(_recordDurationSeconds),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const Expanded(
                            child: Center(child: _BouncingWaveform()),
                          ),
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
                            child: _SendButton(
                              onTap: isBusy ? null : _sendRecording,
                              isLoading: isBusy,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 6,
                              bottom: 6,
                              top: 6,
                            ),
                            child: _ComposerIconBtn(
                              icon: CupertinoIcons.add,
                              onTap: isBusy ? null : _pickFile,
                              tooltip: 'Joindre un fichier',
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              enabled: !isBusy,
                              minLines: 1,
                              maxLines: 5,
                              textInputAction: TextInputAction.newline,
                              onSubmitted: (_) {
                                if (_controller.text.trim().isNotEmpty) {
                                  _submit();
                                }
                              },
                              decoration: InputDecoration(
                                hintText: 'Posez une question ',
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 15,
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
                          if (!hasAction)
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
                                    onTap: isBusy ? null : _startRecording,
                                    tooltip: 'Dicter',
                                  ),
                                ),
                              ),
                            ),
                          if (hasAction)
                            ScaleTransition(
                              scale: _sendScale,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  right: 6,
                                  bottom: 6,
                                  top: 6,
                                ),
                                child: _SendButton(
                                  onTap: isBusy ? null : _submit,
                                  isLoading: false,
                                ),
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

class _ComposerStatus extends StatefulWidget {
  const _ComposerStatus({required this.label});

  final String label;

  @override
  State<_ComposerStatus> createState() => _ComposerStatusState();
}

class _ComposerStatusState extends State<_ComposerStatus>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppThemeColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppThemeColors.stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CircularProgressIndicator(
                  value: null,
                  strokeWidth: 1.8,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppThemeColors.textSoft.withValues(
                      alpha: 0.6 + (_controller.value * 0.4),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppThemeColors.textSoft,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({required this.file, required this.onRemove});

  final PickedFileInfo file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppThemeColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppThemeColors.stroke),
        boxShadow: AppThemeShadows.soft,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppThemeColors.accentSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              file.isImage ? CupertinoIcons.photo : CupertinoIcons.doc,
              size: 16,
              color: AppThemeColors.accent,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppThemeColors.textStrong,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            file.size,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppThemeColors.textMuted),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              CupertinoIcons.xmark,
              size: 14,
              color: AppThemeColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerIconBtn extends StatelessWidget {
  const _ComposerIconBtn({
    required this.icon,
    required this.onTap,
    this.tooltip = '',
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: AppThemeColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 20, color: AppThemeColors.textStrong),
        ),
      ),
    );

    if (tooltip.isEmpty) {
      return button;
    }

    return Tooltip(message: tooltip, excludeFromSemantics: true, child: button);
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onTap, this.isLoading = false});

  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final iconColor = AppThemeColors.isDark ? Colors.black : Colors.white;
    return Material(
      color: onTap == null ? AppThemeColors.pill : AppThemeColors.textStrong,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                    ),
                  )
                : Icon(CupertinoIcons.arrow_up, color: iconColor, size: 20),
          ),
        ),
      ),
    );
  }
}

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
        decoration: BoxDecoration(
          color: AppThemeColors.danger,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

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
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_heights.length, (index) {
            final value = _anim.value;
            final height = _heights[index] * (0.4 + 0.6 * value);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 3,
              height: height,
              decoration: BoxDecoration(
                color: AppThemeColors.accent.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        );
      },
    );
  }
}
