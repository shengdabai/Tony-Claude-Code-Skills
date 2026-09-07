#!/bin/bash
# Weekly capacity report; one implementation shared with the daily storage task.
set -euo pipefail
if [[ "${1:-report}" != "report" ]]; then
  echo "Use Storage-Inbox for reviewed copy-and-backup routing. Legacy Downloads moves are retired."
  exit 2
fi
exec /Library/Frameworks/Python.framework/Versions/3.13/bin/python3 "$HOME/.local/share/storage-manager/storage_manager.py" report
