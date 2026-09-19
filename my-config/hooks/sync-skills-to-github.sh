#!/bin/bash
# Legacy automatic publication is retired after a session-export credential leak.
# A clean index does not prove that outgoing Git history is safe to publish.
# This hook intentionally performs no sync, staging, commit, or push.
# For a reviewed manual change, stage explicit paths and run:
#   python3 scripts/check-public-content.py
# Review outgoing history and obtain publication authorization separately.
exit 0
