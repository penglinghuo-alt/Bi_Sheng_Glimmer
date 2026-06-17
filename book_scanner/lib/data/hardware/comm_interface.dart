import 'dart:async';

abstract class IHardwareComm {
  Future<bool> connect(String deviceIdOrIp);
  Future<void> disconnect();

  Future<void> startScanAndPrint();
  Future<void> stopAll();
  Future<void> nextPaperReady();
  Future<void> sendCommand(String command, {Map<String, dynamic>? params});

  Stream<String> get deviceStatusStream;
}
