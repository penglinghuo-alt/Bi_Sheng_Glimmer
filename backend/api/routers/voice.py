"""语音输入 — 客户端采集推流 + sherpa-onnx 流式转写

客户端（网页/App）在本地采集 USB 麦克风/手机麦克风音频，
通过 WebSocket 将 16kHz 单声道 float32 PCM 分块推送到本后端，
后端用 sherpa-onnx streaming zipformer 实时转写，
回推 partial 文本，停止时返回完整文本，可保存进存储库用于打印。

依赖: sherpa-onnx, numpy
"""
import json
import os
import threading
import uuid

import numpy as np
from fastapi import APIRouter, Depends, HTTPException, status, WebSocket
from pydantic import BaseModel
from sqlalchemy.orm import Session

from database import get_db
from models import BrailleRecord, User
from auth_utils import get_current_user

try:
    import sherpa_onnx
except Exception as e:  # 依赖缺失时接口返回明确错误
    sherpa_onnx = None
    _IMPORT_ERROR = str(e)

router = APIRouter(prefix="/api/voice", tags=["语音输入"])

_MODEL_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "models", "zh14m")
_SAMPLE_RATE = 16000
_ENCODER = os.path.join(_MODEL_DIR, "encoder-epoch-99-avg-1.int8.onnx")
_DECODER = os.path.join(_MODEL_DIR, "decoder-epoch-99-avg-1.int8.onnx")
_JOINER = os.path.join(_MODEL_DIR, "joiner-epoch-99-avg-1.int8.onnx")
_TOKENS = os.path.join(_MODEL_DIR, "tokens.txt")

_lock = threading.Lock()
_recognizer = None


class SaveRequest(BaseModel):
    title: str = ""
    text: str


class VoiceStatusResponse(BaseModel):
    ready: bool
    detail: str


class VoiceSaveResponse(BaseModel):
    id: str
    title: str
    source_type: str


def _ensure_deps():
    if sherpa_onnx is None:
        raise HTTPException(status_code=500, detail=f"语音依赖未安装: {_IMPORT_ERROR}")


def _get_recognizer():
    global _recognizer
    _ensure_deps()
    if _recognizer is not None:
        return _recognizer
    if not all(os.path.isfile(p) for p in (_ENCODER, _DECODER, _JOINER, _TOKENS)):
        raise HTTPException(status_code=500, detail="语音模型文件缺失，请检查 backend/models/zh14m")
    _recognizer = sherpa_onnx.OnlineRecognizer.from_transducer(
        tokens=_TOKENS,
        encoder=_ENCODER,
        decoder=_DECODER,
        joiner=_JOINER,
        num_threads=2,
        decoding_method="greedy_search",
        # 关闭端点自动检测：由客户端"按住说话/松开"控制一段话的起止，
        # 避免说话中途停顿触发自动 reset 导致已识别文本丢失
        enable_endpoint_detection=False,
    )
    return _recognizer


def _feed_decode(recognizer, stream, samples):
    """在锁内喂入一帧 PCM 并解码，返回当前部分文本。"""
    with _lock:
        stream.accept_waveform(_SAMPLE_RATE, samples)
        while recognizer.is_ready(stream):
            recognizer.decode_stream(stream)
        return recognizer.get_result_all(stream).text


def _finish_decode(recognizer, stream):
    """在锁内收尾：补尾部静音、结束输入、返回最终文本。"""
    with _lock:
        tail = np.zeros(int(0.4 * _SAMPLE_RATE), dtype=np.float32)
        stream.accept_waveform(_SAMPLE_RATE, tail)
        stream.input_finished()
        while recognizer.is_ready(stream):
            recognizer.decode_stream(stream)
        return recognizer.get_result_all(stream).text


@router.websocket("/ws")
async def voice_ws(ws: WebSocket):
    """WebSocket 实时转写端点。

    客户端用文本消息发控制指令，用二进制消息发 float32 PCM（16000Hz 单声道）：
      -> {"type":"start"}      开始一次识别
      -> <bytes: float32 PCM>  持续推送音频，服务端回推 {"type":"partial","text":...}
      -> {"type":"stop"}       结束本次识别，服务端回推 {"type":"final","text":...}
    服务端错误回推 {"type":"error","detail":...}
    """
    await ws.accept()
    if sherpa_onnx is None:
        await ws.send_text(json.dumps({"type": "error", "detail": f"语音依赖未安装: {_IMPORT_ERROR}"}))
        await ws.close()
        return
    try:
        recognizer = _get_recognizer()
    except HTTPException as e:
        await ws.send_text(json.dumps({"type": "error", "detail": e.detail}))
        await ws.close()
        return

    stream = None
    try:
        while True:
            message = await ws.receive()
            if message["type"] == "websocket.disconnect":
                break
            if message["type"] != "websocket.receive":
                continue
            if "bytes" in message and message["bytes"]:
                data = message["bytes"]
                if stream is None or len(data) == 0:
                    continue
                samples = np.frombuffer(data, dtype=np.float32)
                if samples.size == 0:
                    continue
                text = await _run_blocking(_feed_decode, recognizer, stream, samples)
                if text:
                    await ws.send_text(json.dumps({"type": "partial", "text": text}))
            elif "text" in message and message["text"]:
                try:
                    ctrl = json.loads(message["text"])
                except (ValueError, TypeError):
                    continue
                ctype = ctrl.get("type")
                if ctype == "start":
                    if stream is None:
                        stream = recognizer.create_stream()
                    else:
                        recognizer.reset(stream)
                    await ws.send_text(json.dumps({"type": "started"}))
                elif ctype == "stop":
                    if stream is not None:
                        final = await _run_blocking(_finish_decode, recognizer, stream)
                        stream = None
                        await ws.send_text(json.dumps({"type": "final", "text": final}))
    except Exception as e:  # noqa: BLE001
        try:
            await ws.send_text(json.dumps({"type": "error", "detail": str(e)}))
        except Exception:  # noqa: BLE001
            pass
    finally:
        pass


async def _run_blocking(fn, *args):
    """在独立线程执行 CPU 密集的 sherpa-onnx 解码，避免阻塞事件循环。"""
    from starlette.concurrency import run_in_threadpool
    return await run_in_threadpool(fn, *args)


@router.get("/status", response_model=VoiceStatusResponse, summary="查询语音服务状态")
def status_endpoint():
    _ensure_deps()
    if not os.path.isdir(_MODEL_DIR):
        return VoiceStatusResponse(ready=False, detail="模型目录缺失")
    return VoiceStatusResponse(ready=True, detail="语音服务就绪")


@router.post("/save", response_model=VoiceSaveResponse, status_code=status.HTTP_201_CREATED, summary="保存转写文本到存储库")
def save_endpoint(req: SaveRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    text = req.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="转写文本为空")
    now = __import__("datetime").datetime.now()
    title = req.title.strip()
    if not title:
        title = "语音输入_{:02d}{:02d}_{:02d}{:02d}".format(now.month, now.day, now.hour, now.minute)
    record = BrailleRecord(
        id=uuid.uuid4().hex[:16],
        user_id=current_user.id,
        title=title,
        source_type="语音输入",
        dot_matrix_width=0,
        dot_matrix_height=0,
        dot_matrix_data=[],
        text_content=text,
        page_count=1,
        source_post_id=None,
    )
    db.add(record)
    db.commit()
    db.refresh(record)
    return VoiceSaveResponse(id=record.id, title=record.title, source_type=record.source_type)
