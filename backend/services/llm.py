"""轻量 LLM 客户端（OpenAI 兼容 /chat/completions，默认 DeepSeek）。

配置方式（环境变量，或 backend/.env）:
    USER_LLM_API_KEY   API Key（必填；未配置时上层功能自动降级为启发式）
    USER_LLM_BASE_URL   接口地址，默认 https://api.deepseek.com/v1
    USER_LLM_MODEL      模型名，默认 deepseek-chat
"""
import json
import os
import urllib.request

from dotenv import load_dotenv

load_dotenv()

DEFAULT_BASE_URL = "https://api.deepseek.com/v1"
DEFAULT_MODEL = "deepseek-chat"


def llm_api_key() -> str:
    return os.environ.get("USER_LLM_API_KEY", "").strip()


def llm_configured() -> bool:
    """LLM 是否已配置（有 API Key）。未配置时调用方应使用启发式降级。"""
    return bool(llm_api_key())


def chat_json(system: str, user: str, timeout: int = 40) -> dict:
    """调用 LLM 并强制返回 JSON 对象。出错时抛出异常由调用方降级。"""
    key = llm_api_key()
    if not key:
        raise RuntimeError("USER_LLM_API_KEY 未配置")
    base = os.environ.get("USER_LLM_BASE_URL", DEFAULT_BASE_URL).rstrip("/")
    model = os.environ.get("USER_LLM_MODEL", DEFAULT_MODEL).strip() or DEFAULT_MODEL
    url = base + "/chat/completions"
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "temperature": 0.2,
        "response_format": {"type": "json_object"},
    }
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {key}",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    content = data["choices"][0]["message"]["content"]
    return json.loads(content)


def chat(
    system: str,
    user: str,
    timeout: int = 120,
    max_tokens: int = 4096,
    temperature: float = 0.7,
) -> str:
    """调用 LLM 生成纯文本（长文/报告用）。出错时抛出异常由调用方处理。"""
    key = llm_api_key()
    if not key:
        raise RuntimeError("USER_LLM_API_KEY 未配置")
    base = os.environ.get("USER_LLM_BASE_URL", DEFAULT_BASE_URL).rstrip("/")
    model = os.environ.get("USER_LLM_MODEL", DEFAULT_MODEL).strip() or DEFAULT_MODEL
    url = base + "/chat/completions"
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "temperature": temperature,
        "max_tokens": max_tokens,
    }
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {key}",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    return data["choices"][0]["message"]["content"]
