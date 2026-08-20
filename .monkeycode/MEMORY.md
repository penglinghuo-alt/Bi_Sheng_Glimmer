# User Instruction Memory

This file records user instructions, preferences, and teachings for reference in future interactions.

## Format

### User Instruction Entry
User instruction entries should follow this format:

[User Instruction Summary]
- Date: [YYYY-MM-DD]
- Context: [Mentioned scenario or time]
- Instructions:
  - [Content of user teaching or instruction, described line by line]

### Project Knowledge Entry
Entries discovered by the Agent during task execution should follow this format:

[Project Knowledge Summary]
- Date: [YYYY-MM-DD]
- Context: Discovered by Agent while performing [specific task description]
- Category: [Operations & Deployment|Build Methods|Testing Methods|Troubleshooting & Debugging|Workflow & Collaboration|Environment Configuration]
- Instructions:
  - [Specific knowledge points, described line by line]

## Deduplication Strategy
- Before adding a new entry, check for similar or identical instructions.
- If a duplicate is found, skip the new entry or merge it with the existing one.
- When merging, update the context or date information.
- This helps avoid redundant entries and keeps the memory file tidy.

## Entries

[Project Knowledge Summary]
- Date: 2026-08-20
- Context: Discovered by Agent while deploying 央视新闻、语音输入 等后端功能并修复生产问题
- Category: Operations & Deployment
- Instructions:
  - 生产后端目录是用户 Windows 机器上的 `C:\wwwroot\backend`（即本仓库 backend/ 的部署副本），启动命令 `uvicorn main:app --host 0.0.0.0 --port 9000`，公网端口 9000 直连暴露，无 Nginx 反代，日志有大量扫描噪音
  - 生产 Python 版本 < 3.9，后端代码禁用 `tuple[str, ...]` 等 3.9+ 语法，须用 `typing.Tuple`（见 news.py 修复记录）
  - 前端 Web 的 baseUrl 直连 `http://119.91.119.89:9000`（api_client.dart），勿改成相对路径或本地地址

[Project Knowledge Summary]
- Date: 2026-08-20
- Context: Discovered by Agent while implementing 语音输入（客户端采集 + WebSocket 推流 + sherpa-onnx 转写）功能
- Category: Environment Configuration
- Instructions:
  - 生产后端运行在腾讯云服务器（无麦克风），语音采集必须在客户端（浏览器/App）完成：客户端本地采集 16kHz float32 PCM，经 WebSocket 推送到后端 `/api/voice/ws` 转写，后端再回推 partial/final 文本。服务器端不需要 sounddevice，只需 `pip install sherpa-onnx numpy`
  - sherpa-onnx>=1.11 Python API：用 `OnlineRecognizer.from_transducer(tokens, encoder, decoder, joiner, num_threads, decoding_method='greedy_search', enable_endpoint_detection=True, ...)` 工厂方法创建识别器；结果取 `get_result_all(stream).text`；OnlineStream 无 `free()` 方法，靠 GC 释放；流式喂入需按块 `accept_waveform` + `is_ready`/`decode_stream` 循环
  - 语音模型文件位于 `backend/models/zh14m/`（streaming-zipformer-zh-14M 的 int8 量化 encoder/decoder/joiner + tokens.txt，约 25MB）
  - Web 端 WS 地址从当前页面 URL 推导（`ws://`/`wss://` + `/api/voice/ws`），App 端从 ApiClient.baseUrl 推导；WS 端点无鉴权，靠公网访问控制
  - Web 麦克风采集用 `package:web` + `dart:web_audio` 兼容对象（AudioContext/ScriptProcessor），不能用 `dart:html`/`dart:web_audio` 原始库（analyze 报 deprecated/undefined）
  - 本地沙箱验证方式：edge-tts 合成中文语音 → ffmpeg 转 16kHz float32 PCM → Python websockets 客户端分块推送，可完整验证 WS 转写链路（含公网 WSS 代理）

[Project Knowledge Summary]
- Date: 2026-08-20
- Context: Discovered by Agent while managing code submissions
- Category: Workflow & Collaboration
- Instructions:
  - 本仓库 git 分支统一使用 `demo-mock-flow`，代码锚定为 GitHub 最新版本
  - Git 远程仓库已迁移，新地址 `https://github.com/penglinghuo-alt/Bi_Sheng_Glimmer.git`，旧地址仍可 push
