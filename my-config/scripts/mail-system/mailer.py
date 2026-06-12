"""SMTP 发送 —— 攻克 Clash TUN 环境的最终方案。

本机环境特征(实测):
  - 原生直连 SMTP 465:被 TUN 劫持 → SSL EOF
  - 经 Clash 代理隧道:节点封锁 465 端口 → SSL EOF
  - 绑物理网卡源地址直连真实 IP:成功绕过 TUN ✓

最终方案:
  1. 经 Clash 代理做 DoH(443 不被封)解析 SMTP 真实 IP(禁校验仅取 IP,
     密码安全由第 2 步的完整证书校验保证)
  2. 绑物理网卡源地址直连该真实 IP:465,SSL 用 certifi CA + SNI 完整校验

策略:先试直连(Clash 关 TUN 时可成)→ 失败则 DoH + 绑网卡。
"""
import json
import os
import re
import smtplib
import socket
import ssl
import subprocess
import urllib.request
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.utils import formatdate
from urllib.parse import urlparse
from urllib.request import ProxyHandler, Request, build_opener

try:
    import certifi
    _CA_FILE = certifi.where()
except ImportError:
    _CA_FILE = None

_DOH_ENDPOINTS = [
    "https://223.5.5.5/resolve?name={host}&type=A",       # 阿里 DNS
    "https://doh.pub/dns-query?name={host}&type=A",        # 腾讯 DNSPod
    "https://1.1.1.1/dns-query?name={host}&type=A",        # Cloudflare
]


def _ssl_ctx() -> ssl.SSLContext:
    """带完整证书校验的 context(优先 certifi CA)。"""
    return ssl.create_default_context(cafile=_CA_FILE)


def _get_proxy() -> tuple[str, int] | None:
    for var in ("HTTPS_PROXY", "https_proxy", "HTTP_PROXY", "http_proxy",
                "ALL_PROXY", "all_proxy"):
        v = os.environ.get(var)
        if v:
            u = urlparse(v)
            if u.hostname and u.port:
                return (u.hostname, u.port)
    for port in (7897, 7890, 1087):
        s = socket.socket()
        s.settimeout(1)
        try:
            s.connect(("127.0.0.1", port))
            s.close()
            return ("127.0.0.1", port)
        except Exception:
            continue
    return None


def _doh_resolve(host: str) -> str | None:
    """经 Clash 代理做 DoH 解析真实 IP(禁校验仅取 IP)。"""
    proxy = _get_proxy()
    handlers = [urllib.request.HTTPSHandler(context=ssl._create_unverified_context())]
    if proxy:
        p = f"http://{proxy[0]}:{proxy[1]}"
        handlers.append(ProxyHandler({"http": p, "https": p}))
    else:
        handlers.append(ProxyHandler({}))
    opener = build_opener(*handlers)
    for tpl in _DOH_ENDPOINTS:
        try:
            req = Request(tpl.format(host=host), headers={"Accept": "application/dns-json"})
            with opener.open(req, timeout=8) as r:
                data = json.load(r)
            for ans in data.get("Answer", []):
                if ans.get("type") == 1:
                    return ans["data"]
        except Exception:
            continue
    return None


def _physical_ip(preferred: str = "") -> str | None:
    for iface in ([preferred] if preferred else []) + ["en0", "en1", "en2"]:
        if not iface:
            continue
        try:
            out = subprocess.run(["ipconfig", "getifaddr", iface],
                                 capture_output=True, text=True, timeout=5).stdout.strip()
            if re.match(r"^\d+\.\d+\.\d+\.\d+$", out):
                return out
        except Exception:
            continue
    return None


class _BoundSMTP_SSL(smtplib.SMTP_SSL):
    """连接到真实 IP、绑物理网卡源地址,SSL 仍按真实域名完整校验。"""

    def __init__(self, *args, real_ip=None, source_ip=None, **kwargs):
        self._real_ip = real_ip
        self._source_ip = source_ip
        super().__init__(*args, **kwargs)

    def _get_socket(self, host, port, timeout):
        src = (self._source_ip, 0) if self._source_ip else None
        raw = socket.create_connection((self._real_ip or host, port), timeout, source_address=src)
        return self.context.wrap_socket(raw, server_hostname=host)


def _build_message(subject: str, html_body: str, text_body: str, cfg: dict) -> MIMEMultipart:
    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = cfg["user"]
    msg["To"] = cfg["to"]
    msg["Date"] = formatdate(localtime=True)
    msg.attach(MIMEText(text_body, "plain", "utf-8"))
    msg.attach(MIMEText(html_body, "html", "utf-8"))
    return msg


def send(subject: str, html_body: str, text_body: str, cfg: dict,
         physical_iface: str = "") -> str:
    """发送邮件,返回通道标识。失败抛出异常。"""
    msg = _build_message(subject, html_body, text_body, cfg)
    host, port, user, pw = cfg["host"], cfg["port"], cfg["user"], cfg["password"]
    recipients = [cfg["to"]]
    ctx = _ssl_ctx()

    # 尝试 1:直连
    try:
        with smtplib.SMTP_SSL(host, port, context=ctx, timeout=15) as s:
            s.login(user, pw)
            s.sendmail(user, recipients, msg.as_string())
        return "direct"
    except Exception as e_std:
        std_err = e_std

    # 尝试 2:DoH 解析真实 IP + 绑物理网卡直连(绕 TUN)
    real_ip = _doh_resolve(host)
    src = _physical_ip(physical_iface)
    if not real_ip:
        raise RuntimeError(f"直连失败({std_err}),且 DoH 解析 {host} 失败")
    try:
        s = _BoundSMTP_SSL(host, port, context=ctx, timeout=30, real_ip=real_ip, source_ip=src)
        try:
            s.login(user, pw)
            s.sendmail(user, recipients, msg.as_string())
        finally:
            try:
                s.quit()
            except Exception:
                pass
        return f"bind({src}→{real_ip})"
    except Exception as e_bind:
        raise RuntimeError(
            f"直连失败({std_err});绑网卡直连也失败"
            f"(src={src}, ip={real_ip}):{e_bind}"
        )
