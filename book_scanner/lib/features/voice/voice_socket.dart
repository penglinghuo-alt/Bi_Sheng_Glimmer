import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket 客户端：向云端后端推送 PCM 并接收转写结果
class VoiceSocket {
  WebSocketChannel? _channel;
  StreamController<String> _messages = StreamController<String>();

  /// 服务端回推的文本消息流（JSON 字符串）
  Stream<String> get messages => _messages.stream;

  Future<void> connect(Uri uri) async {
    await close();
    if (!_messages.isClosed) {
      await _messages.close();
    }
    _messages = StreamController<String>();
    _channel = WebSocketChannel.connect(uri);
    _channel!.stream.listen(
      (data) {
        if (data is String && !_messages.isClosed) {
          _messages.add(data);
        }
      },
      onError: (_) {},
      onDone: () {
        if (!_messages.isClosed) {
          _messages.close();
        }
      },
    );
  }

  void sendText(String text) => _channel?.sink.add(text);

  void sendBytes(List<int> bytes) => _channel?.sink.add(bytes);

  Future<void> close() async {
    await _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    if (!_messages.isClosed) {
      _messages.close();
    }
  }
}
