import 'dart:typed_data';

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
