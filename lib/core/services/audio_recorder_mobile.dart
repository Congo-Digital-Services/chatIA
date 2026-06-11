import 'dart:async';
import 'package:flutter/foundation.dart';
import 'audio_recorder_base.dart';

class AudioRecorderMobile extends AudioRecorderPlatform {
  bool _isRecording = false;
  Timer? _playbackTimer;

  @override
  bool get isRecording => _isRecording;

  @override
  Future<void> startRecording() async {
    _isRecording = true;
    debugPrint('Mock recording started on mobile/desktop');
  }

  @override
  Future<RecordedAudioInfo?> stopRecording() async {
    if (!_isRecording) return null;
    _isRecording = false;
    debugPrint('Mock recording stopped on mobile/desktop');
    return const RecordedAudioInfo(
      url: 'mock_recorded_audio.mp3',
      name: 'mock_recorded_audio.mp3',
      mimeType: 'audio/mpeg',
    );
  }

  @override
  void play(
    String url, {
    required void Function(double progress) onPositionChanged,
    required VoidCallback onComplete,
  }) {
    stopPlaying();
    debugPrint('Mock audio playing: $url');
    double currentProgress = 0.0;
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      currentProgress += 0.05;
      if (currentProgress >= 1.0) {
        onPositionChanged(1.0);
        onComplete();
        stopPlaying();
      } else {
        onPositionChanged(currentProgress);
      }
    });
  }

  @override
  void stopPlaying() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
  }
}

AudioRecorderPlatform getAudioRecorder() => AudioRecorderMobile();
