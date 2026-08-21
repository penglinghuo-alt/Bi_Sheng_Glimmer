"""AI 盲文报告 — 根据主题生成结构化长文报告，供盲文打印

用例（"眼盲心不盲"）：输入"本月科技发展"，AI 汇总生成多章节报告，
前端可一键打印为多页盲文书。
"""
from typing import Optional

from fastapi import APIRouter
from pydantic import BaseModel

from services import llm

router = APIRouter(prefix="/api/ai", tags=["AI 盲文报告"])


class ReportRequest(BaseModel):
    topic: str = ""
    extra: str = ""  # 可选补充要求


class ReportResponse(BaseModel):
    title: str
    content: str
    word_count: int


def _fallback_report(topic: str) -> ReportResponse:
    """未配置 LLM 或生成失败时的降级内容。"""
    title = topic.strip() or "AI 盲文报告"
    content = (
        f"【{title}】\n\n"
        "AI 汇总报告功能需要配置大模型 API Key 才能使用。\n"
        "请在后端 backend/.env 中设置 USER_LLM_API_KEY 后重启服务。\n\n"
        "未配置时，当前使用降级提示内容。"
    )
    return ReportResponse(title=title, content=content, word_count=len(content))


@router.post("/report", response_model=ReportResponse, summary="根据主题生成 AI 盲文报告")
def generate_report(req: ReportRequest) -> ReportResponse:
    topic = (req.topic or "").strip() or "本月科技发展"
    extra = (req.extra or "").strip()

    if not llm.llm_configured():
        return _fallback_report(topic)

    system = (
        "你是专业科普编辑，为视障人士撰写适合盲文朗读的信息报告。\n"
        "要求：结构清晰，使用 # 作为大标题、## 作为章节标题，每章 2-4 段；"
        "语言通俗、表述完整、可朗读；全文 2000-3500 字。只输出报告正文。"
    )
    user = (
        "请围绕主题【{topic}】撰写一篇完整报告。{extra}"
    ).format(topic=topic, extra=("补充要求：" + extra if extra else ""))

    try:
        content = llm.chat(system, user, timeout=150, max_tokens=6000).strip()
    except Exception:
        return _fallback_report(topic)

    if not content:
        return _fallback_report(topic)

    # 标题：取第一个 # 标题，否则用主题
    title = topic
    for line in content.splitlines():
        if line.strip().startswith("#"):
            title = line.strip().lstrip("#").strip()
            break
    return ReportResponse(title=title, content=content, word_count=len(content))
