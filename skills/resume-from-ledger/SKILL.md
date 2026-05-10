---
name: resume-from-ledger
description: Resume an interrupted multi-step task by reading a TODO ledger from .omc/plans/. Use when the user says "continue", "resume", "pick up where we left off", or references a prior session that was cut off by usage limits.
---

# Resume From Ledger

Recover from interrupted long-running tasks by reading the persistent TODO ledger. Pairs with the `session-resilience` rule.

## When to Trigger

User says any of:
- "continue [the] audit/refactor/migration"
- "resume [from where we left off]"
- "pick up the X task"
- "what's left on X"
- References a task that hit usage limits

## Procedure

### Step 1: Locate ledger
```bash
ls -lt ~/.omc/plans/*-todo.md 2>/dev/null | head -10
```
If multiple, ask user which task. If one obvious match, confirm before proceeding.

### Step 2: Parse ledger
- Count `[x]` (done), `[ ]` (pending), `[!]` (failed)
- Identify next pending item

### Step 3: Status report (BEFORE doing work)
```
Resuming: <task name>
Done: M / N items
Failed: K items (will retry: yes/no)
Next: item-X (<description>)
```
Wait for user "go" / "skip failures" / "retry K first".

### Step 4: Execute next batch
Follow the rules in `rules/session-resilience.md`:
- Max 3-5 items per batch
- Mark `[x]` immediately after each item
- Mark `[!]` for failures with reason
- Stop after batch, report progress, await go-ahead for next batch

## Failure Recovery

If item-X failed previously:
1. Read its previous attempt notes (in ledger or /tmp/)
2. Diagnose root cause
3. Propose new approach
4. Confirm with user before retrying

## Anti-Patterns

- ❌ Re-running already-done `[x]` items (wastes tokens)
- ❌ Re-planning from scratch (defeats the ledger's purpose)
- ❌ Skipping the status report (user loses visibility)
- ❌ Auto-retrying failed items without diagnosis
