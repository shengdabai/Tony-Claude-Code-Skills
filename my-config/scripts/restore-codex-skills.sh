#!/usr/bin/env bash
# restore-codex-skills.sh — 恢复被 sync 流程移走的 Codex 自带 skill
#
# sync-skills-to-codex 配套流程曾把 240 个 codex 自带泛用开发模板
# (airflow/bazel/angular-migration/k8s/defi/iso27001 等冷门技术 skill)
# 从 ~/.codex/skills/ 移到 ~/.codex/skills-disabled/ 以腾出 prompt 预算,
# 让用户自研 skill(opc-*/seedance-*/xiaolai-* 等)进入模型可见窗口。
#
# 本脚本把它们全部移回。注意:恢复后 skill 总数回升,字母靠后的自研
# skill 可能再次被 Codex 列表截断。建议只在确需某个被禁 skill 时,手工
# 单独移回:  mv ~/.codex/skills-disabled/<name> ~/.codex/skills/
#
# 用法: bash ~/.claude/scripts/restore-codex-skills.sh        # 全部恢复
#       bash ~/.claude/scripts/restore-codex-skills.sh <name> # 只恢复一个
set -u

DIS="$HOME/.codex/skills-disabled"
CODEX="$HOME/.codex/skills"

if [ ! -d "$DIS" ]; then echo "无禁用目录 $DIS,没什么可恢复"; exit 0; fi

if [ "${1:-}" != "" ]; then
  n="$1"
  if [ -d "$DIS/$n" ]; then mv "$DIS/$n" "$CODEX/$n" && echo "已恢复: $n"; else echo "未找到 $DIS/$n"; fi
  exit 0
fi

moved=0
for d in "$DIS"/*; do
  [ -d "$d" ] || continue
  name="$(basename "$d")"
  if [ -e "$CODEX/$name" ]; then echo "跳过(已存在): $name"; continue; fi
  mv "$d" "$CODEX/$name" && moved=$((moved+1))
done
echo "恢复 $moved 个 codex skill"
echo "Codex skills 总数: $(find "$CODEX" -maxdepth 1 -mindepth 1 ! -name '.system' | wc -l | tr -d ' ')"
