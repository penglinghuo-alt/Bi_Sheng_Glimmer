# 板端硬件通信接口对接文档

## 概述

本文档描述 Flutter 前端中与 elf2 主控板通信的预留接口层，供负责硬件通信的同学修改。

当前代码已内置 Mock 实现（模拟异步延迟 + 假状态返回），APP 可完整运行。真实对接时只需替换 Mock 实现为真实 BLE/WiFi 操作代码。

## 架构分层

```
UI (HomePage / ControlPanel)
  │  read/notify DeviceState
  ▼
DeviceNotifier (lib/core/providers/device_provider.dart)
  │  调用方法、接收响应
  ▼
HardwareManager (lib/data/hardware/hardware_manager.dart)
  │  单例，管理 BLE/WiFi 模式切换
  ▼
IHardwareComm (抽象接口)
  ├── BleCommService  ← 你只需改这个
  └── WifiCommService ← 或这个
```

## 需要修改的文件（只需改这 3 个）

| 文件 | 说明 |
|------|------|
| `lib/data/hardware/ble_comm_service.dart` | BLE 通信实现（Mock） |
| `lib/data/hardware/wifi_comm_service.dart` | WiFi 通信实现（Mock） |
| `lib/core/constants/hardware_config.dart` | 协议常量（可按需扩展） |

以下文件无需修改：
- `lib/data/hardware/comm_interface.dart` — 接口定义，已固定
- `lib/data/hardware/hardware_manager.dart` — 管理器，已固定
- `lib/core/providers/device_provider.dart` — 状态管理，已固定（走 API，非直连硬件）

## 通信抽象接口

文件: `lib/data/hardware/comm_interface.dart`

```dart
abstract class IHardwareComm {
  Future<bool> connect(String deviceIdOrIp);
  Future<void> disconnect();
  Future<bool> initialize();
  Future<void> startScanAndPrint();
  Future<void> stopAll();
  Future<void> nextPaperReady();
  Future<void> sendCommand(String command, {Map<String, dynamic>? params});
  Stream<String> get deviceStatusStream;
}
```

### 各方法职责

| 方法 | 触发时机 | 应做什么 |
|------|---------|---------|
| `connect(id)` | 用户选择设备/输入IP后 | BLE: scan + connectGatt。WiFi: socket connect。返回 true/false |
| `disconnect()` | 用户断开或模式切换 | 关闭连接、释放资源 |
| `initialize()` | 连接成功后 | 发送初始化指令（校准摄像头、归位电机等），返回成功/失败 |
| `startScanAndPrint()` | 用户点击"确定打印" | 发送扫描+打印指令，后续通过 statusStream 推送进度 |
| `stopAll()` | 用户点"紧急停止" | 发送急停指令，硬件立即停止所有动作 |
| `nextPaperReady()` | 换纸完成后 | 通知硬件可以开始下一张纸的扫描打印 |
| `sendCommand(cmd,params)` | 高级/调试指令 | 透传自定义命令到硬件 |
| `deviceStatusStream` | 持续监听 | 硬件主动上报状态的 Stream（状态、进度、错误等） |

## 状态码协议

文件: `lib/core/constants/hardware_config.dart`

```dart
// 下行命令 (APP → 硬件)
static const String cmdStartScan      = 'CMD_START_SCAN';
static const String cmdStopAll        = 'CMD_STOP_ALL';
static const String cmdNextPaperReady = 'CMD_NEXT_PAPER_READY';
static const String cmdStartPrint     = 'CMD_START_PRINT';
static const String cmdQueryStatus    = 'CMD_QUERY_STATUS';

// 上行状态 (硬件 → APP，通过 statusStream)
static const String statusPaperDone = 'STATUS_PAPER_DONE';   // 当前页打印完
static const String statusPrinting  = 'STATUS_PRINTING';     // 打印中
static const String statusIdle      = 'STATUS_IDLE';         // 空闲待机
static const String statusError     = 'STATUS_ERROR';        // 异常
```

### deviceStatusStream 输出格式

Stream 推送的 JSON 字符串格式：

```json
{"status": "connected"}
{"status": "initializing"}
{"status": "initialized"}
{"status": "working", "step": "capturing"}
{"status": "working", "step": "printing"}
{"status": "stopped"}
{"status": "error", "message": "过热保护"}
```

UI 层通过 DeviceNotifier 订阅该 Stream，按 status 字段更新界面状态。

## BLE 实现模板

文件: `lib/data/hardware/ble_comm_service.dart`

你需要引入 `flutter_blue_plus` 或类似的 BLE 库。以下为推荐改造方向：

```dart
class BleCommService implements IHardwareComm {
  // 1. 添加 Bloc 或蓝牙管理库的单例
  // 2. connect() 中执行 BLE 扫描、连接 GATT
  // 3. listen 到 characteristic notify，将数据写入 _statusController
  // 4. 各命令方法 write characteristic 发送指令字节
  // 5. disconnect() 中断开 GATT、释放资源
}
```

关键常量（在 `HardwareConfig` 中已定义）：

```dart
static const String bleServiceUuid        = '0000ffe0-0000-1000-8000-00805f9b34fb';
static const String bleCharacteristicUuid = '0000ffe1-0000-1000-8000-00805f9b34fb';
```

这些是 elf2 主控板的默认 UUID。如果实际硬件不同，修改 `HardwareConfig` 中的值即可。

## WiFi 实现模板

文件: `lib/data/hardware/wifi_comm_service.dart`

elf2 板通常通过 TCP Socket (默认端口 8080) 透传串口指令：

```dart
class WifiCommService implements IHardwareComm {
  // 1. import 'dart:io'; 使用 Socket
  // 2. connect() 中 Socket.connect(ip, HardwareConfig.wifiPort)
  // 3. Socket.listen 读取数据，解析后写入 _statusController
  // 4. 命令方法通过 Socket 发送字节指令
  // 5. disconnect() 中 close socket
}
```

## 枚举定义参考

文件: `lib/core/constants/app_enums.dart`

```dart
enum DeviceStatus { disconnected, connecting, connected, initializing, initialized, working, printing, error }
enum PrintStep { idle, turningPage, capturing, recognizing, converting, printing, completed, stopped }
```

## API 后端交互（当前实现）

当前 DeviceNotifier 通过 HTTP API 调用后端接口（而非直连硬件）：

| 前端调用 | API 端点 |
|---------|---------|
| `DeviceNotifier.connect()` | `POST /api/device/connect` |
| `DeviceNotifier.disconnect()` | `POST /api/device/disconnect` |
| `DeviceNotifier.initialize()` | `POST /api/device/initialize` |
| `DeviceNotifier.startPrintJob()` | `POST /api/device/start` |
| `DeviceNotifier.emergencyStop()` | `POST /api/device/stop` |
| `DeviceNotifier.confirmPaperReady()` | `POST /api/device/paper-ready` |

这是当前的前后端分离方案。如果后续改为 APP 直连硬件（不经过后端），需要在 `DeviceNotifier` 中直接调用 `HardwareManager` 而非 `ApiClient`。两种方案可根据实际需求切换。

## 调试辅助

文件: `lib/core/utils/logger.dart`

```dart
Logger.info('[BLE] ...');
Logger.debug('[WiFi] ...');
Logger.error('[Hardware] ...');
```

所有通信代码已有 Logger 桩点，调试时可直接看到日志输出。

## 对接检查清单

- [ ] `ble_comm_service.dart` — 引入 BLE 库，实现 scan/connect/notify/write
- [ ] `wifi_comm_service.dart` — 引入 Socket，实现 TCP 连接+协议解析
- [ ] `hardware_config.dart` — 根据实际协议调整命令码和 UUID
- [ ] `deviceStatusStream` — 确保硬件状态能正确推送到 UI
- [ ] 异常处理 — 连接超时、断线重连、指令无响应等场景
- [ ] 真机测试 — Android 真机 BLE 需位置权限 + 蓝牙开关检测

## 联系

如需了解 UI 层对状态的消费逻辑，参考：
- `lib/features/home/view/home_page.dart`
- `lib/features/home/widgets/control_panel.dart`
- `lib/features/home/widgets/device_status_card.dart`
