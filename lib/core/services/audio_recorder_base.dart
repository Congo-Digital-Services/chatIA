import 'dart:ui';

abstract class AudioRecorderPlatform {
  Future<void> startRecording();
  Future<String?> stopRecording();
  bool get isRecording;
  void play(String url, {required void Function(double progress) onPositionChanged, required VoidCallback onComplete});
  void stopPlaying();
}
