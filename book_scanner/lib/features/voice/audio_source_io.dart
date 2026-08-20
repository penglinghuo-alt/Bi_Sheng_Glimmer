import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import 'audio_source.dart';
import 'pcm_conversion.dart';

/// App（移动端）采集实现：使用 record 包获取 PCM16 流
class AppAudioSource implements AudioSource {  final AudioRecorder _recorder = AudioRecorder();
  final StreamController<Float32List> _controller =
      StreamController<Float32List>();
  StreamSubscription<Uint8List>? _sub;

  @override
  Stream<Float32List> get pcmStream => _controller.stream;

  @override
  Future<void> start() async {
    final ok = await _recorder.hasPermission();
    if (!ok) {
      throw Exception('未获得麦克风权限');
    }
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );
    _sub = stream.listen((chunk) {
      if (!_controller.isClosed) {
        _controller.add(pcm16ToFloat32(chunk));
      }
    });
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    await _recorder.stop();
  }

  @override
  void dispose() {
    _recorder.dispose();
    _controller.close();
  }
}

/// App 平台工厂
AudioSource platformCreateAudioSource() => AppAudioSource();
