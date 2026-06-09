import 'audio_recorder_base.dart';

AudioRecorderPlatform getAudioRecorder() =>
    throw UnsupportedError('Cannot create an audio recorder without platform implementation');
