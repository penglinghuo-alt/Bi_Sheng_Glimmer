class HardwareConfig {
  static const String bleServiceUuid = '0000ffe0-0000-1000-8000-00805f9b34fb';
  static const String bleCharacteristicUuid = '0000ffe1-0000-1000-8000-00805f9b34fb';
  static const int wifiPort = 8080;
  static const int connectionTimeout = 5000;
  static const int scanTimeout = 10000;

  static const String cmdStartScan = 'CMD_START_SCAN';
  static const String cmdStopAll = 'CMD_STOP_ALL';
  static const String cmdNextPaperReady = 'CMD_NEXT_PAPER_READY';
  static const String cmdStartPrint = 'CMD_START_PRINT';
  static const String cmdQueryStatus = 'CMD_QUERY_STATUS';

  static const String statusPaperDone = 'STATUS_PAPER_DONE';
  static const String statusPrinting = 'STATUS_PRINTING';
  static const String statusIdle = 'STATUS_IDLE';
  static const String statusError = 'STATUS_ERROR';
}
