import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

/// Transcrit un segment audio (fichier WAV complet) et renvoie le texte.
typedef SegmentTranscriber = Future<String> Function(Uint8List wav);

enum LiveSegmentStatus { pending, done, failed }

class LiveSegment {
  LiveSegment(this.index, this._wav);

  final int index;
  Uint8List? _wav; // conservé tant que la transcription n'a pas réussi
  String text = '';
  LiveSegmentStatus status = LiveSegmentStatus.pending;
  String? error;
}

class _Frame {
  _Frame(this.pcm, this.db, this.speech);

  final Uint8List pcm;
  final double db;
  final bool speech;
}

/// Découpe de la parole en unités aux pauses naturelles. Logique pure (sans
/// micro), testable : on lui donne des échantillons PCM 16 bits, elle dit
/// quand une unité de parole est complète.
///
/// - Analyse par trames de 20 ms, indépendante de la taille des blocs reçus.
/// - Seuil adaptatif : le plancher de bruit suit le fond sonore (descend vite,
///   remonte lentement), la parole doit le dépasser de 10 dB pour commencer
///   (hystérésis : 6 dB pour continuer), pendant 60 ms (les clics sont ignorés).
/// - Une unité finit sur une vraie pause ([pause]) ; passé [softSegment], une
///   respiration ([shortPause]) suffit. Au-delà de [maxSegment] sans pause,
///   la coupe tombe sur la trame la plus calme des 2 dernières secondes,
///   jamais au milieu d'un mot.
/// - Seuls [preRoll] avant la parole et [tail] après sont gardés : le silence
///   n'est pas envoyé à la transcription.
class SpeechSegmenter {
  SpeechSegmenter({
    this.sampleRate = 16000,
    this.pause = const Duration(milliseconds: 650),
    this.shortPause = const Duration(milliseconds: 250),
    this.minSpeech = const Duration(milliseconds: 400),
    this.softSegment = const Duration(seconds: 10),
    this.maxSegment = const Duration(seconds: 25),
    this.preRoll = const Duration(milliseconds: 300),
    this.tail = const Duration(milliseconds: 250),
  });

  final int sampleRate;
  final Duration pause;
  final Duration shortPause;
  final Duration minSpeech;
  final Duration softSegment;
  final Duration maxSegment;
  final Duration preRoll;
  final Duration tail;

  static const _frameMs = 20;
  static const _onsetFrames = 3; // 60 ms de parole pour démarrer
  static const _hardCutWindowMs = 2000;

  int _frames(Duration d) => (d.inMilliseconds / _frameMs).ceil();
  int get _frameBytes => sampleRate * _frameMs ~/ 1000 * 2;

  Uint8List _carry = Uint8List(0);
  final List<_Frame> _pre = <_Frame>[];
  List<_Frame> _seg = <_Frame>[];
  final List<Uint8List> _ready = <Uint8List>[];
  bool _inSegment = false;
  int _onsetRun = 0;
  int _silenceRun = 0;
  double _floorDb = -60;

  /// Dernier niveau mesuré, normalisé 0..1 (-45 dBFS -> 0, 0 dBFS -> 1).
  double level = 0;

  static double _db(Uint8List pcm) {
    final view = ByteData.sublistView(pcm);
    final n = pcm.lengthInBytes ~/ 2;
    if (n == 0) return -100;
    var sum = 0.0;
    for (var i = 0; i < n; i++) {
      final v = view.getInt16(i * 2, Endian.little);
      sum += v * v;
    }
    final rms = math.sqrt(sum / n) / 32768;
    return rms > 0 ? 20 * math.log(rms) / math.ln10 : -100.0;
  }

  /// Ajoute un bloc PCM 16 bits mono. Renvoie une unité de parole à
  /// transcrire quand elle est complète, sinon `null`. S'il y en a plusieurs
  /// (bloc très long), les suivantes sont rendues par [takeReady].
  Uint8List? add(Uint8List pcm) {
    if (pcm.isEmpty) return takeReady();
    level = ((_db(pcm) + 45) / 45).clamp(0.0, 1.0);

    final data = _carry.isEmpty
        ? pcm
        : (BytesBuilder(copy: false)
                ..add(_carry)
                ..add(pcm))
              .takeBytes();
    final size = _frameBytes;
    var offset = 0;
    while (offset + size <= data.length) {
      _onFrame(Uint8List.fromList(data.sublist(offset, offset + size)));
      offset += size;
    }
    _carry = Uint8List.fromList(data.sublist(offset));
    return takeReady();
  }

  /// Unité suivante déjà complète, ou `null`.
  Uint8List? takeReady() => _ready.isEmpty ? null : _ready.removeAt(0);

  void _onFrame(Uint8List pcm) {
    final db = _db(pcm);
    final threshold = _inSegment
        ? math.max(-48.0, _floorDb + 6)
        : math.max(-45.0, _floorDb + 10);
    final speech = db > threshold;
    if (!speech) {
      // Plancher : descend vite vers le fond sonore, remonte lentement.
      _floorDb = db < _floorDb
          ? math.max(-75.0, _floorDb + (db - _floorDb) * 0.3)
          : _floorDb + 0.01;
    }
    final frame = _Frame(pcm, db, speech);

    if (!_inSegment) {
      _pre.add(frame);
      final keep = _frames(preRoll) + _onsetFrames;
      if (_pre.length > keep) _pre.removeRange(0, _pre.length - keep);
      _onsetRun = speech ? _onsetRun + 1 : 0;
      if (_onsetRun >= _onsetFrames) {
        _inSegment = true;
        _seg = List.of(_pre);
        _pre.clear();
        _onsetRun = 0;
        _silenceRun = 0;
      }
      return;
    }

    _seg.add(frame);
    _silenceRun = speech ? 0 : _silenceRun + 1;
    final segMs = _seg.length * _frameMs;
    final needed = segMs >= softSegment.inMilliseconds
        ? _frames(shortPause)
        : _frames(pause);
    if (_silenceRun >= needed) {
      _cutAtPause();
    } else if (segMs >= maxSegment.inMilliseconds) {
      _cutAtQuietest();
    }
  }

  int get _lastSpeech => _seg.lastIndexWhere((f) => f.speech);

  void _emit(List<_Frame> frames) {
    final speechMs = frames.where((f) => f.speech).length * _frameMs;
    if (speechMs < minSpeech.inMilliseconds || frames.isEmpty) return;
    final out = BytesBuilder(copy: false);
    for (final f in frames) {
      out.add(f.pcm);
    }
    _ready.add(out.takeBytes());
  }

  /// Pause trouvée : l'unité finit [tail] après la dernière parole ; le
  /// silence qui suit sert d'amorce à la prochaine.
  void _cutAtPause() {
    final end = math.min(_seg.length, _lastSpeech + 1 + _frames(tail));
    _emit(_seg.sublist(0, end));
    final rest = _seg.sublist(end);
    _pre
      ..clear()
      ..addAll(rest.skip(math.max(0, rest.length - _frames(preRoll))));
    _seg = <_Frame>[];
    _inSegment = false;
    _silenceRun = 0;
  }

  /// Parole sans pause trop longue : coupe à la trame la plus calme des
  /// 2 dernières secondes ; la suite continue l'unité suivante.
  void _cutAtQuietest() {
    final from = math.max(1, _seg.length - _hardCutWindowMs ~/ _frameMs);
    var cut = _seg.length - 1;
    for (var i = _seg.length - 1; i >= from; i--) {
      if (_seg[i].db < _seg[cut].db) cut = i;
    }
    _emit(_seg.sublist(0, cut + 1));
    _seg = _seg.sublist(cut + 1);
    _silenceRun = 0;
    for (var i = _seg.length - 1; i >= 0 && !_seg[i].speech; i--) {
      _silenceRun++;
    }
  }

  /// Rend l'unité en cours (fin de dictée, pause) si elle contient assez de
  /// parole, sinon `null`. Les unités déjà complètes passent d'abord.
  Uint8List? flush() {
    if (_inSegment) {
      final end = math.min(_seg.length, _lastSpeech + 1 + _frames(tail));
      _emit(_seg.sublist(0, math.max(0, end)));
    }
    _seg = <_Frame>[];
    _pre.clear();
    _carry = Uint8List(0);
    _inSegment = false;
    _onsetRun = 0;
    _silenceRun = 0;
    return takeReady();
  }

  /// En-tête WAV (PCM 16 bits mono) autour d'échantillons bruts.
  static Uint8List wav(Uint8List pcm, {int sampleRate = 16000}) {
    final header = ByteData(44);
    void ascii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        header.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    header.setUint32(4, 36 + pcm.length, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    header.setUint32(16, 16, Endian.little); // taille du bloc fmt
    header.setUint16(20, 1, Endian.little); // PCM
    header.setUint16(22, 1, Endian.little); // mono
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little); // octets / s
    header.setUint16(32, 2, Endian.little); // octets / échantillon
    header.setUint16(34, 16, Endian.little); // bits / échantillon
    ascii(36, 'data');
    header.setUint32(40, pcm.length, Endian.little);
    return (BytesBuilder(copy: false)
          ..add(header.buffer.asUint8List())
          ..add(pcm))
        .takeBytes();
  }
}

/// Dictée transcrite au fur et à mesure : le micro reste ouvert, chaque
/// segment (coupé à une pause) part aussitôt à la transcription, dans l'ordre.
class LiveTranscriber extends ChangeNotifier {
  LiveTranscriber({required this.transcribe, AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  static const sampleRate = 16000;

  final SegmentTranscriber transcribe;
  final AudioRecorder _recorder;
  final SpeechSegmenter _segmenter = SpeechSegmenter(sampleRate: sampleRate);

  /// Niveau du micro (0..1), pour l'animation — sans reconstruire tout l'écran.
  final ValueNotifier<double> level = ValueNotifier<double>(0);

  final List<LiveSegment> segments = <LiveSegment>[];
  StreamSubscription<Uint8List>? _audio;
  Future<void> _queue = Future<void>.value();
  final Stopwatch _clock = Stopwatch();
  bool _listening = false;
  bool _paused = false;
  bool _disposed = false;

  bool get isListening => _listening;
  bool get isPaused => _paused;
  Duration get elapsed => _clock.elapsed;
  bool get hasPending =>
      segments.any((s) => s.status == LiveSegmentStatus.pending);
  bool get hasFailures =>
      segments.any((s) => s.status == LiveSegmentStatus.failed);

  /// Première erreur de transcription (même message pour tous les segments).
  String? get lastError => segments
      .where((s) => s.status == LiveSegmentStatus.failed)
      .map((s) => s.error)
      .firstWhere((e) => e != null, orElse: () => null);

  String get transcript => segments
      .where((s) => s.status == LiveSegmentStatus.done && s.text.isNotEmpty)
      .map((s) => s.text)
      .join(' ');

  Future<void> start() async {
    if (!await _recorder.hasPermission()) {
      throw Exception('Autorisation microphone refusée.');
    }
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
      ),
    );
    _audio = stream.listen(_onAudio);
    _listening = true;
    _clock.start();
    _notify();
  }

  void _onAudio(Uint8List pcm) {
    if (_paused || _disposed) return;
    var segment = _segmenter.add(pcm);
    level.value = _segmenter.level;
    while (segment != null) {
      _enqueue(segment);
      segment = _segmenter.takeReady();
    }
  }

  void _enqueue(Uint8List pcm) {
    final segment = LiveSegment(
      segments.length,
      SpeechSegmenter.wav(pcm, sampleRate: sampleRate),
    );
    segments.add(segment);
    _notify();
    _queue = _queue.then((_) => _run(segment));
  }

  void _drainFlush() {
    var rest = _segmenter.flush();
    while (rest != null) {
      _enqueue(rest);
      rest = _segmenter.takeReady();
    }
  }

  Future<void> _run(LiveSegment segment) async {
    final wav = segment._wav;
    if (wav == null) return;
    segment.status = LiveSegmentStatus.pending;
    segment.error = null;
    _notify();
    try {
      segment.text = (await transcribe(wav)).trim();
      segment.status = LiveSegmentStatus.done;
      segment._wav = null;
    } catch (error) {
      segment.status = LiveSegmentStatus.failed;
      segment.error = error.toString();
    }
    _notify();
  }

  Future<void> pause() async {
    if (!_listening || _paused) return;
    _paused = true;
    _clock.stop();
    await _recorder.pause();
    _drainFlush();
    level.value = 0;
    _notify();
  }

  Future<void> resume() async {
    if (!_listening || !_paused) return;
    await _recorder.resume();
    _paused = false;
    _clock.start();
    _notify();
  }

  /// Arrête le micro, transcrit le dernier morceau et attend tous les segments.
  Future<String> finish() async {
    await _stopMicrophone();
    _drainFlush();
    await _queue;
    return transcript;
  }

  /// Relance les segments en échec (serveur revenu, par exemple).
  Future<void> retryFailed() async {
    for (final segment in segments.where(
      (s) => s.status == LiveSegmentStatus.failed,
    )) {
      _queue = _queue.then((_) => _run(segment));
    }
    await _queue;
  }

  /// Abandon : micro coupé, rien n'est transcrit ni envoyé.
  Future<void> cancel() async {
    await _stopMicrophone();
    _segmenter.flush();
  }

  Future<void> _stopMicrophone() async {
    if (!_listening) return;
    _listening = false;
    _paused = false;
    _clock.stop();
    await _audio?.cancel();
    _audio = null;
    try {
      await _recorder.stop();
    } catch (_) {}
    if (!_disposed) level.value = 0;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_stopMicrophone());
    unawaited(_recorder.dispose());
    level.dispose();
    super.dispose();
  }
}
