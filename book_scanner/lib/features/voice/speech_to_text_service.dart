import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

class SpeechToTextService {
  static const String _assetDir = 'assets/models/zh14m';
  static const String _modelDir = 'models/zh14m';
  static const List<String> _modelFiles = [
    'encoder-epoch-99-avg-1.int8.onnx',
    'decoder-epoch-99-avg-1.int8.onnx',
    'joiner-epoch-99-avg-1.int8.onnx',
    'tokens.txt',
  ];

  sherpa_onnx.OnlineRecognizer? _recognizer;
  sherpa_onnx.OnlineStream? _stream;
  bool _initialized = false;

  bool get isInitialized => _initialized;
  bool get isRecording => _stream != null;

  /// 把 assets 中的模型文件拷贝到应用目录（sherpa-onnx 原生端需要文件路径）
  Future<void> ensureModelFiles() async {
    final dir = await getApplicationSupportDirectory();
    final modelDir = Directory('${dir.path}/$_modelDir');
    if (modelDir.existsSync()) return;
    modelDir.createSync(recursive: true);

    for (final file in _modelFiles) {
      final data = await rootBundle.load('$_assetDir/$file');
      File('${modelDir.path}/$file').writeAsBytesSync(data.buffer.asUint8List());
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    await ensureModelFiles();

    final dir = await getApplicationSupportDirectory();
    final modelDir = '${dir.path}/$_modelDir';

    final config = sherpa_onnx.OnlineRecognizerConfig(
      feat: const sherpa_onnx.FeatureConfig(sampleRate: 16000, featureDim: 80),
      model: sherpa_onnx.OnlineModelConfig(
        transducer: sherpa_onnx.OnlineTransducerModelConfig(
          encoder: '$modelDir/encoder-epoch-99-avg-1.int8.onnx',
          decoder: '$modelDir/decoder-epoch-99-avg-1.int8.onnx',
          joiner: '$modelDir/joiner-epoch-99-avg-1.int8.onnx',
        ),
        tokens: '$modelDir/tokens.txt',
        numThreads: 2,
        modelType: 'zipformer',
        debug: false,
      ),
      decodingMethod: 'greedy_search',
      enableEndpoint: true,
      rule1MinTrailingSilence: 2.4,
      rule2MinTrailingSilence: 1.2,
      rule3MinUtteranceLength: 20,
    );
    _recognizer = sherpa_onnx.OnlineRecognizer(config);
    _initialized = true;
  }

  void startSession() {
    if (_recognizer == null) return;
    _stream = _recognizer!.createStream();
  }

  /// 输入 16kHz 单声道 PCM 数据（Float32），喂给模型并实时解码
  void acceptPcm(Float32List samples) {
    if (_recognizer == null || _stream == null) return;
    _stream!.acceptWaveform(samples: samples, sampleRate: 16000);
    _decode();
  }

  void _decode() {
    if (_recognizer == null || _stream == null) return;
    while (_recognizer!.isReady(_stream!)) {
      _recognizer!.decode(_stream!);
    }
  }

  /// 当前部分识别结果（实时显示用）
  String get currentText {
    if (_recognizer == null || _stream == null) return '';
    return _recognizer!.getResult(_stream!).text;
  }

  bool get isEndpoint {
    if (_recognizer == null || _stream == null) return false;
    return _recognizer!.isEndpoint(_stream!);
  }

  void resetEndpoint() {
    if (_recognizer == null || _stream == null) return;
    _recognizer!.reset(_stream!);
  }

  /// 结束本次会话，返回完整转写文本
  String finish() {
    if (_recognizer == null || _stream == null) return '';
    _stream!.inputFinished();
    _decode();
    final result = _recognizer!.getResult(_stream!).text;
    _stream!.free();
    _stream = null;
    return result;
  }

  void dispose() {
    _stream?.free();
    _recognizer?.free();
    _recognizer = null;
    _stream = null;
    _initialized = false;
  }
}

/// 将 16bit PCM 字节流转为 Float32 采样（sherpa-onnx 输入格式）
Float32List pcm16ToFloat32(Uint8List bytes) {
  final count = bytes.length ~/ 2;
  final out = Float32List(count);
  final bd = ByteData.sublistView(bytes);
  for (var i = 0; i < count; i++) {
    out[i] = bd.getInt16(i * 2, Endian.little) / 32768.0;
  }
  return out;
}
