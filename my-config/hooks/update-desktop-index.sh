#!/bin/bash
# Auto-maintain 索引.md (AUTO-TREE block) for the 4 main Desktop folders:
#   ~/Desktop/项目开发, ~/Desktop/学习资料, ~/Desktop/内容创作, ~/Desktop/杂项
#
# - Scans 2 levels of each folder, regenerates the block between
#   <!-- AUTO-TREE-START --> and <!-- AUTO-TREE-END -->.
# - If 索引.md does not exist, creates a minimal skeleton with the markers.
# - Hidden dirs (.omc, .git, .DS_Store etc.) excluded.
# - Idempotent: if structure unchanged (ignoring timestamp), no rewrite.
#
# Usage:
#   update-desktop-index.sh              # update all 4 folders
#   update-desktop-index.sh <abs-path>   # update one folder only
#
# NOTE: intentionally NO `set -e`. This runs against live directories that may
# change mid-scan (Finder add/delete); a transient non-zero from find/cd must
# not abort the whole rewrite, or deletions silently fail to propagate.

DESKTOP="$HOME/Desktop"
TARGETS=("项目开发" "学习资料" "内容创作" "杂项")
START_MARKER="<!-- AUTO-TREE-START -->"
END_MARKER="<!-- AUTO-TREE-END -->"

build_tree() {
  local root="$1" name="$2" today
  today=$(date '+%Y-%m-%d %H:%M')
  printf '%s\n' "$START_MARKER"
  printf '\n> 自动生成 · 最后扫描 %s\n\n' "$today"
  printf '```\n'
  printf '%s/\n' "$name"

  local top_dirs=()
  while IFS= read -r d; do
    top_dirs+=("$d")
  done < <(cd "$root" && find . -maxdepth 1 -mindepth 1 -type d ! -name '.*' | sed 's|^\./||' | LC_ALL=C sort)

  local n=${#top_dirs[@]} i=0
  for top in "${top_dirs[@]}"; do
    i=$((i+1))
    local top_branch="├──" sub_pipe="│"
    if [ "$i" = "$n" ]; then top_branch="└──"; sub_pipe=" "; fi
    printf '%s %s/\n' "$top_branch" "$top"

    local subs=()
    while IFS= read -r s; do
      subs+=("$s")
    done < <(cd "$root/$top" && find . -maxdepth 1 -mindepth 1 -type d ! -name '.*' 2>/dev/null | sed 's|^\./||' | LC_ALL=C sort)
    local sn=${#subs[@]} si=0
    for sub in "${subs[@]}"; do
      si=$((si+1))
      local sub_branch="├──"
      [ "$si" = "$sn" ] && sub_branch="└──"
      printf '%s   %s %s/\n' "$sub_pipe" "$sub_branch" "$sub"
    done
  done
  printf '```\n'
  printf '\n%s\n' "$END_MARKER"
}

create_skeleton() {
  local index="$1" name="$2"
  {
    printf '# %s · 索引\n\n' "$name"
    printf '> 顶层目录树由 hook 自动维护(Claude 会话 + Finder 改动均触发刷新)。\n'
    printf '> 下方"详细说明"为手写部分,新建项目后请手动补充描述。\n\n'
    printf '%s\n\n## 目录结构总览(自动维护)\n\n' '---'
    printf '%s\n\n%s\n' "$START_MARKER" "$END_MARKER"
  } > "$index"
}

update_one() {
  local root="$1"
  local name; name=$(basename "$root")
  local index="$root/索引.md"

  [ ! -d "$root" ] && return 0
  [ ! -f "$index" ] && create_skeleton "$index" "$name"
  grep -qF "$START_MARKER" "$index" || return 0

  local NEW_BLOCK CURRENT_BLOCK
  NEW_BLOCK=$(build_tree "$root" "$name")
  CURRENT_BLOCK=$(awk -v s="$START_MARKER" -v e="$END_MARKER" '
    $0 ~ s {flag=1} flag {print} $0 ~ e {flag=0}' "$index")

  norm() { grep -v '自动生成 · 最后扫描' | sed '/^$/d'; }
  local NEW_NORM CUR_NORM
  NEW_NORM=$(printf '%s' "$NEW_BLOCK" | norm)
  CUR_NORM=$(printf '%s' "$CURRENT_BLOCK" | norm)
  [ "$NEW_NORM" = "$CUR_NORM" ] && return 0

  local NEW_FILE TMP
  NEW_FILE=$(mktemp)
  printf '%s\n' "$NEW_BLOCK" > "$NEW_FILE"
  TMP=$(mktemp)
  awk -v s="$START_MARKER" -v e="$END_MARKER" -v newfile="$NEW_FILE" '
    BEGIN {in_block=0}
    $0 ~ s { while ((getline line < newfile) > 0) print line; close(newfile); in_block=1; next }
    $0 ~ e { in_block=0; next }
    !in_block {print}
  ' "$index" > "$TMP"
  mv "$TMP" "$index"
  rm -f "$NEW_FILE"
}

if [ -n "$1" ]; then
  update_one "$1"
else
  for t in "${TARGETS[@]}"; do
    update_one "$DESKTOP/$t"
  done
fi
exit 0
