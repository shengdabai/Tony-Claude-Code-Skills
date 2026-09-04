#!/usr/bin/env python3
"""Run `hermes send` for Feishu after credentials load, with proxies removed."""

from __future__ import annotations

import os
import sys


def _is_feishu_send(argv: list[str]) -> bool:
    if not argv or argv[0] != "send":
        return False
    for index, value in enumerate(argv):
        if value in {"--to", "-t"} and index + 1 < len(argv):
            return argv[index + 1].startswith("feishu:")
    return False


if not _is_feishu_send(sys.argv[1:]):
    print("hermes-send-direct-feishu: only `send --to feishu:...` is allowed", file=sys.stderr)
    raise SystemExit(2)

from hermes_cli import send_cmd  # noqa: E402

_original_load_env = send_cmd._load_hermes_env


def _load_env_without_proxies() -> None:
    _original_load_env()
    for key in (
        "HTTP_PROXY",
        "HTTPS_PROXY",
        "ALL_PROXY",
        "http_proxy",
        "https_proxy",
        "all_proxy",
    ):
        os.environ.pop(key, None)
    direct_hosts = "localhost,127.0.0.1,::1,open.feishu.cn,.feishu.cn,open.larksuite.com,.larksuite.com"
    os.environ["NO_PROXY"] = direct_hosts
    os.environ["no_proxy"] = direct_hosts


send_cmd._load_hermes_env = _load_env_without_proxies

from hermes_cli.main import main  # noqa: E402

raise SystemExit(main())
