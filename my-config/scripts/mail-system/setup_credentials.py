#!/usr/bin/env python3
"""交互式安全录入邮箱凭证 → .env

授权码用 getpass 隐藏输入:
  - 终端不回显(看不到字符)
  - 不进入 shell 历史
  - 不进入任何对话 / 日志 / jsonl
写入的 .env 自动设为 600(仅本人可读写),并被 .gitignore 排除。

用法:
  cd ~/.claude/scripts/mail-system
  python3 setup_credentials.py
"""
import getpass
import os
import stat
from pathlib import Path

BASE = Path(__file__).resolve().parent
ENV = BASE / ".env"


def _read_existing() -> dict:
    existing = {}
    if ENV.exists():
        for line in ENV.read_text(encoding="utf-8").splitlines():
            s = line.strip()
            if not s or s.startswith("#") or "=" not in s:
                continue
            k, _, v = s.partition("=")
            existing[k.strip()] = v.strip()
    return existing


def _ask(label: str, default: str = "", secret: bool = False) -> str:
    suffix = f" [{default}]" if default and not secret else ""
    hint = "(隐藏输入,直接回车保留原值)" if secret else ""
    val = (getpass.getpass if secret else input)(f"{label}{suffix} {hint}: ").strip()
    return val or default


def main() -> None:
    print("=== 邮件系统凭证录入 ===")
    print("授权码为隐藏输入,不会显示、不进对话、不进 shell 历史。\n")
    old = _read_existing()

    def keep(k):
        v = old.get(k, "")
        return "" if v.startswith("YOUR_") else v

    qq_email = _ask("QQ 邮箱地址", keep("QQ_EMAIL") or "1090826911@qq.com")
    qq_code = _ask("QQ 授权码", keep("QQ_AUTH_CODE"), secret=True).replace(" ", "")
    gmail_email = _ask("Gmail 地址", keep("GMAIL_EMAIL") or "<email-redacted>")
    gmail_pw = _ask("Gmail 应用专用密码", keep("GMAIL_APP_PASSWORD"), secret=True).replace(" ", "")
    digest_to = _ask("总结发送到", keep("DIGEST_TO") or qq_email)

    lines = [
        "# 邮件系统凭证 —— 由 setup_credentials.py 生成(chmod 600, git 忽略)",
        f"QQ_EMAIL={qq_email}",
        f"QQ_AUTH_CODE={qq_code}",
        f"GMAIL_EMAIL={gmail_email}",
        f"GMAIL_APP_PASSWORD={gmail_pw}",
        f"DIGEST_TO={digest_to}",
        f"OLLAMA_MODEL={old.get('OLLAMA_MODEL', 'qwen3:8b')}",
        f"OLLAMA_HOST={old.get('OLLAMA_HOST', 'http://127.0.0.1:11434')}",
        f"PHYSICAL_IFACE={old.get('PHYSICAL_IFACE', '')}",
    ]
    ENV.write_text("\n".join(lines) + "\n", encoding="utf-8")
    os.chmod(ENV, stat.S_IRUSR | stat.S_IWUSR)  # 600

    print(f"\n✓ 已写入 {ENV}(权限 600,仅你可读写)")
    print("✓ 授权码未显示、未进对话、未进 shell 历史")
    missing = [n for n, v in [("QQ 授权码", qq_code), ("Gmail 密码", gmail_pw)] if not v]
    if missing:
        print(f"⚠ 以下仍为空,可重跑本脚本补填:{', '.join(missing)}")
    else:
        print("✓ 两个邮箱凭证均已填写,可进行 smoke test")


if __name__ == "__main__":
    main()
