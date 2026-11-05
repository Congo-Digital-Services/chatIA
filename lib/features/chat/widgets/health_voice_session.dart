import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/live_transcriber.dart';
import '../../../shared/theme/app_motion.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/maloba_glyph.dart';
import '../providers/chat_state_provider.dart';

enum _Phase { starting, listening, finishing, review }

/// Écran plein de dictée Santé, dans l'esprit de Gemini Live : fond sombre,
/// halo qui suit la voix, parole lingala transcrite puis traduite en français
/// au fur et à mesure (français en grand, lingala en petit au-dessus).
/// Rend le texte lingala (relu et corrigé) à envoyer, ou `null` si
/// l'utilisateur annule.
class HealthVoiceSession extends ConsumerStatefulWidget {
  const HealthVoiceSession({super.key});

  static Future<String?> open(BuildContext context) {
    final duration = AppMotion.duration(context, AppMotion.enter);
    return Navigator.of(context).push<String>(
      PageRouteBuilder<String>(
        transitionDuration: duration,
        reverseTransitionDuration: duration,
        pageBuilder: (_, _, _) => const HealthVoiceSession(),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: AppMotion.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  ConsumerState<HealthVoiceSession> createState() => _HealthVoiceSessionState();
}

class _HealthVoiceSessionState extends ConsumerState<HealthVoiceSession> {
  static const _fondHaut = Color(0xFF0C1412);
  static const _fondBas = Color(0xFF050807);

  late final LiveTranscriber _live = LiveTranscriber(
    transcribe: (wav) => ref
        .read(chatControllerProvider)
        .transcribeVoice(bytes: wav, filename: 'segment.wav'),
  );
  final TextEditingController _review = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Timer? _tick;
  _Phase _phase = _Phase.starting;
  String? _startError;
  String _reviewPrefix = ''; // texte déjà relu avant une reprise de la dictée
  String _reviewPrefixFr = ''; // sa traduction
  int _firstSegmentOfTake = 0;

  // Traduction ln -> fr, passage par passage, dans l'ordre de la dictée.
  final Map<int, String> _fr = {};
  final Map<int, String> _frSource = {}; // texte lingala traduit
  final Set<int> _frFailed = {};
  final List<int> _frQueue = [];
  bool _frBusy = false;

  // Relecture : traduction du texte relu, refaite à la demande s'il change.
  String _reviewFr = '';
  String _reviewFrSource = '';
  bool _reviewFrBusy = false;
  bool _reviewFrFailed = false;

  /// Traduction au fil de la dictée (lingala -> français). Activée par
  /// défaut depuis que le service a un modèle propre au sens ln→fr (v2.3.0,
  /// testé le 05/11/2026). Le choix de l'utilisateur est mémorisé.
  static const _prefTranslate = 'health_auto_translate';
  bool _translateOn = true;

  @override
  void initState() {
    super.initState();
    _live.addListener(_onLiveChanged);
    _loadTranslatePreference();
    _startListening();
  }

  Future<void> _loadTranslatePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_prefTranslate) ?? true;
      if (mounted && saved != _translateOn) _setTranslate(saved, save: false);
    } catch (_) {
      // Préférences indisponibles : on garde la valeur par défaut (ON).
    }
  }

  void _setTranslate(bool value, {bool save = true}) {
    setState(() {
      _translateOn = value;
      if (!value) _frQueue.clear(); // une traduction en cours se termine seule
    });
    if (value) {
      _scheduleTranslations();
      if (_phase == _Phase.review && _reviewFr.isEmpty) _retranslateReview();
    }
    if (save) {
      SharedPreferences.getInstance()
          .then((prefs) => prefs.setBool(_prefTranslate, value))
          .catchError((_) => false);
    }
  }

  Future<void> _startListening() async {
    try {
      _firstSegmentOfTake = _live.segments.length;
      await _live.start();
      if (!mounted) return;
      setState(() => _phase = _Phase.listening);
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _startError = error.toString().replaceFirst('Exception: ', '');
          _phase = _Phase.review;
        });
      }
    }
  }

  void _onLiveChanged() {
    if (!mounted) return;
    _scheduleTranslations();
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: AppMotion.duration(context, AppMotion.base),
          curve: AppMotion.easeOut,
        );
      }
    });
  }

  // Sens imposé ln→fr, et non détecté : la dictée passe par Whisper, qui
  // force language=ln côté serveur ; le texte est donc toujours du lingala, et
  // la détection automatique classerait « Nazali na fièvre » en français.
  Future<String> _translate(String text) => ref
      .read(chatControllerProvider)
      .translateText(text, lingalaToFrench: true);

  /// Met en file chaque passage transcrit pas encore traduit (ou dont le
  /// texte a changé après un nouvel essai de transcription).
  void _scheduleTranslations() {
    if (!_translateOn) return;
    for (final segment in _live.segments) {
      final text = segment.text.trim();
      if (segment.status != LiveSegmentStatus.done || text.isEmpty) continue;
      if (_frSource[segment.index] == text ||
          _frQueue.contains(segment.index)) {
        continue;
      }
      _frFailed.remove(segment.index);
      _frQueue.add(segment.index);
    }
    _pumpTranslations();
  }

  Future<void> _pumpTranslations() async {
    if (_frBusy) return;
    _frBusy = true;
    try {
      while (_frQueue.isNotEmpty && mounted) {
        final index = _frQueue.removeAt(0);
        final segment = _live.segments
            .where((s) => s.index == index)
            .firstOrNull;
        final text = segment?.text.trim() ?? '';
        if (text.isEmpty) continue;
        try {
          final fr = await _translate(text);
          if (fr.isEmpty) throw Exception('traduction vide');
          _fr[index] = fr;
          _frSource[index] = text;
        } catch (_) {
          _frFailed.add(index);
          _frSource[index] = text; // pas de nouvel essai automatique
        }
        if (mounted) setState(() {});
      }
    } finally {
      _frBusy = false;
    }
  }

  /// Attend la fin des traductions en cours (au plus [limit]).
  Future<void> _waitTranslations({
    Duration limit = const Duration(seconds: 20),
  }) async {
    final end = DateTime.now().add(limit);
    while ((_frBusy || _frQueue.isNotEmpty) && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  String _takeTranslation() => _live.segments
      .skip(_firstSegmentOfTake)
      .where((s) => s.status == LiveSegmentStatus.done && s.text.isNotEmpty)
      .map((s) => _fr[s.index] ?? '')
      .where((t) => t.isNotEmpty)
      .join(' ');

  void _enterReview(String text) {
    final fr = [
      _reviewPrefixFr,
      _takeTranslation(),
    ].where((t) => t.trim().isNotEmpty).join(' ');
    _review.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _reviewFr = fr;
    _reviewFrSource = fr.isEmpty ? '' : text;
    _reviewFrFailed = false;
    setState(() => _phase = _Phase.review);
  }

  Future<void> _retranslateReview() async {
    final text = _review.text.trim();
    if (text.isEmpty || _reviewFrBusy) return;
    setState(() {
      _reviewFrBusy = true;
      _reviewFrFailed = false;
    });
    try {
      final fr = await _translate(text);
      if (!mounted) return;
      setState(() {
        _reviewFr = fr;
        _reviewFrSource = text;
        _reviewFrFailed = fr.isEmpty;
      });
    } catch (_) {
      if (mounted) setState(() => _reviewFrFailed = true);
    } finally {
      if (mounted) setState(() => _reviewFrBusy = false);
    }
  }

  String _takeTranscript() => _live.segments
      .skip(_firstSegmentOfTake)
      .where((s) => s.status == LiveSegmentStatus.done && s.text.isNotEmpty)
      .map((s) => s.text)
      .join(' ');

  Future<void> _finish() async {
    _tick?.cancel();
    setState(() => _phase = _Phase.finishing);
    await _live.finish();
    _scheduleTranslations();
    if (_translateOn) await _waitTranslations();
    if (!mounted) return;
    final take = _takeTranscript();
    final text = [
      _reviewPrefix,
      take,
    ].where((t) => t.trim().isNotEmpty).join(' ');
    _enterReview(text);
  }

  Future<void> _resumeDictation() async {
    _reviewPrefix = _review.text.trim();
    _reviewPrefixFr = _reviewFrSource == _reviewPrefix ? _reviewFr : '';
    setState(() {
      _startError = null;
      _phase = _Phase.starting;
    });
    await _startListening();
  }

  Future<void> _retry() async {
    setState(() => _phase = _Phase.finishing);
    await _live.retryFailed();
    _scheduleTranslations();
    if (_translateOn) await _waitTranslations();
    if (!mounted) return;
    final take = _takeTranscript();
    final text = [
      _reviewPrefix,
      take,
    ].where((t) => t.trim().isNotEmpty).join(' ');
    _enterReview(text);
  }

  Future<void> _cancel() async {
    _tick?.cancel();
    await _live.cancel();
    if (mounted) Navigator.of(context).pop();
  }

  void _send() {
    final text = _review.text.trim();
    if (text.isNotEmpty) Navigator.of(context).pop(text);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _live.removeListener(_onLiveChanged);
    _live.dispose();
    _review.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _clock(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        backgroundColor: _fondBas,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_fondHaut, _fondBas],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: _VoiceGlow(
                    level: _live.level,
                    active: _phase == _Phase.listening && !_live.isPaused,
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    _header(theme),
                    Expanded(
                      child: _phase == _Phase.review
                          ? _reviewEditor(theme)
                          : _liveText(theme),
                    ),
                    if (_live.lastError != null && _phase != _Phase.review)
                      _ErrorPill(message: _live.lastError!),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                      child: _controls(theme),
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

  Widget _header(ThemeData theme) {
    final listening = _phase == _Phase.listening && !_live.isPaused;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Annuler',
            onPressed: _cancel,
            icon: const Icon(CupertinoIcons.xmark, color: Colors.white70),
          ),
          const Spacer(),
          AnimatedContainer(
            duration: AppMotion.duration(context, AppMotion.base),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: listening ? const Color(0xFFFF5A5A) : Colors.white30,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _phase == _Phase.review
                ? 'Relisez avant d’envoyer'
                : _live.isPaused
                ? 'En pause · ${_clock(_live.elapsed)}'
                : 'Santé · en direct · ${_clock(_live.elapsed)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          _TranslateToggle(
            enabled: _translateOn,
            onChanged: (v) => _setTranslate(v),
          ),
        ],
      ),
    );
  }

  Widget _liveText(ThemeData theme) {
    final segments = _live.segments.skip(_firstSegmentOfTake).toList();
    final french = theme.textTheme.headlineSmall?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w500,
      height: 1.35,
      letterSpacing: -0.2,
    );
    final lingala = _translateOn
        ? theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white54,
            height: 1.4,
          )
        : french;
    if (_reviewPrefix.isEmpty && segments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _phase == _Phase.starting
                ? 'Ouverture du micro…'
                : _translateOn
                ? 'Parlez en lingala, je traduis en français…'
                : 'Parlez en lingala, je vous écoute…',
            textAlign: TextAlign.center,
            style: french?.copyWith(color: Colors.white54),
          ),
        ),
      );
    }
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      children: [
        if (_reviewPrefix.isNotEmpty)
          _Passage(
            lingala: _reviewPrefix,
            lingalaStyle: lingala,
            french: !_translateOn || _reviewPrefixFr.isEmpty
                ? null
                : Text(
                    _reviewPrefixFr,
                    style: french?.copyWith(color: Colors.white60),
                  ),
          ),
        for (final segment in segments)
          EnterOnce(
            key: ValueKey('segment-${segment.index}'),
            animate: true,
            child: switch (segment.status) {
              LiveSegmentStatus.pending => const Padding(
                padding: EdgeInsets.only(bottom: 18),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: MalobaLoader(
                    size: 30,
                    semanticLabel: 'Transcription en cours',
                  ),
                ),
              ),
              LiveSegmentStatus.failed => Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.exclamationmark_circle,
                      size: 18,
                      color: Colors.white38,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Passage non transcrit',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
              LiveSegmentStatus.done => _Passage(
                lingala: segment.text,
                lingalaStyle: lingala,
                french: !_translateOn
                    ? null
                    : _fr[segment.index] != null
                    ? Text(_fr[segment.index]!, style: french)
                    : _frFailed.contains(segment.index)
                    ? Text(
                        'Traduction indisponible pour ce passage',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white38,
                        ),
                      )
                    : const MalobaLoader(
                        size: 24,
                        color: Colors.white70,
                        semanticLabel: 'Traduction en cours',
                      ),
              ),
            },
          ),
      ],
    );
  }

  Widget _reviewEditor(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_startError != null)
            _ErrorPill(message: _startError!)
          else if (_live.hasFailures)
            _ErrorPill(
              message:
                  _live.lastError ?? 'Une partie n’a pas pu être transcrite.',
            ),
          if (_translateOn) ...[
            _Label('Français'),
            Flexible(
              flex: 5,
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _review,
                builder: (context, value, _) {
                  final stale =
                      value.text.trim().isNotEmpty &&
                      value.text.trim() != _reviewFrSource.trim();
                  return _FrenchPanel(
                    text: _reviewFr,
                    busy: _reviewFrBusy,
                    failed: _reviewFrFailed,
                    stale: stale,
                    onRetranslate: stale || _reviewFrFailed
                        ? _retranslateReview
                        : null,
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
          ],
          _Label(
            _translateOn
                ? 'Lingala · modifiable, c’est ce texte qui est envoyé'
                : 'Lingala · modifiable avant l’envoi',
          ),
          Expanded(
            flex: 4,
            child: TextField(
              controller: _review,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style:
                  (_translateOn
                          ? theme.textTheme.bodyLarge
                          : theme.textTheme.titleLarge)
                      ?.copyWith(
                        color: _translateOn ? Colors.white70 : Colors.white,
                        height: 1.45,
                      ),
              cursorColor: AppThemeColors.accent,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                hintText: 'Aucun texte reconnu. Écrivez ou reprenez la dictée.',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white38,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: AppThemeColors.accent,
                    width: 1.4,
                  ),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controls(ThemeData theme) {
    switch (_phase) {
      case _Phase.starting:
      case _Phase.finishing:
        return SizedBox(
          height: 72,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const MalobaLoader(size: 26),
              const SizedBox(width: 12),
              Text(
                _phase == _Phase.starting
                    ? 'Ouverture du micro…'
                    : 'Finalisation de la traduction…',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        );
      case _Phase.listening:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _RoundAction(
              icon: CupertinoIcons.xmark,
              label: 'Annuler',
              onTap: _cancel,
            ),
            _RoundAction(
              icon: _live.isPaused
                  ? CupertinoIcons.mic_fill
                  : CupertinoIcons.pause_fill,
              label: _live.isPaused ? 'Reprendre' : 'Pause',
              onTap: () => _live.isPaused ? _live.resume() : _live.pause(),
            ),
            _RoundAction(
              icon: CupertinoIcons.checkmark_alt,
              label: 'Terminer',
              onTap: _finish,
              primary: true,
            ),
          ],
        );
      case _Phase.review:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _RoundAction(
              icon: CupertinoIcons.mic_fill,
              label: 'Reprendre',
              onTap: _resumeDictation,
            ),
            if (_live.hasFailures && _startError == null)
              _RoundAction(
                icon: CupertinoIcons.arrow_clockwise,
                label: 'Réessayer',
                onTap: _retry,
              ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _review,
              builder: (context, value, _) => _RoundAction(
                icon: CupertinoIcons.arrow_up,
                label: 'Envoyer',
                onTap: value.text.trim().isEmpty ? null : _send,
                primary: true,
              ),
            ),
          ],
        );
    }
  }
}

/// Halo au bas de l'écran qui grandit avec la voix (retour « je vous entends »).
class _VoiceGlow extends StatefulWidget {
  const _VoiceGlow({required this.level, required this.active});

  final ValueNotifier<double> level;
  final bool active;

  @override
  State<_VoiceGlow> createState() => _VoiceGlowState();
}

class _VoiceGlowState extends State<_VoiceGlow> {
  double _smooth = 0;

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    return ValueListenableBuilder<double>(
      valueListenable: widget.level,
      builder: (context, level, _) {
        // Lissage : le halo suit la voix sans trembler.
        final target = widget.active ? level : 0.0;
        _smooth = reduced
            ? (widget.active ? 0.4 : 0.0)
            : _smooth + (target - _smooth) * 0.35;
        return Align(
          alignment: Alignment.bottomCenter,
          child: Transform.scale(
            alignment: Alignment.bottomCenter,
            scaleY: 0.55 + 0.75 * _smooth,
            scaleX: 1 + 0.15 * _smooth,
            child: Opacity(
              opacity: 0.35 + 0.55 * _smooth,
              child: Container(
                height: 380,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.bottomCenter,
                    radius: 1.1,
                    colors: [
                      AppThemeColors.accent.withValues(alpha: 0.75),
                      AppThemeColors.accent.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.45, 1],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final background = primary
        ? (enabled ? AppThemeColors.accent : Colors.white12)
        : Colors.white.withValues(alpha: 0.10);
    final foreground = primary && enabled
        ? AppThemeColors.onAccent
        : Colors.white;
    return Semantics(
      button: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PressScale(
            enabled: enabled,
            child: Material(
              color: background,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: SizedBox(
                  width: primary ? 68 : 58,
                  height: primary ? 68 : 58,
                  child: Icon(
                    icon,
                    size: primary ? 28 : 24,
                    color: enabled ? foreground : Colors.white38,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _ErrorPill extends StatelessWidget {
  const _ErrorPill({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0x33FF6B6B),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle_fill,
              size: 16,
              color: Color(0xFFFFB4B4),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFFFFDADA)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un passage dicté : lingala en petit, traduction française en grand.
class _Passage extends StatelessWidget {
  const _Passage({
    required this.lingala,
    required this.lingalaStyle,
    required this.french,
  });

  final String lingala;
  final TextStyle? lingalaStyle;
  final Widget? french;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lingala, style: lingalaStyle),
          if (french != null) ...[const SizedBox(height: 6), french!],
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white38,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Traduction française du texte relu, avec « Retraduire » s'il a changé.
class _FrenchPanel extends StatelessWidget {
  const _FrenchPanel({
    required this.text,
    required this.busy,
    required this.failed,
    required this.stale,
    required this.onRetranslate,
  });

  final String text;
  final bool busy;
  final bool failed;
  final bool stale;
  final VoidCallback? onRetranslate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: busy
                ? const Center(
                    child: MalobaLoader(
                      size: 34,
                      semanticLabel: 'Traduction en cours',
                    ),
                  )
                : SingleChildScrollView(
                    child: Text(
                      text.isEmpty
                          ? (failed
                                ? 'Traduction indisponible.'
                                : 'Aucune traduction.')
                          : text,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: text.isEmpty ? Colors.white38 : Colors.white,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
          ),
          if (onRetranslate != null && !busy)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRetranslate,
                icon: const Icon(CupertinoIcons.arrow_2_circlepath, size: 16),
                label: Text(stale ? 'Retraduire' : 'Réessayer'),
                style: TextButton.styleFrom(
                  foregroundColor: AppThemeColors.accent,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Interrupteur « Traduire » (lingala -> français), en haut à droite.
class _TranslateToggle extends StatelessWidget {
  const _TranslateToggle({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppThemeColors.accent : Colors.white54;
    return Semantics(
      button: true,
      toggled: enabled,
      label: 'Traduire du lingala vers le français',
      child: Material(
        color: enabled
            ? AppThemeColors.accent.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.08),
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => onChanged(!enabled),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.globe, size: 14, color: color),
                const SizedBox(width: 6),
                Text(
                  enabled ? 'LN → FR' : 'Traduire',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
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
