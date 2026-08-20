import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import 'audio_source.dart';
import 'pcm_conversion.dart';

/// App（移动端）采集实现：使用 record 包获取 PCM16 流
class AppAudioSource implements AudioSource {
  final AudioRecorder _recorder = AudioRecorder();
  final StreamController<Float32List> _controller =
      StreamController<Float32List>();
  StreamSubscription<Uint8List>? _sub;
  bool _running = false;

  @override
  Stream<Float32List> get pcmStream => _controller.stream;

  @override
  String? get deviceName => null;

  @override
  Future<void> start() async {
    if (_running) return;
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
    _running = true;
  }

  @override
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    await _sub?.cancel();
    _sub = null;
    await _recorder.stop();
  }

  @override
  void dispose() {
    if (!_controller.isClosed) {
      _controller.close();
    }
    _recorder.dispose();
  }
}
/// App 平台工厂
AudioSource platformCreateAudioSource() => AppAudioSource();
