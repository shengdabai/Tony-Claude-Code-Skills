---
name: chezmoi-dotfiles
description: Secure dotfiles management with chezmoi. Use when helping users initialize chezmoi repositories, add/manage dotfiles, handle secrets with age encryption, create templates for multi-machine configs, troubleshoot chezmoi issues, or review dotfiles for security. Always checks for security implications before adding files.
---

# Chezmoi Dotfiles Management

## Overview

Provide expert guidance for managing dotfiles securely with chezmoi, focusing on security-first practices, multi-machine synchronization, and proper secrets management. Help users maintain well-organized, secure dotfiles repositories that follow industry best practices.

**Core Capabilities:**
- Initialize and configure chezmoi repositories with security defaults
- Safely add dotfiles while preventing secret exposure
- Implement age encryption for sensitive files
- Create templates for machine-specific configurations
- Audit dotfiles for security issues
- Troubleshoot chezmoi workflows

## Security-First Workflow

**Before ANY operation involving files, follow this security evaluation:**

```
User wants to add/modify a file
    ↓
1. Does the file contain secrets?
   (API keys, passwords, tokens, private keys, credentials)
    ├─ YES → Go to step 2
    └─ NO → Check if it mixes secrets with public config → Go to step 3

2. File contains secrets:
   ├─ Is it a private key? → Use age encryption: `chezmoi add --encrypt`
   ├─ Can secrets be externalized? → Use templates + chezmoi.yaml
   └─ Should it be tracked at all? → Add to .chezmoiignore

3. File mixes public config and secrets:
   → Use templates to separate concerns
   → Store secrets in ~/.config/chezmoi/chezmoi.yaml (not committed)
   → Template example: {{ .git.email }} instead of hardcoded email

4. File is safe (no secrets):
   → Check .chezmoiignore patterns first
   → Use `chezmoi add` normally
   → Run `scripts/check_secrets.py` before committing
```

**Security Checklist - Run Before Every Commit:**
```bash
# 1. Scan for secrets
python3 ~/.local/share/chezmoi/scripts/check_secrets.py

# 2. Review what's being committed
cd ~/.local/share/chezmoi && git diff --cached

# 3. Verify .chezmoiignore is working
chezmoi managed | grep -E "(\.env|credentials|secret)"
```

## Core Workflows

### 1. Initialize New Chezmoi Repository

**When:** First-time setup, creating new dotfiles repository

**Steps:**

```bash
# 1. Run initialization script (creates secure defaults)
bash scripts/init_chezmoi_repo.sh

# 2. Set up age encryption (recommended)
age-keygen -o ~/.config/chezmoi/key.txt

# Note the public key, then configure:
cat >> ~/.config/chezmoi/chezmoi.yaml << EOF
encryption: "age"
age:
  identity: "${HOME}/.config/chezmoi/key.txt"
  recipient: "age1..."  # Public key from key.txt
EOF

# 3. Add git remote
cd ~/.local/share/chezmoi
git remote add origin https://github.com/username/dotfiles.git

# 4. Add first dotfiles
chezmoi add ~/.bashrc ~/.zshrc
```

**Script Available:** `scripts/init_chezmoi_repo.sh` creates:
- `.chezmoiignore` with security defaults
- README.md with instructions
- `.chezmoidata.yaml.template` for custom variables
- Initial git commit

### 2. Adding Dotfiles

**When:** User wants to track a new configuration file

**Security Decision Tree:**

```
File type?
├─ Shell config (.bashrc, .zshrc) → Check for secrets → Add normally or template
├─ Git config (.gitconfig) → Template for email: `chezmoi add --template`
├─ SSH config → Template for host-specific configs
├─ SSH private key → `chezmoi add --encrypt ~/.ssh/id_ed25519`
├─ .env file → NEVER ADD - Add to .chezmoiignore
├─ Cloud credentials (.aws/credentials) → Encrypt or don't track
└─ Editor config (.vimrc, nvim/) → Usually safe to add normally
```

**Commands:**

```bash
# Regular file
chezmoi add ~/.bashrc

# Template file (for variables)
chezmoi add --template ~/.gitconfig

# Encrypted file (for secrets)
chezmoi add --encrypt ~/.ssh/id_ed25519

# Directory (recursive)
chezmoi add ~/.config/nvim
```

**Always warn about:**
- Never commit `.env` files with real secrets
- Private keys should be encrypted
- Files with mixed content should use templates

### 3. Managing Secrets

**When:** User needs to handle sensitive files

**Three Approaches:**

#### Option A: Age Encryption (Preferred for Keys)
```bash
# Add with encryption
chezmoi add --encrypt ~/.ssh/id_ed25519

# Edit encrypted file
chezmoi edit ~/.ssh/id_ed25519

# Result: Creates encrypted_id_ed25519.age in source
```

**Use for:**
- SSH private keys
- GPG private keys
- Certificate files

#### Option B: Templates + External Config (Preferred for Credentials)
```bash
# 1. Add as template
chezmoi add --template ~/.gitconfig

# 2. Edit to use variables
chezmoi edit ~/.gitconfig

# Content becomes:
# [user]
#   email = "{{ .git.email }}"
#   signingkey = "{{ .git.signingkey }}"

# 3. Store actual values in ~/.config/chezmoi/chezmoi.yaml (not committed)
data:
  git:
    email: "user@example.com"
    signingkey: "ABCD1234"
```

**Use for:**
- Git configuration with emails/keys
- API endpoints that vary by machine
- Configuration files with embedded tokens

#### Option C: Don't Track At All
```bash
# Add to .chezmoiignore
**/.aws/credentials
**/.env
```

**Use for:**
- Cloud provider credentials (retrieve from vault instead)
- Local development .env files
- Browser cookies/sessions

**Security Reference:** See `references/security-checklist.md` for comprehensive guidance.

### 4. Creating Templates

**When:** Configuration needs to vary by machine

**Common Template Scenarios:**

#### Git Config with Multiple Emails
```toml
# dot_gitconfig.tmpl
[user]
  name = "{{ .git.name }}"
{{- if eq .machine.type "work" }}
  email = "{{ .email.work }}"
{{- else }}
  email = "{{ .email.personal }}"
{{- end }}
```

#### SSH Config with Host-Specific Keys
```
# dot_ssh/config.tmpl
{{- if eq .machine.type "work" }}
Host github-work
  HostName github.com
  IdentityFile ~/.ssh/id_ed25519_work
{{- end }}
```

#### Shell RC with OS-Specific Settings
```bash
# dot_zshrc.tmpl
{{- if eq .chezmoi.os "darwin" }}
eval "$(/opt/homebrew/bin/brew shellenv)"
{{- else if eq .chezmoi.os "linux" }}
alias ls='ls --color=auto'
{{- end }}
```

**Template Reference:** See `references/template-examples.md` for comprehensive examples.

**Data Configuration:** Use `assets/.chezmoidata.yaml.template` as starting point.

### 5. Multi-Machine Setup

**When:** Syncing dotfiles to new machine

**Setup Process:**

```bash
# On new machine:
# 1. Install chezmoi
sh -c "$(curl -fsLS get.chezmoi.io)"

# 2. Initialize from repository
chezmoi init https://github.com/username/dotfiles.git

# 3. Configure machine-specific data
cp ~/.local/share/chezmoi/assets/.chezmoidata.yaml.template \
   ~/.config/chezmoi/chezmoi.yaml

# Edit for this machine:
# - Set machine.type (personal, work, server)
# - Configure email addresses
# - Set development tool preferences

# 4. Preview changes
chezmoi diff

# 5. Apply dotfiles
chezmoi apply -v
```

**For Encrypted Files:**
- Copy age key from secure location: `~/.config/chezmoi/key.txt`
- Or regenerate and re-encrypt files for new machine

### 6. Security Audit

**When:** Regular maintenance, before sharing repository, after adding many files

**Audit Checklist:**

```bash
# 1. Run secret scanner
python3 scripts/check_secrets.py

# 2. Check git history for leaked secrets
cd ~/.local/share/chezmoi
git log -p | grep -E "api[_-]?key|password|secret" | head -20

# 3. Verify .chezmoiignore effectiveness
chezmoi managed | wc -l  # Should be reasonable
chezmoi managed | grep -E "(\.env|credentials|secret|password)"

# 4. List encrypted files
chezmoi status | grep "\.age$"

# 5. Review template security
grep -r "password\|secret\|key" ~/.local/share/chezmoi/*.tmpl
```

**Security Reference:** `references/security-checklist.md` contains comprehensive audit procedures.

### 7. Troubleshooting

**Common Issues:**

#### "File Not Updating After Edit"
```bash
# Check if managed
chezmoi managed | grep filename

# Check if ignored
cat $(chezmoi source-path)/.chezmoiignore | grep filename

# View diff
chezmoi diff ~/.filename

# Force re-add if needed
chezmoi add --force ~/.filename
```

#### "Template Not Rendering Correctly"
```bash
# Preview template output
chezmoi cat ~/.filename

# View available data
chezmoi data

# Test specific expression
chezmoi execute-template "{{ .variable }}"
```

#### "Encrypted File Won't Decrypt"
```bash
# Verify age key exists
ls ~/.config/chezmoi/key.txt

# Check chezmoi.yaml has encryption configured
cat ~/.config/chezmoi/chezmoi.yaml | grep -A3 "encryption"

# Test decryption
chezmoi cat ~/.ssh/id_ed25519
```

## Essential Commands

**Quick Reference** (See `references/chezmoi-commands.md` for comprehensive guide):

```bash
# Initialize
chezmoi init [repo-url]

# Add files
chezmoi add ~/.bashrc
chezmoi add --template ~/.gitconfig
chezmoi add --encrypt ~/.ssh/id_ed25519

# Edit files
chezmoi edit ~/.bashrc
chezmoi edit --apply ~/.bashrc

# Apply changes
chezmoi diff          # Preview
chezmoi apply -v      # Apply with verbose output

# Sync with remote
chezmoi update -v     # Pull and apply

# Git operations
chezmoi git status
chezmoi git commit -m "message"
chezmoi git push

# Inspection
chezmoi status        # Show what would change
chezmoi managed       # List managed files
chezmoi cat ~/.file   # Show target content
chezmoi data          # Show template data
```

## Proactive Security Guidance

**Always provide these warnings when relevant:**

1. **Before adding .env files:**
   > ⚠️ **Security Warning:** .env files often contain secrets. Add to `.chezmoiignore` instead, or use templates with variables stored in non-committed `chezmoi.yaml`.

2. **Before adding SSH keys:**
   > ⚠️ **Security Warning:** Use age encryption for private keys: `chezmoi add --encrypt ~/.ssh/id_ed25519`

3. **Before adding mixed-content files:**
   > ⚠️ **Security Note:** This file contains both public config and secrets. Consider using a template with variables to separate concerns.

4. **Before committing:**
   > ⚠️ **Security Check:** Run `scripts/check_secrets.py` to scan for accidentally included secrets before committing.

5. **When suggesting .chezmoiignore patterns:**
   > Suggest running `scripts/generate_chezmoiignore.py` with relevant categories instead of manually typing patterns.

## Using Bundled Resources

### Scripts

**`scripts/check_secrets.py`** - Scan for potential secrets
```bash
# Scan default chezmoi source directory
python3 scripts/check_secrets.py

# Scan specific directory
python3 scripts/check_secrets.py /path/to/directory
```
Run before every commit to catch accidentally included secrets.

**`scripts/init_chezmoi_repo.sh`** - Initialize with security defaults
```bash
bash scripts/init_chezmoi_repo.sh
```
Creates `.chezmoiignore`, README, and git repository with secure defaults.

**`scripts/generate_chezmoiignore.py`** - Generate comprehensive ignore patterns
```bash
# Interactive mode with defaults
python3 scripts/generate_chezmoiignore.py

# Specific categories
python3 scripts/generate_chezmoiignore.py --categories python node macos

# All patterns
python3 scripts/generate_chezmoiignore.py --all

# List available categories
python3 scripts/generate_chezmoiignore.py --list

# Output to file
python3 scripts/generate_chezmoiignore.py --output ~/.local/share/chezmoi/.chezmoiignore
```

### References

Load these into context when needed for detailed information:

- **`references/security-checklist.md`** - Comprehensive security practices, encryption setup, pre-commit checks, secret management strategies
- **`references/ignore-patterns.md`** - Extensive catalog of `.chezmoiignore` patterns organized by category (security, languages, OS, editors, etc.)
- **`references/template-examples.md`** - Practical template examples for common scenarios (Git config, SSH config, shell RC, AWS config, etc.)
- **`references/chezmoi-commands.md`** - Complete command reference with explanations of when and how to use each command

### Assets

Provide these templates to users:

- **`assets/.chezmoiignore.template`** - Comprehensive starter ignore file with security-focused defaults
- **`assets/.chezmoidata.yaml.template`** - Template data configuration with examples for common variables
- **`assets/README.md.template`** - Professional README for documenting dotfiles repositories

## Best Practices Summary

**Always:**
- ✅ Run security checks before committing
- ✅ Use age encryption for private keys
- ✅ Use templates for files with mixed public/secret content
- ✅ Maintain comprehensive `.chezmoiignore`
- ✅ Document why files are encrypted/templated
- ✅ Back up age encryption keys separately

**Never:**
- ❌ Commit .env files with real secrets
- ❌ Track browser storage or cookies
- ❌ Skip reviewing git diffs
- ❌ Share age encryption keys via repository
- ❌ Track cache or temporary directories
- ❌ Commit `chezmoi.yaml` if it contains secrets

**Recommend:**
- Use `scripts/generate_chezmoiignore.py` for comprehensive patterns
- Set up pre-commit hooks with `scripts/check_secrets.py`
- Regular security audits (quarterly)
- Meaningful commit messages
- Testing on multiple machines before finalizing templates
