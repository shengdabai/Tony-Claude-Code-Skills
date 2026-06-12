"""用本机 Ollama 模型为重要邮件生成中文要点。

Ollama 不可用时返回 None,主程序自动降级为「发件人+主题」纯列表,
保证总结邮件永远发得出去。
"""
import json
import re
from urllib.request import Request, ProxyHandler, build_opener

from config import OLLAMA_HOST, OLLAMA_MODEL

# 强制不走代理访问本地 Ollama(避免 http_proxy 把 localhost 也代理掉)
_opener = build_opener(ProxyHandler({}))

_SYSTEM = (
    "你是高效的私人邮件助理。下面是用户过去 24 小时收到的重要邮件清单。"
    "请用简洁中文,为每封邮件提炼一句话核心要点,并在行首标注 "
    "【需处理】或【知会】。按紧急程度从高到低排序。"
    "直接输出列表,不要任何开场白、结束语或解释。"
)


def summarize(important_mails: list[dict], max_items: int = 40) -> str | None:
    if not important_mails:
        return "(过去 24 小时无重要邮件)"

    total = len(important_mails)
    subset = important_mails[:max_items]
    lines = []
    for m in subset:
        snippet = (m.get("snippet") or "").strip()[:200]
        lines.append(
            f"- 发件人:{m['sender']} | 主题:{m['subject']}"
            + (f" | 摘要:{snippet}" if snippet else "")
        )
    overflow = f"\n\n…另有 {total - max_items} 封重要邮件未逐条列出" if total > max_items else ""
    prompt = "/no_think\n" + _SYSTEM + "\n\n邮件清单:\n" + "\n".join(lines)

    payload = {
        "model": OLLAMA_MODEL,
        "prompt": prompt,
        "stream": False,
        "options": {"temperature": 0.3},
    }
    try:
        req = Request(
            OLLAMA_HOST.rstrip("/") + "/api/generate",
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"},
        )
        with _opener.open(req, timeout=180) as r:
            data = json.load(r)
        text = data.get("response", "")
        # 去掉 qwen3 等模型的思考块
        text = re.sub(r"<think>.*?</think>", "", text, flags=re.S).strip()
        return (text + overflow) if text else None
    except Exception:
        return None
