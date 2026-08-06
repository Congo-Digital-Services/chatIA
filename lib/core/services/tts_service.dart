import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService._() {
    _tts.setCompletionHandler(() => isSpeaking.value = false);
    _tts.setCancelHandler(() => isSpeaking.value = false);
    _tts.setErrorHandler((_) => isSpeaking.value = false);
    _tts.setStartHandler(() => isSpeaking.value = true);
  }

  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  final ValueNotifier<bool> isSpeaking = ValueNotifier<bool>(false);

  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    await _tts.setLanguage('fr-FR');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
  }

  Future<void> speak(String text) async {
    final clean = _stripMarkdown(text);
    if (clean.isEmpty) {
      return;
    }
    await _ensureInitialized();
    await _tts.stop();
    await _tts.speak(clean);
  }

  Future<void> stop() async {
    await _tts.stop();
    isSpeaking.value = false;
  }

  Future<void> toggle(String text) async {
    if (isSpeaking.value) {
      await stop();
    } else {
      await speak(text);
    }
  }

  String _stripMarkdown(String text) {
    var clean = text
        .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
        .replaceAll(RegExp(r'`([^`]*)`'), r'$1')
        .replaceAll(RegExp(r'[*_~#>{}\[\]()!|\\-]'), ' ');
    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();
    return clean;
  }
}

final ttsService = TtsService.instance;
