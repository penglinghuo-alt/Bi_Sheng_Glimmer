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

  /// 内置麦克风的特征词（命中即视为内置，优先排除）
  static const _builtinHints = [
    'built-in', 'builtin', 'internal', 'integrated', 'realtek',
    'default', '内置', '集成', '内建',
  ];

  /// 外接麦克风的特征词（命中即视为外接，优先选择）
  static const _externalHints = [
    'usb', '4-mic', 'hikvision', 'conference', 'webcam', '外接', 'usb audio',
  ];

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

  /// 判断设备 label 是否指向外接麦克风
  bool _isExternalLabel(String label) {
    final l = label.toLowerCase();
    if (_builtinHints.any(l.contains)) return false;
    return _externalHints.any(l.contains);
  }

  /// 优先使用外接麦克风：先拿默认授权流，再枚举设备，
  /// 若存在外接设备（含 usb / 4-mic 等）且当前用的不是它，则切换；切换失败回退默认
  Future<web.MediaStream> _acquirePreferred() async {
    var stream = await _acquire(web.MediaStreamConstraints(audio: true.toJS));
    try {
      final preferredId = await _findPreferredDeviceId();
      if (preferredId == null) return stream;
      final tracks = stream.getAudioTracks().toDart;
      final current = tracks.isEmpty ? null : tracks.first;
      if (current != null && _isExternalLabel(current.label)) {
        return stream;
      }
      final preferredStream = await _acquire(web.MediaStreamConstraints(
        audio: {'deviceId': {'exact': preferredId}}.jsify()!,
      ));
      stream.getTracks().toDart.forEach((track) => track.stop());
      return preferredStream;
    } catch (_) {
      return stream;
    }
  }

  Future<String?> _findPreferredDeviceId() async {
    try {
      final infos = (await web.window.navigator.mediaDevices
              .enumerateDevices()
              .toDart)
          .toDart;
      final audioInputs =
          infos.where((info) => info.kind == 'audioinput').toList();
      if (audioInputs.length < 2) return null;
      // 1. 优先 USB 外接
      for (final info in audioInputs) {
        if (_isExternalLabel(info.label) &&
            info.label.toLowerCase().contains('usb')) {
          return info.deviceId;
        }
      }
      // 2. 其次其他外接特征（4-mic / 品牌名等）
      for (final info in audioInputs) {
        if (_isExternalLabel(info.label)) {
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
