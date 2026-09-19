# Security Policy

Please do not report vulnerabilities, exposed secrets, credentials, or private user data in public issues.

Use GitHub private vulnerability reporting when it is available for this repository. If it is not available, contact the repository owner through the profile contact channel.

If a secret is exposed, revoke or rotate it first, then remove it from Git history and close the related GitHub secret scanning alert only after verification.

## Publication checks

The legacy `my-config/hooks/sync-skills-to-github.sh` hook is retired and does not
sync, stage, commit, or push. Existing installed copies must be retired separately.
For a reviewed manual change, stage explicit file paths, then run
`python3 scripts/check-public-content.py`. The check reads staged blobs, including
`.env.example` templates, and emits only paths and rule names on a finding.
It complements other secret scanners; passing it does not establish that outgoing
Git history is safe, that a leaked key is revoked, or that an incident is closed.
Do not publish session exports, browser state, or conversation archives.
