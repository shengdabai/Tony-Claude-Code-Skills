---
name: dependency-guard
description: Dependency security & health audit across npm/Python/Go/Ruby/Java/Rust/PHP. Use when the user mentions dependency vulnerabilities, CVE scan, npm audit, outdated packages, license compliance, supply-chain / typosquatting risk, bundle-size bloat, or asks to audit / update / harden project dependencies. Produces a prioritized remediation plan with severity ratings and update PR scaffolding.
---

# Dependency Guard

Comprehensive dependency security and health auditing. Scans known vulnerabilities (CVE),
license compatibility, outdated packages, supply-chain risk (typosquatting / maintainer
changes), and bundle-size impact — then produces a prioritized, actionable remediation plan.

## When to use

- "扫一下依赖有没有安全漏洞" / "npm audit 报了一堆 CVE"
- "这些依赖过时了吗 / 该升级哪些"
- "license 合规检查" / "有没有 GPL 污染"
- "供应链安全 / typosquatting / 包被劫持"
- "依赖体积太大 / bundle size 优化"
- 发布前依赖体检 / 加固

## Workflow

1. **Discover** — inventory all dependency manifests (package.json, requirements.txt,
   go.mod, Cargo.toml, pom.xml, Gemfile, composer.json…), build the dependency tree.
2. **Vulnerability scan** — check each package against CVE/advisory databases; rate
   severity (critical/high/moderate/low) and compute a risk score.
3. **License compliance** — flag incompatible (e.g. GPL-in-MIT) and unknown licenses.
4. **Outdated analysis** — find stale packages, prioritize by security > age > releases-behind.
5. **Supply-chain checks** — typosquatting (Levenshtein vs popular names), maintainer
   changes, suspicious install scripts.
6. **Size impact** — flag oversized packages, suggest lighter alternatives / lazy-load.
7. **Remediation** — generate safe update commands (with test gate + auto-revert) and a
   ready-to-open update PR body.

## Output

Executive summary → vulnerability report → license matrix → prioritized updates →
supply-chain findings → remediation scripts → size report → optional CI monitoring workflow.

## Reference

Full multi-language detection code, scanner logic, license tables, and PR/CI templates
live in `reference.md` — read it when you need the concrete implementation patterns.

## Notes for this environment

- Prefer running the actual ecosystem tools when available: `npm audit --json`,
  `pip-audit` / `safety`, `osv-scanner`, `govulncheck`, `cargo audit`. The reference
  code shows the API shapes; real CLI output is more authoritative.
- Never auto-run `npm audit fix --force` without a test gate — it can introduce breaking
  major bumps. Always propose, run tests, revert on failure.
