"""Conservative mail classification for a low-noise daily digest."""

import re

URGENT_KEYWORDS = [
    "security", "安全", "verification", "验证码", "sign-in", "signin", "登录",
    "password", "密码", "2fa", "otp", "alert", "告警", "suspicious", "异常",
    "failed", "失败", "overdue", "逾期", "expires today", "今日到期",
]

ACTION_KEYWORDS = [
    "invoice", "账单", "receipt", "收据", "payment", "付款", "支付", "order",
    "订单", "refund", "退款", "subscription renew", "续费", "发票",
    "transaction", "交易", "shipped", "delivery", "已发货", "快递", "物流",
    "tracking", "邀请", "invitation", "approval", "审批", "confirm", "确认",
]

# These subscriptions are valuable input, not advertising.
FOCUS_KEYWORDS = [
    "artificial intelligence", "generative ai", "machine learning", "大模型", "人工智能",
    "openai", "chatgpt", "gpt", "codex", "anthropic", "claude", "gemini",
    "deepseek", "kimi", "qwen", "通义", "智谱", "glm", "minimax", "mistral",
    "llama", "hugging face", "github", "cursor", "windsurf", "manus", "agent",
    "mcp", "model context protocol", "cloudflare", "vercel", "developer", "sdk",
    "api", "科技", "技术", "开源", "saas", "indie hacker", "独立开发",
]

PROMO_KEYWORDS = [
    "促销", "优惠", "折扣", "限时", "秒杀", "特惠", "钜惠", "大促", "清仓",
    "sale", "deal", "discount", "% off", "off!", "save now", "promotion",
    "promo", "coupon", "clearance", "free shipping", "限量", "新品上市", "立减",
    "满减", "领券", "抢购", "种草", "广告", "会员专享", "buy now",
]


def _norm(text: str) -> str:
    return (text or "").lower()


def _contains(blob: str, keywords: list[str]) -> bool:
    for keyword in keywords:
        needle = keyword.lower()
        if needle.isascii():
            pattern = rf"(?<![a-z0-9]){re.escape(needle)}(?![a-z0-9])"
            if re.search(pattern, blob):
                return True
        elif needle in blob:
            return True
    return False


def classify(subject: str, sender: str, has_list_unsubscribe: bool) -> str:
    """Return urgent, action, focus, subscription, promo, or info."""
    subject_blob = _norm(subject)
    blob = f"{subject_blob} {_norm(sender)}"
    if _contains(blob, URGENT_KEYWORDS):
        return "urgent"
    if _contains(blob, ACTION_KEYWORDS):
        return "action"
    if _contains(blob, FOCUS_KEYWORDS):
        return "focus"
    # Never move a message solely because a sender address contains sales/promo.
    if _contains(subject_blob, PROMO_KEYWORDS):
        return "promo"
    if has_list_unsubscribe:
        return "subscription"
    return "info"


def is_promo(subject: str, sender: str, has_list_unsubscribe: bool) -> bool:
    return classify(subject, sender, has_list_unsubscribe) == "promo"
