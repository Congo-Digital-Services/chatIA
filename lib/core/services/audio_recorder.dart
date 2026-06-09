export 'audio_recorder_base.dart';
import 'audio_recorder_stub.dart'
    if (dart.library.html) 'audio_recorder_web.dart'
    if (dart.library.io) 'audio_recorder_mobile.dart';

final audioRecorder = getAudioRecorder();
