import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'audio_recorder_base.dart';

class AudioRecorderWeb extends AudioRecorderPlatform {
  html.MediaRecorder? _mediaRecorder;
  final List<html.Blob> _chunks = [];
  bool _isRecording = false;

  html.AudioElement? _audioElement;
  StreamSubscription? _audioTimeSub;

  @override
  bool get isRecording => _isRecording;

  @override
  Future<void> startRecording() async {
    try {
      _chunks.clear();
      if (html.window.navigator.mediaDevices == null) {
        throw Exception("MediaDevices API non disponible sur ce navigateur");
      }
      final stream = await html.window.navigator.mediaDevices!.getUserMedia({'audio': true});
      _mediaRecorder = html.MediaRecorder(stream);
      _mediaRecorder!.addEventListener('dataavailable', (html.Event event) {
        final dynamic blobEvent = event;
        if (blobEvent.data != null) {
          _chunks.add(blobEvent.data);
        }
      });
      _mediaRecorder!.start();
      _isRecording = true;
    } catch (e) {
      debugPrint('Error starting recording on web: $e');
    }
  }

  @override
  Future<String?> stopRecording() async {
    if (_mediaRecorder == null || !_isRecording) return null;

    final completer = Completer<String?>();
    _mediaRecorder!.addEventListener('stop', (html.Event event) {
      final blob = html.Blob(_chunks, 'audio/webm');
      final url = html.Url.createObjectUrlFromBlob(blob);
      completer.complete(url);
    });

    _mediaRecorder!.stop();
    _mediaRecorder!.stream?.getTracks().forEach((track) => track.stop());
    _mediaRecorder = null;
    _isRecording = false;

    return completer.future;
  }

  @override
  void play(String url, {required void Function(double progress) onPositionChanged, required VoidCallback onComplete}) {
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
