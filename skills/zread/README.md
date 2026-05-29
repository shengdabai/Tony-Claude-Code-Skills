# Zread Skill

This repository contains a skill for `zread`, a CLI that generates wiki-style
documentation for code repositories.

The skill is meant for one job: help an agent understand an unfamiliar codebase
through `zread` output instead of re-reading the entire repository file by file.

## Installation

### 1. Install the zread CLI

Install `zread` first. There are two supported installation methods:

```bash
npm install -g zread_cli
```

or

```bash
brew tap ZreadAI/homebrew-tap
brew install zread
```

Then verify the installation:

```bash
zread version
```

### 2. Install this skill

Ask your AI agent to install the skill from GitHub:

```text
install this skill https://github.com/ZreadAI/zread-skill
```

If you prefer to install it manually, copy this directory into your local
skills directory:

| Agent       | Skills directory        |
| ----------- | ----------------------- |
| Claude Code | `~/.claude/skills/`   |
| OpenClaw    | `~/.openclaw/skills/` |
| Codex       | `~/.agents/skills/`   |

Example:

```bash
cp -R zread ~/.claude/skills/zread
```

Your final layout should look like this:

```text
<skills-dir>/zread/
  SKILL.md
  README.md
  references/
    stdio-protocol.md
```

Once the folder is in place, an agent that supports `SKILL.md`-based skills can
load and use it.

## Features

- Read existing `./.zread/wiki/` output instead of crawling source files again
- Guide an agent to run `zread generate` safely when documentation does not
  exist yet
- Use `--stdio` as the default mode for agent automation, instead of parsing
  the interactive TUI
- Explain the role of `current`, `versions`, and `drafts` in zread output
- Include a reference for the `zread --stdio` JSON-line protocol

## When To Use

Use this skill when you want to:

- understand an unfamiliar repository quickly
- read an existing zread-generated wiki
- generate a repository overview or project wiki
- serve docs locally with `zread browse`
- drive `zread` programmatically from a script or agent

## How It Works

The skill follows a simple workflow:

1. If `./.zread/wiki/current` exists, read the generated wiki files directly.
2. If no wiki exists, run `zread generate` only when the user wants docs to be
   generated.
3. Before generation, confirm with the user because generation consumes LLM
   tokens and writes under `./.zread/`.
4. In automated workflows, use `--stdio`.

## Repository Layout

- `SKILL.md`: the skill definition, trigger conditions, and operating rules
- `references/stdio-protocol.md`: the `zread --stdio` machine protocol
- `appmap.log`: local artifact, not part of the skill itself

## zread Output

After a successful generation, zread typically writes:

- `./.zread/wiki/current`: the active wiki version id
- `./.zread/wiki/versions/<id>/wiki.json`: the generated page index
- `./.zread/wiki/versions/<id>/<file>`: the actual markdown pages
- `./.zread/wiki/drafts/`: unfinished generation state

If you need to integrate with `zread` programmatically, see
[references/stdio-protocol.md](./references/stdio-protocol.md).
