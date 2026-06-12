#!/bin/bash
# Periodic index refresh (launched by launchd StartInterval, every 60s).
# Single full scan of the 4 main Desktop folders, then exit. No long-running
# process, no event capture — just a guaranteed eventual-consistency sweep that
# catches any Finder change (add/move/delete/rename) within ~60s.
#
# Claude-session changes are handled faster by the PostToolUse/Stop/SessionStart
# hooks; this poller is the Finder-side backstop.

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
bash "$HOME/.claude/hooks/update-desktop-index.sh" >/dev/null 2>&1
exit 0
