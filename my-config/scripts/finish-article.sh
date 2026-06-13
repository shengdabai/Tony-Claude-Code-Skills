#!/bin/bash
# 把指定 slug 的 xiaolai-write 文章续跑到完成并发布双版.
# 用法: bash finish-article.sh <slug> [publish-date]
# 不依赖会话 resume — 靠 xiaolai-write 的 .state.json (按 slug 存进度) 续跑.
set -uo pipefail

SLUG="${1:?需要 slug}"
PUBDATE="${2:-$(date +%Y-%m-%d)}"
WORK="$HOME/.local/share/tony-articles"
CLAUDE="$HOME/.local/bin/claude"
LOG="$HOME/.claude/logs/finish-article.log"
FACTORY="$HOME/Desktop/03-内容创作/01-文章加工厂"
SF="$FACTORY/$SLUG/.state.json"

log(){ echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }
phase_of(){ python3 -c "import json;print(json.load(open('$SF')).get('current_phase'))" 2>/dev/null || echo '?'; }
is_done(){ python3 -c "import json;d=json.load(open('$SF'));import sys;sys.exit(0 if '12' in [str(x) for x in d.get('completed',[])] else 1)" 2>/dev/null; }

[ -f "$SF" ] || { log "FATAL: $SF 不存在"; exit 1; }
log "===== 续跑 $SLUG (起始 phase $(phase_of)) ====="

FLAGS=(--mcp-config "$HOME/.claude/mcp-servers/getnote-only.json" --permission-mode bypassPermissions --add-dir "$WORK")

PROMPT="你是盛大白的写作助手。现在要把一篇已经开始的 xiaolai-write 文章续跑到完成。

第一步: 运行 /plan-switch-article $SLUG 切到这篇文章(它的进度在 .state.json)。
第二步: 运行 /xiaolai-write 续跑剩余阶段, 直到全部 13 阶段完成。
关键约束(避免卡死):
- research / fact-check 等阶段【不要派发 subagent】, 在主会话里直接用 WebSearch / getnote / 已有 research 文件直接完成, 快速推进。
- 全程 zero-pause, 不要停下问我。
第三步: 完成后产出中英双版:
- 英文版存到 $WORK/articles/en/${PUBDATE}-<slug>.md
- 中文版存到 $WORK/articles/zh/${PUBDATE}-<中文标题>.md
- 两版开头加标题 + '> 发布日期:${PUBDATE}' + 互链
报告最终 phase 和双版文件名。"

CONT="继续把当前这篇 xiaolai-write 文章(slug=$SLUG)的剩余阶段跑完。research/fact-check 不要派 subagent, 主会话直接做。完成 13 阶段后产出中英双版到 articles/en 和 articles/zh (日期 ${PUBDATE}), 互链。zero-pause。"

OUT="$HOME/.claude/logs/.finish-out.txt"
limit_hit(){ grep -qiE "session limit|usage limit|hit your .* limit" "$OUT" 2>/dev/null; }

# 首轮 switch + 启动
log "轮 1: switch + 续跑..."
echo "$PROMPT" | timeout 1200 "$CLAUDE" -p "${FLAGS[@]}" > "$OUT" 2>&1
cat "$OUT" >> "$LOG"; log "  轮1 rc=$? phase=$(phase_of)"
limit_hit && { log "撞用量上限, 退出待重试"; exit 2; }

PREV=""; STALL=0
for r in $(seq 2 14); do
  if ls "$WORK"/articles/en/${PUBDATE}-*.md >/dev/null 2>&1 && ls "$WORK"/articles/zh/${PUBDATE}-*.md >/dev/null 2>&1; then
    log "  双版已落地, 完成"; break
  fi
  CUR=$(phase_of)
  [ "$CUR" = "$PREV" ] && STALL=$((STALL+1)) || STALL=0
  PREV="$CUR"
  [ "$STALL" -ge 3 ] && { log "  连续停滞在 $CUR, 退出"; exit 3; }
  log "轮 $r: 续跑 (phase=$CUR)..."
  echo "$CONT" | timeout 1200 "$CLAUDE" -p --continue "${FLAGS[@]}" > "$OUT" 2>&1
  cat "$OUT" >> "$LOG"; log "  轮$r rc=$? phase=$(phase_of)"
  limit_hit && { log "撞用量上限, 退出待重试"; exit 2; }
done

log "===== $SLUG 续跑结束, 最终 phase $(phase_of) ====="
