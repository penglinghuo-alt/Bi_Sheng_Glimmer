"""AI 新闻摘要 — 央视网公开接口聚合 + LLM 热度筛选

数据源: https://news.cctv.com (cmsdatainterface JSONP 接口)
策略:  央视接口优先，失败/超时自动回退到本地兜底数据，避免前端白屏。
热度:  抓取前 7 页合并为候选池（覆盖近一周），接入 LLM（DeepSeek）从中挑选
        近一周最重要的大事件 5 条并置顶；未配置 API Key 或调用失败时降级为
        启发式（取候选池前 5 条）。
原文:  GET /api/news/detail 抓取新闻网页正文，供前端应用内查看。
缓存:  候选池内存缓存 5 分钟；热度筛选结果独立缓存 5 分钟。
"""
import json
import os
import re
import time
import urllib.request
from html.parser import HTMLParser
from typing import List, Optional, Tuple

from fastapi import APIRouter
from pydantic import BaseModel

from services import llm

router = APIRouter(prefix="/api/news", tags=["AI 新闻"])

CCTV_URL = (
    "https://news.cctv.com/2019/07/gaiban/cmsdatainterface/"
    "page/news_{n}.jsonp?cb=cb"
)

# 央视该接口最多约 7 页（每页 80 条），约覆盖近一周新闻
_CCTV_PAGES = 7

_FALLBACK_FILE = os.path.join(os.path.dirname(__file__), "..", "..", "data", "news_fallback.json")

_HOT_COUNT = 5
_LATEST_COUNT = 80  # 非热度新闻最多返回条数

_cache: dict = {"ts": 0.0, "items": []}
_CACHE_TTL = 300.0  # 5 分钟

_hot_cache: dict = {"ts": 0.0, "ids": []}

_article_cache: dict = {"ts": {}, "items": {}}
_ARTICLE_TTL = 600.0  # 10 分钟


class NewsItem(BaseModel):
    id: str
    title: str
    brief: str
    keywords: str
    url: str
    focus_date: Optional[str] = None
    image: Optional[str] = None
    is_hot: bool = False
    hot_rank: Optional[int] = None


class NewsListResponse(BaseModel):
    source: str
    total: int
    items: List[NewsItem]


class NewsDetailResponse(BaseModel):
    url: str
    title: str
    content: str


def _fetch_cctv(pages: int = _CCTV_PAGES) -> List[dict]:
    """抓取前 pages 页并合并去重，得到覆盖近一周的候选池。"""
    seen: dict = {}
    for n in range(1, pages + 1):
        url = CCTV_URL.format(n=n)
        try:
            req = urllib.request.Request(url, headers={
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
                "Referer": "https://news.cctv.com/",
            })
            with urllib.request.urlopen(req, timeout=8) as resp:
                raw = resp.read().decode("utf-8", errors="ignore")

            # JSONP 格式: news({...})，提取括号内的 JSON
            match = re.search(r"news\((.*)\)\s*;?\s*$", raw, re.S)
            if not match:
                continue
            obj = json.loads(match.group(1))
            for it in obj.get("data", {}).get("list", []):
                title = (it.get("title") or "").strip()
                nid = str(it.get("id") or "")
                if not title or not nid or nid in seen:
                    continue
                seen[nid] = {
                    "id": nid,
                    "title": title,
                    "brief": (it.get("brief") or "").strip(),
                    "keywords": (it.get("keywords") or "").strip(),
                    "url": (it.get("url") or "").strip(),
                    "focus_date": it.get("focus_date"),
                    "image": it.get("image") or None,
                }
        except Exception:
            continue
    return list(seen.values())


def _load_fallback() -> List[dict]:
    try:
        with open(_FALLBACK_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, list) else []
    except Exception:
        return []


def _get_items() -> Tuple[str, List[dict]]:
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


def _select_hot_ids(items: List[dict]) -> List[str]:
    """挑选近一周最重要的大事件 5 条（按热度从高到低）。

    优先用 LLM 基于候选池（近一周新闻）判断；未配置 API Key 或调用失败时，
    降级为取候选池前 5 条（候选池按央视页面顺序 = 最新在前）。
    """
    if llm.llm_configured():
        try:
            candidates = [
                {"id": it["id"], "title": it["title"], "brief": it["brief"], "date": it.get("focus_date") or ""}
                for it in items
            ]
            user = (
                "下面是某新闻平台近一周的新闻候选列表（JSON 数组，含标题/摘要/发布时间）。\n"
                "请从中挑选近一周内最重要、公众关注度最高的大事件 %d 条，按热度从高到低排列。\n"
                "注意：只选影响大、有持续关注度的重要事件，不要选琐碎的日常新闻。\n"
                "只返回合法 JSON，格式：{\"hot_ids\": [\"<新闻id>\", ...]}，最多 %d 个，不要输出任何其他内容。\n"
                "候选列表：%s"
            ) % (_HOT_COUNT, _HOT_COUNT, json.dumps(candidates, ensure_ascii=False))
            data = llm.chat_json(
                "你是资深新闻编辑，负责从近一周新闻中挑选最重要的大事件。只输出合法 JSON。",
                user,
            )
            ids = [str(x) for x in (data.get("hot_ids") or [])]
            known = {it["id"] for it in items}
            picked = [x for x in ids if x in known][:_HOT_COUNT]
            if picked:
                return picked
        except Exception:
            pass
    return [it["id"] for it in items[:_HOT_COUNT]]


def _mark_hot(items: List[dict]) -> List[dict]:
    """标记热度最高的 5 条并置顶（带独立缓存，避免频繁调 LLM）。"""
    now = time.time()
    if now - _hot_cache["ts"] >= _CACHE_TTL or not _hot_cache["ids"]:
        _hot_cache["ids"] = _select_hot_ids(items)
        _hot_cache["ts"] = now

    order = {hid: i for i, hid in enumerate(_hot_cache["ids"])}
    ranked = [it for it in items if it["id"] in order]
    ranked.sort(key=lambda it: order[it["id"]])
    rest = [it for it in items if it["id"] not in order]

    out = []
    for i, it in enumerate(ranked):
        copy = dict(it)
        copy["is_hot"] = True
        copy["hot_rank"] = i + 1
        out.append(copy)
    for it in rest:
        copy = dict(it)
        copy["is_hot"] = False
        copy["hot_rank"] = None
        out.append(copy)
    return out


# ─── 原文正文抓取 ─────────────────────────────────

def _detect_charset(resp, raw: bytes) -> str:
    ctype = resp.headers.get("Content-Type", "")
    m = re.search(r"charset=([\w-]+)", ctype, re.I)
    if m:
        return m.group(1)
    head = raw[:2048].decode("latin-1", errors="ignore")
    m = re.search(r'charset=["\']?([\w-]+)', head, re.I)
    return m.group(1) if m else "utf-8"


def _strip_scripts(html: str) -> str:
    html = re.sub(r"<script[\s\S]*?</script>", "", html, flags=re.I)
    html = re.sub(r"<style[\s\S]*?</style>", "", html, flags=re.I)
    return html


class _ContentExtractor(HTMLParser):
    """提取 id=content_area 的 div 内纯文本（保留段落换行）。"""

    def __init__(self) -> None:
        super().__init__()
        self._capture = False
        self._depth = 0
        self._buf: List[str] = []

    def handle_starttag(self, tag: str, attrs) -> None:
        attr_map = dict(attrs)
        if not self._capture:
            if tag == "div" and attr_map.get("id", "").lower() == "content_area":
                self._capture = True
                self._depth = 1
                self._buf.append("\n")
            return
        if tag == "div":
            self._depth += 1
        if tag in ("p", "br", "div", "h1", "h2", "h3", "li"):
            self._buf.append("\n")

    def handle_endtag(self, tag: str) -> None:
        if self._capture and tag == "div":
            self._depth -= 1
            if self._depth <= 0:
                self._capture = False

    def handle_data(self, data: str) -> None:
        if self._capture:
            self._buf.append(data)


def _clean_text(text: str) -> str:
    lines = [re.sub(r"\s+", " ", ln).strip() for ln in text.splitlines()]
    lines = [ln for ln in lines if ln]
    content = "\n".join(lines)
    return content[:12000]


def _extract_contentdate(html: str) -> str:
    """提取页面内 var contentdate = '...' 的 JS 字符串正文（央视正文内嵌于此）。"""
    idx = html.find("var contentdate")
    if idx < 0:
        return ""
    start = html.find("'", idx + len("var contentdate"))
    if start < 0:
        return ""
    out = []
    k = start + 1
    while k < len(html):
        c = html[k]
        if c == "\\":
            if k + 1 < len(html):
                out.append(html[k + 1])
            k += 2
            continue
        if c == "'":
            break
        out.append(c)
        k += 1
    return "".join(out)


def _html_to_text(html_fragment: str) -> str:
    text = re.sub(r"\[!--begin:.*?\[!--end:.*?\]", "", html_fragment, flags=re.S)
    text = re.sub(r"<[^>]+>", "\n", text)
    import html as _html
    return _clean_text(_html.unescape(text))


def _fetch_article(url: str) -> Tuple[str, str]:
    req = urllib.request.Request(url, headers={
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Referer": "https://news.cctv.com/",
    })
    with urllib.request.urlopen(req, timeout=10) as resp:
        raw = resp.read()
    charset = _detect_charset(resp, raw)
    try:
        html = raw.decode(charset, errors="ignore")
    except LookupError:
        html = raw.decode("utf-8", errors="ignore")

    m = re.search(r"<title[^>]*>(.*?)</title>", html, re.S)
    title = (m.group(1).strip() if m else "").replace("\n", " ")[:200]

    # 优先取 JS 内嵌正文（需在剥离 script 之前提取）
    content = _html_to_text(_extract_contentdate(html))
    html = _strip_scripts(html)

    # 兜底：静态 content_area
    if not content:
        extractor = _ContentExtractor()
        extractor.feed(html)
        content = _clean_text("".join(extractor._buf))
    # 再兜底：整个 body 去标签
    if not content:
        m = re.search(r"<body[^>]*>(.*)</body>", html, re.S)
        if m:
            body = re.sub(r"<[^>]+>", "\n", m.group(1))
            content = _clean_text(body)
    return title, content


@router.get("/latest", response_model=NewsListResponse, summary="获取新闻列表（近一周大事件前5置顶）")
def get_latest_news() -> NewsListResponse:
    source, items = _get_items()
    marked = _mark_hot(items)
    hot = [it for it in marked if it["is_hot"]]
    rest = [it for it in marked if not it["is_hot"]]
    rest.sort(key=lambda it: it.get("focus_date") or "", reverse=True)
    items = hot + rest[:_LATEST_COUNT]
    return NewsListResponse(
        source=source,
        total=len(items),
        items=[NewsItem(**it) for it in items],
    )


@router.get("/detail", response_model=NewsDetailResponse, summary="抓取新闻原文正文（带缓存）")
def get_news_detail(url: str) -> NewsDetailResponse:
    if not url:
        return NewsDetailResponse(url="", title="", content="")
    now = time.time()
    if url in _article_cache["items"]:
        item = _article_cache["items"][url]
        if now - _article_cache["ts"].get(url, 0.0) < _ARTICLE_TTL:
            return NewsDetailResponse(**item)
    try:
        title, content = _fetch_article(url)
    except Exception as e:
        return NewsDetailResponse(url=url, title="", content=f"原文抓取失败: {e}")
    item = {"url": url, "title": title, "content": content}
    _article_cache["items"][url] = item
    _article_cache["ts"][url] = now
    return NewsDetailResponse(**item)
