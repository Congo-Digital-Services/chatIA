import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'audio_recorder_base.dart';

class AudioRecorderMobile extends AudioRecorderPlatform {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  bool _isRecording = false;
  String? _currentRecordingPath;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<void>? _completionSubscription;
  Duration _playbackDuration = Duration.zero;

  AudioRecorderMobile() {
    _player.onDurationChanged.listen((duration) {
      _playbackDuration = duration;
    });
  }

  @override
  bool get isRecording => _isRecording;

  @override
  Stream<double>? get onAmplitude => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 80))
      .map(_normalizeAmplitude);

  double _normalizeAmplitude(Amplitude amplitude) {
    final current = amplitude.current.isNaN ? 0.0 : amplitude.current;
    return ((current + 45) / 45).clamp(0.0, 1.0);
  }

  @override
  Future<void> startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw Exception('Autorisation microphone refusée.');
    }

    final directory = await getTemporaryDirectory();
    final filename = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final path = '${directory.path}/$filename';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );

    _currentRecordingPath = path;
    _isRecording = true;
  }

  @override
  Future<RecordedAudioInfo?> stopRecording() async {
    if (!_isRecording) {
      return null;
    }

    final path = await _recorder.stop();
    _isRecording = false;

    final resolvedPath = path ?? _currentRecordingPath;
    _currentRecordingPath = null;
    if (resolvedPath == null || resolvedPath.isEmpty) {
      return null;
    }

    final file = File(resolvedPath);
    if (!await file.exists()) {
      throw Exception('Le fichier audio enregistré est introuvable.');
    }

    final bytes = await file.readAsBytes();
    return RecordedAudioInfo(
      url: resolvedPath,
      name: file.uri.pathSegments.isNotEmpty
          ? file.uri.pathSegments.last
          : 'voice-message.m4a',
      mimeType: 'audio/mp4',
      bytes: bytes,
    );
  }

  @override
  void play(
    String url, {
    required void Function(double progress) onPositionChanged,
    required VoidCallback onComplete,
  }) {
    unawaited(
      _play(url, onPositionChanged: onPositionChanged, onComplete: onComplete),
    );
  }

  Future<void> _play(
    String url, {
    required void Function(double progress) onPositionChanged,
    required VoidCallback onComplete,
  }) async {
    stopPlaying();

    final source = _resolveSource(url);
    _playbackDuration = Duration.zero;
    _positionSubscription = _player.onPositionChanged.listen((position) {
      final total = _playbackDuration.inMilliseconds;
      if (total <= 0) {
        onPositionChanged(0);
        return;
      }
      onPositionChanged(position.inMilliseconds / total);
    });
    _completionSubscription = _player.onPlayerComplete.listen((_) {
      onPositionChanged(1);
      onComplete();
      stopPlaying();
    });

    await _player.play(source);
  }

  Source _resolveSource(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return UrlSource(url);
    }
    return DeviceFileSource(url);
  }

  @override
  void stopPlaying() {
    unawaited(_player.stop());
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _completionSubscription?.cancel();
    _completionSubscription = null;
    _playbackDuration = Duration.zero;
  }
}

AudioRecorderPlatform getAudioRecorder() => AudioRecorderMobile();
