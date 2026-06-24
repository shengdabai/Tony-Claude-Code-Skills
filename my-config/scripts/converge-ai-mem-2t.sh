#!/bin/bash
# 把 AI 记忆系统收敛回 /Volumes/2T 为唯一权威库(2026-06-24)
# 在有完整磁盘访问的终端/Ghostty 里跑:  bash ~/.claude/scripts/converge-ai-mem-2t.sh
# 安全:不删任何东西(home 改名作回滚)、union 合并(不 --delete)、可重复跑
set -uo pipefail
HOME_ROOT="$HOME/ai-memory-system"
T2_ROOT="/Volumes/2T/ai-memory-system"
U=$(id -u)
TS=$(date +%Y%m%d-%H%M)
JOBS="com.tony.ai-mem com.tony.ai-mem-fast com.tony.ai-mem-backfill com.tony.cloud-session-pull com.tony.command-center-health"

echo "== 0) 前置检查 =="
df "$T2_ROOT" >/dev/null 2>&1 || { echo "❌ 2T 未挂载"; exit 1; }
if touch "$T2_ROOT/.wt$$" 2>/dev/null; then rm -f "$T2_ROOT/.wt$$"; echo "✅ 本终端可写 2T"; else
  echo "❌ 本终端也写不了 2T → 去 系统设置>隐私与安全性>完整磁盘访问 勾上 终端(或 Ghostty),重开终端再跑"; exit 1; fi
[ -d "$HOME_ROOT" ] || { echo "⚠️ home 副本已不在,可能已收敛过,只做后续重指/刷新"; }

echo "== 1) 停 home 指向的 launchd(防迁移期竞态) =="
for L in $JOBS; do launchctl bootout gui/$U/$L 2>/dev/null && echo "  停 $L" || true; done

echo "== 2) 合并 home → 2T(union,不删,保住 cloud/ 云端会话) =="
if [ -d "$HOME_ROOT" ]; then rsync -a "$HOME_ROOT"/ "$T2_ROOT"/ && echo "✅ 合并完成"; else echo "  跳过(无 home)"; fi

echo "== 3) 把 5 个 launchd plist 路径指回 2T =="
for L in $JOBS; do P="$HOME/Library/LaunchAgents/$L.plist"
  [ -f "$P" ] && { sed -i '' "s#$HOME_ROOT#$T2_ROOT#g" "$P"; echo "  改 $L"; }; done

echo "== 4) 重载 launchd =="
for L in $JOBS; do P="$HOME/Library/LaunchAgents/$L.plist"
  [ -f "$P" ] && launchctl bootstrap gui/$U "$P" 2>/dev/null && echo "  载 $L" || true; done

echo "== 5) 飞书入口指回 2T =="
sed -i '' "s#$HOME_ROOT#$T2_ROOT#g" "$HOME/.claude/rules/feishu-bot.md" 2>/dev/null && echo "✅ feishu-bot.md → 2T"

echo "== 6) 全量刷新 2T + 验证会话数 =="
AI_MEM_ROOT="$T2_ROOT" "$T2_ROOT/bin/ai-mem" fast
python3 -c "import json;print('2T 会话总数:',len(json.load(open('$T2_ROOT/index/sessions.json'))))" 2>/dev/null

echo "== 7) 关键:测 launchd 自己能否真写 2T =="
launchctl kickstart -k gui/$U/com.tony.ai-mem-fast 2>/dev/null; sleep 10
if tail -4 "$HOME/Library/Logs/2t-jobs/com.tony.ai-mem-fast.log" 2>/dev/null | grep -q "/Volumes/2T"; then
  echo "✅ launchd 已成功写 2T —— 收敛稳了"
else
  echo "⚠️ launchd 日志没出现 2T 路径!很可能 launchd 进程没 FDA(这正是 6/15 当初迁 home 的原因)。"
  echo "   补救:把 launchd 跑的解释器加进完整磁盘访问 —— 系统设置>隐私>完整磁盘访问 添加 /bin/bash 和 $(which python3)"
  echo "   加完重跑本脚本第 7 步即可;若嫌麻烦,撤销改回 home 为准也行(见下)"
fi

echo "== 8) 归档 home 副本(回滚用,确认几天没问题再删) =="
[ -d "$HOME_ROOT" ] && mv "$HOME_ROOT" "$HOME/ai-memory-system.migrated-$TS" && echo "✅ home → ~/ai-memory-system.migrated-$TS"
echo ""
echo "🎉 完成。验证:手机飞书发「记忆」应看到最新;桌面 ai-mem 命令(软链已指 2T)也读 2T。"
echo "↩️ 若第7步是 ⚠️ 且不想折腾 FDA,撤回 home 为准:"
echo "   for L in $JOBS; do P=\$HOME/Library/LaunchAgents/\$L.plist; sed -i '' \"s#$T2_ROOT#$HOME_ROOT#g\" \$P; launchctl bootout gui/$U/\$L 2>/dev/null; launchctl bootstrap gui/$U \$P; done"
echo "   sed -i '' \"s#$T2_ROOT#$HOME_ROOT#g\" \$HOME/.claude/rules/feishu-bot.md; mv ~/ai-memory-system.migrated-$TS ~/ai-memory-system"
