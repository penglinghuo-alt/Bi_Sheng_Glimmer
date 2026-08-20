import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'audio_source.dart';

/// Web 采集实现：getUserMedia + AudioContext ScriptProcessor 拿 float32 PCM
class WebAudioSource implements AudioSource {
  final StreamController<Float32List> _controller =
      StreamController<Float32List>();
  web.AudioContext? _ctx;
  web.MediaStream? _mediaStream;
  web.ScriptProcessorNode? _processor;

  @override
  Stream<Float32List> get pcmStream => _controller.stream;

  @override
  Future<void> start() async {
    final devices = web.window.navigator.mediaDevices;
    final constraints = web.MediaStreamConstraints(audio: true.toJS);
    final mediaStream = await devices.getUserMedia(constraints).toDart;
    _mediaStream = mediaStream;

    final ctx = web.AudioContext();
    _ctx = ctx;
    final source = ctx.createMediaStreamSource(mediaStream);
    final processor = ctx.createScriptProcessor(4096, 1, 1);
    processor.addEventListener('audioprocess', ((web.Event event) {
      final evt = event as web.AudioProcessingEvent;
      final samples = evt.inputBuffer.getChannelData(0).toDart;
      if (!_controller.isClosed) {
        _controller.add(Float32List.fromList(samples));
      }
    }).toJS);
    source.connect(processor);
    processor.connect(ctx.destination);
    _processor = processor;
  }

  @override
  Future<void> stop() async {
    _processor?.disconnect();
    _processor = null;
    _mediaStream?.getTracks().toDart.forEach((track) => track.stop());
    _mediaStream = null;
    _ctx?.close();
    _ctx = null;
  }

  @override
  void dispose() {
    _controller.close();
  }
}

/// Web 平台工厂
AudioSource platformCreateAudioSource() => WebAudioSource();
