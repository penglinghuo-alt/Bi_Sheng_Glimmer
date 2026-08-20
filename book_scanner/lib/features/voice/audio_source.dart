import 'dart:typed_data';

import 'audio_source_io.dart' if (dart.library.html) 'audio_source_web.dart';

export 'audio_source_io.dart' if (dart.library.html) 'audio_source_web.dart';

/// 客户端音频采集源：本地采集麦克风 PCM（16000Hz 单声道 float32）
abstract class AudioSource {
  /// 采集到的 PCM 采样流
  Stream<Float32List> get pcmStream;

  Future<void> start();

  Future<void> stop();

  void dispose();
}

/// 按平台创建采集源（web → WebAudioSource，app → AppAudioSource）
AudioSource createAudioSource() => platformCreateAudioSource();
