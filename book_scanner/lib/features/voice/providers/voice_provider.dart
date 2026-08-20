import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

import '../../../data/services/api_client.dart';
import '../speech_to_text_service.dart';

enum VoiceStatus { idle, initializing, recording, processing, saving, done, error }

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

final speechToTextServiceProvider = Provider<SpeechToTextService>((ref) => SpeechToTextService());

final voiceProvider = StateNotifierProvider<VoiceNotifier, VoiceState>((ref) {
  final service = ref.read(speechToTextServiceProvider);
  return VoiceNotifier(service);
});

class VoiceNotifier extends StateNotifier<VoiceState> {
  VoiceNotifier(this._service) : super(const VoiceState());

  final SpeechToTextService _service;
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;

  /// 初始化本地 ASR 模型（首次进入时调用一次）
  Future<void> init() async {
    if (_service.isInitialized || state.status == VoiceStatus.initializing) return;
    state = state.copyWith(status: VoiceStatus.initializing);
    try {
      await _service.init();
      state = state.copyWith(status: VoiceStatus.idle);
    } catch (e) {
      state = state.copyWith(status: VoiceStatus.error, error: '模型加载失败：$e');
    }
  }

  /// Web 端不支持原生 sherpa-onnx 转写时的降级提示
  void setWebUnsupported() {
    state = state.copyWith(status: VoiceStatus.error, error: '网页端暂不支持本地语音转写，请在 App 中使用');
  }

  /// 开始录音并流式转写
  Future<void> startRecording() async {
    if (state.status == VoiceStatus.recording) return;
    try {
      final ok = await _recorder.hasPermission();
      if (!ok) {
        state = state.copyWith(status: VoiceStatus.error, error: '未获得麦克风权限');
        return;
      }
      await init();
      if (!_service.isInitialized) return;

      _service.startSession();
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );
      _sub = stream.listen((chunk) {
        final samples = pcm16ToFloat32(chunk);
        _service.acceptPcm(samples);
        final partial = _service.currentText;
        if (partial != state.partialText) {
          state = state.copyWith(status: VoiceStatus.recording, partialText: partial);
        }
      });
      state = state.copyWith(status: VoiceStatus.recording, partialText: '', finalText: '');
    } catch (e) {
      state = state.copyWith(status: VoiceStatus.error, error: '录音启动失败：$e');
    }
  }

  /// 停止录音，得到最终转写文本
  Future<void> stopRecording() async {
    if (state.status != VoiceStatus.recording) return;
    state = state.copyWith(status: VoiceStatus.processing);
    try {
      await _sub?.cancel();
      _sub = null;
      await _recorder.stop();
      final text = _service.finish();
      state = state.copyWith(status: VoiceStatus.done, partialText: '', finalText: text.trim());
    } catch (e) {
      state = state.copyWith(status: VoiceStatus.error, error: '停止录音失败：$e');
    }
  }

  /// 将转写文字上传到后端，存入存储库（MySQL）
  Future<bool> save({String? title}) async {
    final text = state.finalText;
    if (text.isEmpty) return false;
    state = state.copyWith(status: VoiceStatus.saving);
    try {
      final api = ApiClient();
      final now = DateTime.now();
      final t = (title != null && title.trim().isNotEmpty)
          ? title.trim()
          : '语音输入_${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      await api.createRecord({
        'title': t,
        'source_type': '语音输入',
        'text_content': text,
        'dot_matrix_width': 0,
        'dot_matrix_height': 0,
      });
      state = state.copyWith(status: VoiceStatus.idle, finalText: '', partialText: '');
      return true;
    } catch (e) {
      state = state.copyWith(status: VoiceStatus.error, error: '上传失败：$e');
      return false;
    }
  }

  /// 清空当前转写结果
  void reset() {
    _service.resetEndpoint();
    state = state.copyWith(status: VoiceStatus.idle, partialText: '', finalText: '', error: null);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _recorder.dispose();
    _service.dispose();
    super.dispose();
  }
}
