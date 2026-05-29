---
description: Start session by loading context from CLAUDE.md + recent session logs
model: opus
allowed-tools: Read, Glob, Bash
---

# /resume - Resume Work with Full Context

Quickly get up to speed by reading CLAUDE.md AND recent session logs. Supports topic-based search for relevant past sessions.

**Usage:**
- `/resume`: Load CLAUDE.md + last 3 session summaries
- `/resume 5`: Load CLAUDE.md + last 5 session summaries
- `/resume auth`: Load CLAUDE.md + last 3 + search for "auth" related sessions
- `/resume 10 migration`: Load CLAUDE.md + last 10 + search for "migration"

## Instructions for Claude

### Step 1: Parse Arguments

Check if user provided arguments:
- **Number (N):** How many recent sessions to read (default: 3, max: 50)
- **Topic keyword:** Search for related sessions beyond the last N

Examples:
- `/resume` -> N=3, no topic search
- `/resume 5` -> N=5, no topic search
- `/resume auth` -> N=3, topic="auth"
- `/resume 10 jira` -> N=10, topic="jira"

### Step 2: Find and Read CLAUDE.md

Search for project memory file:
- `CLAUDE.md`
- `Claude.md`
- `.claude/CLAUDE.md`
- `docs/CLAUDE.md`

Read and extract:
- Project name/purpose
- Current phase/status
- Key paths and references
- Recent decisions
- Blockers
- Next steps

### Step 3: Find Session Logs

**Detect project root:**
```
1. Get current working directory (pwd)
2. Find project root: walk up from pwd looking for CLAUDE.md or .git
3. If found: project_root = that directory
4. If not found: project_root = pwd
5. Session logs path: {project_root}/CC-Session-Logs/
```

**List and count session logs:**
```bash
ls -1 "{project_root}/CC-Session-Logs/"*.md 2>/dev/null | wc -l
```

### Step 4: Read Session Summaries (Scaling Logic)

**IF session logs < 100:**
1. List all session log files, sorted by filename (newest first)
2. Read the SUMMARY ONLY (everything BEFORE "## Raw Session Log") for the last N files
3. If topic keyword provided, also scan all summaries for keyword matches

**IF session logs >= 100:**
1. Read last N session summaries directly
2. For topic matching, use grep to search through session logs:
   ```bash
   grep -rl "{topic keyword}" "{project_root}/CC-Session-Logs/"*.md
   ```
3. Read summaries of top 5 topic-matched results (if not already in last N)

**IMPORTANT: Only read up to "## Raw Session Log".** Do NOT read the full raw conversation to save tokens. The summary contains the "Quick Reference" keywords needed for context.

### Step 5: Extract Key Information

From each session summary, extract:
- **Date and topic** (from filename and title)
- **Confidence keywords** (from Quick Reference section)
- **Projects referenced** (from Quick Reference section)
- **Outcome** (from Quick Reference section)
- **Key decisions** (if present)
- **Pending tasks** (if present)

### Step 6: Topic Search (If Keyword Provided)

If user provided a topic keyword:

1. **For <100 logs:** Grep through summaries for keyword matches
2. **For >=100 logs:** Use grep to search session logs

Find sessions where:
- Topic name contains keyword
- Confidence keywords contain keyword
- Projects contain keyword
- Content mentions keyword

Add matched sessions to the output (mark them as "RELATED SESSIONS").

### Step 7: Output Combined Report

```
══════════════════════════════════════════════
 RESUMING: {Project Name}
══════════════════════════════════════════════

PHASE: {Current phase}, {Status}

CONTEXT:
- {Key insight from CLAUDE.md}
- {What was last worked on}
- {Important project state}

EXISTS:
- {Key directories/files that matter}

BLOCKERS:
- {Any blockers, or "None"}

══════════════════════════════════════════════
 MOST RECENT SESSION: {DD-MM-YYYY HH:MM}
 Topic: {Topic Name}
══════════════════════════════════════════════

**Keywords:** {confidence keywords}
**Projects:** {projects referenced}
**Outcome:** {outcome summary}

**Key Points:**
- {Decision or learning 1}
- {Decision or learning 2}
- {Pending task if any}

══════════════════════════════════════════════
 PREVIOUS SESSIONS ({N-1} more)
══════════════════════════════════════════════

- {DD-MM-YYYY}: {Topic}, {Outcome snippet}
- {DD-MM-YYYY}: {Topic}, {Outcome snippet}
- {DD-MM-YYYY}: {Topic}, {Outcome snippet}

{If topic search was performed:}
══════════════════════════════════════════════
 RELATED SESSIONS (Topic: "{keyword}")
══════════════════════════════════════════════

- {DD-MM-YYYY}: {Topic}, {Why it matched}
- {DD-MM-YYYY}: {Topic}, {Why it matched}

══════════════════════════════════════════════
 READY TO:
══════════════════════════════════════════════

- {Next step from CLAUDE.md}
- {Pending task from recent session}
- {Additional next steps}

══════════════════════════════════════════════
```

### Step 8: Handle Edge Cases

**If no CLAUDE.md found:**
```
No CLAUDE.md found in this project.

Options:
1. Tell me about this project and I'll help create one
2. Just start working and run /preserve later

What would you like to do?
```

**If no session logs exist (0 files or folder doesn't exist):**
- Skip the session logs sections entirely
- Just show CLAUDE.md context
- Note: "No session logs yet. Run /preserve and/or /compress before /compact to start building session history."

**If fewer than N session logs exist:**
- Read all available logs
- Note: "Found {X} session logs (requested {N})"

---

## Session Summary Reading Pattern

When reading a session log, STOP at "## Raw Session Log":

```python
# Pseudocode for reading summary only
content = read_file(session_log_path)
summary_end = content.find("## Raw Session Log")
if summary_end > 0:
    summary = content[:summary_end]
else:
    summary = content  # No raw log section, read all
```

This ensures we get context without consuming tokens on the full conversation archive.

---

## Filename Parsing

Session log filenames follow: `DD-MM-YYYY-HH_MM-topic-name.md`

Parse to extract:
- **Date:** `DD-MM-YYYY`
- **Time:** `HH:MM` (replace _ with :)
- **Topic:** Everything after the time, with hyphens replaced by spaces

Example: `05-03-2026-17_30-api-auth-refactor.md`
- Date: 05-03-2026
- Time: 17:30
- Topic: api auth refactor

---

## Performance Notes

- **Default N=3:** Keeps token usage low while providing recent context
- **Max N=50:** Reasonable upper limit for summary scanning
- **Summary-only reading:** Critical for token efficiency, never read raw logs in /resume
- **Grep search:** Lightweight and available everywhere, no external dependencies needed
