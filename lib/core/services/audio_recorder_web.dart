import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

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
      _isRecording = true;
    } catch (e) {
      debugPrint('Error starting recording on web: $e');
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
