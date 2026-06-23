# Tony-Claude-Code-Skills

320+ curated Claude Code skills, 9 agents, 39 commands, sanitized configs & a Codex bridge — auto-indexed from skills/.

## Business Context

- **Category:** AI workflow infrastructure
- **Audience:** AI builders, creators, independent developers, and small teams that want repeatable local AI workflows.
- **Repository status:** Public repository. Keep examples, docs, and issues free of credentials, private data, and machine-specific paths.
- **Topics:** agents, ai, anthropic, claude-code, codex, developer-tools, llm, mcp, prompt-engineering, skills

## What This Project Is For

- 320+ curated Claude Code skills, 9 agents, 39 commands, sanitized configs & a Codex bridge — auto-indexed from skills/.
- Package repeatable AI workflows into reusable local assets.
- Reduce one-off prompt work with versioned skills, guardrails, and handoff files.

## Where It Fits

This repository is part of a broader AI local-workbench operating model: reusable skills, local automation, auditable configuration, and repeatable delivery workflows.

## Technical Overview

- **Primary language:** HTML
- **Detected stack:** HTML, Node.js, Python project metadata, Python dependencies, Docker, Docker Compose
- **Default branch:** `main`
- **Visibility:** `PUBLIC`
- **License:** MIT License

> **License scope:** The top-level MIT LICENSE applies to `my-config/`,
> `install.sh`, and original tooling in this repo. Several vendored directories
> retain their own licenses — including top-level `opc-methodology/`
> (CC-BY-NC-SA 4.0) and various directories under `skills/` (e.g. `skills/gstack/`
> ships its own LICENSE). See `NOTICE.md` for the full attribution list and always
> defer to a subdirectory's own LICENSE where one exists.

## Repository Map

- `Dockerfile`
- `LICENSE`
- `NOTICE.md`
- `README.md`
- `SECURITY.md`
- `config`
- `install.sh`
- `mcp-servers`
- `my-config`
- `opc-methodology`
- `skills`
- `tools`

## Quick Start

This repository is a collection of Claude Code skills, agents, commands, and a
sanitized `~/.claude/` config mirror. It installs into your local `~/.claude/`
directory via `install.sh` — there is no `npm` build step for the repo itself.

```bash
# Clone, then run the installer:
bash install.sh --link    # symlink to repo — assets auto-update on `git pull` (recommended)
bash install.sh --copy    # copy independent files — no link back to the repo
bash install.sh --dry-run # preview what would change without writing anything
bash install.sh --help    # show usage
```

| Command | Purpose |
|---|---|
| `bash install.sh --link` | Symlink assets (skills, agents, commands, rules, hooks, scripts, output-styles) into `~/.claude/`; `git pull` keeps them current. Existing non-symlink dirs are skipped. |
| `bash install.sh --copy` | Copy assets into `~/.claude/` as independent files (no auto-update). |
| `bash install.sh --dry-run` | Show the planned changes without modifying anything. |

> Individual skills under `skills/` may carry their own dependencies (Node.js,
> Python, Bun, Docker). Those are per-skill and documented inside each skill's
> own directory — they are not required to install this repository.

## Operating Notes

- Keep real credentials out of the repository. Use local environment files, GitHub repository secrets, or the deployment platform secret manager.
- If a `.env.example` file exists, treat it as documentation only; never commit filled-in `.env` files.
- Before publishing screenshots, demos, or client examples, remove private names, internal paths, account IDs, and API endpoints.
- The `Repository Hygiene` workflow is a lightweight guardrail, not a replacement for product-specific tests.

## Delivery Checklist

- [ ] README describes the user, business outcome, and operating boundary.
- [ ] Setup or preview commands are current and do not rely on private machine state.
- [ ] No real secrets, private user data, or machine-local state are tracked.
- [ ] Screenshots, demos, or sample outputs are safe to share publicly when the repository is public.
- [ ] Product-specific tests or smoke checks are documented before production use.

## Roadmap

- Tighten the fastest path from clone to useful demo.
- Add project-specific screenshots, sample outputs, or a short walkthrough where useful.
- Promote repeated manual steps into scripts, tests, or documented workflows.
- Keep security, privacy, and licensing boundaries explicit as the project evolves.

## Maintainer Notes

Maintained by [Tony Sheng](https://github.com/shengdabai). This README is written as a business-facing handoff: it should help a future collaborator, client, or reviewer understand why the repository exists, how to inspect it, and what must be true before it is reused or shipped.
