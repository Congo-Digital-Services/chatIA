import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/backend_config.dart';
import '../../../core/services/audio_recorder.dart';
import '../../../core/services/file_picker.dart';
import '../../../shared/theme/app_motion.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/chat_state_provider.dart';
import 'health_voice_session.dart';
import '../../../shared/widgets/maloba_glyph.dart';

class ChatComposer extends ConsumerStatefulWidget {
  const ChatComposer({
    super.key,
    required this.onSend,
    required this.userName,
    required this.isAwaitingResponse,
    required this.isRenderingResponse,
    this.mode = ChatMode.discussion,
    this.onHealthSend,
  });

  final ValueChanged<String> onSend;
  final String userName;
  final bool isAwaitingResponse;
  final bool isRenderingResponse;
  final ChatMode mode;

  /// Appelé juste avant l'envoi d'un message dicté en mode Santé.
  final VoidCallback? onHealthSend;

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
  bool _isTranscribing = false;
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
    _sendScale = CurvedAnimation(parent: _sendAnim, curve: AppMotion.easeOut);
    _micOpacity = Tween<double>(
      begin: 1,
      end: 0,
    ).animate(CurvedAnimation(parent: _sendAnim, curve: AppMotion.easeOut));
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

  Future<void> _pickFileWith(Future<PickedFileInfo?> Function() pick) async {
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
    // Dictée relue : la transcription va dans la zone de saisie, l'utilisateur
    // la corrige puis envoie. Le mode Santé garde l'envoi direct historique.
    final reviewFirst =
        widget.mode != ChatMode.health &&
        ref.read(settingsControllerProvider).reviewVoiceBeforeSend;
    if (reviewFirst) {
      await _transcribeRecordingToInput();
      return;
    }
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

  /// Mode Santé : dictée plein écran transcrite en direct, puis envoi du
  /// texte relu à l'agent Santé. Si le micro ne démarre pas, l'écran le dit
  /// et permet d'écrire le message à la main.
  Future<void> _openHealthSession() async {
    final text = await HealthVoiceSession.open(context);
    if (!mounted || text == null || text.trim().isEmpty) {
      return;
    }
    widget.onHealthSend?.call();
    await ref
        .read(chatControllerProvider)
        .sendMessageAsAgent(text, agentId: BackendConfig.healthAgentId);
  }

  Future<void> _transcribeRecordingToInput() async {
    RecordedAudioInfo? audio;
    try {
      audio = await audioRecorder.stopRecording();
    } catch (_) {
      audio = null;
    }
    _stopRecordingTimer();
    if (!mounted) {
      return;
    }
    setState(() {
      _isRecording = false;
      _recordDurationSeconds = 0;
    });
    final bytes = audio?.bytes;
    if (audio == null || bytes == null || bytes.isEmpty) {
      showAppToast(
        context,
        message: 'Aucun son enregistré.',
        type: AppToastType.error,
      );
      return;
    }

    setState(() => _isTranscribing = true);
    try {
      final text = await ref
          .read(chatControllerProvider)
          .transcribeVoice(bytes: bytes, filename: audio.name);
      if (!mounted) {
        return;
      }
      final existing = _controller.text.trimRight();
      final merged = existing.isEmpty ? text : '$existing $text';
      _controller.value = TextEditingValue(
        text: merged,
        selection: TextSelection.collapsed(offset: merged.length),
      );
      showAppToast(
        context,
        message: 'Transcription terminée. Relisez puis envoyez.',
        type: AppToastType.success,
        iconOnly: true,
      );
    } on VoiceTranscriptionException catch (error) {
      if (mounted) {
        showAppToast(context, message: error.message, type: AppToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isTranscribing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider);
    final isBusy = chat.isStreaming;
    final hasAction =
        _controller.text.trim().isNotEmpty || _attachedFile != null;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    if (widget.mode == ChatMode.health) {
      return _buildHealthComposer(
        context,
        isBusy: isBusy,
        isLandscape: isLandscape,
      );
    }

    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: EdgeInsets.fromLTRB(16, 0, 16, isLandscape ? 8 : 18),
      child: DecoratedBox(
        decoration: BoxDecoration(color: AppThemeColors.background),
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
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppThemeColors.stroke),
                  boxShadow: AppThemeShadows.soft,
                ),
                child: AnimatedSwitcher(
                  duration: AppMotion.duration(context, AppMotion.fast),
                  switchInCurve: AppMotion.easeOut,
                  switchOutCurve: AppMotion.easeOut,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.98,
                        end: 1,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: _isRecording
                      ? KeyedSubtree(
                          key: const ValueKey('enregistrement'),
                          child: _buildRecordingBar(context, isBusy: isBusy),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('saisie'),
                          child: Row(
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
                                    hintText: _isTranscribing
                                        ? 'Transcription en cours…'
                                        : 'Posez une question ',
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 15,
                                    ),
                                    hintStyle: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
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
                              if (isBusy)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    right: 6,
                                    bottom: 6,
                                    top: 6,
                                  ),
                                  child: _StopButton(
                                    onTap: () => ref
                                        .read(chatControllerProvider)
                                        .cancelStreaming(),
                                  ),
                                )
                              else if (!hasAction)
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
                                        onTap: isBusy || _isTranscribing
                                            ? null
                                            : _startRecording,
                                        tooltip: 'Dicter',
                                      ),
                                    ),
                                  ),
                                )
                              else if (hasAction)
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthComposer(
    BuildContext context, {
    required bool isBusy,
    required bool isLandscape,
  }) {
    // Mode Santé : le micro seul, sans boîte autour. L'enregistrement se fait
    // dans l'écran plein de dictée (HealthVoiceSession), pas dans le composeur.
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, isLandscape ? 8 : 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HealthMicButton(
            onTap: isBusy || _isTranscribing ? null : _openHealthSession,
          ),
          const SizedBox(height: 10),
          Text(
            'Touchez pour parler',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppThemeColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingBar(BuildContext context, {required bool isBusy}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 340;
        return Row(
          children: [
            SizedBox(width: compact ? 10 : 16),
            const _BlinkingRedDot(),
            const SizedBox(width: 8),
            Text(
              _formatDuration(_recordDurationSeconds),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            // Écran étroit : onde plus courte plutôt que masquée.
            Expanded(
              child: Center(
                child: compact
                    ? const _LiveWaveform(barCount: 12)
                    : const _LiveWaveform(),
              ),
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
      },
    );
  }
}

class _StopButton extends StatelessWidget {
  const _StopButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Arrêter la réponse',
    child: Material(
      color: const Color(0xFFFFE9E7),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            CupertinoIcons.stop_fill,
            size: 18,
            color: Color(0xFFCC3B32),
          ),
        ),
      ),
    ),
  );
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
    final iconColor = AppThemeColors.onAccent;
    return PressScale(
      enabled: onTap != null,
      child: Material(
        color: onTap == null ? AppThemeColors.pill : AppThemeColors.accent,
        shape: const CircleBorder(),
        elevation: onTap == null ? 0 : 3,
        shadowColor: AppThemeColors.accent.withValues(alpha: 0.35),
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
    final iconColor = onTap == null
        ? AppThemeColors.textMuted
        : AppThemeColors.onAccent;
    return PressScale(
      enabled: onTap != null,
      child: Material(
        color: onTap == null ? AppThemeColors.pill : AppThemeColors.accent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: isLoading
                  ? MalobaLoader(size: 20, color: iconColor)
                  : Icon(CupertinoIcons.arrow_up, color: iconColor, size: 20),
            ),
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
  const _LiveWaveform({this.barCount = 26});

  final int barCount;

  @override
  State<_LiveWaveform> createState() => _LiveWaveformState();
}

class _LiveWaveformState extends State<_LiveWaveform> {
  late final List<double> _levels = List.filled(widget.barCount, 0.06);
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
      children: List.generate(_levels.length, (index) {
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
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppThemeColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppThemeColors.stroke)),
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
                  onTap: () => Navigator.of(
                    context,
                  ).pop(_FileSourceChoice.values[index]),
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
