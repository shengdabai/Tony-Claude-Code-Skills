#!/bin/bash
# Log rotate hook — runs occasionally (Stop event).
# Cleans .omc/logs/ files older than 7 days to prevent unbounded growth.
# Idempotent and safe: only deletes plain files, never directories.

LOG_DIR="$HOME/.omc/logs"
[ ! -d "$LOG_DIR" ] && exit 0

# Delete files in .omc/logs older than 7 days (last modified)
find "$LOG_DIR" -maxdepth 2 -type f -mtime +7 -delete 2>/dev/null

# Also rotate huge single files (>5MB → keep only last 1000 lines)
find "$LOG_DIR" -maxdepth 2 -type f -size +5M 2>/dev/null | while read -r big_file; do
  tail -n 1000 "$big_file" > "${big_file}.tmp" && mv "${big_file}.tmp" "$big_file"
done

exit 0
