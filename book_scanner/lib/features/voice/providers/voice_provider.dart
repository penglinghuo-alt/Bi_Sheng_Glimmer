import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/api_client.dart';
import '../audio_source.dart';
import '../voice_socket.dart';

enum VoiceStatus { idle, starting, recording, processing, saving, done, error }

class VoiceState {
  final VoiceStatus status;
  final String partialText;
  final String finalText;
  final String? error;

  const VoiceState({
    this.status = VoiceStatus.idle,
    this.partialText = '',
    this.finalText = '',
    this.error,
  });

  VoiceState copyWith({
    VoiceStatus? status,
    String? partialText,
    String? finalText,
    String? error,
  }) {
    return VoiceState(
      status: status ?? this.status,
      partialText: partialText ?? this.partialText,
      finalText: finalText ?? this.finalText,
      error: error ?? this.error,
    );
  }
}

final voiceProvider = StateNotifierProvider<VoiceNotifier, VoiceState>((ref) {
  return VoiceNotifier(ApiClient());
});

class VoiceNotifier extends StateNotifier<VoiceState> {
  VoiceNotifier(this._api) : super(const VoiceState());

  final ApiClient _api;
  final VoiceSocket _socket = VoiceSocket();
  AudioSource? _source;
  StreamSubscription<Float32List>? _pcmSub;
  StreamSubscription<String>? _msgSub;
  Completer<String>? _finalCompleter;
  Timer? _finalTimer;

  Uri get _wsUri {
    if (kIsWeb) {
      final base = Uri.base;
      return base.replace(
        scheme: base.scheme == 'https' ? 'wss' : 'ws',
        path: '/api/voice/ws',
      );
    }
    final base = Uri.parse(ApiClient.baseUrl);
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '/api/voice/ws',
    );
  }

  /// 启动：连接后端 WS、开始本地采集并实时推流
  Future<void> startRecording() async {
    if (state.status == VoiceStatus.recording) return;
    state = state.copyWith(status: VoiceStatus.starting, partialText: '', finalText: '', error: null);
    try {
      await _socket.connect(_wsUri).timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw Exception('连接语音服务超时'),
      );
      _msgSub = _socket.messages.listen(_onMessage);
      _socket.sendText('{"type":"start"}');

      _source = createAudioSource();
      _pcmSub = _source!.pcmStream.listen((samples) {
        final bytes = samples.buffer.asInt8List();
        _socket.sendBytes(bytes);
      });
      await _source!.start().timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw Exception('麦克风授权无响应：请确认已允许麦克风权限，且使用 https 或 localhost 访问'),
      );
      state = state.copyWith(status: VoiceStatus.recording);
    } catch (e) {
      await _cleanup();
      state = state.copyWith(status: VoiceStatus.error, error: '启动录音失败：$e');
    }
  }

  void _onMessage(String raw) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (msg['type']) {
      case 'partial':
        final text = msg['text'] as String? ?? '';
        if (state.status == VoiceStatus.recording && text != state.partialText) {
          state = state.copyWith(partialText: text);
        }
      case 'final':
        _finalCompleter?.complete(msg['text'] as String? ?? '');
      case 'error':
        state = state.copyWith(status: VoiceStatus.error, error: msg['detail'] as String? ?? '转写服务出错');
        _finalCompleter?.complete('');
    }
  }

  /// 停止：结束本地采集，通知后端返回最终文本
  Future<void> stopRecording() async {
    if (state.status != VoiceStatus.recording) return;
    state = state.copyWith(status: VoiceStatus.processing);
    try {
      await _source?.stop();
      _pcmSub?.cancel();
      _pcmSub = null;

      final completer = Completer<String>();
      _finalCompleter = completer;
      _socket.sendText('{"type":"stop"}');

      final timer = Timer(const Duration(seconds: 8), () {
        if (!completer.isCompleted) completer.complete('');
      });
      _finalTimer = timer;

      final text = await completer.future;
      timer.cancel();
      _finalCompleter = null;
      await _cleanup();
      state = state.copyWith(
        status: VoiceStatus.done,
        partialText: '',
        finalText: text.trim(),
      );
    } catch (e) {
      await _cleanup();
      state = state.copyWith(status: VoiceStatus.error, error: '停止录音失败：$e');
    }
  }

  /// 将转写文字保存到存储库（后端建记录）
  Future<bool> save({String? title}) async {
    final text = state.finalText;
    if (text.isEmpty) return false;
    state = state.copyWith(status: VoiceStatus.saving);
    try {
      await _api.saveVoice(title: title ?? '', text: text);
      state = state.copyWith(status: VoiceStatus.idle, finalText: '', partialText: '');
      return true;
    } catch (e) {
      state = state.copyWith(status: VoiceStatus.error, error: '上传失败：$e');
      return false;
    }
  }

  /// 清空当前转写结果
  void reset() {
    _finalTimer?.cancel();
    _cleanup();
    state = state.copyWith(status: VoiceStatus.idle, partialText: '', finalText: '', error: null);
  }

  Future<void> _cleanup() async {
    _finalTimer?.cancel();
    _finalTimer = null;
    await _source?.stop();
    _source?.dispose();
    _source = null;
    await _pcmSub?.cancel();
    _pcmSub = null;
    await _msgSub?.cancel();
    _msgSub = null;
    await _socket.close();
  }

  @override
  void dispose() {
    _finalTimer?.cancel();
    _cleanup();
    _socket.dispose();
    super.dispose();
  }
}
