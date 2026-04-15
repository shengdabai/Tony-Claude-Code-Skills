---
name: autoresearch
description: "Autonomous ML research agent inspired by Karpathy's autoresearch. Given a training codebase, the agent runs continuous experimentation loops: modify model code, train for 5 minutes, check if val_bpb improved, keep or discard changes. Use when the user mentions 'start autoresearch', 'auto experiment', 'train agent', 'autonomous research', '自动实验', '自动训练', '自动优化模型'."
---

# Autoresearch — Autonomous ML Research Agent

## Overview

Karpathy's autoresearch gives an AI agent a small but real LLM training setup and lets it experiment autonomously. The agent modifies code, trains, checks results, keeps or discards changes, and repeats indefinitely.

## Files

- **`prepare.py`** — Fixed constants, data prep, tokenizer, dataloader, evaluation. Do NOT modify.
- **`train.py`** — The single file the agent edits. Model architecture, optimizer, training loop.
- **`program.md`** — Full agent instructions for the autonomous research loop (read this to understand how to run).

## How to Use

1. Read `program.md` for the complete autonomous research workflow
2. Set up the environment (NVIDIA GPU, Python 3.10+, uv)
3. Run `uv sync` and `uv run prepare.py` to prepare data
4. Start the autonomous loop — read `program.md` and follow the experiment loop instructions
5. Let it run — the agent should NEVER stop on its own

## Key Constraints

- Only modify `train.py` — never `prepare.py`
- Each experiment runs for exactly 5 minutes (fixed time budget)
- Log results to `results.tsv` (tab-separated)
- Keep only improvements (lower val_bpb), discard regressions
- Use git branches (`autoresearch/<tag>`) for experiment isolation

## Reference

See `program.md` for the complete workflow including setup, experimentation loop, output format, and logging.
