#!/bin/bash
# env-guard.sh — PreToolUse hook
# 拦截 Read / Edit / Write 触碰机密文件,默认 deny。
# 用户在当条消息里**明确点名**该具体文件路径才放行(由模型基于 Cardinal Rule 6 判断,
# 此 hook 仅做硬黑名单兜底:不允许任何工具自动触碰)。
#
# Exit codes:
#   0 — allow (静默放行)
#   2 — deny  (Claude Code 会把 stderr 作为拒绝原因展示给模型)
#
# 输入:Claude Code 通过 stdin 传 JSON {tool_input: {file_path: "..."}}

set -e

INPUT=$(cat 2>/dev/null || echo "{}")

FILE_PATH=$(echo "$INPUT" | /usr/bin/python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    fp = data.get('tool_input', {}).get('file_path', '')
    print(fp)
except Exception:
    print('')
" 2>/dev/null)

# 没拿到路径 → 不归我管
[ -z "$FILE_PATH" ] && exit 0

# 取 basename 做精确匹配
BASENAME=$(basename "$FILE_PATH")

# === 文件名黑名单 ===
# 匹配 .env 系列、密钥文件、SSH/GPG 私钥、云凭证
case "$BASENAME" in
    .env|.env.*|*.env|*.env.local|*.env.production|*.env.development|*.env.staging)
        DENY_REASON=".env 系列文件" ;;
    *.pem|*.key|*.p12|*.pfx|*.jks|*.keystore)
        DENY_REASON="密钥/证书文件" ;;
    id_rsa|id_rsa.*|id_ed25519|id_ed25519.*|id_ecdsa|id_ecdsa.*|id_dsa|id_dsa.*)
        DENY_REASON="SSH 私钥" ;;
    credentials|credentials.json|credentials.yaml|credentials.yml)
        DENY_REASON="凭证文件" ;;
    secrets|secrets.json|secrets.yaml|secrets.yml|secrets.env)
        DENY_REASON="secrets 文件" ;;
    .npmrc|.pypirc|.netrc|.pgpass|.my.cnf)
        DENY_REASON="工具凭证文件" ;;
    *.gpg|*.asc|*.kbx|secring.*)
        DENY_REASON="GPG 密钥" ;;
    *)
        DENY_REASON="" ;;
esac

# === 路径黑名单 ===
# 匹配凭证目录(优先级低于 basename,只有 basename 没命中才检查)
if [ -z "$DENY_REASON" ]; then
    case "$FILE_PATH" in
        */.aws/credentials|*/.aws/config)
            DENY_REASON="AWS 凭证目录" ;;
        */.ssh/id_*|*/.ssh/*_rsa|*/.ssh/*_ed25519|*/.ssh/*_ecdsa)
            DENY_REASON="SSH 私钥目录" ;;
        */.config/gcloud/*|*/.gcloud/*)
            DENY_REASON="GCP 凭证" ;;
        */.kube/config)
            DENY_REASON="Kubernetes 凭证" ;;
        */.docker/config.json)
            DENY_REASON="Docker 凭证" ;;
        */.gnupg/*)
            DENY_REASON="GnuPG 密钥环" ;;
        */.netrc|*/.pgpass|*/.my.cnf)
            DENY_REASON="工具凭证" ;;
        *)
            DENY_REASON="" ;;
    esac
fi

# === 白名单豁免 ===
# 这些是"示例文件",可以读
case "$BASENAME" in
    .env.example|.env.sample|.env.template|.env.dist|*.example|*.sample|*.template)
        exit 0 ;;
esac

# 命中黑名单 → deny
if [ -n "$DENY_REASON" ]; then
    cat >&2 <<EOF
🛡️  ENV-GUARD: 拒绝访问机密文件
路径: $FILE_PATH
类别: $DENY_REASON

Cardinal Rule 6:此类文件必须先得到用户当条消息的明确授权,且授权后也禁止把内容
echo 到对话或日志。请询问用户:
  "我需要 Read/Edit \`$BASENAME\`,这是机密文件,你确认要让我访问吗?"
EOF
    exit 2
fi

exit 0
