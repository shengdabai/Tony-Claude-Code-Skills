#!/bin/sh
set -eu

CLAUDE_HOME="$HOME/.claude"
SETTINGS="$CLAUDE_HOME/settings.json"
PROFILE_DIR="$CLAUDE_HOME/profiles"
STATE_ROOT="$HOME/.config/ai-profiles"
BACKUP_ROOT="$STATE_ROOT/backups"

usage() {
  printf 'Use:\n'
  printf '  claude-profile.sh list\n'
  printf '  claude-profile.sh apply [fast|delivery|deep] [--dry-run]\n'
  printf '  claude-profile.sh [fast|delivery|deep]          # shortcut for apply\n'
  printf '  claude-profile.sh rollback --last\n'
}

list_profiles() {
  printf 'Available Claude profiles:\n'
  printf '  fast     low effort, thinking off, autoCompact on\n'
  printf '  delivery high effort, thinking on, autoCompact on\n'
  printf '  deep     xhigh effort, thinking on, autoDream on\n'
}

sha256_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

ACTION="${1:-list}"
shift 2>/dev/null || true

case "$ACTION" in
  fast|delivery|deep)
    PROFILE="$ACTION"
    ACTION="apply"
    ;;
  list|"")
    list_profiles
    exit 0
    ;;
  apply)
    PROFILE="${1:-}"
    [ -n "$PROFILE" ] || { usage >&2; exit 2; }
    shift 2>/dev/null || true
    ;;
  rollback)
    if [ "${1:-}" != "--last" ]; then
      usage >&2
      exit 2
    fi
    latest="$(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -1)"
    [ -n "$latest" ] && [ -f "$latest/settings.json" ] || { printf 'No rollback backup found.\n' >&2; exit 1; }
    cp "$SETTINGS" "$latest/settings.before-rollback.json"
    cp "$latest/settings.json" "$SETTINGS"
    printf 'Rolled back Claude settings from: %s/settings.json\n' "$latest"
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

case "$PROFILE" in
  fast|delivery|deep) ;;
  *)
    printf 'Unknown profile: %s\n' "$PROFILE" >&2
    usage >&2
    exit 2
    ;;
esac

DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    *) printf 'Unknown option: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

PROFILE_FILE="$PROFILE_DIR/$PROFILE.settings.json"
[ -f "$PROFILE_FILE" ] || { printf 'Missing profile file: %s\n' "$PROFILE_FILE" >&2; exit 1; }

tmp="$(mktemp /tmp/claude-profile.XXXXXX.json)"
trap 'rm -f "$tmp"' EXIT

/usr/bin/python3 - "$SETTINGS" "$PROFILE_FILE" "$PROFILE" "$tmp" <<'PY'
import json
import pathlib
import sys
from datetime import datetime, timezone

settings_path = pathlib.Path(sys.argv[1])
profile_path = pathlib.Path(sys.argv[2])
profile_name = sys.argv[3]
out_path = pathlib.Path(sys.argv[4])

settings = json.loads(settings_path.read_text())
profile = json.loads(profile_path.read_text())
updates = profile["settings"]

allowed = {"alwaysThinkingEnabled", "effortLevel", "autoDreamEnabled", "autoCompact"}
unknown = set(updates) - allowed
if unknown:
    raise SystemExit(f"profile contains unsupported keys: {sorted(unknown)}")

before = {key: settings.get(key) for key in sorted(allowed)}
settings.update(updates)
settings["_activeProfile"] = profile_name
settings["_activeProfileUpdatedAt"] = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
after = {key: settings.get(key) for key in sorted(allowed)}

out_path.write_text(json.dumps(settings, ensure_ascii=False, indent=2) + "\n")
print(json.dumps({"profile": profile_name, "before": before, "after": after}, ensure_ascii=False, indent=2))
PY

before_hash="$(sha256_file "$SETTINGS")"
after_hash="$(sha256_file "$tmp")"

if [ "$DRY_RUN" = true ]; then
  printf 'DRY_RUN only. No files changed.\n'
  printf 'before_sha256=%s\n' "$before_hash"
  printf 'after_sha256=%s\n' "$after_hash"
  exit 0
fi

ts="$(date +%Y%m%d-%H%M%S)"
backup_dir="$BACKUP_ROOT/$ts"
mkdir -p "$backup_dir"
cp "$SETTINGS" "$backup_dir/settings.json"
cp "$PROFILE_FILE" "$backup_dir/profile.settings.json"
cp "$tmp" "$SETTINGS"

/usr/bin/python3 - "$backup_dir/manifest.json" "$PROFILE" "$before_hash" "$after_hash" "$SETTINGS" "$PROFILE_FILE" <<'PY'
import json
import pathlib
import sys
from datetime import datetime, timezone

manifest_path = pathlib.Path(sys.argv[1])
payload = {
    "tool": "claude-profile.sh",
    "profile": sys.argv[2],
    "updatedAt": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "files": {
        "settings": {
            "path": sys.argv[5],
            "beforeSha256": sys.argv[3],
            "afterSha256": sys.argv[4],
        },
        "profile": {
            "path": sys.argv[6],
        },
    },
    "rollback": "$HOME/.claude/scripts/claude-profile.sh rollback --last",
}
manifest_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
PY

printf 'Applied Claude profile: %s\n' "$PROFILE"
printf 'Backup: %s/settings.json\n' "$backup_dir"
printf 'Manifest: %s/manifest.json\n' "$backup_dir"
