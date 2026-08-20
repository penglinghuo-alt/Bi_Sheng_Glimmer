import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'audio_source.dart';

/// 线性插值重采样到 16kHz（浏览器麦克风常为 44.1k/48k，后端要求 16k）
Float32List resampleTo16k(Float32List input, int fromRate) {
  const toRate = 16000;
  if (fromRate == toRate || input.isEmpty) return input;
  final ratio = fromRate / toRate;
  final outLen = (input.length / ratio).floor();
  final out = Float32List(outLen);
  for (var i = 0; i < outLen; i++) {
    final pos = i * ratio;
    final i0 = pos.floor();
    final frac = pos - i0;
    final i1 = i0 + 1 < input.length ? i0 + 1 : i0;
    out[i] = input[i0] * (1 - frac) + input[i1] * frac;
  }
  return out;
}

/// Web 采集实现：getUserMedia + AudioContext ScriptProcessor 拿 float32 PCM
class WebAudioSource implements AudioSource {
  final StreamController<Float32List> _controller =
      StreamController<Float32List>();
  web.AudioContext? _ctx;
  web.MediaStream? _mediaStream;
  web.ScriptProcessorNode? _processor;
  bool _running = false;

  @override
  Stream<Float32List> get pcmStream => _controller.stream;

  @override
  Future<void> start() async {
    if (_running) return;
    final devices = web.window.navigator.mediaDevices;
    final constraints = web.MediaStreamConstraints(audio: true.toJS);
    late web.MediaStream mediaStream;
    try {
      mediaStream = await devices.getUserMedia(constraints).toDart;
    } catch (e) {
      throw Exception('无法访问麦克风：请确认页面为 https 或 localhost，且浏览器已允许麦克风权限（$e）');
    }
    _mediaStream = mediaStream;

    final ctx = web.AudioContext();
    _ctx = ctx;
    await ctx.resume().toDart;
    final source = ctx.createMediaStreamSource(mediaStream);
    final processor = ctx.createScriptProcessor(4096, 1, 1);
    final sampleRate = ctx.sampleRate.round();
    processor.addEventListener('audioprocess', ((web.Event event) {
      final evt = event as web.AudioProcessingEvent;
      var samples = evt.inputBuffer.getChannelData(0).toDart;
      samples = resampleTo16k(samples, sampleRate);
      if (!_controller.isClosed && samples.isNotEmpty) {
        _controller.add(samples);
      }
    }).toJS);
    source.connect(processor);
    processor.connect(ctx.destination);
    _processor = processor;
    _running = true;
  }

  @override
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _processor?.disconnect();
    _processor = null;
    _mediaStream?.getTracks().toDart.forEach((track) => track.stop());
    _mediaStream = null;
    _ctx?.close();
    _ctx = null;
  }

  @override
  void dispose() {
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}

/// Web 平台工厂
AudioSource platformCreateAudioSource() => WebAudioSource();
