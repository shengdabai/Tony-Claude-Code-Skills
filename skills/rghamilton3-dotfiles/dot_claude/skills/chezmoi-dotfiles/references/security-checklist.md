# Security Checklist for Chezmoi Dotfiles

Comprehensive checklist for maintaining secure dotfiles with chezmoi.

## Before Adding Any File

- [ ] **Scan for secrets**: Does the file contain API keys, tokens, passwords, or credentials?
- [ ] **Check for mixed content**: Does the file mix public config with secrets?
- [ ] **Review file type**: Is this a binary file that might contain hidden data?
- [ ] **Consider encryption**: Would this file benefit from age encryption?

## Secret Detection Patterns

### Never Commit These

**Credentials:**
- API keys and secrets
- Access tokens and bearer tokens
- OAuth client secrets
- Database passwords
- Service account credentials

**Private Keys:**
- SSH private keys (`id_rsa`, `id_ed25519`, `id_ecdsa`)
- PGP/GPG private keys
- SSL/TLS private keys (`.key`, `.pem` files)
- Code signing certificates

**Cloud Provider Credentials:**
- `~/.aws/credentials`
- `~/.config/gcloud/credentials.json`
- `~/.azure/credentials`
- `~/.kube/config` (may contain tokens)

**Application Secrets:**
- `.env` files with secrets
- `secrets.yaml` / `secrets.yml`
- Browser cookies and session storage
- Password manager databases

### Safe to Commit (Usually)

**Configuration Templates:**
- `.env.template` or `.env.example`
- Files with placeholder values like `YOUR_API_KEY_HERE`

**Public Configurations:**
- Shell RC files without secrets (`.bashrc`, `.zshrc`)
- Editor configurations (`.vimrc`, `init.vim`)
- Git configuration (if using templates for email)
- Terminal configurations (`.tmux.conf`, Alacritty config)

## Using Age Encryption

### Setup Age Encryption

```bash
# Generate age key pair
age-keygen -o ~/.config/chezmoi/key.txt

# Note the public key (starts with 'age1...')
grep "public key:" ~/.config/chezmoi/key.txt

# Configure chezmoi to use age
cat >> ~/.config/chezmoi/chezmoi.yaml << EOF
encryption: "age"
age:
  identity: "${HOME}/.config/chezmoi/key.txt"
  recipient: "age1..."  # Your public key here
EOF
```

### Encrypt Files

```bash
# Add file with encryption
chezmoi add --encrypt ~/.ssh/id_ed25519

# Result: Creates encrypted_id_ed25519.age in chezmoi source
# The .age extension tells chezmoi to decrypt on apply
```

### Edit Encrypted Files

```bash
# Edit encrypted file (decrypts temporarily)
chezmoi edit ~/.ssh/id_ed25519

# View encrypted file contents
chezmoi cat ~/.ssh/id_ed25519
```

### Files That Should Be Encrypted

- SSH private keys
- GPG private keys
- API credentials that must be in files
- Database connection strings with passwords
- Private certificates and keys

## Using Templates for Mixed Content

When a file contains both public config and secrets, use templates.

### Template Workflow

1. **Create the template** with placeholders:
```bash
chezmoi add --template ~/.gitconfig
```

2. **Edit the template** to use variables:
```bash
chezmoi edit ~/.gitconfig
```

Content becomes:
```toml
[user]
  name = "{{ .git.name }}"
  email = "{{ .git.email }}"
  signingkey = "{{ .git.signingkey }}"
```

3. **Store secrets separately** in `~/.config/chezmoi/chezmoi.yaml`:
```yaml
data:
  git:
    name: "Your Name"
    email: "your@email.com"
    signingkey: "ABCD1234"
```

4. **Keep chezmoi.yaml private**:
- Never commit `chezmoi.yaml` if it contains secrets
- Add to `.gitignore` in chezmoi source directory
- Or use encrypted `chezmoi.yaml` with age

## Using .chezmoiignore

### Critical Patterns

Add these to `.chezmoiignore`:

```
# Secrets and credentials
**/.env
**/.env.*
!**/.env.template
!**/.env.example
**/secrets.yaml
**/secrets.yml
**/*credentials*
**/.aws/credentials
**/.kube/config

# Private keys
**/.ssh/id_*
**/.ssh/*_rsa
**/.gnupg/**
**/*.key
**/*.pem

# Browser data (often contains tokens)
**/.mozilla/**/storage/**
**/.config/google-chrome/**/Storage/**
```

### Testing .chezmoiignore

```bash
# Check what files chezmoi would manage
chezmoi managed

# Verify a specific file is ignored
chezmoi status | grep "filename"

# If file appears, it's NOT being ignored
```

## Pre-Commit Security Checks

### Manual Checks

Before every commit:

```bash
# 1. Run secret scanner
python3 ~/.local/share/chezmoi/scripts/check_secrets.py

# 2. Review what's being committed
cd ~/.local/share/chezmoi
git diff --cached

# 3. Check for binary files
git diff --cached --numstat | grep "^-"

# 4. Verify .chezmoiignore is working
chezmoi managed | grep -E "(\.env|credentials|secret)"
```

### Automated Pre-Commit Hook

Create `.git/hooks/pre-commit` in chezmoi source directory:

```bash
#!/bin/bash
# Pre-commit hook to check for secrets

CHEZMOI_SOURCE="${HOME}/.local/share/chezmoi"
cd "${CHEZMOI_SOURCE}"

# Run secret scanner
if [ -f "${CHEZMOI_SOURCE}/scripts/check_secrets.py" ]; then
    python3 "${CHEZMOI_SOURCE}/scripts/check_secrets.py"
    if [ $? -ne 0 ]; then
        echo "❌ Secrets detected! Commit aborted."
        echo "Review the findings and either:"
        echo "  1. Remove the secrets"
        echo "  2. Use templates with variables"
        echo "  3. Add files to .chezmoiignore"
        echo "  4. Use age encryption"
        exit 1
    fi
fi

# Check for large files (>1MB) that might contain secrets
large_files=$(git diff --cached --name-only | xargs -I {} stat -f%z {} 2>/dev/null | awk '$1 > 1048576')
if [ ! -z "$large_files" ]; then
    echo "⚠️  Warning: Large files detected in commit"
    echo "Consider if these should be tracked in dotfiles"
fi

exit 0
```

Make it executable:
```bash
chmod +x ~/.local/share/chezmoi/.git/hooks/pre-commit
```

## Machine-Specific Secrets

For secrets that vary by machine:

### Option 1: Machine-Specific chezmoi.yaml

Each machine has its own `~/.config/chezmoi/chezmoi.yaml` (not committed):

```yaml
data:
  machine:
    type: "work"
  aws:
    profile: "work-profile"
  git:
    email: "user@company.com"
```

### Option 2: Encrypted Machine-Specific Files

```bash
# Add machine-specific encrypted file
chezmoi add --encrypt ~/.aws/credentials

# This creates a file like: encrypted_credentials.age
# Different on each machine, committed safely
```

### Option 3: External Secret Management

For teams or complex setups:
- Use a password manager API (1Password, Bitwarden)
- Use cloud secret managers (AWS Secrets Manager, etc.)
- Retrieve secrets in chezmoi scripts

## Security Audit Procedure

Regular security audits (quarterly recommended):

```bash
# 1. Full repository scan
cd ~/.local/share/chezmoi
git log --all --full-history -- "*.key" "*.pem" "*credentials*"

# 2. Check git history for past secrets
git log -p | grep -E "api[_-]?key|password|secret"

# 3. Verify all encrypted files
chezmoi status | grep "\.age$"

# 4. Review .chezmoiignore effectiveness
chezmoi managed | wc -l  # Should be reasonable number

# 5. Check for accidental plaintext secrets
python3 scripts/check_secrets.py
```

## Recovery from Accidental Secret Commit

If a secret was committed:

```bash
# 1. IMMEDIATELY rotate the exposed secret
# Change passwords, regenerate API keys, etc.

# 2. Remove from git history
cd ~/.local/share/chezmoi
git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch path/to/secret/file' \
  --prune-empty --tag-name-filter cat -- --all

# 3. Force push (if already pushed)
git push origin --force --all

# 4. Prevent future exposure
# Add to .chezmoiignore or use encryption
```

## Best Practices Summary

✅ **DO:**
- Use age encryption for private keys and credentials
- Use templates for files with mixed public/secret content
- Store secrets in non-committed chezmoi.yaml
- Run secret scanner before commits
- Use .chezmoiignore aggressively
- Document why sensitive files are encrypted/templated
- Keep age key secure and backed up separately

❌ **DON'T:**
- Commit .env files with real secrets
- Track browser storage or cookie data
- Assume binary files are safe
- Skip reviewing git diffs before pushing
- Share age encryption keys via dotfiles repo
- Commit chezmoi.yaml if it contains secrets
- Track cache or temporary directories
