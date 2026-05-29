# Monitoring script for Tony-Claude-Code-Skills
# Run periodically to check skills health

#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${1:-$(pwd)}"

echo "=== Skills Health Check ==="
echo "Timestamp: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo ""

# Count skills
total_skills=$(find "$REPO_DIR/skills" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
echo "Total skills: $total_skills"

# Count rules
total_rules=$(find "$REPO_DIR/my-config/rules" -maxdepth 1 -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
echo "Total rules: $total_rules"

# Count hooks
total_hooks=$(find "$REPO_DIR/my-config/hooks" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
echo "Total hooks: $total_hooks"

# Check for skills without SKILL.md
missing_skill_md=0
for dir in "$REPO_DIR/skills"/*/; do
  [ -d "$dir" ] || continue
  if [ ! -f "$dir/SKILL.md" ]; then
    echo "WARNING: $(basename "$dir") missing SKILL.md"
    missing_skill_md=$((missing_skill_md + 1))
  fi
done

# Check for empty skills directories
empty_skills=0
for dir in "$REPO_DIR/skills"/*/; do
  [ -d "$dir" ] || continue
  file_count=$(find "$dir" -type f | wc -l | tr -d ' ')
  if [ "$file_count" -eq 0 ]; then
    echo "WARNING: $(basename "$dir") is empty"
    empty_skills=$((empty_skills + 1))
  fi
done

echo ""
echo "Issues: $((missing_skill_md + empty_skills))"
echo "  - Missing SKILL.md: $missing_skill_md"
echo "  - Empty directories: $empty_skills"

if [ "$((missing_skill_md + empty_skills))" -eq 0 ]; then
  echo "Status: HEALTHY"
else
  echo "Status: NEEDS ATTENTION"
fi
