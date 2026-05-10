# Common .chezmoiignore Patterns

Comprehensive collection of ignore patterns organized by category. Use these to build a robust `.chezmoiignore` file.

## How .chezmoiignore Works

- Uses Go's `filepath.Match` syntax (similar to `.gitignore`)
- `**` matches multiple directory levels
- `*` matches within a single directory level
- `!pattern` negates a previous ignore rule
- Evaluated in order (later rules can override earlier ones)

## Security-Critical Patterns

Always include these to prevent secret exposure:

```
# Environment files with secrets
**/.env
**/.env.*
!**/.env.template
!**/.env.example
!**/.env.sample

# Secret storage files
**/secrets.yaml
**/secrets.yml
**/secrets.json
**/*credentials*
**/*secret*

# Private keys
**/.ssh/id_*
**/.ssh/*_rsa
**/.ssh/*_ed25519
**/.ssh/*_ecdsa
**/*.key
**/*.pem
**/.gnupg/**

# Cloud provider credentials
**/.aws/credentials
**/.aws/config  # May contain sensitive data
**/.azure/credentials
**/.config/gcloud/credentials*
**/.config/gcloud/**/credentials*
**/.kube/config

# Docker authentication
**/.docker/config.json

# Application-specific
**/.netrc
**/.pgpass
**/.my.cnf
```

## Cache Directories

Common cache locations that should never be tracked:

```
# Generic cache
**/.cache/**
**/cache/**

# Python
**/__pycache__/**
**/.pytest_cache/**
**/.mypy_cache/**
**/.ruff_cache/**
**/.hypothesis/**

# Node.js/JavaScript
**/node_modules/**
**/.npm/**
**/.yarn/**
**/.pnpm-store/**
**/.next/cache/**
**/.nuxt/**
**/.turbo/**
**/.parcel-cache/**
**/.cache/webpack/**

# Ruby
**/.bundle/cache/**

# Go
**/.cache/go-build/**

# Rust
**/target/debug/**
**/target/release/**

# Build systems
**/.gradle/caches/**
**/.m2/repository/**

# IDE caches
**/.idea/**/caches/**
**/.vscode/.cache/**
```

## Language-Specific Build Artifacts

### Python

```
# Python compiled files
**/*.pyc
**/*.pyo
**/*.pyd
**/.Python

# Virtual environments
**/.venv/**
**/venv/**
**/ENV/**
**/env/**
**/.virtualenv/**

# Distribution/packaging
**/dist/**
**/build/**
**/*.egg-info/**
**/*.egg

# Testing
**/.tox/**
**/.coverage
**/.pytest_cache/**
**/htmlcov/**

# Type checking
**/.mypy_cache/**
**/.pytype/**
```

### Node.js/JavaScript

```
# Dependencies
**/node_modules/**
**/jspm_packages/**

# Package manager files (debatable - see note)
**/package-lock.json
**/yarn.lock
**/pnpm-lock.yaml

# Build outputs
**/dist/**
**/build/**
**/.next/**
**/.nuxt/**
**/out/**

# Cache and temp
**/.npm/**
**/.yarn/**
**/.pnpm-store/**
**/.eslintcache
**/.cache/**
```

**Note:** Some prefer to track lock files. Exclude this section if you want lock files versioned.

### Rust

```
# Cargo build
**/target/**
**/*.rs.bk
**/Cargo.lock  # Usually tracked for bins, not libs
```

### Go

```
# Compiled binaries
**/*.exe
**/*.exe~
**/*.dll
**/*.so
**/*.dylib

# Go workspace
**/go.work
**/go.work.sum
```

### Ruby

```
# Gems
**/.bundle/**
**/vendor/bundle/**
**/*.gem

# Bundler version
**/.ruby-version
**/.ruby-gemset
```

### Java/Kotlin

```
# Compiled class files
**/*.class

# Build directories
**/target/**
**/build/**
**/out/**

# Gradle
**/.gradle/**
**/gradle/wrapper/gradle-wrapper.jar

# Maven
**/.m2/repository/**

# Package files
**/*.jar
**/*.war
**/*.ear
```

## Operating System Files

### macOS

```
# Finder
**/.DS_Store
**/.AppleDouble
**/.LSOverride

# Thumbnails
**/._*

# Spotlight
**/.Spotlight-V100
**/.Trashes

# Volumes
**/.fseventsd
**/.VolumeIcon.icns

# Directories for iCloud
**/.DocumentRevisions-V100
**/.TemporaryItems
```

### Windows

```
# Windows thumbnails
**/Thumbs.db
**/ehthumbs.db

# Folder config
**/desktop.ini

# Recycle Bin
**/$RECYCLE.BIN/**

# Windows shortcuts
**/*.lnk

# System files
**/System Volume Information/**
```

### Linux

```
# Trash
**/.local/share/Trash/**

# Thumbnails
**/.thumbnails/**

# KDE
**/.directory

# Recently used files
**/.recently-used
```

## Editor and IDE Files

### VS Code

```
**/.vscode/**
!**/.vscode/settings.json  # Optionally track settings
!**/.vscode/tasks.json
!**/.vscode/launch.json
!**/.vscode/extensions.json
**/.vscode/*.code-workspace
```

### JetBrains (IntelliJ, PyCharm, etc.)

```
**/.idea/**
!**/.idea/codeStyles/**
!**/.idea/inspectionProfiles/**
**/*.iml
**/*.ipr
**/*.iws
```

### Vim/Neovim

```
# Swap files
**/*.swp
**/*.swo
**/*~

# Session
**/Session.vim

# Undo
**/.vim/undo/**

# Backup
**/.vim/backup/**
**/.vim/swap/**

# Neovim state
**/.local/share/nvim/swap/**
**/.local/share/nvim/shada/**
```

### Emacs

```
**/*~
**/#*#
**/.emacs.desktop
**/.emacs.desktop.lock
**/auto-save-list
**/.emacs.bmk
```

### Sublime Text

```
**/*.sublime-project
**/*.sublime-workspace
**/.sublime-*
```

## Browser Data

```
# Firefox
**/.mozilla/**/storage/**
**/.mozilla/**/cache2/**
**/.mozilla/**/cookies.sqlite
**/.mozilla/**/formhistory.sqlite

# Chrome/Chromium
**/.config/google-chrome/**/Storage/**
**/.config/google-chrome/**/Cache/**
**/.config/google-chrome/**/Cookies
**/.config/chromium/**/Storage/**
**/.config/chromium/**/Cache/**
**/.config/chromium/**/Cookies

# Brave
**/.config/BraveSoftware/**/Storage/**
**/.config/BraveSoftware/**/Cache/**
```

## Shell History

```
# Bash
**/.bash_history

# Zsh
**/.zsh_history
**/.zsh_sessions/**

# Fish
**/.local/share/fish/fish_history

# Other
**/.python_history
**/.node_repl_history
**/.sqlite_history
**/.lesshst
**/.wget-hsts
**/.psql_history
```

## Application State and Logs

```
# Logs
**/*.log
**/logs/**
**/*.pid

# Databases (local)
**/*.db
**/*.sqlite
**/*.sqlite3

# Temporary files
**/*.tmp
**/*.temp
**/tmp/**
**/temp/**

# Backup files
**/*.bak
**/*.backup
**/*~
```

## Container and Virtualization

```
# Docker
**/.docker/cli-plugins/**
**/.docker/contexts/**
**/.docker/scout/**

# Vagrant
**/.vagrant/**

# VirtualBox
**/VirtualBox VMs/**
```

## Development Tools

```
# Git
**/.git/**  # chezmoi already ignores this

# Make
**/*.o
**/*.a

# CMake
**/CMakeFiles/**
**/CMakeCache.txt

# Terraform
**/.terraform/**
**/*.tfstate
**/*.tfstate.backup

# Ansible
**/.ansible/**
**/retry/**
```

## Multimedia and Large Files

```
# Images (if generated)
**/screenshots/**
**/thumbs/**

# Videos (rarely in dotfiles)
**/*.mp4
**/*.avi
**/*.mov

# Archives
**/*.zip
**/*.tar.gz
**/*.rar
**/*.7z
```

## Testing Frameworks

```
# Coverage reports
**/coverage/**
**/htmlcov/**
**/.coverage
**/.nyc_output/**

# Test results
**/test-results/**
**/.pytest_cache/**
**/junit.xml
```

## Example .chezmoiignore File

Minimal but effective starter:

```
# Security (REQUIRED)
**/.env
**/.env.*
!**/.env.template
**/.ssh/id_*
**/.gnupg/**
**/.aws/credentials

# Caches
**/.cache/**
**/__pycache__/**
**/node_modules/**

# OS
**/.DS_Store
**/Thumbs.db

# Editors
**/.vscode/
**/.idea/
**/*.swp

# History
**/.bash_history
**/.zsh_history

# Logs and temp
**/*.log
**/*.tmp
```

## Advanced Patterns

### Conditional Ignoring

Chezmoi doesn't support conditionals in .chezmoiignore directly, but you can use templates:

```
# In .chezmoiignore.tmpl
{{ if eq .chezmoi.os "darwin" }}
# macOS-specific ignores
**/.DS_Store
{{ end }}

{{ if eq .chezmoi.os "linux" }}
# Linux-specific ignores
**/.local/share/Trash/**
{{ end }}
```

### Negation Examples

Include specific files in otherwise ignored directories:

```
# Ignore all VS Code settings except these
**/.vscode/**
!**/.vscode/settings.json
!**/.vscode/keybindings.json
```

### Testing Your Patterns

```bash
# See what files chezmoi would manage
chezmoi managed

# Check if specific file is ignored
chezmoi status | grep "filename"

# Dry run to see what would be added
chezmoi add --dry-run ~/.config/somedir
```

## Pattern Anti-Patterns

❌ **Too Broad:**
```
# This ignores TOO much
**/config/**  # Might ignore important configs
```

✅ **More Specific:**
```
# Better - target specific configs
**/.config/google-chrome/**/Cache/**
**/.config/*/cache/**
```

❌ **Missing Wildcards:**
```
# This only matches root .cache
.cache/**
```

✅ **Correct Pattern:**
```
# Matches .cache at any level
**/.cache/**
```
