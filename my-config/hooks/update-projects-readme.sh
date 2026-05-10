#!/bin/bash
# Auto-update ~/Desktop/项目开发/README.md auto-tree section.
# Stop hook: scans 2 levels of ~/Desktop/项目开发/, regenerates the
# block between <!-- AUTO-TREE-START --> and <!-- AUTO-TREE-END -->.
#
# Skip rules (only update when something actually changed):
#   - Compare new tree against existing block; if identical, exit 0 fast
#   - Hidden dirs (.omc, .git, .DS_Store etc.) excluded
#
# Idempotent. Safe to run on every Stop event.

set -e

ROOT="$HOME/Desktop/项目开发"
README="$ROOT/README.md"
START_MARKER="<!-- AUTO-TREE-START -->"
END_MARKER="<!-- AUTO-TREE-END -->"

[ ! -d "$ROOT" ] && exit 0
[ ! -f "$README" ] && exit 0
grep -qF "$START_MARKER" "$README" || exit 0

build_tree() {
  local today
  today=$(date '+%Y-%m-%d %H:%M')
  printf '%s\n' "$START_MARKER"
  printf '\n> 自动生成 · 最后扫描 %s\n\n' "$today"
  printf '```\n'
  printf '项目开发/\n'

  # Top-level dirs (sorted, no hidden, no files)
  local top_dirs=()
  while IFS= read -r d; do
    top_dirs+=("$d")
  done < <(cd "$ROOT" && find . -maxdepth 1 -mindepth 1 -type d ! -name '.*' | sed 's|^\./||' | LC_ALL=C sort)

  local n=${#top_dirs[@]}
  local i=0
  for top in "${top_dirs[@]}"; do
    i=$((i+1))
    local top_branch="├──"
    local sub_pipe="│"
    if [ "$i" = "$n" ]; then
      top_branch="└──"
      sub_pipe=" "
    fi
    printf '%s %s/\n' "$top_branch" "$top"

    # Second level
    local subs=()
    while IFS= read -r s; do
      subs+=("$s")
    done < <(cd "$ROOT/$top" && find . -maxdepth 1 -mindepth 1 -type d ! -name '.*' 2>/dev/null | sed 's|^\./||' | LC_ALL=C sort)
    local sn=${#subs[@]}
    local si=0
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

NEW_BLOCK=$(build_tree)

# Extract current block
CURRENT_BLOCK=$(awk -v s="$START_MARKER" -v e="$END_MARKER" '
  $0 ~ s {flag=1}
  flag {print}
  $0 ~ e {flag=0}
' "$README")

# Compare ignoring the timestamp line so identical structure doesn't trigger rewrite
norm() { grep -v '自动生成 · 最后扫描' | sed '/^$/d'; }
NEW_NORM=$(printf '%s' "$NEW_BLOCK" | norm)
CUR_NORM=$(printf '%s' "$CURRENT_BLOCK" | norm)

if [ "$NEW_NORM" = "$CUR_NORM" ]; then
  exit 0  # no real change
fi

# Replace block in README atomically.
# BSD awk on macOS chokes on multi-line strings via -v, so we feed the new
# block from a temp file using getline.
NEW_FILE=$(mktemp)
printf '%s\n' "$NEW_BLOCK" > "$NEW_FILE"

TMP=$(mktemp)
awk -v s="$START_MARKER" -v e="$END_MARKER" -v newfile="$NEW_FILE" '
  BEGIN {in_block=0}
  $0 ~ s {
    while ((getline line < newfile) > 0) print line
    close(newfile)
    in_block=1
    next
  }
  $0 ~ e {in_block=0; next}
  !in_block {print}
' "$README" > "$TMP"

mv "$TMP" "$README"
rm -f "$NEW_FILE"
exit 0
