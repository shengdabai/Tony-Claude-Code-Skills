#!/bin/bash
# Initialize a new chezmoi dotfiles repository with sensible defaults
# This script sets up chezmoi with security-conscious defaults and best practices

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Chezmoi directories
CHEZMOI_SOURCE="${HOME}/.local/share/chezmoi"
CHEZMOI_CONFIG="${HOME}/.config/chezmoi"

echo -e "${BLUE}🚀 Initializing chezmoi dotfiles repository${NC}"
echo ""

# Check if chezmoi is installed
if ! command -v chezmoi &> /dev/null; then
    echo -e "${RED}❌ chezmoi is not installed${NC}"
    echo "Install chezmoi first: https://www.chezmoi.io/install/"
    exit 1
fi

# Check if already initialized
if [ -d "${CHEZMOI_SOURCE}/.git" ]; then
    echo -e "${YELLOW}⚠️  chezmoi repository already initialized at ${CHEZMOI_SOURCE}${NC}"
    read -p "Reinitialize? This will not delete existing files (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Initialize chezmoi
echo -e "${GREEN}📂 Initializing chezmoi source directory${NC}"
chezmoi init

# Create config directory if it doesn't exist
mkdir -p "${CHEZMOI_CONFIG}"

# Create .chezmoiignore with sensible defaults
echo -e "${GREEN}📝 Creating .chezmoiignore with security defaults${NC}"
cat > "${CHEZMOI_SOURCE}/.chezmoiignore" << 'EOF'
# Security: Never track these files
**/.env
**/.env.*
!**/.env.template
!**/.env.example
**/secrets.yaml
**/secrets.yml
**/*credentials*
**/*secret*
**/*.key
**/*.pem
**/.ssh/id_*
**/.ssh/*_rsa
**/.gnupg/**
**/.aws/credentials
**/.docker/config.json

# Cache directories
**/.cache/**
**/__pycache__/**
**/node_modules/**
**/.npm/**
**/.yarn/**
**/.pnpm-store/**
**/.next/**
**/.nuxt/**
**/dist/**
**/build/**
**/.venv/**
**/.tox/**
**/.pytest_cache/**
**/.mypy_cache/**
**/.ruff_cache/**

# OS-specific files
**/.DS_Store
**/Thumbs.db
**/desktop.ini
**/.Spotlight-V100
**/.Trashes

# Temporary files
**/*.tmp
**/*.temp
**/*.swp
**/*.swo
**/*~
**/*.log
**/*.pid

# IDE and editor files
**/.vscode/
**/.idea/
**/*.sublime-project
**/*.sublime-workspace

# Application state/history
**/.bash_history
**/.zsh_history
**/.python_history
**/.node_repl_history
**/.lesshst
**/.wget-hsts

# Browser data
**/.mozilla/**/storage/**
**/.config/google-chrome/**/Storage/**
**/.config/chromium/**/Storage/**

# Compiled files
**/*.pyc
**/*.pyo
**/*.o
**/*.so
**/*.dylib
**/*.exe
**/*.dll

# Archives
**/*.zip
**/*.tar.gz
**/*.rar
**/*.7z
EOF

# Create README template
echo -e "${GREEN}📄 Creating README.md${NC}"
cat > "${CHEZMOI_SOURCE}/README.md" << 'EOF'
# My Dotfiles

Managed with [chezmoi](https://www.chezmoi.io/).

## Quick Start

### First-time setup on a new machine

```bash
# Initialize chezmoi with this repository
chezmoi init https://github.com/YOUR_USERNAME/dotfiles.git

# Preview what will be changed
chezmoi diff

# Apply the dotfiles
chezmoi apply -v
```

### Daily workflow

```bash
# Edit a dotfile
chezmoi edit ~/.bashrc

# See what would change
chezmoi diff

# Apply changes
chezmoi apply -v

# Add a new file to chezmoi
chezmoi add ~/.config/newfile

# Pull latest changes from repo
chezmoi update -v
```

## File Organization

- `.chezmoiignore` - Files/patterns to never track
- `.chezmoidata.yaml` - Machine-specific configuration data for templates
- Encrypted files use `.age` extension for age encryption

## Security

This repository uses:
- `.chezmoiignore` to prevent tracking sensitive files
- age encryption for secrets (private keys, credentials)
- Templates for files that mix public config with secrets

**Never commit:**
- API keys, passwords, tokens
- Private SSH keys
- Cloud provider credentials
- Browser cookies/session data

## Templates

Files ending in `.tmpl` are templates that can use:
- `{{ .chezmoi.hostname }}` - Current machine hostname
- `{{ .chezmoi.os }}` - Operating system (linux, darwin, etc.)
- Custom variables from `.chezmoidata.yaml`

Example `.chezmoidata.yaml`:
```yaml
data:
  email:
    work: "user@work.com"
    personal: "user@personal.com"
  git:
    name: "Your Name"
```

## Encrypted Files

Add encrypted files with:
```bash
chezmoi add --encrypt ~/.ssh/id_rsa
```

View/edit encrypted files:
```bash
chezmoi edit ~/.ssh/id_rsa
```

## Troubleshooting

```bash
# Check what chezmoi would do
chezmoi apply --dry-run --verbose

# See source state
chezmoi status

# Re-add a file (if modified in source)
chezmoi add --force ~/.bashrc

# Verify state
chezmoi verify
```
EOF

# Create .chezmoidata.yaml template
echo -e "${GREEN}⚙️  Creating .chezmoidata.yaml template${NC}"
cat > "${CHEZMOI_SOURCE}/.chezmoidata.yaml.template" << 'EOF'
# Template for machine-specific configuration data
# Copy this to .chezmoidata.yaml and customize for this machine
# Add .chezmoidata.yaml to .gitignore if it contains secrets

data:
  # Git configuration
  git:
    name: "Your Name"
    email:
      work: "user@work.com"
      personal: "user@personal.com"

  # Machine type (for conditional templates)
  machine:
    type: "personal"  # personal, work, server
    hostname: "{{ .chezmoi.hostname }}"

  # Cloud/service tokens (consider using age encryption instead)
  # tokens:
  #   github: "use-age-encryption"
EOF

# Initialize git repository
echo -e "${GREEN}🔧 Initializing git repository${NC}"
cd "${CHEZMOI_SOURCE}"
git init
git add .chezmoiignore README.md .chezmoidata.yaml.template

# Create initial commit
echo -e "${GREEN}💾 Creating initial commit${NC}"
git commit -m "Initial commit: chezmoi setup with security defaults"

echo ""
echo -e "${GREEN}✅ Chezmoi repository initialized successfully!${NC}"
echo ""
echo -e "${BLUE}📍 Source directory: ${CHEZMOI_SOURCE}${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Add a git remote:"
echo "   cd ${CHEZMOI_SOURCE}"
echo "   git remote add origin https://github.com/YOUR_USERNAME/dotfiles.git"
echo ""
echo "2. Add your first dotfile:"
echo "   chezmoi add ~/.bashrc"
echo ""
echo "3. Configure age encryption (recommended):"
echo "   age-keygen -o \${HOME}/.config/chezmoi/key.txt"
echo "   Add to ${CHEZMOI_CONFIG}/chezmoi.yaml:"
echo "   encryption: \"age\""
echo "   age:"
echo "     identity: \"${HOME}/.config/chezmoi/key.txt\""
echo "     recipient: \"age1...\"  # Public key from key.txt"
echo ""
echo "4. Review .chezmoiignore and customize for your needs"
echo ""
echo "5. Before committing, scan for secrets:"
echo "   python3 scripts/check_secrets.py"
