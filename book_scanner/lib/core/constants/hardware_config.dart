/// 盲文打印系统 MQTT 通信配置
/// 依据文档: MQTT通信接口说明与定义文档 v1.0
class HardwareConfig {
  // ─── EMQX Broker (公共) ────────────────────────
  static const String mqttBrokerHost = 'broker.emqx.io';
  static const int mqttPort = 1883;
  static const int mqttQos = 0;
  static const String mqttClientId = 'bisheng_app';
  static const int keepAlivePeriod = 60;

  // ─── 板端设备 ID ────────────────────────────────
  static const String deviceId = 'printer1878561109';

  // ─── App 订阅 Topic (板子发布) ──────────────────
  /// 状态变更 + 打印进度 (STATUS_STATE / STATUS_PROGRESS)
  static const String topicStatusState = 'printer1878561109/status/state';

  /// 三轴电机位置 (STATUS_POSITION)
  static const String topicStatusPosition = 'printer1878561109/status/position';

  /// 错误上报 (STATUS_ERROR)
  static const String topicStatusError = 'printer1878561109/status/error';

  /// OCR 识别结果 (STATUS_OCR_RESULT)
  static const String topicStatusOcr = 'printer1878561109/status/ocr';

  /// 心跳——文档标注预留，暂未启用
  // static const String topicStatusHeartbeat = 'printer1878561109/status/heartbeat';

  // ─── App 发布 Topic (板子订阅) ──────────────────
  /// 打印指令 + 文字输入 (CMD_* / TEXT_BATCH)
  static const String topicCmdPrint = 'printer1878561109/cmd/print';

  /// 控制指令 (CMD_*)
  static const String topicCmdControl = 'printer1878561109/cmd/control';

  // ─── 命令类型 (App → 板子) ──────────────────────
  static const String cmdStartPrint = 'CMD_START_PRINT';
  // CMD_PAUSE_PRINT — 板端有 bug，不使用
  // CMD_RESUME_PRINT — 板端有 bug，不使用
  static const String cmdStopPrint = 'CMD_STOP_PRINT';
  static const String cmdEmergencyStop = 'CMD_EMERGENCY_STOP';
  static const String cmdHome = 'CMD_HOME';
  static const String cmdReset = 'CMD_RESET';
  static const String cmdStopOcr = 'CMD_STOP_OCR';
  static const String cmdTriggerTurnPage = 'CMD_TRIGGER_TURN_PAGE';

  // ─── 文字输入 ───────────────────────────────────
  static const String textBatch = 'TEXT_BATCH';

  // ─── 状态类型 (板子 → App) ──────────────────────
  static const String statusState = 'STATUS_STATE';
  static const String statusProgress = 'STATUS_PROGRESS';
  static const String statusPosition = 'STATUS_POSITION';
  static const String statusError = 'STATUS_ERROR';
  static const String statusOcrResult = 'STATUS_OCR_RESULT';

  // ─── BLE/WiFi 内部状态 (桩代码使用) ─────────────
  static const String statusConnected = 'STATUS_CONNECTED';
  static const String statusIdle = 'STATUS_IDLE';

  // ─── BLE (备用) ─────────────────────────────────
  static const String bleServiceUuid = '0000ffe0-0000-1000-8000-00805f9b34fb';
  static const String bleCharacteristicUuid = '0000ffe1-0000-1000-8000-00805f9b34fb';

  // ─── 连接/重连 ──────────────────────────────────
  static const int connectionTimeout = 5000;
  static const int commandTimeout = 3000;
  static const int reconnectDelayMs = 3000;
  static const int maxReconnectAttempts = 10;
}
