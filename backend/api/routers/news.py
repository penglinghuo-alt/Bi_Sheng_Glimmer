"""AI 新闻摘要 — 央视网公开接口聚合

数据源: https://news.cctv.com (cmsdatainterface JSONP 接口)
策略:  央视接口优先，失败/超时自动回退到本地兜底数据，避免前端白屏。
缓存:  模块级内存缓存 5 分钟，降低对上游接口的请求频率。
"""
import json
import os
import re
import time
import urllib.request
from typing import List, Optional

from fastapi import APIRouter
from pydantic import BaseModel

router = APIRouter(prefix="/api/news", tags=["AI 新闻"])

CCTV_URL = (
    "https://news.cctv.com/2019/07/gaiban/cmsdatainterface/"
    "page/news_1.jsonp?cb=cb"
)

_FALLBACK_FILE = os.path.join(os.path.dirname(__file__), "..", "..", "data", "news_fallback.json")

_cache: dict = {"ts": 0.0, "items": []}
_CACHE_TTL = 300.0  # 5 分钟


class NewsItem(BaseModel):
    id: str
    title: str
    brief: str
    keywords: str
    url: str
    focus_date: Optional[str] = None
    image: Optional[str] = None


class NewsListResponse(BaseModel):
    source: str
    total: int
    items: List[NewsItem]


def _fetch_cctv() -> List[dict]:
    req = urllib.request.Request(CCTV_URL, headers={
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Referer": "https://news.cctv.com/",
    })
    with urllib.request.urlopen(req, timeout=8) as resp:
        raw = resp.read().decode("utf-8", errors="ignore")

    # JSONP 格式: news({...})，提取括号内的 JSON
    match = re.search(r"news\((.*)\)\s*;?\s*$", raw, re.S)
    if not match:
        return []
    obj = json.loads(match.group(1))
    items = obj.get("data", {}).get("list", [])
    out = []
    for it in items:
        title = (it.get("title") or "").strip()
        if not title:
            continue
        out.append({
            "id": str(it.get("id") or ""),
            "title": title,
            "brief": (it.get("brief") or "").strip(),
            "keywords": (it.get("keywords") or "").strip(),
            "url": (it.get("url") or "").strip(),
            "focus_date": it.get("focus_date"),
            "image": it.get("image") or None,
        })
    return out


def _load_fallback() -> List[dict]:
    try:
        with open(_FALLBACK_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, list) else []
    except Exception:
        return []


def _get_items() -> tuple[str, List[dict]]:
    now = time.time()
    if now - _cache["ts"] < _CACHE_TTL and _cache["items"]:
        return "cache", _cache["items"]

    items = []
    try:
        items = _fetch_cctv()
    except Exception:
        items = []

    source = "cctv"
    if not items:
        items = _load_fallback()
        source = "fallback"

    if items:
        _cache["ts"] = now
        _cache["items"] = items
    return source, items


@router.get("/latest", response_model=NewsListResponse, summary="获取最新新闻列表（央视优先，本地兜底）")
def get_latest_news() -> NewsListResponse:
    source, items = _get_items()
    return NewsListResponse(
        source=source,
        total=len(items),
        items=[NewsItem(**it) for it in items],
    )
