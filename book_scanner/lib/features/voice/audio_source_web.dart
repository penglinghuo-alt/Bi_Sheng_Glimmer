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
  String? _deviceName;

  @override
  Stream<Float32List> get pcmStream => _controller.stream;

  @override
  String? get deviceName => _deviceName;

  Future<web.MediaStream> _acquire(web.MediaStreamConstraints constraints) async {
    final devices = web.window.navigator.mediaDevices;
    try {
      return await devices.getUserMedia(constraints).toDart;
    } catch (e) {
      throw Exception('无法访问麦克风：请确认页面为 https 或 localhost，且浏览器已允许麦克风权限（$e）');
    }
  }

  /// 优先使用 USB 外接麦克风：先拿默认授权流，再枚举设备，
  /// 若存在 USB 设备且当前用的不是它，则切换；切换失败回退默认
  Future<web.MediaStream> _acquirePreferred() async {
    var stream = await _acquire(web.MediaStreamConstraints(audio: true.toJS));
    try {
      final usbId = await _findUsbDeviceId();
      if (usbId == null) return stream;
      final tracks = stream.getAudioTracks().toDart;
      final current = tracks.isEmpty ? null : tracks.first;
      if (current != null && current.label.toLowerCase().contains('usb')) {
        return stream;
      }
      final usbStream = await _acquire(web.MediaStreamConstraints(
        audio: {'deviceId': {'exact': usbId}}.jsify()!,
      ));
      stream.getTracks().toDart.forEach((track) => track.stop());
      return usbStream;
    } catch (_) {
      return stream;
    }
  }

  Future<String?> _findUsbDeviceId() async {
    try {
      final infos = (await web.window.navigator.mediaDevices
              .enumerateDevices()
              .toDart)
          .toDart;
      for (final info in infos) {
        if (info.kind == 'audioinput' &&
            info.label.toLowerCase().contains('usb')) {
          return info.deviceId;
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> start() async {
    if (_running) return;
    final mediaStream = await _acquirePreferred();
    _mediaStream = mediaStream;

    final tracks = mediaStream.getAudioTracks().toDart;
    final track = tracks.isEmpty ? null : tracks.first;
    _deviceName = (track != null && track.label.isNotEmpty)
        ? track.label
        : '默认麦克风';

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
