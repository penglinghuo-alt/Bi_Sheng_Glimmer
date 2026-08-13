import 'dart:convert';

// ─── App → 板子 命令 ──────────────────────────────
class CmdStartPrint {
  static const String type = 'CMD_START_PRINT';
  final Map<String, dynamic> payload;
  const CmdStartPrint({this.payload = const {}});
  Map<String, dynamic> toJson() => _wrap(type, payload);
}

class CmdStopPrint {
  static const String type = 'CMD_STOP_PRINT';
  final Map<String, dynamic> payload;
  const CmdStopPrint({this.payload = const {}});
  Map<String, dynamic> toJson() => _wrap(type, payload);
}

class CmdEmergencyStop {
  static const String type = 'CMD_EMERGENCY_STOP';
  final Map<String, dynamic> payload;
  const CmdEmergencyStop({this.payload = const {}});
  Map<String, dynamic> toJson() => _wrap(type, payload);
}

class CmdHome {
  static const String type = 'CMD_HOME';
  final Map<String, dynamic> payload;
  const CmdHome({this.payload = const {}});
  Map<String, dynamic> toJson() => _wrap(type, payload);
}

class CmdReset {
  static const String type = 'CMD_RESET';
  final Map<String, dynamic> payload;
  const CmdReset({this.payload = const {}});
  Map<String, dynamic> toJson() => _wrap(type, payload);
}

class CmdStopOcr {
  static const String type = 'CMD_STOP_OCR';
  final Map<String, dynamic> payload;
  const CmdStopOcr({this.payload = const {}});
  Map<String, dynamic> toJson() => _wrap(type, payload);
}

class CmdTriggerTurnPage {
  static const String type = 'CMD_TRIGGER_TURN_PAGE';
  final Map<String, dynamic> payload;
  const CmdTriggerTurnPage({this.payload = const {}});
  Map<String, dynamic> toJson() => _wrap(type, payload);
}

class TextBatch {
  static const String type = 'TEXT_BATCH';
  final String text;
  const TextBatch({required this.text});
  Map<String, dynamic> toJson() => _wrap(type, {'text': text});
}

// ─── 板子 → App 状态 ──────────────────────────────
class StatusState {
  static const String type = 'STATUS_STATE';
  final String newState;
  final String? reason;
  final double ts;
  final String? src;

  const StatusState({required this.newState, this.reason, required this.ts, this.src});

  factory StatusState.fromPayload(Map<String, dynamic> payload) {
    return StatusState(
      newState: payload['new_state'] ?? 'UNKNOWN',
      reason: payload['reason'],
      ts: (payload['ts'] ?? 0.0).toDouble(),
      src: payload['src'],
    );
  }

  bool get isIdle => newState == 'IDLE';
  bool get isPrinting => newState == 'PRINTING';
  bool get isError => newState == 'ERROR';
  bool get isPageComplete => newState == 'PAGE_COMPLETE';
}

class StatusProgress {
  static const String type = 'STATUS_PROGRESS';
  final int current;
  final int total;
  final double percentage;
  final double ts;
  final String? src;

  const StatusProgress({
    required this.current,
    required this.total,
    required this.percentage,
    required this.ts,
    this.src,
  });

  factory StatusProgress.fromPayload(Map<String, dynamic> payload) {
    return StatusProgress(
      current: payload['current'] ?? 0,
      total: payload['total'] ?? 0,
      percentage: (payload['percentage'] ?? 0.0).toDouble(),
      ts: (payload['ts'] ?? 0.0).toDouble(),
      src: payload['src'],
    );
  }
}

class StatusPosition {
  static const String type = 'STATUS_POSITION';
  final int y1;
  final int y2;
  final int x;
  final double ts;
  final String? src;

  const StatusPosition({
    required this.y1,
    required this.y2,
    required this.x,
    required this.ts,
    this.src,
  });

  factory StatusPosition.fromPayload(Map<String, dynamic> payload) {
    return StatusPosition(
      y1: payload['y1'] ?? 0,
      y2: payload['y2'] ?? 0,
      x: payload['x'] ?? 0,
      ts: (payload['ts'] ?? 0.0).toDouble(),
      src: payload['src'],
    );
  }
}

class StatusError {
  static const String type = 'STATUS_ERROR';
  final String code;
  final String msg;
  final double ts;
  final String? src;

  const StatusError({required this.code, required this.msg, required this.ts, this.src});

  factory StatusError.fromPayload(Map<String, dynamic> payload) {
    return StatusError(
      code: payload['code'] ?? 'UNKNOWN',
      msg: payload['msg'] ?? '未知错误',
      ts: (payload['ts'] ?? 0.0).toDouble(),
      src: payload['src'],
    );
  }
}

class StatusOcrResult {
  static const String type = 'STATUS_OCR_RESULT';
  final String text;
  final int blocks;
  final int totalChars;
  final double ts;
  final String? src;

  const StatusOcrResult({
    required this.text,
    required this.blocks,
    required this.totalChars,
    required this.ts,
    this.src,
  });

  factory StatusOcrResult.fromPayload(Map<String, dynamic> payload) {
    return StatusOcrResult(
      text: payload['text'] ?? '',
      blocks: payload['blocks'] ?? 0,
      totalChars: payload['total_chars'] ?? 0,
      ts: (payload['ts'] ?? 0.0).toDouble(),
      src: payload['src'],
    );
  }
}

// ─── 设备上线通知 (STATUS_ONLINE) ────────────────
/// 板端首次连接 MQTT Broker 后发布的扁平 JSON（不走通用 type/payload 包裹）
class StatusOnline {
  final String event;
  final String messageId;
  final String timestamp;
  final String clientId;
  final String configVersion;
  final Map<String, dynamic> services;
  final String healthStatus;
  final Map<String, dynamic> healthChecks;
  final int uptimeMs;

  const StatusOnline({
    required this.event,
    required this.messageId,
    required this.timestamp,
    required this.clientId,
    required this.configVersion,
    required this.services,
    required this.healthStatus,
    required this.healthChecks,
    required this.uptimeMs,
  });

  bool get isDeviceOnline => event == 'device_online';

  factory StatusOnline.fromRawJson(Map<String, dynamic> json) {
    final health = Map<String, dynamic>.from(json['health'] ?? {});
    return StatusOnline(
      event: json['event'] ?? '',
      messageId: json['message_id'] ?? '',
      timestamp: json['timestamp'] ?? '',
      clientId: json['client_id'] ?? '',
      configVersion: json['config_version'] ?? '',
      services: Map<String, dynamic>.from(json['services'] ?? {}),
      healthStatus: health['status'] ?? '',
      healthChecks: Map<String, dynamic>.from(health['checks'] ?? {}),
      uptimeMs: json['uptime_ms'] ?? 0,
    );
  }
}

// ─── 通用消息 ─────────────────────────────────────
class HardwareMessage {
  final String type;
  final Map<String, dynamic> payload;

  const HardwareMessage({required this.type, required this.payload});

  factory HardwareMessage.fromJson(Map<String, dynamic> json) {
    return HardwareMessage(
      type: json['type'] ?? '',
      payload: Map<String, dynamic>.from(json['payload'] ?? {}),
    );
  }

  factory HardwareMessage.fromJsonString(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final payload = Map<String, dynamic>.from(map['payload'] ?? {});
      payload['ts'] = map['ts'];
      payload['src'] = map['src'];
      return HardwareMessage(type: map['type'] ?? '', payload: payload);
    } catch (_) {
      return HardwareMessage(type: 'UNKNOWN', payload: {'raw': raw});
    }
  }

  Map<String, dynamic> toJson() => {'type': type, 'payload': payload};
  String toJsonString() => jsonEncode(toJson());
}

// ─── 内部工具 ─────────────────────────────────────
Map<String, dynamic> _wrap(String type, Map<String, dynamic> payload) {
  return {
    'type': type,
    'payload': payload,
    'src': 'external',
  };
}
