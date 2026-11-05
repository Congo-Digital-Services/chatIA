import 'dart:async';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'audio_recorder_base.dart';

class AudioRecorderWeb extends AudioRecorderPlatform {
  html.MediaRecorder? _mediaRecorder;
  final List<html.Blob> _chunks = [];
  bool _isRecording = false;

  html.AudioElement? _audioElement;
  StreamSubscription? _audioTimeSub;

  // Mesure du niveau du micro (Web Audio via package:web), pour l'onde en
  // direct. Flux micro séparé de celui du MediaRecorder : aucune conversion
  // entre dart:html et package:web, et l'autorisation déjà donnée suffit.
  web.AudioContext? _audioContext;
  web.MediaStream? _meterStream;
  Timer? _levelTimer;
  StreamController<double>? _levels;
  int _meterRun = 0;

  @override
  bool get isRecording => _isRecording;

  /// Niveau réel du micro, sur la même échelle que le mobile :
  /// -45 dBFS -> 0.0, 0 dBFS -> 1.0. Sans Web Audio, le flux reste muet
  /// (onde plate) : on n'affiche pas d'onde factice.
  @override
  Stream<double>? get onAmplitude => _levels?.stream;

  Future<void> _startLevelMeter(StreamController<double> levels) async {
    final run = ++_meterRun;
    try {
      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
          .toDart;
      if (run != _meterRun) {
        // Enregistrement arrêté pendant l'attente : on libère le micro.
        _stopTracks(stream);
        return;
      }
      final context = web.AudioContext();
      final analyser = context.createAnalyser()..fftSize = 512;
      context.createMediaStreamSource(stream).connect(analyser);
      final buffer = Uint8List(analyser.fftSize).toJS;
      _audioContext = context;
      _meterStream = stream;
      _levelTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
        analyser.getByteTimeDomainData(buffer);
        final samples = buffer.toDart;
        var sum = 0.0;
        for (final value in samples) {
          final sample = (value - 128) / 128;
          sum += sample * sample;
        }
        final rms = math.sqrt(sum / samples.length);
        final db = rms > 0 ? 20 * math.log(rms) / math.ln10 : -100.0;
        if (!levels.isClosed) {
          levels.add(((db + 45) / 45).clamp(0.0, 1.0));
        }
      });
    } catch (e) {
      debugPrint('Mesure du niveau micro indisponible : $e');
    }
  }

  void _stopTracks(web.MediaStream stream) {
    for (final track in stream.getTracks().toDart) {
      track.stop();
    }
  }

  void _stopLevelMeter() {
    _meterRun++;
    _levelTimer?.cancel();
    _levelTimer = null;
    _levels?.close();
    _levels = null;
    final stream = _meterStream;
    _meterStream = null;
    if (stream != null) {
      _stopTracks(stream);
    }
    _audioContext?.close();
    _audioContext = null;
  }

  @override
  Future<void> startRecording() async {
    try {
      _chunks.clear();
      if (html.window.navigator.mediaDevices == null) {
        throw Exception("MediaDevices API non disponible sur ce navigateur");
      }
      final stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'audio': true,
      });
      _mediaRecorder = html.MediaRecorder(stream);
      _mediaRecorder!.addEventListener('dataavailable', (html.Event event) {
        final dynamic blobEvent = event;
        if (blobEvent.data != null) {
          _chunks.add(blobEvent.data);
        }
      });
      _mediaRecorder!.start();
      final levels = StreamController<double>.broadcast();
      _levels = levels;
      unawaited(_startLevelMeter(levels));
      _isRecording = true;
    } catch (e) {
      debugPrint('Error starting recording on web: $e');
      _stopLevelMeter();
      // Comme sur mobile : l'appelant doit savoir que l'enregistrement n'a pas
      // démarré (micro refusé ou absent), sinon l'interface croit enregistrer.
      rethrow;
    }
  }

  @override
  Future<RecordedAudioInfo?> stopRecording() async {
    if (_mediaRecorder == null || !_isRecording) return null;

    final completer = Completer<RecordedAudioInfo?>();
    final recorder = _mediaRecorder!;
    final recorderMimeType = recorder.mimeType ?? '';
    final mimeType = recorderMimeType.isNotEmpty
        ? recorderMimeType
        : 'audio/webm';

    recorder.addEventListener('stop', (html.Event event) async {
      final blob = html.Blob(_chunks, mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final bytes = await _readBlobBytes(blob);
      completer.complete(
        RecordedAudioInfo(
          url: url,
          name: 'voice-message.webm',
          mimeType: mimeType,
          bytes: bytes,
        ),
      );
    });

    recorder.stop();
    recorder.stream?.getTracks().forEach((track) => track.stop());
    _stopLevelMeter();
    _mediaRecorder = null;
    _isRecording = false;

    return completer.future;
  }

  Future<Uint8List> _readBlobBytes(html.Blob blob) {
    final completer = Completer<Uint8List>();
    final reader = html.FileReader();

    reader.onLoad.first.then((_) {
      final result = reader.result;
      if (result is ByteBuffer) {
        completer.complete(result.asUint8List());
      } else if (result is Uint8List) {
        completer.complete(result);
      } else {
        completer.complete(Uint8List(0));
      }
    });

    reader.onError.first.then((_) {
      completer.complete(Uint8List(0));
    });

    reader.readAsArrayBuffer(blob);
    return completer.future;
  }

  @override
  void play(
    String url, {
    required void Function(double progress) onPositionChanged,
    required VoidCallback onComplete,
  }) {
    stopPlaying();
    _audioElement = html.AudioElement(url);
    _audioElement!.play();

    _audioTimeSub = _audioElement!.onTimeUpdate.listen((_) {
      if (_audioElement != null && _audioElement!.duration > 0) {
        final progress = _audioElement!.currentTime / _audioElement!.duration;
        onPositionChanged(progress);
      }
    });

    _audioElement!.onEnded.listen((_) {
      onComplete();
      stopPlaying();
    });
  }

  @override
  void stopPlaying() {
    _audioTimeSub?.cancel();
    _audioTimeSub = null;
    if (_audioElement != null) {
      _audioElement!.pause();
      _audioElement = null;
    }
  }
}

AudioRecorderPlatform getAudioRecorder() => AudioRecorderWeb();
