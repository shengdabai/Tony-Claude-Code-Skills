#!/usr/bin/env bash
# claude-reap — 安全回收闲置的 claude CLI 会话,缓解 swap 压力
#
# 用法:
#   claude-reap            回收运行 >6h 的闲置 CLI 会话(SIGTERM 优雅退出)
#   claude-reap 12h        自定义阈值(支持 30m / 2h / 90 这种,纯数字=分钟)
#   claude-reap --dry      只列候选不回收
#   claude-reap --all      回收除当前会话外的所有 CLI 会话(谨慎)
#
# 安全保证:
#   - 只动 ~/.local/bin/claude 主进程,绝不碰 Claude.app 桌面应用 / node MCP 子进程
#   - 自动保护当前会话整条祖先链
#   - 默认 SIGTERM(claude 捕获后保存会话,可 `claude --continue` 恢复)
#   - 白名单文件 ~/.claude/reap-keep.txt(每行一个 PID 或 cwd 关键字)永不回收

set -uo pipefail

KEEP_FILE="$HOME/.claude/reap-keep.txt"
DRY=""; ALL=""; THRESH_MIN=360

for arg in "$@"; do
  case "$arg" in
    --dry|-n)  DRY=1 ;;
    --all)     ALL=1 ;;
    *h)        THRESH_MIN=$(( ${arg%h} * 60 )) ;;
    *m)        THRESH_MIN=${arg%m} ;;
    ''|*[!0-9]*) : ;;   # 忽略未知非数字
    *)         THRESH_MIN=$arg ;;
  esac
done

# 1) 当前会话祖先链中的 claude 主进程 → 保护
SELF=""
p=$$
while [ "${p:-1}" -gt 1 ]; do
  c=$(/bin/ps -o command= -p "$p" 2>/dev/null)
  case "$c" in */.local/bin/claude|*/.local/bin/claude\ *) SELF="$p" ;; esac
  p=$(/bin/ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
  [ -z "$p" ] && break
done

# 2) 读白名单(PID 或 cwd 关键字)
KEEP_PIDS=" "; KEEP_WORDS=""
if [ -f "$KEEP_FILE" ]; then
  while IFS= read -r line; do
    line="${line%%#*}"; line="$(echo "$line" | xargs 2>/dev/null)"
    [ -z "$line" ] && continue
    case "$line" in
      *[!0-9]*) KEEP_WORDS="$KEEP_WORDS $line" ;;
      *)        KEEP_PIDS="$KEEP_PIDS$line " ;;
    esac
  done < "$KEEP_FILE"
fi

etime2secs() { awk -F'[-:]' '{n=NF;s=$n;if(n>=2)s+=$(n-1)*60;if(n>=3)s+=$(n-2)*3600;if(n>=4)s+=$(n-3)*86400;print s}'; }

THRESH=$(( THRESH_MIN * 60 ))
[ -n "$ALL" ] && THRESH=0

before=$(sysctl -n vm.swapusage | sed -E 's/.*used = ([0-9.]+)M.*/\1/')
killed=0; listed=0

while read -r pid etime; do
  [ "$pid" = "$SELF" ] && continue
  case "$KEEP_PIDS" in *" $pid "*) echo "🔒 保护 $pid (白名单)"; continue ;; esac
  # cwd 关键字白名单
  if [ -n "$KEEP_WORDS" ]; then
    cwd=$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -1)
    for w in $KEEP_WORDS; do
      case "$cwd" in *"$w"*) echo "🔒 保护 $pid (cwd~$w)"; pid=""; break ;; esac
    done
    [ -z "$pid" ] && continue
  fi
  secs=$(printf '%s' "$etime" | etime2secs)
  [ "${secs:-0}" -lt "$THRESH" ] && continue
  if [ -n "$DRY" ]; then
    echo "候选 $pid (运行 $etime)"; listed=$((listed+1))
  else
    kill -TERM "$pid" 2>/dev/null && { echo "♻️  回收 $pid (运行 $etime)"; killed=$((killed+1)); }
  fi
done < <(/bin/ps -axo pid=,etime=,command= | awk '{p=$1;e=$2;$1="";$2="";cmd=$0;gsub(/^ +/,"",cmd); if(cmd ~ /\/\.local\/bin\/claude($| )/) print p, e}')

if [ -n "$DRY" ]; then
  echo "—— dry-run:$listed 个候选(阈值 ${THRESH_MIN}m)。去掉 --dry 执行回收。"
  exit 0
fi

sleep 2
after=$(sysctl -n vm.swapusage | sed -E 's/.*used = ([0-9.]+)M.*/\1/')
echo "✅ 回收 $killed 个会话 | swap used ${before}M → ${after}M | 当前会话 $SELF 已保护"
echo "   恢复任意会话: cd <项目> && claude --continue"
