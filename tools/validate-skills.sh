#!/usr/bin/env bash
# Skills Validation Test Suite

set -euo pipefail

# Validates that all skills in the skills/ directory have proper structure

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="$REPO_DIR/skills"
# Match CI: collection roots are defined in the shared helper.
# shellcheck source=tools/skill-collections.sh
source "$REPO_DIR/tools/skill-collections.sh"
PASS=0
FAIL=0

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
