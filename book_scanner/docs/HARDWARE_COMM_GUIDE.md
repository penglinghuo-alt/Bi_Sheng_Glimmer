# 板端硬件通信接口对接文档 (v3.0 — 基于正式 MQTT 协议)

## 通信架构

```
硬件 (RK3588 主控板)
  │ MQTT (TCP 1883, QoS 0)
  │ JSON {"type":"...","payload":{...},"ts":...,"src":"..."}
  ▼
EMQX Broker (broker.emqx.io:1883)
  │
  ▼
IHardwareComm (抽象接口)
  ├── MqttCommService  ← 已完整实现
  ├── BleCommService   ← BLE 备用 (桩代码)
  └── WifiCommService  ← WiFi 备用 (桩代码)
  │
  ▼
HardwareManager (单例，管理模式切换)
  │
  ▼
DeviceNotifier (状态管理)
  │
  ▼
UI (HomePage / DeviceManagePage)
```

## MQTT 配置

文件: `lib/core/constants/hardware_config.dart`

```dart
static const String mqttBrokerHost = 'broker.emqx.io';
static const int mqttPort = 1883;
static const int mqttQos = 0;
static const String mqttClientId = 'bisheng_app';
static const int keepAlivePeriod = 60;       // 板端: 60s
static const int reconnectDelayMs = 3000;
static const int maxReconnectAttempts = 10;
static const String deviceId = 'printer1878561109';
```

## Topic 总览

### App 订阅 (板子发布)

| Topic | 消息 type | 说明 |
|-------|----------|------|
| `printer1878561109/status/state` | `STATUS_STATE`, `STATUS_PROGRESS` | 状态变更 + 打印进度 |
| `printer1878561109/status/position` | `STATUS_POSITION` | 三轴电机位置 (脉冲) |
| `printer1878561109/status/error` | `STATUS_ERROR` | 错误上报 |
| `printer1878561109/status/ocr` | `STATUS_OCR_RESULT` | OCR 识别结果 |

> `printer1878561109/status/heartbeat` — 预留，暂未启用

### App 发布 (板子订阅)

| Topic | 消息 type | 说明 |
|-------|----------|------|
| `printer1878561109/cmd/print` | `CMD_*`, `TEXT_BATCH` | 打印指令 + 文字输入 |
| `printer1878561109/cmd/control` | `CMD_*` | 控制指令 |

> App 命令同时发布到 `cmd/print` 和 `cmd/control` 两个 Topic，板子均可接收。

## 消息格式

所有消息使用统一 JSON 信封：

```json
{
  "type": "CMD_START_PRINT",
  "payload": {},
  "src": "external"
}
```

- `type` — 消息类型标识 (必填)
- `payload` — 消息负载 (必填，可为空 `{}`)
- `src` — 来源标识 (App 统一填 `"external"`)
- `ts` — 时间戳，板端出站消息自动填充 (App 入站不填)

## 命令类型 (App → 板子)

| type | payload | 说明 |
|------|---------|------|
| `CMD_START_PRINT` | `{}` | 开始打印 / 确认换页 |
| `CMD_STOP_PRINT` | `{}` | 停止打印，清空队列 |
| `CMD_EMERGENCY_STOP` | `{}` | 急停 (优先级最高) |
| `CMD_HOME` | `{}` | 三轴回零 |
| `CMD_RESET` | `{}` | 复位，清空队列恢复 IDLE |
| `CMD_STOP_OCR` | `{}` | 停止 OCR 循环 |
| `CMD_TRIGGER_TURN_PAGE` | `{}` | 触发翻页 |
| `TEXT_BATCH` | `{"text": "..."}` | 文字输入 |

> `CMD_PAUSE_PRINT` / `CMD_RESUME_PRINT` — 板端有 bug，App 侧已移除

## 状态类型 (板子 → App)

| type | payload | 说明 |
|------|---------|------|
| `STATUS_STATE` | `{"new_state": "IDLE"/"PRINTING"/"ERROR", "reason": "..."}` | 状态变更 |
| `STATUS_PROGRESS` | `{"current": 42, "total": 100, "percentage": 42.0}` | 逐字进度 |
| `STATUS_POSITION` | `{"y1": 153600, "y2": 153600, "x": 256000}` | 电机脉冲位置 |
| `STATUS_ERROR` | `{"code": "WATCHDOG_TIMEOUT", "msg": "..."}` | 错误上报 |
| `STATUS_OCR_RESULT` | `{"text": "...", "blocks": 3, "total_chars": 1250}` | OCR 结果 |

## 指令优先级

| 优先级 | 指令 |
|--------|------|
| 0 (最高) | `CMD_EMERGENCY_STOP` |
| 1 | `CMD_HOME` |
| 2 | `CMD_STOP_PRINT` |
| 5 | `CMD_START_PRINT` |
| 6 | `CMD_RESET` |

## 典型交互流程

```
App                          板子
 |                             |
 |── CMD_START_PRINT ─────────>|
 |                             |── STATUS_STATE(new_state=PRINTING)
 |                             |── STATUS_PROGRESS(current=1, total=20)
 |                             |── STATUS_POSITION(y1=153600, ...)
 |                             |── STATUS_PROGRESS(current=20, total=20)
 |                             |── STATUS_STATE(new_state=IDLE)
```

## 测试方法

### mosquitto 测试连通性

```bash
mosquitto_sub -h broker.emqx.io -p 1883 -t "printer1878561109/status/+" -v
```

### 模拟板子发消息

```bash
mosquitto_pub -h broker.emqx.io -p 1883 -t "printer1878561109/status/state" -m '{"type":"STATUS_STATE","payload":{"new_state":"IDLE","reason":"test"},"ts":1752650123.456,"src":"test"}'
```

### Flutter App 测试

进入设备管理页面，选择 MQTT 模式，点击连接按钮。日志输出：

```
[MQTT] 正在连接 broker.emqx.io:1883
[MQTT] 已连接 EMQX broker
[MQTT] 已订阅 4 个状态 Topic
[MQTT] onSubscribed → printer1878561109/status/state
[MQTT] onSubscribed → printer1878561109/status/position
[MQTT] onSubscribed → printer1878561109/status/error
[MQTT] onSubscribed → printer1878561109/status/ocr
```
