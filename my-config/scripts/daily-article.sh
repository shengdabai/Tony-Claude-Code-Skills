#!/bin/bash
# 每日文章自动创作 + 推送 — Codex 版草稿(.codex.sh) — launchd 每天 12:00 触发
# ⚠️ 这是 Codex 迁移草稿,供主会话审后切换。原 daily-article.sh 不动、launchd 不碰。
#
# ============================================================================
# 重要限制(主会话切换前必读)——为什么这是"最佳可行版"而非完整迁移:
# ============================================================================
# daily-article.sh 的 13-phase 接力依赖 xiaolai-write 这套【Claude plugin】:
#   /xiaolai-write、/plan-list-articles、/plan-switch-article、/plan-translate
#   都是 Claude 的 slash 命令 + subagent(orchestrator/architect/drafter/...),
#   实体在 ~/.claude/plugins/cache/tony/xiaolai-write/。
# Codex 侧实测确认:
#   - ~/.codex/skills 下【没有 xiaolai-write】(已 ls 验证缺失)
#   - 只有 article-writing(真实目录)、dedao-write(软链)、xiaolai-methodology(软链)
#   - Codex 无 plugin/slash/subagent 体系,skill≈prompt 注入,无法跑 13-phase 编排
#   - 脚本里 latest_state()/is_done() 读的 .state.json 也是 xiaolai-write 写的,
#     Codex 不会生成这个 .state.json,故 phase 推进/停滞检测在 Codex 下失效。
#
# 因此本草稿采取【Codex 起草 + 保留接力结构】方案:
#   - 保留全部 锁/幂等/done-mark/重试/兜底 push 结构(与原脚本同构)
#   - 把"用 xiaolai-write 跑 13-phase"改为在 prompt 里把写作步骤【显式展开成纯文本】,
#     让 Codex 在单会话(+ resume 接力)里完成:取素材→选题脱敏→成文→翻译→双版落盘→push
#   - 不依赖 .state.json;接力的收敛判据改为"双版文件是否已落地"(原脚本兜底循环本就用它)
#   - 质量基线:gpt-5.5,中文长文结构/收尾比 Opus 弱(见 evidence),主会话切换前
#     建议先做 3-5 篇盲测 A/B,或仅把"研究/翻译"交 Codex、"结构/收尾"仍走 Claude。
#
# 迁移 delta(CLI 接口,与 daily-ai-news.codex.sh 同构):
#   CLAUDE=~/.local/bin/claude          → CODEX=~/.nvm/.../codex(绝对路径,防 exit 127)
#   claude -p --session-id $SID         → codex exec --json(捕获 session_id)
#   claude -p --resume $SID             → codex exec resume $SID(不传 -s,继承首轮沙箱)
#   --mcp-config getnote-only.json      → 删除(getnote 已在 ~/.codex/config.toml 注册;
#                                          依赖 ~/.config/getnote/.env 存在,已实测 YES)
#   --permission-mode bypassPermissions → --dangerously-bypass-approvals-and-sandbox
#   --add-dir $WORK                     → -C $WORK + --add-dir $WORK + --skip-git-repo-check
#   默认 Opus                           → -m gpt-5.5
#   完成条件只认 GitHub origin/main；不再触发飞书/微信分发
# ============================================================================
set -uo pipefail
# --- 共享互斥锁:daily-article 与 daily-ai-news 都调用推理 session,排队避免并发抢占 ---
CLAUDE_SESSION_LOCK="/tmp/daily-claude-session.lock"
if ! mkdir "$CLAUDE_SESSION_LOCK" 2>/dev/null; then
  _lock_pid=$(cat "$CLAUDE_SESSION_LOCK/pid" 2>/dev/null || true)
  if [ -n "$_lock_pid" ] && kill -0 "$_lock_pid" 2>/dev/null; then
    echo "[lock] another daily generation is running (PID $_lock_pid); retry slot skips" >&2
    exit 0
  fi
  rm -f "$CLAUDE_SESSION_LOCK/pid" 2>/dev/null || true
  rmdir "$CLAUDE_SESSION_LOCK" 2>/dev/null || true
  mkdir "$CLAUDE_SESSION_LOCK" 2>/dev/null || {
    echo "[lock] cannot acquire shared lock; retry slot skips" >&2
    exit 0
  }
fi
echo $$ > "$CLAUDE_SESSION_LOCK/pid"
trap 'rm -f "$CLAUDE_SESSION_LOCK/pid"; rmdir "$CLAUDE_SESSION_LOCK" 2>/dev/null' EXIT
# --- 锁结束 ---

WORK="$HOME/.local/share/tony-articles"
CODEX="$HOME/.nvm/versions/node/v24.14.0/bin/codex"
CODEX_MODEL="gpt-5.5"
LOG="$HOME/.claude/logs/daily-article.codex.log"
TODAY="$(date +%Y-%m-%d)"
RUN_STATE_DIR="$HOME/.claude/logs"
DONE_MARK="$RUN_STATE_DIR/.daily-article-done-${TODAY}"
BLOCKED_MARK="$RUN_STATE_DIR/.daily-article-blocked-${TODAY}"
BLOCKER_SNIPPET="$RUN_STATE_DIR/.daily-article-blocker-${TODAY}.txt"
DAILY_ARTICLE_FORCE="${DAILY_ARTICLE_FORCE:-0}"
# This background job has its own logs and final digest. Suppress generic
# Codex Stop-hook Feishu progress messages so relay attempts do not spam chat.
export CODEX_NOTIFY_DISABLE="${CODEX_NOTIFY_DISABLE:-1}"

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
terminal_blocker_seen() {
  # 只检查 agent 回复与纯文本接力输出。整份 JSONL 还包含 prompt、memory 和
  # tool 输出，直接 grep 会把规则里的“今日无合适选题”误判成真实 blocker。
  {
    python3 - "$RELAY_JSON" <<'PY' 2>/dev/null
import json, sys
last_text = ""
try:
    for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
        try:
            ev = json.loads(line)
        except Exception:
            continue
        item = ev.get("item") if isinstance(ev, dict) else None
        if isinstance(item, dict) and item.get("type") == "agent_message":
            text = item.get("text")
            if isinstance(text, str):
                last_text = text
except Exception:
    pass
print(last_text)
PY
    tail -n 160 "$RELAY_OUT" 2>/dev/null
  } | grep -qiE "GetNote.*未授权|未授权.*GetNote|GetNote unavailable|401[^[:alnum:]]*/?[^[:alnum:]]*未授权|没有.*当前文章|没有文章草稿|当前没有文章草稿|缺少合法输入|无法读取今天笔记|无法取得今天笔记|硬编造|硬写并推送|伪造来源|今日无合适选题|no article was generated"
}

sync_main_checkout() {
  cd "$WORK" || return 1
  if [ -n "$(git status --porcelain)" ]; then
    log "WARN: 主发布 checkout 有未提交改动，跳过自动切分支/快进"
    return 1
  fi
  git fetch -q origin main 2>>"$LOG" || return 1
  if [ "$(git symbolic-ref --short HEAD 2>/dev/null)" != "main" ]; then
    git switch -q main 2>>"$LOG" || return 1
  fi
  git merge -q --ff-only origin/main 2>>"$LOG" || return 1
}

release_audit_ok() {
  command -v product-release-audit >/dev/null 2>&1 || {
    log "FATAL: product-release-audit 不可用，拒绝公开发布"
    return 1
  }
  product-release-audit audit . >>"$LOG" 2>&1 &&
    product-release-audit verify . >>"$LOG" 2>&1
}
mark_terminal_blocker() {
  local reason="$1"
  log "STOP: 非重试型阻塞(${reason}), 今日不再接力/重试。可在修复后用 DAILY_ARTICLE_FORCE=1 手动重跑。"
  {
    echo "date=${TODAY}"
    echo "reason=${reason}"
    echo "created_at=$(date '+%Y-%m-%d %H:%M:%S')"
    echo "rerun=DAILY_ARTICLE_FORCE=1 bash $HOME/.claude/scripts/daily-article.sh"
    echo
    echo "--- recent output ---"
    { tail -n 80 "$RELAY_OUT" 2>/dev/null; tail -n 80 "$RELAY_JSON" 2>/dev/null; } | sed -n '1,120p'
  } > "$BLOCKER_SNIPPET"
  touch "$BLOCKED_MARK"
}

log "===== 开始每日文章任务(Codex 版) $TODAY ====="

# 1. 同步仓库
cd "$WORK" || { log "FATAL: 工作目录不存在 $WORK"; exit 1; }
sync_main_checkout || log "WARN: 启动时未能把主发布 checkout 快进到 origin/main；后续发布将 fail-closed"
cat > .gitignore <<'GI'
.DS_Store
.omc/
*.log
ruvector.db
*.db
.tools/__pycache__/
.tools/daily-post-failures.md
GI
git rm -r --cached --ignore-unmatch ruvector.db "*.db" ".omc" >/dev/null 2>&1 || true
rm -f ruvector.db ./*.db 2>/dev/null || true
rm -rf .omc 2>/dev/null || true
if [ -n "$(git status --porcelain)" ]; then
  git add -A 2>/dev/null
  git commit -q -m "chore: ignore 运行时产物 (auto)" 2>>"$LOG" || true
fi
for i in 1 2 3; do
  if git pull -q --rebase origin main 2>>"$LOG"; then break; fi
  log "git pull 第 $i 次失败, 重试..."
  rm -f ruvector.db ./*.db 2>/dev/null
  [ "$i" -eq 3 ] && { git rebase --abort 2>/dev/null; git fetch -q origin main && git reset --hard origin/main 2>>"$LOG" && log "  已 reset --hard 对齐远端"; }
  sleep $((i*3))
done

# 2. 幂等:完成标记存在才直接跳过；若文件已存在但上次在标记前中断，先回查远端。
if [ -f "$DONE_MARK" ]; then
  log "今日中英双版已完成, 跳过"
  exit 0
fi
if ls articles/en/${TODAY}-*.md >/dev/null 2>&1 && ls articles/zh/${TODAY}-*.md >/dev/null 2>&1; then
  EXISTING_EN=$(ls articles/en/${TODAY}-*.md 2>/dev/null | head -1)
  EXISTING_ZH=$(ls articles/zh/${TODAY}-*.md 2>/dev/null | head -1)
  git fetch -q origin main 2>>"$LOG" || true
  if git cat-file -e "origin/main:${EXISTING_EN}" 2>/dev/null &&
     git cat-file -e "origin/main:${EXISTING_ZH}" 2>/dev/null; then
    touch "$DONE_MARK"
    rm -f "$BLOCKED_MARK" "$BLOCKER_SNIPPET"
    log "今日双版已在 origin/main；补写完成标记"
    exit 0
  fi
  log "WARN: 本地已有今日双版但 origin/main 未齐，直接重试审核/提交/push，不重新生成"
  python3 .tools/gen_readme.py >>"$LOG" 2>&1 || true
  EXISTING_ZH_T=$(head -1 "$EXISTING_ZH" | sed 's/^#[[:space:]]*//')
  grep -qxF "$EXISTING_ZH_T" .tools/published-topics.log 2>/dev/null || echo "$EXISTING_ZH_T" >> .tools/published-topics.log
  git add "$EXISTING_EN" "$EXISTING_ZH" README.md .gitignore .tools/gen_readme.py .tools/published-topics.log 2>/dev/null
  if ! release_audit_ok; then
    log "FATAL: release audit 未通过，不 commit、不 push；等待下一补偿时刻"
    exit 1
  fi
  if [ -n "$(git diff --cached --name-only)" ]; then
    git commit -q -m "post: ${TODAY} 中英双版" 2>>"$LOG" || {
      log "ERROR: retry commit 失败；等待下一补偿时刻"
      exit 1
    }
  fi
  for i in 1 2 3; do
    if git push -q origin HEAD:main 2>>"$LOG"; then
      log "retry push 成功"
      break
    fi
    log "retry push 第 $i 次失败"
    sleep $((i*5))
  done
  git fetch -q origin main 2>>"$LOG" || true
  if git cat-file -e "origin/main:${EXISTING_EN}" 2>/dev/null &&
     git cat-file -e "origin/main:${EXISTING_ZH}" 2>/dev/null; then
    touch "$DONE_MARK"
    rm -f "$BLOCKED_MARK" "$BLOCKER_SNIPPET"
    log "retry 已确认 origin/main 双版齐全，标记完成"
    exit 0
  fi
  log "ERROR: retry 后 origin/main 仍未齐；不标记完成，等待下一补偿时刻"
  exit 1
fi
if [ -f "$BLOCKED_MARK" ] && [ "$DAILY_ARTICLE_FORCE" != "1" ]; then
  log "今日已有非重试型阻塞标记且远端双版未齐, 跳过。修复 GetNote/草稿后可 DAILY_ARTICLE_FORCE=1 手动重跑。marker=$BLOCKED_MARK"
  exit 0
fi
LOCK="$HOME/.claude/logs/.daily-article.codex.lock"
if [ -f "$LOCK" ] && kill -0 "$(cat "$LOCK" 2>/dev/null)" 2>/dev/null; then
  log "上一次任务仍在运行 (PID $(cat "$LOCK")), 本次跳过"
  exit 0
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK" "$CLAUDE_SESSION_LOCK/pid"; rmdir "$CLAUDE_SESSION_LOCK" 2>/dev/null' EXIT
mkdir -p articles/en articles/zh

# 已发布主题持久 log(选题去重防重发)
PUB_LOG=".tools/published-topics.log"
if [ ! -f "$PUB_LOG" ]; then
  for f in articles/*.md articles/en/*.md articles/zh/*.md; do
    [ -f "$f" ] && head -1 "$f" | sed 's/^#[[:space:]]*//'
  done 2>/dev/null | sed '/^[[:space:]]*$/d' | sort -u > "$PUB_LOG"
  log "bootstrap published-topics.log: $(wc -l < "$PUB_LOG" 2>/dev/null | tr -d ' ') 条历史主题(全量)"
fi

# 3. 调 Codex 非交互完成全流程(中英双版)
#    注意:13-phase 已展开成显式步骤(Codex 无 xiaolai-write subagent 编排)
PROMPT=$(cat <<'PROMPT_EOF'
你是盛大白(Tony)本人的写作助手。今天的任务:基于我今天的 GetNote 笔记,创作一篇有思想深度的长文,产出【中文版 + 英文版】两个版本,发布到 Tony-Articles 仓库。全程 zero-pause,不要中途停下问我任何问题,也不要尝试派发子任务/subagent(单会话直接做)。

【第零步:去重判断,不重发旧主题】
先 ls ~/.local/share/tony-articles/articles/en/ 和 articles/zh/, 记下已发布的所有 slug / 中文标题。
再读 ~/.local/share/tony-articles/.tools/published-topics.log(每行一个历史已发布主题,含已删除旧文)。
你选的主题若与其中任一同义/高度重复,必须换一个未写过的点。重发旧主题(哪怕已删除)是严重错误。

【第一步:取素材】
调用 GetNote 工具读取我最近的笔记:
- 先用 getnote 的 list_notes (since_id=0) 取最近 20 条笔记
- 再针对关键主题用 getnote 的 recall 做语义召回, 补充相关历史笔记
- 若 GetNote 返回 502/超时, 重试最多 3 次(间隔几秒); 仍失败则记录原因后退出, 不要硬编造内容

【第二步:选题——价值观过滤】
从笔记里捕捉「有独特价值、能引发思考、与我(Tony)相关」的内容点。价值理念主线(选题必须贴合其一):
- 跨时空连接:把不同领域/时代/学科的东西连起来产生新意
- 工程化破界:用系统化、工程化的方法突破个人能力边界
- 自进化系统:让人和系统持续自我迭代、复利成长
- "第零阶级" / 用 AI 让人变强而非变懒
- 终身学习、长期主义、践行导向(受李笑来影响)
只选 1 个最有张力的点。若今天笔记里没有任何贴合上述理念、值得写的点,就不要硬写——记录"今日无合适选题"到日志后退出(exit 0)。

【隐私与脱敏铁律(最高优先级,凌驾选题与创作)】
笔记是私人素材,文章公开发布到 GitHub。严禁把以下私密信息写进文章正文:
- 真实人名一律不出现(学员、客户、家人、朋友、同事、合作方;含化名/昵称)。需举例就用"一位学员""有位朋友""有人"泛指。
- 中文教学业务信息:学员名单/数据、排课、课程内容、收费/营收、招生运营、机构/平台名称。
- 个人隐私:真实姓名(用笔名盛大白)、家庭、住址、行程、联系方式、收入、健康。
- 敏感话题:政治、宗教、涉他人未公开隐私、争议性个人立场——不碰。
- 技术敏感信息:API key、token、服务器 IP、内部路径、私有项目代号。
做法:只提炼可公开的抽象观点、方法论、成长/学习/AI 思考,把私密载体抽象成普适道理。
若某选题离开私密细节就立不住,放弃它换一个。宁可"今日无合适选题"退出,也不发含隐私的文章。

【第三步:创作(单会话显式展开,不依赖 subagent)】
按以下内部阶段顺序在本会话里依次完成,每阶段产出后接着下一阶段:
1. 研究:用 WebSearch / getnote 已召回内容补充论据与事实,所有引用的数字/日期/事实要可核。
2. 立结构:先列出 3-5 段的逻辑骨架(论点→论据→延伸→收口)。
3. 写英文初稿:1000-2000 词,论证扎实、有真实张力,不要空泛口号。
4. 自我批判一遍:找逻辑漏洞 / 幸存者偏差 / 收尾是否有力,据此修订(英文长文收尾是 gpt-5.5 已知弱项,务必让结尾收得住)。
5. 翻译中文版:不要逐字翻译,用盛大白真诚、口语化、有温度的公众号风格【重写】成中文,与英文一一对应。
6. CJK 排版:中文版用全角标点,中英混排时 ASCII 与中文之间留空格。
目标读者:关注成长、学习、AI、自我进化的普通人。长度:正文 1500-3000 字(英文 1000-2000 词)。

【第四步:保存双版 + 发布】
今天日期记为 TODAY(YYYY-MM-DD),取简洁英文 slug(小写连字符,去特殊字符)。
- 英文版: articles/en/TODAY-<slug>.md
- 中文版: articles/zh/TODAY-<中文标题>.md(中文标题去掉 / : 等特殊字符)
两文件开头都加:
  # 标题

  > 发布日期:TODAY · [中文](../zh/...) | [English](../en/...)

  ---
(互链对方语言版本)
- 重建 README:在仓库根目录运行 python3 .tools/gen_readme.py
- git add -A && git commit -m "post: <slug> 中英双版 (TODAY)"
- 用户已明确授权这项每日自动任务公开发布到 GitHub main。完成脱敏检查并运行
  product-release-audit audit . 与 product-release-audit verify . 后，必须执行
  git push origin HEAD:main。只 push 到 ai/* 分支或只给 PR 链接不算完成。

完成后用一句话报告:文章标题(中/英)+ 两版是否都已推送成功。
PROMPT_EOF
)

# Codex 调用 flags(首轮 codex exec 支持 -C/--add-dir;resume 子命令不支持,见下)
CODEX_FLAGS=(--dangerously-bypass-approvals-and-sandbox --skip-git-repo-check -C "$WORK" --add-dir "$WORK" -m "$CODEX_MODEL")
# resume 子命令【不支持 -C/--add-dir】,靠当前进程 cwd 过滤会话;脚本已 cd "$WORK",故自动定位本仓库会话。
RESUME_FLAGS=(--dangerously-bypass-approvals-and-sandbox --skip-git-repo-check -m "$CODEX_MODEL")

RELAY_OUT="$HOME/.claude/logs/.daily-relay-codex-out.txt"
RELAY_JSON="$HOME/.claude/logs/.daily-relay-codex-events.jsonl"

# 撞用量上限检测(ChatGPT 订阅额度 / 429)
hit_session_limit() {
  grep -qiE "usage limit reached|usage_limit_reached|rate limit exceeded|429 too many requests|quota exceeded|exceeded your current quota" "$RELAY_OUT" 2>/dev/null
}

# 第一轮:启动写作,用 --json 捕获 session_id
log "接力第 1 轮: 启动 Codex 写作..."
echo "$PROMPT" | run_limited 1500 "$CODEX" exec --json "${CODEX_FLAGS[@]}" - \
  > "$RELAY_JSON" 2>"$RELAY_OUT"
log "  第 1 轮 rc=$? (124=超时)"
cat "$RELAY_OUT" >> "$LOG"
if hit_session_limit; then
  log "  撞用量上限, 止损退出。当前 launchd 每天只跑一次, 可在 reset 后手动重跑"
  ntfy_send "⚠️ daily-article 撞 Codex 429 限额(首轮), 今日($TODAY)文章暂未出。可在额度 reset 后手动重跑: DAILY_ARTICLE_FORCE=1 bash ~/.claude/scripts/daily-article.sh"
  exit 0
fi
if terminal_blocker_seen; then
  mark_terminal_blocker "first-round-terminal-blocker"
  exit 0
fi

# 解析 session_id(多键兜底,失败则后续用 --last)
SID=$(python3 - "$RELAY_JSON" <<'PY' 2>/dev/null
import json, sys
sid = ""
try:
    for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
        line = line.strip()
        if not line: continue
        try: ev = json.loads(line)
        except Exception: continue
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
log "本次接力 session-id=${SID:-<空,接力改用 --last>}"

# 后续接力:resume 续跑,收敛判据 = 双版是否已落地(Codex 无 .state.json,故不做 phase 推进检测)
CONT_PROMPT="继续完成当前文章:把英文版保存到 articles/en/、中文版保存到 articles/zh/(中英互链),运行 python3 .tools/gen_readme.py 重建 README,git add/commit，完成脱敏与 product-release-audit 后执行 git push origin HEAD:main。用户已明确授权每日公开发布；只推 ai/* 分支或给 PR 链接不算完成。全程不要停下问我,不要派 subagent。"
MAX_RELAYS=12
for r in $(seq 1 $MAX_RELAYS); do
  if ls "$WORK"/articles/en/${TODAY}-*.md >/dev/null 2>&1 && ls "$WORK"/articles/zh/${TODAY}-*.md >/dev/null 2>&1; then
    log "  双版已落地, 接力结束(第 $r 轮前)"; break
  fi
  log "接力第 $((r+1)) 轮: resume 续跑..."
  if [ -n "$SID" ]; then
    echo "$CONT_PROMPT" | run_limited 1200 "$CODEX" exec resume "$SID" "${RESUME_FLAGS[@]}" - > "$RELAY_OUT" 2>&1
  else
    echo "$CONT_PROMPT" | run_limited 1200 "$CODEX" exec resume --last "${RESUME_FLAGS[@]}" - > "$RELAY_OUT" 2>&1
  fi
  cat "$RELAY_OUT" >> "$LOG"
  log "  第 $((r+1)) 轮 rc=$?"
  if hit_session_limit; then
    log "  撞用量上限, 止损退出。当前 launchd 每天只跑一次, 可在 reset 后手动重跑"
    ntfy_send "⚠️ daily-article 撞 Codex 429 限额(接力轮), 今日($TODAY)文章暂未出。可在额度 reset 后手动重跑: DAILY_ARTICLE_FORCE=1 bash ~/.claude/scripts/daily-article.sh"
    exit 0
  fi
  if terminal_blocker_seen; then
    mark_terminal_blocker "relay-${r}-terminal-blocker"
    exit 0
  fi
done

# 4. 兜底确认双版是否真的推送了
cd "$WORK"
sync_main_checkout || true
EN_FILE=$(ls articles/en/${TODAY}-*.md 2>/dev/null | head -1)
ZH_FILE=$(ls articles/zh/${TODAY}-*.md 2>/dev/null | head -1)
if [ -n "$EN_FILE" ] && [ -n "$ZH_FILE" ]; then
  log "SUCCESS: 英文=$(basename "$EN_FILE") 中文=$(basename "$ZH_FILE")"
  rm -f ruvector.db ./*.db 2>/dev/null
  git rm --cached --ignore-unmatch ruvector.db "*.db" >/dev/null 2>&1 || true
  python3 .tools/gen_readme.py >>"$LOG" 2>&1 || true
  for i in 1 2 3; do
    git pull -q --rebase origin main 2>>"$LOG" && break
    [ "$i" -eq 3 ] && { git rebase --abort 2>/dev/null; git fetch -q origin main; git reset --hard origin/main 2>>"$LOG"; }
    rm -f ruvector.db ./*.db 2>/dev/null; sleep $((i*3))
  done
  ZH_T=$(head -1 "$ZH_FILE" | sed 's/^#[[:space:]]*//')
  grep -qxF "$ZH_T" .tools/published-topics.log 2>/dev/null || echo "$ZH_T" >> .tools/published-topics.log
  git add articles/ README.md .gitignore .tools/gen_readme.py .tools/published-topics.log 2>/dev/null
  if [ -n "$(git diff --cached --name-only)" ]; then
    if ! release_audit_ok; then
      log "FATAL: release audit 未通过，不 commit、不 push"
      exit 1
    fi
    git commit -q -m "post: ${TODAY} 中英双版" 2>>"$LOG" || true
    for i in 1 2 3; do
      git push -q origin main 2>>"$LOG" && { log "push 成功"; break; }
      log "push 第 $i 次失败"; sleep $((i*5))
    done
  fi
  git fetch -q origin main 2>>"$LOG" || true
  if git cat-file -e "origin/main:${ZH_FILE}" 2>/dev/null && git cat-file -e "origin/main:${EN_FILE}" 2>/dev/null; then
    touch "$DONE_MARK"
    rm -f "$BLOCKED_MARK" "$BLOCKER_SNIPPET"
    log "已验证远端含今日中文版, 标记完成"
    log "GitHub origin/main 是唯一完成通道；不再触发飞书/微信"
  else
    log "WARN: 远端未确认今日文章, 不标记完成, 后续重试"
  fi
else
  if terminal_blocker_seen; then
    mark_terminal_blocker "missing-files-after-terminal-blocker"
  else
    log "ERROR: 今日双版未齐(en=${EN_FILE:-无} zh=${ZH_FILE:-无}), 未设置 blocker; 下次定时任务再尝试"
  fi
fi

log "===== 任务结束 ====="
