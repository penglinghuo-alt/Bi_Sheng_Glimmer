# MQTT 接入 EMQX Broker 改造说明

## 依据文档

《盲文打印系统 MQTT 通信接口说明与定义文档》v1.0，设备 ID: `printer1878561109`

## Topic 设计

### App 订阅的 Topic (接收板子数据)

| Topic | 消息类型 |
|-------|---------|
| `printer1878561109/status/state` | STATUS_STATE, STATUS_PROGRESS |
| `printer1878561109/status/position` | STATUS_POSITION |
| `printer1878561109/status/error` | STATUS_ERROR |
| `printer1878561109/status/ocr` | STATUS_OCR_RESULT |

> `printer1878561109/status/heartbeat` 为预留 Topic，暂未启用，App 不订阅

### App 发布的 Topic (向板子发指令)

| Topic | 消息类型 |
|-------|---------|
| `printer1878561109/cmd/print` | CMD_*, TEXT_BATCH |
| `printer1878561109/cmd/control` | CMD_* |

> 每个命令同时发布到以上两个 Topic

## 变更文件

| 文件 | 变更 |
|------|------|
| `hardware_config.dart` | 按文档重写：设备 ID `printer1878561109`、QoS 0、keepAlive 60s、8 个 Topic 常量、7 个命令类型、5 个状态类型 |
| `comm_protocol.dart` | 新增 `ts`/`src` 字段支持；新增 `StatusState`、`StatusPosition`、`StatusOcrResult`、`CmdHome`、`CmdReset`、`CmdStopOcr`、`CmdTriggerTurnPage`、`TextBatch`；移除 `CmdPausePrint` |
| `mqtt_comm_service.dart` | 订阅 4 个状态 Topic (跳过 heartbeat)；命令双发 `cmd/print` + `cmd/control`；QoS 改为 0；keepAlive 60s |
| `device_provider.dart` | 新增 `boardState`、`motorX/Y1/Y2`、`ocrText`、`ocrTotalChars` 字段；处理全部 5 种状态消息；板端状态映射到 App 状态 |
| `device_manage_page.dart` | 新增 MQTT 模式选项，连接按钮显示 Broker 地址 |
| `HARDWARE_COMM_GUIDE.md` | 重写为 v3.0，基于正式协议 |

## 需要配置

所有配置已填入正确值，无需手动修改：

- Broker: `broker.emqx.io:1883` (公共，无认证)
- QoS: 0
- keepAlive: 60s
- 设备 ID: `printer1878561109`

## 验证方法

```bash
# 监听板子所有状态 Topic
mosquitto_sub -h broker.emqx.io -p 1883 -t "printer1878561109/status/+" -v

# 模拟板子发状态消息
mosquitto_pub -h broker.emqx.io -p 1883 -t "printer1878561109/status/state" -m '{"type":"STATUS_STATE","payload":{"new_state":"IDLE","reason":"test"},"ts":1752650123.456,"src":"test"}'
```
