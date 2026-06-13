#!/usr/bin/env bash
# sync-skills-to-codex.sh — 把 Claude Code 的精选 skill 桥接到 Codex CLI
#
# 背景:Codex 0.129 把 skill 列表按字母序注入模型 prompt,有字节/条数预算。
#       skill 太多会截断,字母靠后的(opc-*/seedance-*/xiaolai-*)看不到。
#       因此采用「精选桥接 + 移走 codex 自带泛用模板」策略,而非全量同步。
#
# 行为:读 codex-selfdev-skills.txt 清单,把每个 Claude skill 以 symlink
#       桥接进 ~/.codex/skills/(指向解析后的真实目录,避免二级链)。幂等。
#
# 用法: bash ~/.claude/scripts/sync-skills-to-codex.sh
# 恢复被禁用的 codex 自带 skill: bash ~/.claude/scripts/restore-codex-skills.sh
set -u

CL="$HOME/.claude/skills"
CODEX="$HOME/.codex/skills"
LIST="$HOME/.claude/scripts/codex-selfdev-skills.txt"
LOG="$HOME/.claude/scripts/.codex-selfdev.log"

mkdir -p "$CODEX"
: > "$LOG"
linked=0; exist=0; fail=0

# 源覆盖表:真身不在 ~/.claude/skills/ 下的 skill,在此显式给绝对路径
# 格式: skill名|绝对源目录(含 SKILL.md)
declare -a SRC_OVERRIDE=(
  "liuxiaopai-product|$HOME/Desktop/01-项目开发/03-刘小排-可以抄作业的闷声发财产品/01-刘小排产品研究流程/.claude/skills/liuxiaopai-product"
)
resolve_override() {
  local n="$1"
  for row in "${SRC_OVERRIDE[@]}"; do
    [ "${row%%|*}" = "$n" ] && { echo "${row#*|}"; return 0; }
  done
  return 1
}

while IFS= read -r raw; do
  name="${raw%%#*}"; name="$(echo "$name" | xargs)"
  [ -z "$name" ] && continue
  if ov="$(resolve_override "$name")"; then
    src="$(readlink -f "$ov" 2>/dev/null)"
  else
    src="$(readlink -f "$CL/$name" 2>/dev/null)"
  fi
  if [ -z "$src" ] || [ ! -f "$src/SKILL.md" ]; then
    echo "FAIL  $name (Claude 侧无 SKILL.md)" >> "$LOG"; fail=$((fail+1)); continue
  fi
  dst="$CODEX/$name"
  if [ -L "$dst" ] || [ -e "$dst" ]; then
    echo "EXIST $name" >> "$LOG"; exist=$((exist+1)); continue
  fi
  if ln -s "$src" "$dst"; then
    echo "LINK  $name -> $src" >> "$LOG"; linked=$((linked+1))
  else
    echo "FAIL  $name (ln)" >> "$LOG"; fail=$((fail+1))
  fi
done < "$LIST"

echo "桥接: $linked  已存在: $exist  失败: $fail"
echo "日志: $LOG"
echo "Codex skills 总数: $(find "$CODEX" -maxdepth 1 -mindepth 1 ! -name '.system' | wc -l | tr -d ' ')"
echo
echo "验证模型可见性: codex debug prompt-input x | grep <skill-name>"
echo "注意: frontmatter 里 name 字段是通用词(如 query/ingest)的 skill 会被 Codex"
echo "      按 name 去重,以通用名出现,不带前缀 — 属正常,功能仍可用。"
