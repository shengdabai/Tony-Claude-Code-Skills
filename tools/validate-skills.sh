#!/usr/bin/env bash
# Skills Validation Test Suite

set -euo pipefail

# Validates that all skills in the skills/ directory have proper structure

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# Physical path of the checkout, used to decide whether a symlink stays inside it.
REPO_REAL="$(cd -P "$REPO_DIR" && pwd -P)"
SKILLS_DIR="$REPO_DIR/skills"
# Match CI: collection roots are defined in the shared helper.
# shellcheck source=tools/skill-collections.sh
source "$REPO_DIR/tools/skill-collections.sh"
PASS=0
FAIL=0

# Resolve a path through every symlink without `readlink -f` (absent from
# macOS bash 3.2 setups). Prints the physical path and returns 0 when the
# final target exists, returns 1 when a link dangles, 2 on a symlink loop.
resolve_path() {
  local path="$1" dir base target hops=0
  while :; do
    dir="$(dirname "$path")"
    base="$(basename "$path")"
    dir="$(cd -P "$dir" 2>/dev/null && pwd -P)" || return 1
    path="$dir/$base"
    [ -L "$path" ] || break
    hops=$((hops + 1))
    [ "$hops" -le 40 ] || return 2
    target="$(readlink "$path")"
    case "$target" in
      /*) path="$target" ;;
      *) path="$dir/$target" ;;
    esac
  done
  [ -e "$path" ] || return 1
  printf '%s\n' "$path"
}

# A symlinked SKILL.md is valid only when it resolves to a regular file
# inside this checkout (issue #17). Prints the failure reason, if any.
check_skill_link() {
  local link="$1" target resolved status=0
  target="$(readlink "$link")"
  resolved="$(resolve_path "$link")" || status=$?
  if [ "$status" -eq 2 ]; then
    echo "symlink -> '$target' is a symlink loop"
  elif [ "$status" -ne 0 ]; then
    echo "symlink -> '$target' dangles (target does not exist)"
  else
    case "$resolved" in
      "$REPO_REAL"/*) ;;
      *) echo "symlink -> '$target' resolves outside the repository"; return ;;
    esac
    [ -f "$resolved" ] || echo "symlink -> '$target' is not a regular file"
  fi
}

echo "=== Tony-Claude-Code-Skills Validation ==="
echo ""

# 1. Check skills directory exists
if [ ! -d "$SKILLS_DIR" ]; then
  echo "FAIL: skills/ directory not found"
  exit 1
fi

# 2. Count and validate each skill
for skill_dir in "$SKILLS_DIR"/*/; do
  [ -d "$skill_dir" ] || continue
  skill_name=$(basename "$skill_dir")

  if is_skill_collection "$skill_name"; then
    continue
  fi

  # Symlinked SKILL.md: must resolve to a regular file inside the checkout.
  if [ -L "$skill_dir/SKILL.md" ]; then
    reason="$(check_skill_link "$skill_dir/SKILL.md")"
    if [ -n "$reason" ]; then
      echo "FAIL: $skill_name/SKILL.md $reason"
      FAIL=$((FAIL + 1))
      continue
    fi
  fi

  # Check for required files
  if [ -f "$skill_dir/SKILL.md" ]; then
    PASS=$((PASS + 1))
  else
    echo "FAIL: $skill_name missing SKILL.md"
    FAIL=$((FAIL + 1))
  fi

  # A readable linked document is sufficient; find -type f skips file symlinks.
  if [ -f "$skill_dir/SKILL.md" ] && [ ! -s "$skill_dir/SKILL.md" ]; then
    echo "FAIL: $skill_name has empty SKILL.md"
    FAIL=$((FAIL + 1))
  fi
done

# 3. Validate my-config/ structure
for dir in rules hooks agents commands scripts; do
  if [ -d "$REPO_DIR/my-config/$dir" ]; then
    PASS=$((PASS + 1))
  else
    echo "WARN: my-config/$dir not found"
  fi
done

# 4. Validate install.sh is executable or at least valid bash
if [ -f "$REPO_DIR/install.sh" ]; then
  if bash -n "$REPO_DIR/install.sh" 2>/dev/null; then
    PASS=$((PASS + 1))
  else
    echo "FAIL: install.sh has syntax errors"
    FAIL=$((FAIL + 1))
  fi
else
  echo "FAIL: install.sh not found"
  FAIL=$((FAIL + 1))
fi

# 5. Check NOTICE.md exists
if [ -f "$REPO_DIR/NOTICE.md" ]; then
  PASS=$((PASS + 1))
else
  echo "WARN: NOTICE.md not found"
fi

echo ""
echo "=== Results ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
