import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/backend_config.dart';
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
    this.mode = ChatMode.discussion,
  });

  final ValueChanged<String> onSend;
  final String userName;
  final bool isAwaitingResponse;
  final bool isRenderingResponse;
  final ChatMode mode;

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

  Future<void> _showFileSourceSheet() async {
    final choice = await showModalBottomSheet<_FileSourceChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _FileSourceSheet(),
    );
    if (choice == null || !mounted) {
      return;
    }

    switch (choice) {
      case _FileSourceChoice.camera:
        await _pickFileWith(() => filePicker.pickImage(useCamera: true));
      case _FileSourceChoice.gallery:
        await _pickFileWith(() => filePicker.pickImage(useCamera: false));
      case _FileSourceChoice.audio:
        await _pickFileWith(() => filePicker.pickAudioFile());
    }
  }

  Future<void> _pickFileWith(
    Future<PickedFileInfo?> Function() pick,
  ) async {
    try {
      final info = await pick();
      if (info == null) {
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _attachedFile = info;
      });
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
            agentId: widget.mode == ChatMode.health
                ? BackendConfig.healthAgentId
                : null,
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

    if (widget.mode == ChatMode.health) {
      return _buildHealthComposer(context, isBusy: isBusy);
    }

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
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                decoration: BoxDecoration(
                  color: AppThemeColors.cardStrong,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppThemeColors.stroke),
                ),
                child: _isRecording
                    ? _buildRecordingBar(context, isBusy: isBusy)
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
                              onTap: isBusy ? null : _showFileSourceSheet,
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

  Widget _buildHealthComposer(BuildContext context, {required bool isBusy}) {
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                decoration: BoxDecoration(
                  color: AppThemeColors.cardStrong,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppThemeColors.stroke),
                ),
                child: _isRecording
                    ? _buildRecordingBar(context, isBusy: isBusy)
                    : Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        child: Column(
                          children: [
                            _HealthMicButton(
                              onTap: isBusy ? null : _startRecording,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Appuyez sur le micro pour enregistrer vos soucis '
                              'de santé, puis envoyez.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppThemeColors.textMuted),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingBar(BuildContext context, {required bool isBusy}) {
    return Row(
      children: [
        const SizedBox(width: 16),
        const _BlinkingRedDot(),
        const SizedBox(width: 10),
        Text(
          _formatDuration(_recordDurationSeconds),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const Expanded(
          child: Center(child: _LiveWaveform()),
        ),
        _ComposerIconBtn(
          icon: CupertinoIcons.trash,
          onTap: _cancelRecording,
          tooltip: 'Annuler',
        ),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(right: 6, bottom: 6, top: 6),
          child: _SendButton(
            onTap: isBusy ? null : _sendRecording,
            isLoading: isBusy,
          ),
        ),
      ],
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

class _HealthMicButton extends StatelessWidget {
  const _HealthMicButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = AppThemeColors.isDark ? Colors.black : Colors.white;
    return Material(
      color: onTap == null ? AppThemeColors.pill : AppThemeColors.pillSelected,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 72,
          height: 72,
          child: Icon(
            CupertinoIcons.mic_fill,
            size: 30,
            color: onTap == null ? AppThemeColors.textMuted : iconColor,
          ),
        ),
      ),
    );
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

class _LiveWaveform extends StatefulWidget {
  const _LiveWaveform();

  @override
  State<_LiveWaveform> createState() => _LiveWaveformState();
}

class _LiveWaveformState extends State<_LiveWaveform> {
  static const int _barCount = 26;
  final List<double> _levels = List.filled(_barCount, 0.06);
  StreamSubscription<double>? _amplitudeSub;
  Timer? _fallbackTimer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    final stream = audioRecorder.onAmplitude;
    if (stream != null) {
      _amplitudeSub = stream.listen((level) {
        if (!mounted) return;
        setState(() => _pushLevel(level.clamp(0.0, 1.0)));
      });
    } else {
      _fallbackTimer = Timer.periodic(const Duration(milliseconds: 90), (_) {
        if (!mounted) return;
        setState(() {
          final wave = 0.5 + 0.5 * math.sin(_index * 0.65);
          final jitter = 0.25 * (0.5 + 0.5 * math.sin(_index * 2.4 + 1.2));
          _index++;
          _pushLevel((wave * 0.72 + jitter).clamp(0.05, 1.0));
        });
      });
    }
  }

  void _pushLevel(double level) {
    for (var i = _levels.length - 1; i > 0; i--) {
      _levels[i] = _levels[i - 1];
    }
    _levels[0] = level;
  }

  @override
  void dispose() {
    _amplitudeSub?.cancel();
    _fallbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(_barCount, (index) {
        final level = _levels[index];
        final height = 6 + level * 34;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 3,
          height: height,
          decoration: BoxDecoration(
            color: AppThemeColors.accent.withValues(alpha: 0.45 + 0.55 * level),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

enum _FileSourceChoice { camera, gallery, audio }

class _FileSourceSheet extends StatelessWidget {
  const _FileSourceSheet();

  @override
  Widget build(BuildContext context) {
    final items = [
      _FileSourceItem(
        icon: CupertinoIcons.camera,
        title: 'Photo',
        subtitle: 'Prendre une photo',
        value: _FileSourceChoice.camera,
      ),
      _FileSourceItem(
        icon: CupertinoIcons.photo,
        title: 'Galerie',
        subtitle: 'Choisir une image',
        value: _FileSourceChoice.gallery,
      ),
      _FileSourceItem(
        icon: CupertinoIcons.music_note,
        title: 'Audio',
        subtitle: 'Choisir un fichier audio',
        value: _FileSourceChoice.audio,
      ),
    ];

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppThemeColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: AppThemeColors.stroke),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppThemeColors.isDark
                      ? AppThemeColors.strokeStrong
                      : AppThemeColors.stroke,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Text(
                  'Joindre un fichier',
                  style: TextStyle(
                    color: AppThemeColors.textStrong,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...List.generate(items.length, (index) {
                final item = items[index];
                return _FileSourceRow(
                  item: item,
                  isLast: index == items.length - 1,
                  onTap: () =>
                      Navigator.of(context).pop(_FileSourceChoice.values[index]),
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileSourceRow extends StatelessWidget {
  const _FileSourceRow({
    required this.item,
    required this.isLast,
    required this.onTap,
  });

  final _FileSourceItem item;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: EdgeInsets.only(left: 16, right: 16, bottom: isLast ? 4 : 2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppThemeColors.cardStrong,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppThemeColors.accentSoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                item.icon,
                size: 21,
                color: AppThemeColors.textStrong,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      color: AppThemeColors.textStrong,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      color: AppThemeColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: AppThemeColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _FileSourceItem {
  const _FileSourceItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final _FileSourceChoice value;
}
