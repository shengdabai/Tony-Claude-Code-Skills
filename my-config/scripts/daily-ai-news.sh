#!/bin/bash
# 每日 AI 热点新闻 — Codex 版草稿(.codex.sh) — launchd 12:05 触发
# ⚠️ 这是 Codex 迁移草稿,供主会话审后切换。原 daily-ai-news.sh 不动、launchd 不碰。
#
# 迁移 delta(相对 daily-ai-news.sh,只换推理引擎,锁/done-mark/重试结构原样保留):
#   - CLAUDE=~/.local/bin/claude          → CODEX=~/.nvm/versions/node/v24.14.0/bin/codex(绝对路径,防后台 PATH 丢失 exit 127)
#   - claude -p --session-id $SID         → codex exec --json(首轮捕获 codex 生成的 session_id)
#   - claude -p --resume $SID             → codex exec resume $SID(续轮,不传 -s,继承首轮沙箱)
#   - --mcp-config getnote-only.json      → 删除(getnote 已在 ~/.codex/config.toml 静态注册)
#   - --permission-mode bypassPermissions → --dangerously-bypass-approvals-and-sandbox
#   - --add-dir $WORK                     → -C $WORK + --add-dir $WORK + --skip-git-repo-check
#   - 默认 Opus                           → -m gpt-5.5(ChatGPT 订阅 auth 只能 5.5/5.2)
#   - 末尾仍触发 daily-digest.sh,微信推送链路不变
# 已知限制:dedao-write 在 Codex 是软链 SKILL.md(~/Projects/gbrain/skills/dedao-write),
#   Codex skill≈prompt 注入(无 subagent 编排)。本脚本用简化模式整理,prompt 已把过滤+整理步骤写死,
#   不依赖 skill 自动展开 subagent,故 dedao 缺编排能力影响小。
set -uo pipefail
# --- 共享互斥锁:daily-article 与 daily-ai-news 都调用推理 session,排队避免并发抢占 ---
# 注意:沿用同一把锁名,使 Codex 版与 Claude 版互斥(同机不会两个引擎同时抢额度/工作区)
CLAUDE_SESSION_LOCK="/tmp/daily-claude-session.lock"
_waited=0
while ! mkdir "$CLAUDE_SESSION_LOCK" 2>/dev/null; do
  _waited=$((_waited+30))
  [ "$_waited" -gt 1800 ] && { echo "[lock] waited 30min, proceeding anyway" >&2; break; }
  sleep 30
done
trap 'rmdir "$CLAUDE_SESSION_LOCK" 2>/dev/null' EXIT
# --- 锁结束 ---

WORK="$HOME/.local/share/tony-articles"
CODEX="$HOME/.nvm/versions/node/v24.14.0/bin/codex"
CODEX_MODEL="gpt-5.5"
LOG="$HOME/.claude/logs/daily-ai-news.codex.log"
TODAY="$(date +%Y-%m-%d)"
WEIXIN_CHANNEL="o9cq80_JAkxB7DYoj-ljixOpFdWY@im.wechat"
MIN_HOT_ITEMS=5

# Codex 调用公共 flags(首轮用;resume 不接受 -s/sandbox 类,见下)
CODEX_FLAGS=(--dangerously-bypass-approvals-and-sandbox --skip-git-repo-check -C "$WORK" --add-dir "$WORK" -m "$CODEX_MODEL")

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }
TIMEOUT_CMD=""
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_CMD="$(command -v timeout)"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_CMD="$(command -v gtimeout)"
elif [ -x /opt/homebrew/bin/gtimeout ]; then
  TIMEOUT_CMD="/opt/homebrew/bin/gtimeout"
fi
run_limited() {
  local seconds="$1"
  shift
  if [ -n "$TIMEOUT_CMD" ]; then
    "$TIMEOUT_CMD" "$seconds" "$@"
  else
    "$@"
  fi
}
# L1 告警:撞 429 时推 ntfy,避免静默漏稿(复用 claude-auto-resume 同款 topic)
ntfy_send() {
  [ -f "$HOME/.config/ntfy/.env" ] || return 0
  source "$HOME/.config/ntfy/.env"
  [ -n "${NTFY_CLAUDE_TOPIC:-}" ] || return 0
  curl -s -m 3 -d "$1" "ntfy.sh/${NTFY_CLAUDE_TOPIC}" >/dev/null 2>&1 || true
}
log "===== 开始每日 AI 热点任务(Codex 版) $TODAY ====="

# 1. 同步仓库
cd "$WORK" || { log "FATAL: $WORK 不存在"; exit 1; }
rm -f ruvector.db ./*.db 2>/dev/null
git rm --cached --ignore-unmatch ruvector.db "*.db" >/dev/null 2>&1
for i in 1 2 3; do
  git pull -q --rebase origin main 2>>"$LOG" && break
  [ "$i" -eq 3 ] && { git rebase --abort 2>/dev/null; git fetch -q origin main; git reset --hard origin/main 2>>"$LOG"; }
  sleep $((i*3))
done

# 2. 幂等
DONE_MARK="$HOME/.claude/logs/.daily-ai-news-done-${TODAY}"
if [ -f "$DONE_MARK" ] || \
   { ls ai-news/zh/${TODAY}-*.md >/dev/null 2>&1 && ls ai-news/en/${TODAY}-*.md >/dev/null 2>&1; }; then
  log "今日 AI 热点双版已完成, 跳过"; exit 0
fi
LOCK="$HOME/.claude/logs/.daily-ai-news.codex.lock"
if [ -f "$LOCK" ] && kill -0 "$(cat "$LOCK" 2>/dev/null)" 2>/dev/null; then
  log "上一次任务仍在运行 (PID $(cat "$LOCK")), 本次跳过"; exit 0
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"; rmdir "$CLAUDE_SESSION_LOCK" 2>/dev/null' EXIT
mkdir -p ai-news/zh ai-news/en

# 3. 拉 aihot 过去 24h 精选数据 → 写到临时文件供 codex 读
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36 aihot-skill/0.2.0"
SINCE=$(date -u -v-24H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ)
AIHOT_RAW="$HOME/.claude/logs/.aihot-raw-${TODAY}.json"
log "拉 aihot 数据 since=$SINCE"
for try in 1 2 3 4 5; do
  curl -sf -H "User-Agent: $UA" --max-time 60 --retry 2 --retry-delay 3 \
    "https://aihot.virxact.com/api/public/items?mode=selected&since=$SINCE&take=60" \
    -o "$AIHOT_RAW" 2>>"$LOG"
  SZ=$(stat -f%z "$AIHOT_RAW" 2>/dev/null || echo 0)
  ITEM_N=$(python3 -c "import json;print(len(json.load(open('$AIHOT_RAW')).get('items',[])))" 2>/dev/null || echo 0)
  log "  第 $try 次: size=$SZ items=$ITEM_N"
  [ "$ITEM_N" -ge "$MIN_HOT_ITEMS" ] && break
  sleep $((try*5))
done
if [ "$ITEM_N" -lt "$MIN_HOT_ITEMS" ]; then
  log "WARN: aihot 5 次重试后只有 $ITEM_N 条, 将交给 Codex 联网搜索补齐到至少 $MIN_HOT_ITEMS 条后继续"
fi

# 4. 调 Codex(headless), dedao-write 简化模式整理 + 个人化过滤
PROMPT=$(cat <<PROMPT_EOF
你是 AI 资讯整理助手。任务: 把过去 24 小时的 AI 圈热点,
用 dedao-write skill 整理成一篇精炼的中英双版日报, 优先下面画像关心的方向。

⚠️ 脱敏铁律(最高优先级): 这是公开 GitHub 仓库的日报正文,严禁出现任何真实人名——
绝不要写 "Tony" / "盛大白" / "刘小排" 或任何具体个人姓名。下面的兴趣画像只用于内部选题打分,
绝不写进输出正文。"为什么该关心" 一律用通用第二人称 "你/读者",
写成 "为什么值得关心",而不是 "为什么 Tony 该关心"。

【第一步: 读热点原始数据 + 不足时联网补全】
读 $AIHOT_RAW (aihot.virxact.com 返回的 JSON), 提取所有 items。
每条字段包括: title / chineseTitle / chineseSummary / url / publishedAt / category。
当前 aihot 原始条数是 ${ITEM_N:-0}, 目标至少 ${MIN_HOT_ITEMS} 条。
如果原始数据少于 ${MIN_HOT_ITEMS} 条, 不要退出、不要等待下个窗口:
- 立刻使用 WebSearch / web.run / curl 可访问的公开网页, 搜索过去 24-48 小时内与 AI 相关的热点。
- 优先补 Claude Code / Anthropic / OpenAI / AI Agent / MCP / AI 编程工具 / 独立开发者 / 国产大模型 / 开源模型 / AI 产品发布。
- 每条补充热点必须有可打开的原文 URL, 不要用只有二手转述且无来源的内容。
- 最终尽量保持 5 条; 若公开信息确实不足, 允许 3-4 条简版日报, 但必须成稿、保存、push 并触发推送, 不能因为条数不足退出。

【第二步: 个人化过滤(Tony 的兴趣画像)】
**Tony 高度关注的方向**(命中加权 +3):
- Claude Code / Claude API / Anthropic / Sonnet / Opus / Haiku 新版本与新能力
- AI Agent 演化(Manus, Cowork, OpenClaw, Cursor, Devin 等)
- 个人产品 / MicroSaaS / 一人公司 / 独立开发者
- AI 编程工具 / SDK / MCP / Skills 生态
- 自我进化系统 / 长期记忆 / AI 与人脑

**Tony 中度关注**(命中 +1):
- OpenAI / GPT 系列 / Codex CLI
- 国产大模型(DeepSeek / Kimi / Qwen / GLM / MiniMax)
- 中文 LLM 教学 / 教育 AI 应用
- 视频生成(Sora / 即梦 / Pika)
- 开源模型 / 本地部署

**降权(命中 -2)**:
- 大厂股价 / 投融资数字 / 政策法规细节
- 通用消费级 AI 玩具
- 与中文创作者关系不大的纯英文学术论文

按上面规则给每条算分, 选 5-8 条做今天日报。aihot 不足时, 用联网搜索补齐到 5 条后再筛选; 最后兜底才允许 3-4 条简版。

【第三步: 用 dedao-write 整理成日报(简化模式)】
这是日报而不是长文, 走简化模式, 主会话直接写、不要尝试派发子任务/subagent:
- **标题**: "AI 圈过去 24 小时 · YYYY-MM-DD"(英文版用 "AI Daily · YYYY-MM-DD")
- **导语**(1-2 句): 今天最值得关心的核心信号是什么
- **正文**: 5-8 条精选, 每条:
  - 加粗中文小标题(1 句话说清是什么)
  - 1-2 句"为什么值得关心"——用 跨时空连接 / 工程化破界 / 自进化系统 / 用 AI 让人变强 的价值视角
  - 原文链接([source](url))
- **尾巴**: 一句话 takeaway, 留给读者一个值得思考的问题

长度: 中文版 800-1500 字, 英文版 600-1000 词。

【第四步: 保存双版 + push】
- 中文: ai-news/zh/${TODAY}-AI圈过去24小时.md
- 英文: ai-news/en/${TODAY}-ai-news-daily.md
- 两版开头加: # 标题  > 发布日期:${TODAY} · 类型:AI 热点日报  ---
- 重建 README: python3 .tools/gen_readme.py
- git add ai-news/ README.md .gitignore .tools/ → commit → push

完成后报告: 中英版文件名 + 是否推送成功 + 选了哪 5-8 条热点(标题列表), 以及哪些来自 aihot、哪些来自联网补全。
PROMPT_EOF
)

log "调用 Codex 整理 AI 热点..."
RELAY_OUT="$HOME/.claude/logs/.daily-ai-news-codex-out.txt"
RELAY_JSON="$HOME/.claude/logs/.daily-ai-news-codex-events.jsonl"

# 撞用量上限检测(ChatGPT 订阅额度 / 429)
hit_session_limit() {
  grep -qiE "usage limit reached|usage_limit_reached|rate limit exceeded|429 too many requests|quota exceeded|exceeded your current quota" "$RELAY_OUT" 2>/dev/null
}

# 首轮:用 --json 捕获 codex 生成的 session_id(供后续 resume)。
# session_id 在 JSONL 事件里(thread.started / session 字段),首轮跑完从 events 解析。
echo "$PROMPT" | run_limited 1500 "$CODEX" exec --json "${CODEX_FLAGS[@]}" - \
  > "$RELAY_JSON" 2>"$RELAY_OUT"
RC=$?
cat "$RELAY_OUT" >> "$LOG"
log "  Codex 首轮调用 rc=$RC (124=超时)"
if hit_session_limit; then
  log "  撞用量上限, 止损退出, 后续 launchd 时刻自动重试"
  ntfy_send "⚠️ daily-ai-news 撞 Codex 429 限额, 今日($TODAY)日报暂未出, 等下个 launchd 窗口(5h窗重置后)自动重试。如需立即出稿可手动跑或临时切 API key。"
  exit 0
fi

# 从 JSONL 事件解析 session_id(字段名随 codex 版本可能变,做多键兜底)
SID=$(python3 - "$RELAY_JSON" <<'PY' 2>/dev/null
import json, sys
sid = ""
try:
    for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
        line = line.strip()
        if not line: continue
        try: ev = json.loads(line)
        except Exception: continue
        # 逐层探测可能承载 session/thread id 的字段
        for k in ("session_id", "sessionId", "thread_id", "threadId", "conversation_id", "id"):
            v = ev.get(k) if isinstance(ev, dict) else None
            if isinstance(v, str) and len(v) >= 8:
                sid = v
        msg = ev.get("msg") if isinstance(ev, dict) else None
        if isinstance(msg, dict):
            for k in ("session_id", "sessionId", "thread_id", "conversation_id"):
                v = msg.get(k)
                if isinstance(v, str) and len(v) >= 8:
                    sid = v
except Exception:
    pass
print(sid)
PY
)
log "  解析到 session_id=${SID:-<空,后续接力改用 --last>}"

# 接力一轮(若首轮没出双版)。优先用解析到的 SID;解析失败用 --last(同 cwd + 共享锁串行,安全)。
# 注意:resume 子命令【不支持 -C/--add-dir】(只有顶层 codex exec 有),靠当前进程 cwd 过滤会话;
#   脚本开头已 cd "$WORK",故 resume 自动定位到本仓库的会话。headless 续跑要跑 git,须带免审批+跳git检查。
RESUME_FLAGS=(--dangerously-bypass-approvals-and-sandbox --skip-git-repo-check -m "$CODEX_MODEL")
CONT_PROMPT="继续完成 AI 热点日报: 如果 aihot 原始数据不足 5 条, 立刻联网搜索过去 24-48 小时 AI 热点补齐, 不要因为条数不足退出。把双版保存到 ai-news/zh/${TODAY}-*.md 和 ai-news/en/${TODAY}-*.md, 运行 python3 .tools/gen_readme.py, git add ai-news/ README.md → commit → push。"
for r in 1 2; do
  if ls ai-news/zh/${TODAY}-*.md >/dev/null 2>&1 && ls ai-news/en/${TODAY}-*.md >/dev/null 2>&1; then break; fi
  log "接力 +$r 轮..."
  if [ -n "$SID" ]; then
    echo "$CONT_PROMPT" | run_limited 900 "$CODEX" exec resume "$SID" "${RESUME_FLAGS[@]}" - >> "$LOG" 2>&1
  else
    echo "$CONT_PROMPT" | run_limited 900 "$CODEX" exec resume --last "${RESUME_FLAGS[@]}" - >> "$LOG" 2>&1
  fi
done

# 5. 兜底: 验证双版 + push + Hermes 推微信
ZH_FILE=$(ls ai-news/zh/${TODAY}-*.md 2>/dev/null | head -1)
EN_FILE=$(ls ai-news/en/${TODAY}-*.md 2>/dev/null | head -1)
if [ -n "$ZH_FILE" ] && [ -n "$EN_FILE" ]; then
  log "SUCCESS: zh=$(basename "$ZH_FILE") en=$(basename "$EN_FILE")"
  rm -f ruvector.db ./*.db 2>/dev/null
  python3 .tools/gen_readme.py >>"$LOG" 2>&1 || true
  git add ai-news/ README.md .gitignore .tools/ 2>/dev/null
  if [ -n "$(git diff --cached --name-only)" ]; then
    git commit -q -m "post(ai-news): ${TODAY} AI 圈过去 24 小时热点" 2>>"$LOG"
    for i in 1 2 3; do git push -q origin main 2>>"$LOG" && { log "push 成功"; break; }; sleep $((i*5)); done
  fi
  touch "$DONE_MARK"

  # 6. 微信推送由 daily-digest.sh 统一处理(思考+热点合并成一条, 国内快链)。
  bash "$HOME/.claude/scripts/daily-digest.sh" >/dev/null 2>&1 || true
else
  log "ERROR: AI 热点双版未齐(zh=${ZH_FILE:-无} en=${EN_FILE:-无})"
fi

log "===== 任务结束 ====="
