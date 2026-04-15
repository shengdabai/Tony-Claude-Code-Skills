# NLPM Audit: tech-leads-club/agent-skills
**Date**: 2026-04-07  |  **Artifacts**: 78  |  **Strategy**: progressive
**NL Score**: 93/100
**Security**: CLEAR
**Bugs**: 1  |  **Quality Issues**: 34  |  **Security Findings**: 5

## NL Score Summary
| File | Type | Score | Top Issue |
|------|------|-------|-----------|
| `(security)/security-best-practices/SKILL.md` | skill | 70 | Vague x10 (-20 cap) + no output format section (-10) |
| `(development)/codenavi/SKILL.md` | skill | 80 | Vague x11 (-20 cap): "appropriate", "leverages", "ensure", "comprehensive" |
| `(creation)/cursor-subagent-creator/SKILL.md` | skill | 80 | Vague x11 (-20 cap): "relevant", "appropriate", "ensure", "comprehensive" |
| `(tooling)/nx-run-tasks/SKILL.md` | skill | 81 | Vague x7 (-14) + no formal output format section (-5) |
| `(cloud)/render-deploy/SKILL.md` | skill | 82 | Vague x4 (-8) + no examples/output section (-10) |
| `(tooling)/nx-generate/SKILL.md` | skill | 83 | Vague x6 (-12) + no output format section (-5) |
| `(cloud)/aws-advisor/SKILL.md` | skill | 85 | Vague x5 (-10) + no formal output section (-5) |
| `(creation)/create-technical-design-doc/SKILL.md` | skill | 86 | Vague x7 (-14): "appropriate", "relevant", "comprehensive", "ensure" |
| `(tooling)/mermaid-studio/SKILL.md` | skill | 86 | Vague x7 (-14): "appropriate", "relevant", "ensure", "various" |
| `(development)/docs-writer/SKILL.md` | skill | 87 | Vague x4 (-8) + no output format section (-5) |
| `(quality)/seo/SKILL.md` | skill | 87 | Vague x4 (-8) + no output format section (-5) |
| `(gtm)/solo-founder-gtm/SKILL.md` | skill | 88 | Vague x6 (-12): "appropriate", "relevant", "ensure", "various" |
| `(development)/confluence-assistant/SKILL.md` | skill | 88 | Vague x6 (-12): "relevant", "appropriate", "ensure" |
| `(architecture)/frontend-blueprint/SKILL.md` | skill | 88 | Vague x6 (-12): "appropriate", "relevant", "several", "proper" |
| `(architecture)/coupling-analysis/SKILL.md` | skill | 89 | Vague x3 (-6) + no output format section (-5) |
| `(quality)/web-best-practices/SKILL.md` | skill | 89 | Vague x3 (-6) + no output format section (-5) |
| `(web-automation)/playwright-skill/SKILL.md` | skill | 90 | Vague x5 (-10): "appropriate", "relevant", "robust", "various" |
| `(gtm)/gtm-metrics/SKILL.md` | skill | 90 | Vague x5 (-10): "relevant", "appropriate", "ensure" |
| `(gtm)/ai-cold-outreach/SKILL.md` | skill | 90 | Vague x5 (-10): "relevant", "appropriate", "comprehensive" |
| `(development)/gh-address-comments/SKILL.md` | skill | 90 | No output format section (-10) |
| `(learning)/learning-opportunities/SKILL.md` | skill | 90 | No output format section (-10) |
| `mcp/.claude-plugin/plugin.json` | plugin | 90 | Missing `version` field (bug -10) |
| `(tooling)/excalidraw-studio/SKILL.md` | skill | 91 | Vague x2 (-4) + no output format section (-5) |
| `(quality)/web-accessibility/SKILL.md` | skill | 91 | Vague x2 (-4) + no output format section (-5) |
| `(cloud)/netlify-deploy/SKILL.md` | skill | 92 | Vague x4 (-8): "appropriate", "relevant", "ensure" |
| `(gtm)/ai-sdr/SKILL.md` | skill | 92 | Vague x4 (-8): "relevant", "appropriate", "ensure" |
| `(gtm)/social-selling/SKILL.md` | skill | 92 | Vague x4 (-8): "relevant", "appropriate", "comprehensive" |
| `(gtm)/expansion-retention/SKILL.md` | skill | 92 | Vague x4 (-8): "relevant", "ensure", "appropriate" |
| `(architecture)/domain-identification-grouping/SKILL.md` | skill | 92 | Vague x4 (-8): "relevant", "ensure", "appropriate" |
| `(creation)/subagent-creator/SKILL.md` | skill | 92 | Vague x4 (-8): "relevant", "appropriate", "comprehensive" |
| `(cloud)/cloudflare-deploy/SKILL.md` | skill | 93 | Vague x1 (-2) + no formal output section (-5) |
| `(architecture)/react-composition-patterns/SKILL.md` | skill | 93 | Vague x1 (-2) + no output format section (-5) |
| `(performance)/core-web-vitals/SKILL.md` | skill | 93 | Vague x1 (-2) + no output format section (-5) |
| `(design)/figma/SKILL.md` | skill | 93 | Vague x1 (-2) + no output format section (-5) |
| `(security)/security-threat-model/SKILL.md` | skill | 93 | Vague x1 (-2) + no output format section (-5) |
| `(tooling)/gh-fix-ci/SKILL.md` | skill | 93 | Vague x1 (-2) + no output format section (-5) |
| `(tooling)/chrome-devtools/SKILL.md` | skill | 93 | Vague x1 (-2) + no output format section (-5) |
| `(quality)/web-quality-audit/SKILL.md` | skill | 93 | Vague x1 (-2) + no formal output section (-5) |
| `(quality)/react-best-practices/SKILL.md` | skill | 93 | Vague x1 (-2) + no output format section (-5) |
| `(gtm)/multi-platform-launch/SKILL.md` | skill | 94 | Vague x3 (-6): "relevant", "appropriate", "comprehensive" |
| `(gtm)/paid-creative-ai/SKILL.md` | skill | 94 | Vague x3 (-6): "relevant", "appropriate", "ensure" |
| `(gtm)/positioning-icp/SKILL.md` | skill | 94 | Vague x3 (-6): "relevant", "appropriate", "ensure" |
| `(gtm)/content-to-pipeline/SKILL.md` | skill | 94 | Vague x3 (-6): "relevant", "appropriate", "comprehensive" |
| `(development)/jira-assistant/SKILL.md` | skill | 94 | Vague x3 (-6): "relevant", "appropriate", "ensure" |
| `(architecture)/legacy-migration-planner/SKILL.md` | skill | 94 | Vague x3 (-6): "relevant", "appropriate", "proper" |
| `(design)/figma-implement-design/SKILL.md` | skill | 94 | Vague x3 (-6): "relevant", "appropriate", "ensure" |
| `(creation)/create-adr/SKILL.md` | skill | 94 | Vague x3 (-6): "relevant", "appropriate", "ensure" |
| `(creation)/skill-architect/SKILL.md` | skill | 94 | Vague x3 (-6): "relevant", "appropriate", "proper" |
| `(development)/shopify-developer/SKILL.md` | skill | 95 | No output format section (-5) |
| `(development)/coding-guidelines/SKILL.md` | skill | 95 | No output format section (-5) |
| `(performance)/perf-web-optimization/SKILL.md` | skill | 95 | No output format section (-5) |
| `(performance)/perf-lighthouse/SKILL.md` | skill | 95 | No output format section (-5) |
| `(performance)/perf-astro/SKILL.md` | skill | 95 | No output format section (-5) |
| `(tooling)/nx-workspace/SKILL.md` | skill | 95 | No output format section (-5) |
| `(gtm)/video-outreach/SKILL.md` | skill | 96 | Vague x2 (-4): "relevant", "appropriate" |
| `(gtm)/gtm-engineering/SKILL.md` | skill | 96 | Vague x2 (-4): "relevant", "appropriate" |
| `(development)/react-native-expert/SKILL.md` | skill | 96 | Vague x2 (-4): "relevant", "appropriate" |
| `(development)/nestjs-modular-monolith/SKILL.md` | skill | 96 | Vague x2 (-4): "relevant", "comprehensive" |
| `(decision-making)/the-fool/SKILL.md` | skill | 96 | Vague x2 (-4): "relevant", "appropriate" |
| `(architecture)/component-identification-sizing/SKILL.md` | skill | 96 | Vague x2 (-4): "relevant", "comprehensive" |
| `(design)/web-design-guidelines/SKILL.md` | skill | 96 | Vague x2 (-4): "relevant", "appropriate" |
| `(design)/frontend-design/SKILL.md` | skill | 96 | Vague x2 (-4): "relevant", "appropriate" |
| `(creation)/create-rfc/SKILL.md` | skill | 96 | Vague x2 (-4): "relevant", "appropriate" |
| `(tooling)/nx-ci-monitor/SKILL.md` | skill | 96 | Vague x2 (-4): "relevant", "ensure" |
| `(cloud)/vercel-deploy/SKILL.md` | skill | 98 | Vague x1 (-2): "appropriate" |
| `(gtm)/ai-seo/SKILL.md` | skill | 98 | Vague x1 (-2): "relevant" |
| `(gtm)/ai-ugc-ads/SKILL.md` | skill | 98 | Vague x1 (-2): "appropriate" |
| `(gtm)/lead-enrichment/SKILL.md` | skill | 98 | Vague x1 (-2): "relevant" |
| `(development)/tlc-spec-driven/SKILL.md` | skill | 98 | Vague x1 (-2): "relevant" |
| `(architecture)/component-flattening-analysis/SKILL.md` | skill | 98 | Vague x1 (-2): "appropriate" |
| `(security)/security-ownership-map/SKILL.md` | skill | 98 | Vague x1 (-2): "relevant" |
| `(monitoring)/sentry/SKILL.md` | skill | 100 | Clean |
| `(gtm)/ai-pricing/SKILL.md` | skill | 100 | Clean |
| `(gtm)/partner-affiliate/SKILL.md` | skill | 100 | Clean |
| `(gtm)/sales-motion-design/SKILL.md` | skill | 100 | Clean |
| `(architecture)/domain-analysis/SKILL.md` | skill | 100 | Clean |
| `(architecture)/decomposition-planning-roadmap/SKILL.md` | skill | 100 | Clean |
| `(architecture)/component-common-domain-detection/SKILL.md` | skill | 100 | Clean |

## Security Scan
| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 0 |
| Medium | 2 |
| Low | 3 |

### Execution Surface Inventory
| Surface | Files |
|---------|-------|
| Hooks | 0 |
| Shell scripts (.sh) | 4 (`vercel-deploy/scripts/deploy.sh`, `nestjs-modular-monolith/scripts/validate-isolation.sh`, `web-quality-audit/scripts/analyze.sh`, `mermaid-studio/scripts/setup.sh`) |
| Python scripts (.py) | 16 (`aws-advisor/scripts/*.py` ×5, `skill-architect/scripts/validate_skill.py`, `gh-address-comments/scripts/fetch_comments.py`, `sentry/scripts/sentry_api.py`, `security-ownership-map/scripts/*.py` ×4, `excalidraw-studio/scripts/*.py` ×3, `gh-fix-ci/scripts/inspect_pr_checks.py`) |
| JavaScript scripts (.js) | 4 (`playwright-skill/run.js`, `playwright-skill/lib/helpers.js`, `eslint.config.js`, `jest.preset.js`) |
| MCP configs (.mcp.json) | 0 |
| Package manifests (package.json) | 8 (root + 7 package-level) |

### Security Findings
| # | Severity | File | Line | Pattern | Description |
|---|----------|------|------|---------|-------------|
| 1 | Medium | `playwright-skill/SKILL.md` | ~118 | Inline code execution | The "Inline Execution (Simple Tasks)" section instructs passing raw user-supplied code strings directly to `node run.js "..."` via shell argument. Content from arbitrary websites could inject shell metacharacters if piped unsafely. Mitigated by the file's own `SECURITY WARNING` notice; risk is design-inherent. |
| 2 | Medium | `playwright-skill/run.js` | 1–80 | Dynamic script loading | Writes caller-supplied code to `/tmp/.temp-execution-{timestamp}.js` then `require()`s it. This is the skill's intentional design but creates an arbitrary code execution surface if input is attacker-controlled. No sandbox or allowlist. |
| 3 | Low | `playwright-skill/lib/helpers.js` | ~80 | Browser sandbox downgrade | Launches Chromium with `--no-sandbox` and `--disable-setuid-sandbox` flags. Reduces browser isolation; relevant if the automation navigates attacker-controlled URLs. |
| 4 | Low | `vercel-deploy/scripts/deploy.sh` | ~50 | External network call | `curl` POST to `https://deploy-skills.vercel.sh` during deployments. Third-party server dependency for deployment flow. HTTPS verified; no credentials forwarded beyond what vercel CLI manages. |
| 5 | Low | `packages/cli/package.json` | ~7 | postbuild chmod | `"postbuild": "chmod +x dist/index.js"` executes unconditionally after build. Safe in isolation but widens executable surface of the CLI entry point. |

## Bugs (PR-worthy)
| # | File | Issue | Impact |
|---|------|-------|--------|
| 1 | `packages/mcp/.claude-plugin/plugin.json` | Missing `version` field — plugin manifest has `name`, `description`, `author` but no `version`. The Claude Code plugin registry requires `version` for install, update, and conflict resolution. | Plugin may fail to install or upgrade correctly; registry deduplication is broken without a version key. |

## Security Fixes (PR-worthy, Medium/Low only)
| # | File | Issue | Suggested Fix |
|---|------|-------|---------------|
| 1 | `playwright-skill/SKILL.md` | Inline execution section lacks input sanitization guidance | Add a note in the "Inline Execution" section warning that code strings should never be constructed from external web content or unsanitized user input. Reference the existing `SECURITY WARNING` block. |
| 2 | `playwright-skill/lib/helpers.js` | `--no-sandbox` flag reduces browser isolation | Document why `--no-sandbox` is required (common in CI/Docker environments). Add a conditional: only pass the flag when `process.env.PLAYWRIGHT_NO_SANDBOX` is set, restoring the sandbox for local interactive use. |
| 3 | `vercel-deploy/scripts/deploy.sh` | Hard-coded external deploy server URL | Pin to a content-hash or version-tagged URL, or move the URL to an environment variable so operators can point to an internal mirror. |
| 4 | `packages/cli/package.json` | Unconditional `postbuild chmod +x` | Scope to the CLI binary only: `chmod +x dist/index.js` is already specific, but verify no glob expansion could catch unintended files if dist layout changes. |

## Quality Issues (informational)
| # | File | Issue | Penalty |
|---|------|-------|---------|
| 1 | `(security)/security-best-practices/SKILL.md` | High vague-term density (10 matches: "appropriate", "relevant", "ensure", "comprehensive", "effective", "best practices", "leverages", "utilize", "optimal", "robust") | -20 (cap) |
| 2 | `(security)/security-best-practices/SKILL.md` | No output format section — skill describes a workflow but never states what the delivered artifact looks like (report structure, severity labels) | -10 |
| 3 | `(development)/codenavi/SKILL.md` | High vague-term density (11 matches: "appropriate", "relevant", "comprehensive", "effective", "ensure", "various", "leverage", "utilize", "proper", "suitable") | -20 (cap) |
| 4 | `(creation)/cursor-subagent-creator/SKILL.md` | High vague-term density (11 matches: "appropriate", "relevant", "comprehensive", "effective", "ensure", "various") | -20 (cap) |
| 5 | `(tooling)/nx-run-tasks/SKILL.md` | Vague x7 (-14) + no formal output format section (-5) | -19 |
| 6 | `(cloud)/render-deploy/SKILL.md` | Vague x4 (-8) + no examples/output section (-10) | -18 |
| 7 | `(tooling)/nx-generate/SKILL.md` | Vague x6 (-12) + no output format section (-5) | -17 |
| 8 | `(cloud)/aws-advisor/SKILL.md` | Vague x5 (-10) + no formal output section (-5) | -15 |
| 9 | `(creation)/create-technical-design-doc/SKILL.md` | Vague x7 (-14): "appropriate", "relevant", "comprehensive", "ensure", "optimal", "effective" | -14 |
| 10 | `(tooling)/mermaid-studio/SKILL.md` | Vague x7 (-14): "appropriate", "relevant", "ensure", "various", "comprehensive" | -14 |
| 11 | `(development)/docs-writer/SKILL.md` | Vague x4 (-8) + no output format section (-5) | -13 |
| 12 | `(quality)/seo/SKILL.md` | Vague x4 (-8) + no output format section (-5) | -13 |
| 13 | `(gtm)/solo-founder-gtm/SKILL.md` | Vague x6 (-12): "relevant", "appropriate", "ensure", "various", "comprehensive", "effective" | -12 |
| 14 | `(development)/confluence-assistant/SKILL.md` | Vague x6 (-12): "relevant", "appropriate", "ensure", "comprehensive" | -12 |
| 15 | `(architecture)/frontend-blueprint/SKILL.md` | Vague x6 (-12): "appropriate", "relevant", "several", "proper", "ensure" | -12 |
| 16 | `(architecture)/coupling-analysis/SKILL.md` | Vague x3 (-6) + no output format section (-5) | -11 |
| 17 | `(quality)/web-best-practices/SKILL.md` | Vague x3 (-6) + no output format section (-5) | -11 |
| 18 | `(web-automation)/playwright-skill/SKILL.md` | Vague x5 (-10): "appropriate", "relevant", "robust", "various", "comprehensive" | -10 |
| 19 | `(gtm)/gtm-metrics/SKILL.md` | Vague x5 (-10) | -10 |
| 20 | `(gtm)/ai-cold-outreach/SKILL.md` | Vague x5 (-10) | -10 |
| 21 | `(development)/gh-address-comments/SKILL.md` | No output format section — 32-line file has no example of expected output | -10 |
| 22 | `(learning)/learning-opportunities/SKILL.md` | No output format section | -10 |
| 23 | `(tooling)/excalidraw-studio/SKILL.md` | Vague x2 + no output format section | -9 |
| 24 | `(quality)/web-accessibility/SKILL.md` | Vague x2 + no output format section | -9 |
| 25 | `(development)/shopify-developer/SKILL.md` | No output format section (code examples present but no "## Output" or equivalent) | -5 |
| 26 | `(development)/coding-guidelines/SKILL.md` | No output format section | -5 |
| 27 | `(performance)/perf-web-optimization/SKILL.md` | No output format section | -5 |
| 28 | `(performance)/perf-lighthouse/SKILL.md` | No output format section | -5 |
| 29 | `(performance)/perf-astro/SKILL.md` | No output format section | -5 |
| 30 | `(tooling)/nx-workspace/SKILL.md` | No output format section | -5 |
| 31 | `(cloud)/cloudflare-deploy/SKILL.md` | No formal output/example section (has decision trees but no worked example) | -5 |
| 32 | `(architecture)/react-composition-patterns/SKILL.md` | No output format section | -5 |
| 33 | `(design)/figma/SKILL.md` | No output format section | -5 |
| 34 | `(security)/security-threat-model/SKILL.md` | No output format section | -5 |

## Cross-Component
**References verified ✓**
- `docs-writer/SKILL.md` → `references/style-guide.md` — file exists at `skills/(development)/docs-writer/references/style-guide.md`
- `playwright-skill/SKILL.md` → `API_REFERENCE.md` — file exists at `skills/(web-automation)/playwright-skill/API_REFERENCE.md`
- `cloudflare-deploy/SKILL.md` → `references/wrangler/auth.md` — not verified in this scan; check exists

**Orphaned/structural concerns**
- `plugin.json` in `packages/mcp/.claude-plugin/` is the only non-skill NL artifact. Its minimal 5-line structure (missing `version`) is inconsistent with the package-level `package.json` files that all carry `version: '1.0.0'` or `'1.0'`.
- The GTM skills (16 files) share a common `metadata.original_author: Chad Boyda / agent-gtm-skills` attribution with `modified_by` overlays. This is coherent but creates a maintenance dependency: if the upstream `agent-gtm-skills` repo updates, these forks diverge silently with no declared sync mechanism.
- Architecture skills (10 files) form a tightly coupled analysis pipeline (`domain-analysis → domain-identification-grouping → component-identification-sizing → coupling-analysis → decomposition-planning-roadmap`). All cross-references are informal (prose, not `references/` links), which means a renamed skill would break the narrative without a detectable broken-reference error.

**No broken references, no contradictions, no orphaned agents detected.**

## Recommendation
CLEAR — submit PRs for all bugs and medium/low security fixes.

**Priority order:**
1. **Bug fix (high value, low effort)**: Add `"version": "1.0.0"` to `packages/mcp/.claude-plugin/plugin.json` — single-line fix that unblocks correct plugin registration.
2. **Security fixes (medium)**: Add input-sanitization guidance to `playwright-skill/SKILL.md` inline execution section; make `--no-sandbox` conditional on an env var in `helpers.js`.
3. **Quality (highest ROI)**: Replace vague terms in `security-best-practices`, `codenavi`, `cursor-subagent-creator` — these three files account for 51 of the 206 total vague-term matches. Substituting specific action verbs ("verify", "inspect", "generate") would raise the corpus average by ~1 point.
4. **Output format stubs**: Add a `## Output` section to the 26 skills currently missing one — a 3–5 line stub describing the deliverable format would resolve all `-5`/`-10` output-format penalties.
