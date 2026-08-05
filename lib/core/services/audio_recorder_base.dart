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

  /// Flux d'amplitude audio normalisé (0.0 = silence, 1.0 = maximum).
  /// Retourne `null` si la plateforme ne peut pas fournir d'amplitude.
  Stream<double>? get onAmplitude;

  void play(
    String url, {
    required void Function(double progress) onPositionChanged,
    required VoidCallback onComplete,
  });
  void stopPlaying();
}
