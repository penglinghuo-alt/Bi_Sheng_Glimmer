class HardwareConfig {
  // ─── EMQX Broker ────────────────────────────────
  /// 按实际部署的 EMQX 地址填写
  static const String mqttBrokerHost = '192.168.xx.xx';
  static const int mqttPort = 1883;
  static const bool mqttUseWebSocket = false;
  static const int mqttQos = 1;
  static const String mqttClientId = 'bisheng_app';

  // ─── EMQX 认证 (无认证则留空) ──────────────────
  static const String? mqttUsername = null;
  static const String? mqttPassword = null;

  // ─── MQTT Topic ────────────────────────────────
  /// 板子发布的 Topic (APP 订阅此 Topic 接收板子数据)
  static const String topicDeviceToApp = 'bisheng/status';

  /// APP 下发命令的 Topic (板子订阅此 Topic 接收指令)
  static const String topicAppToDevice = 'bisheng/cmd';

  // ─── BLE (备用) ─────────────────────────────────
  static const String bleServiceUuid = '0000ffe0-0000-1000-8000-00805f9b34fb';
  static const String bleCharacteristicUuid = '0000ffe1-0000-1000-8000-00805f9b34fb';

  // ─── 命令类型 (APP → 板子) ────────────────────────
  static const String cmdStartPrint = 'CMD_START_PRINT';
  // CMD_PAUSE_PRINT 已移除——板端该命令有 bug
  static const String cmdStopPrint = 'CMD_STOP_PRINT';
  static const String cmdEmergencyStop = 'CMD_EMERGENCY_STOP';

  // ─── 状态类型 (板子 → APP) ────────────────────────
  static const String statusProgress = 'STATUS_PROGRESS';
  static const String statusError = 'STATUS_ERROR';
  static const String statusIdle = 'STATUS_IDLE';
  static const String statusConnected = 'STATUS_CONNECTED';

  // ─── 连接 ───────────────────────────────────────
  static const int connectionTimeout = 5000;
  static const int commandTimeout = 3000;
  static const int keepAlivePeriod = 30;
  static const int reconnectDelayMs = 3000;
  static const int maxReconnectAttempts = 10;
}
