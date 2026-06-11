import 'dart:typed_data';
import 'dart:ui';

class RecordedAudioInfo {
  const RecordedAudioInfo({
    required this.url,
    required this.name,
    required this.mimeType,
    this.bytes,
  });

  final String url;
  final String name;
  final String mimeType;
  final Uint8List? bytes;
}

abstract class AudioRecorderPlatform {
  Future<void> startRecording();
  Future<RecordedAudioInfo?> stopRecording();
  bool get isRecording;
  void play(
    String url, {
    required void Function(double progress) onPositionChanged,
    required VoidCallback onComplete,
  });
  void stopPlaying();
}
