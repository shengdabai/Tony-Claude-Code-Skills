---
name: geo
description: Route GEO and generative engine optimization requests to an available GEOHub capability. Use for broad GEO requests, GEOHub workflow selection, capability checks, or requests spanning discovery, brand/site/page diagnosis, content, strategy, knowledge, publishing, and measurement.
---

# GEOHub

## Workflow

1. Read `references/providers/geo/routing-contract.md` and the suite resolver contract at `references/providers/geo/RESOLVER.md`.
2. Run the deterministic `.venv/bin/python scripts/run_route.py --text "<request>"` wrapper from the GEOHub Skill directory.
3. Dispatch only when the JSON result has 'runnable: true' and a non-null 'entry'.
4. For 'pending-implementation' or 'planned', return the registry status and suggested available route exactly as reported.

## Output contract

Return the selected skill ID, lifecycle status, runnable flag, reason, entry path, suggestion, and optional stable workflow DAG. Preserve uncertainty when two routes have the same score.

## Boundaries

This skill selects capabilities. It does not generate discovery artifacts or simulate unavailable stages.
