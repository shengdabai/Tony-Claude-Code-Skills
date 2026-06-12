"""邮件分类规则 —— 保守策略。

判定逻辑(宁可漏判,不可误判):
  1. 命中「白名单」(安全/账单/验证码等)→ 永远视为重要,绝不清理
  2. 否则,满足「广告强信号」→ 视为广告(标已读 + 移垃圾箱)
  3. 其余 → 重要(只标已读,留收件箱)

广告强信号 = 有退订头(List-Unsubscribe) 或 命中明确营销关键词。
"""

# 白名单关键词:出现在主题/发件人里就强制判为「重要」,即使带退订头
# (安全告警、账单、验证码、订单等绝不能被误清)
WHITELIST_KEYWORDS = [
    # 安全 / 账户
    "security", "安全", "verification", "verify", "验证码", "verification code",
    "sign-in", "signin", "登录", "login", "password", "密码", "2fa", "otp",
    "alert", "告警", "警报", "suspicious", "异常",
    # 财务 / 交易
    "invoice", "账单", "receipt", "收据", "payment", "付款", "支付",
    "order", "订单", "refund", "退款", "subscription renew", "续费",
    "发票", "transaction", "交易",
    # 物流
    "shipped", "delivery", "已发货", "快递", "物流", "tracking",
]

# 营销/广告关键词(主题或发件人命中,且不在白名单 → 广告)
PROMO_KEYWORDS = [
    "促销", "优惠", "折扣", "限时", "秒杀", "特惠", "钜惠", "大促", "清仓",
    "newsletter", "sale", "deal", "discount", "% off", "off!", "save",
    "promotion", "promo", "coupon", "clearance", "bargain", "free shipping",
    "限量", "新品上市", "立减", "满减", "领券", "抢购", "种草",
    "unsubscribe", "退订", "取消订阅",
    "weekly digest", "monthly newsletter", "广告",
]

# 典型营销发件人前缀(@ 前的本地部分命中 → 倾向广告,但仍需配合其它信号)
BULK_SENDER_HINTS = [
    "newsletter", "marketing", "promo", "deals", "noreply-marketing",
    "campaign", "mailer", "bulk", "news@", "info@", "hello@",
]


def _norm(text: str) -> str:
    return (text or "").lower()


def is_whitelisted(subject: str, sender: str) -> bool:
    blob = _norm(subject) + " " + _norm(sender)
    return any(kw.lower() in blob for kw in WHITELIST_KEYWORDS)


def is_promo(subject: str, sender: str, has_list_unsubscribe: bool) -> bool:
    """返回 True 表示判定为广告/不重要。保守:白名单优先。"""
    if is_whitelisted(subject, sender):
        return False

    blob = _norm(subject) + " " + _norm(sender)

    # 强信号 1:命中明确营销关键词
    if any(kw.lower() in blob for kw in PROMO_KEYWORDS):
        return True

    # 强信号 2:带 List-Unsubscribe 退订头 = 订阅/营销邮件。
    # 真人来信、账单、安全警报、订单通常没有此头;白名单已在上方放行重要订阅。
    # (保守策略下即便误判也只进垃圾箱,30天可恢复)
    if has_list_unsubscribe:
        return True

    return False


def classify(subject: str, sender: str, has_list_unsubscribe: bool) -> str:
    """返回 'promo'(广告) 或 'important'(重要)。"""
    return "promo" if is_promo(subject, sender, has_list_unsubscribe) else "important"
