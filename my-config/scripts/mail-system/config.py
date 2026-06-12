"""配置加载:从 .env 读凭证,组装两个邮箱账户。

凭证缺失或仍是 placeholder 的账户会被自动跳过,不会报错中断,
方便先只配 QQ、Gmail 稍后补。
"""
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent


def _load_env() -> None:
    env_path = BASE_DIR / ".env"
    if not env_path.exists():
        return
    for raw in env_path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        os.environ.setdefault(key.strip(), val.strip())


_load_env()


def _is_set(val: str | None) -> bool:
    """判断凭证是否真正填好(非空、非 placeholder)。"""
    return bool(val) and not val.startswith("YOUR_")


def get_accounts() -> list[dict]:
    """返回已配置好的账户列表。未填凭证的账户自动跳过。"""
    accounts = []

    qq_pw = os.environ.get("QQ_AUTH_CODE")
    qq_email = os.environ.get("QQ_EMAIL")
    if _is_set(qq_pw) and _is_set(qq_email):
        accounts.append({
            "name": "QQ",
            "email": qq_email,
            "password": qq_pw,
            "imap_host": "imap.qq.com",
            "imap_port": 993,
            # QQ 垃圾箱/已删除文件夹候选(按顺序探测)
            "trash_candidates": ["Deleted Messages", "已删除", "Junk", "垃圾邮件"],
        })

    gmail_pw = os.environ.get("GMAIL_APP_PASSWORD")
    gmail_email = os.environ.get("GMAIL_EMAIL")
    if _is_set(gmail_pw) and _is_set(gmail_email):
        accounts.append({
            "name": "Gmail",
            "email": gmail_email,
            "password": gmail_pw,
            "imap_host": "imap.gmail.com",
            "imap_port": 993,
            "trash_candidates": ["[Gmail]/Trash", "[Google Mail]/Trash"],
        })

    return accounts


def get_smtp_config() -> dict | None:
    """总结邮件通过 QQ SMTP 发送。QQ 未配则返回 None。"""
    qq_pw = os.environ.get("QQ_AUTH_CODE")
    qq_email = os.environ.get("QQ_EMAIL")
    if not (_is_set(qq_pw) and _is_set(qq_email)):
        return None
    return {
        "host": "smtp.qq.com",
        "port": 465,
        "user": qq_email,
        "password": qq_pw,
        "to": os.environ.get("DIGEST_TO") or qq_email,
    }


OLLAMA_MODEL = os.environ.get("OLLAMA_MODEL", "qwen3:8b")
OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "http://127.0.0.1:11434")
PHYSICAL_IFACE = os.environ.get("PHYSICAL_IFACE", "").strip()
