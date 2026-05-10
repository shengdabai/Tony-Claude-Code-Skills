---
description: Prepare release with version bump and CHANGELOG update
argument-hint: "[major|minor|patch] [version]"
allowed-tools: Bash(git log:*), Bash(git tag:*), Read, Edit
model: openai/gpt-5.1-codex
---

Prepare a new release with CHANGELOG.md update.

Arguments: $ARGUMENTS

**Workflow:**

1. Parse arguments:
   - First arg: bump type (major/minor/patch) or explicit version (e.g., "1.2.3")
2. Determine version:
   - Get latest tag: `git describe --tags --abbrev=0` (fallback to "0.0.0")
   - Calculate new version based on semver

3. Get changes since last release:
   - `git log <last-tag>..HEAD --pretty=format:"%s" --no-merges`
   - Group by conventional commit type

4. Update CHANGELOG.md:
   - Read existing file (warn if missing)
   - Add new section: `## [version] - YYYY-MM-DD`
   - Group commits: Features, Bug Fixes, etc.
   - Replace `## [Unreleased]` section if present

5. Stage CHANGELOG.md: `git add CHANGELOG.md`

6. Inform user to review and then:
   - Commit: `git commit -m "chore(release): v{version}"`
   - Tag: `git tag -a v{version} -m "Release v{version}"`
