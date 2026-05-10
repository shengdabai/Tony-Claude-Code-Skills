---
name: audit-projects
description: Portfolio-wide code audit across multiple repos with ledger-based resumption. Use when the user wants to audit, review, or fix bugs across 3+ projects in parallel. Generates a TODO ledger first (cheap), then executes per-repo sub-agents in batches that survive usage-limit interruptions.
---

# Portfolio Audit Skill

Solve the recurring "16+ project audit cut off mid-sweep" problem from /insights. Splits into plan-phase (resumable) + execute-phase (batched).

## Phase 1: Plan (always run first)

1. Confirm scope with user: which directory? (default `~/Desktop` or `~/programming`)
2. List repos:
   ```bash
   find <root> -maxdepth 2 -name .git -type d | xargs -I{} dirname {}
   ```
3. For each repo, capture metadata (parallel sub-agents OK):
   - Primary language
   - Test framework (or "none")
   - Last commit date
   - Open issue count (if gh available)
4. Write ledger to `.omc/plans/audit-<YYYYMMDD>-todo.md`:
   ```markdown
   # Portfolio Audit <date>
   - [ ] repo-a: scan only — write findings to /tmp/audit-repo-a.md
   - [ ] repo-b: scan only
   ...
   ```
5. **STOP**. Show user the ledger. Get explicit go-ahead before Phase 2.

## Phase 2: Execute (batched, resumable)

1. Read ledger
2. Process **at most 4 repos per batch** (parallel sub-agents)
3. Each sub-agent:
   - Reads its repo
   - Writes findings to `/tmp/audit-<repo>.md` (top 3 issues, severity, file:line)
   - Returns ≤ 3-line summary to main agent
   - Does NOT fix anything
4. After each batch, mark items `[x]` in ledger
5. If usage limit hits → ledger preserves progress

## Phase 3: Resume (auto-detect on next session)

If user says "continue audit" or "resume" → read latest ledger, skip `[x]` items, continue from next `[ ]`.

## Phase 4: Consolidate (after all items done)

Aggregate `/tmp/audit-*.md` into one executive summary:
- Health ranking (worst → best)
- Common issues across repos
- Recommended fix priority
- Estimated effort

## Anti-Patterns (do not do these)

- ❌ Auto-fix during scan phase
- ❌ Run all repos in one batch (kills context)
- ❌ Skip ledger because "user is in a hurry"
- ❌ Lose findings by not writing to /tmp
