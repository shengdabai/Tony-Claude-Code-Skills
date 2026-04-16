# Chezmoi Template Examples

Practical examples for using chezmoi's templating system to handle machine-specific configurations.

## Template Basics

Chezmoi uses Go's `text/template` syntax. Files ending in `.tmpl` are processed as templates.

### Built-in Variables

```
{{ .chezmoi.hostname }}      # Machine hostname
{{ .chezmoi.os }}            # OS: linux, darwin, windows
{{ .chezmoi.osRelease.id }}  # Linux distro: ubuntu, arch, etc.
{{ .chezmoi.arch }}          # Architecture: amd64, arm64
{{ .chezmoi.username }}      # Current username
{{ .chezmoi.homeDir }}       # Home directory path
{{ .chezmoi.sourceDir }}     # ~/.local/share/chezmoi
```

### Custom Data

Define in `~/.config/chezmoi/chezmoi.yaml`:

```yaml
data:
  email:
    work: "user@company.com"
    personal: "user@gmail.com"
  git:
    name: "Your Name"
  machine:
    type: "work"
```

Access with:
```
{{ .email.work }}
{{ .git.name }}
{{ .machine.type }}
```

## Example 1: Git Configuration with Multiple Emails

**Use case:** Different Git email for work vs personal machines

**File:** `dot_gitconfig.tmpl`

```toml
[user]
  name = "{{ .git.name }}"
{{- if eq .machine.type "work" }}
  email = "{{ .email.work }}"
  signingkey = "{{ .git.work_signing_key }}"
{{- else }}
  email = "{{ .email.personal }}"
  signingkey = "{{ .git.personal_signing_key }}"
{{- end }}

[core]
  editor = {{ .editor }}
  autocrlf = {{ if eq .chezmoi.os "windows" }}true{{ else }}input{{ end }}

[github]
  user = "{{ .github.username }}"

[init]
  defaultBranch = "main"

# Work-specific config
{{- if eq .machine.type "work" }}
[includeIf "gitdir:~/work/"]
  path = ~/.gitconfig-work
{{- end }}
```

**Data file** (`~/.config/chezmoi/chezmoi.yaml`):

```yaml
data:
  git:
    name: "Your Name"
    work_signing_key: "ABCD1234"
    personal_signing_key: "EFGH5678"
  email:
    work: "user@company.com"
    personal: "user@gmail.com"
  editor: "nvim"
  github:
    username: "yourusername"
  machine:
    type: "work"  # or "personal"
```

## Example 2: SSH Config with Host-Specific Keys

**Use case:** Different SSH keys and jump hosts per machine

**File:** `dot_ssh/config.tmpl`

```
# Global settings
Host *
  AddKeysToAgent yes
  UseKeychain {{ if eq .chezmoi.os "darwin" }}yes{{ else }}no{{ end }}
  IdentityFile ~/.ssh/id_ed25519
  ServerAliveInterval 60
  ServerAliveCountMax 3

# Personal GitHub
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes

{{- if eq .machine.type "work" }}
# Work GitHub
Host github-work
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_work
  IdentitiesOnly yes

# Work servers via jump host
Host *.internal.company.com
  User {{ .username }}
  ProxyJump {{ .work.jumphost }}
  IdentityFile ~/.ssh/id_ed25519_work

# Work jump host
Host {{ .work.jumphost }}
  HostName {{ .work.jumphost }}
  User {{ .username }}
  IdentityFile ~/.ssh/id_ed25519_work
{{- end }}

{{- if .homelab.enabled }}
# Homelab servers
Host homelab-*
  User {{ .username }}
  IdentityFile ~/.ssh/id_ed25519_homelab
  StrictHostKeyChecking no
{{- range .homelab.servers }}
Host {{ .name }}
  HostName {{ .ip }}
{{- end }}
{{- end }}
```

**Data file:**

```yaml
data:
  username: "yourusername"
  machine:
    type: "work"
  work:
    jumphost: "bastion.company.com"
  homelab:
    enabled: true
    servers:
      - name: "homelab-nas"
        ip: "192.168.1.100"
      - name: "homelab-pi"
        ip: "192.168.1.101"
```

## Example 3: Shell RC with OS-Specific Settings

**Use case:** Different shell configurations for macOS vs Linux

**File:** `dot_zshrc.tmpl`

```bash
# -*- mode: sh -*-
# Managed by chezmoi - DO NOT EDIT DIRECTLY

# History
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history

# OS-specific settings
{{- if eq .chezmoi.os "darwin" }}
# macOS specific
export HOMEBREW_PREFIX="{{ .homebrew.prefix }}"
eval "$($HOMEBREW_PREFIX/bin/brew shellenv)"

# macOS aliases
alias ls='ls -G'
alias updatebrew='brew update && brew upgrade'
{{- else if eq .chezmoi.os "linux" }}
# Linux specific
alias ls='ls --color=auto'
{{- if eq .chezmoi.osRelease.id "ubuntu" }}
alias updateapt='sudo apt update && sudo apt upgrade'
{{- else if eq .chezmoi.osRelease.id "arch" }}
alias updatepac='sudo pacman -Syu'
{{- end }}
{{- end }}

# Machine-specific PATH additions
export PATH="${HOME}/.local/bin:${PATH}"
{{- if eq .machine.type "work" }}
export PATH="{{ .work.tools_path }}:${PATH}"
export COMPANY_ENV="{{ .work.environment }}"
{{- end }}

# Editor
export EDITOR="{{ .editor }}"
export VISUAL="{{ .editor }}"

# Development tools
{{- if .dev.python_enabled }}
export PYENV_ROOT="${HOME}/.pyenv"
export PATH="${PYENV_ROOT}/bin:${PATH}"
eval "$(pyenv init -)"
{{- end }}

{{- if .dev.node_enabled }}
export NVM_DIR="${HOME}/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
{{- end }}

{{- if .dev.rust_enabled }}
export PATH="${HOME}/.cargo/bin:${PATH}"
{{- end }}

# Aliases
alias vim='{{ .editor }}'
alias config='chezmoi'
alias cedit='chezmoi edit'
alias capply='chezmoi apply -v'

{{- if .custom_aliases }}
# Custom aliases
{{ range $alias, $command := .custom_aliases }}
alias {{ $alias }}='{{ $command }}'
{{- end }}
{{- end }}

# Load local overrides
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
```

**Data file:**

```yaml
data:
  editor: "nvim"
  machine:
    type: "personal"
  homebrew:
    prefix: "/opt/homebrew"  # Apple Silicon
  dev:
    python_enabled: true
    node_enabled: true
    rust_enabled: false
  custom_aliases:
    lg: "lazygit"
    dc: "docker compose"
    k: "kubectl"
```

## Example 4: AWS Config with Multiple Profiles

**Use case:** Different AWS profiles per machine

**File:** `dot_aws/config.tmpl`

```ini
[default]
region = {{ .aws.default_region }}
output = json

{{- if eq .machine.type "work" }}
[profile work]
region = {{ .aws.work_region }}
output = json
sso_start_url = {{ .aws.work_sso_url }}
sso_region = {{ .aws.work_sso_region }}
sso_account_id = {{ .aws.work_account_id }}
sso_role_name = {{ .aws.work_role_name }}
{{- end }}

{{- if .aws.personal_profile }}
[profile personal]
region = {{ .aws.default_region }}
{{- end }}
```

**Note:** Never template `~/.aws/credentials` with actual secrets! Use:
- Age encryption: `chezmoi add --encrypt ~/.aws/credentials`
- Or don't track credentials at all

## Example 5: Conditional File Inclusion

**Use case:** Only include certain files on specific machines

**File:** `.chezmoiignore.tmpl`

```
# Ignore files based on machine type
{{- if ne .machine.type "work" }}
# Ignore work-specific configs on non-work machines
.ssh/config-work
.aws/config-work
.kube/config
{{- end }}

{{- if ne .chezmoi.os "darwin" }}
# Ignore macOS-specific files
.hammerspoon/**
Library/Application Support/**
{{- end }}

{{- if ne .chezmoi.os "linux" }}
# Ignore Linux-specific files
.config/i3/**
.config/polybar/**
{{- end }}
```

## Example 6: Dynamic Host-Specific Values

**Use case:** Different proxy settings per location

**File:** `dot_config/environment.d/proxy.conf.tmpl`

```bash
{{- if eq .chezmoi.hostname "work-laptop" }}
# Work proxy
HTTP_PROXY=http://proxy.company.com:8080
HTTPS_PROXY=http://proxy.company.com:8080
NO_PROXY=localhost,127.0.0.1,.company.com
{{- else if eq .chezmoi.hostname "home-desktop" }}
# No proxy at home
{{- else }}
# Default: no proxy
{{- end }}
```

## Example 7: Template with External Command

**Use case:** Insert output of a command

**File:** `dot_config/hostname.txt.tmpl`

```
This machine: {{ .chezmoi.hostname }}
{{- if lookPath "lsb_release" }}
OS Info: {{ output "lsb_release" "-ds" | trim }}
{{- end }}
{{- if eq .chezmoi.os "darwin" }}
macOS Version: {{ output "sw_vers" "-productVersion" | trim }}
{{- end }}
Generated: {{ now | date "2006-01-02 15:04:05" }}
```

## Example 8: Iterating Over Lists

**Use case:** Generate config for multiple servers

**File:** `dot_ssh/known_hosts.tmpl`

```
# Auto-generated known_hosts
{{- range .homelab.servers }}
{{ .name }},{{ .ip }} {{ .ssh_key }}
{{- end }}

{{- if eq .machine.type "work" }}
{{- range .work.servers }}
{{ .hostname }} {{ .ssh_key }}
{{- end }}
{{- end }}
```

**Data file:**

```yaml
data:
  homelab:
    servers:
      - name: "nas"
        ip: "192.168.1.100"
        ssh_key: "ssh-ed25519 AAAA..."
      - name: "pi"
        ip: "192.168.1.101"
        ssh_key: "ssh-ed25519 BBBB..."
  work:
    servers:
      - hostname: "server1.company.com"
        ssh_key: "ssh-ed25519 CCCC..."
```

## Example 9: Nested Templates for Complex Logic

**Use case:** Vim config with machine-specific plugins

**File:** `dot_vimrc.tmpl`

```vim
" Basic settings
set nocompatible
set number
set expandtab
set shiftwidth=2

" Plugin manager
call plug#begin('~/.vim/plugged')

" Universal plugins
Plug 'tpope/vim-sensible'
Plug 'junegunn/fzf.vim'

{{- if .dev.python_enabled }}
" Python development
Plug 'davidhalter/jedi-vim'
Plug 'psf/black'
{{- end }}

{{- if .dev.go_enabled }}
" Go development
Plug 'fatih/vim-go'
{{- end }}

{{- if eq .machine.type "work" }}
" Work-specific plugins
Plug 'company/internal-vim-plugin'
{{- end }}

call plug#end()

{{- if .vim.custom_mappings }}
" Custom key mappings
{{ range .vim.custom_mappings }}
{{ . }}
{{- end }}
{{- end }}
```

## Template Functions Reference

### Comparison

```
{{ eq .a .b }}     # Equal
{{ ne .a .b }}     # Not equal
{{ lt .a .b }}     # Less than
{{ le .a .b }}     # Less than or equal
{{ gt .a .b }}     # Greater than
{{ ge .a .b }}     # Greater than or equal
```

### Logic

```
{{ and .a .b }}    # Logical AND
{{ or .a .b }}     # Logical OR
{{ not .a }}       # Logical NOT
```

### String Operations

```
{{ .str | trim }}           # Remove whitespace
{{ .str | lower }}          # Lowercase
{{ .str | upper }}          # Uppercase
{{ .str | replace "a" "b" }} # Replace
```

### Conditionals

```
{{ if .condition }}
  true branch
{{ else if .other }}
  else if branch
{{ else }}
  else branch
{{ end }}
```

### Loops

```
{{ range .list }}
  {{ . }}
{{ end }}

{{ range $key, $value := .map }}
  {{ $key }}: {{ $value }}
{{ end }}
```

## Testing Templates

```bash
# Preview what a template would generate
chezmoi cat ~/.gitconfig

# See diff before applying
chezmoi diff

# Apply with verbose output
chezmoi apply -v

# Re-add file after modifying template
chezmoi add --force ~/.gitconfig
```

## Best Practices

1. **Keep templates simple** - Complex logic in templates becomes hard to maintain
2. **Use meaningful variable names** - Future you will appreciate it
3. **Comment your conditions** - Explain why certain branches exist
4. **Test on multiple machines** - Templates fail silently if data is missing
5. **Provide defaults** - Use `{{ .value | default "fallback" }}`
6. **Document required data** - List required variables in comments
7. **Version your data file** - Back up `chezmoi.yaml` separately

## Common Pitfalls

❌ **Forgetting to trim whitespace:**
```
{{- if .condition }}  # Use - to trim
```

❌ **Missing data causing silent failures:**
```
{{ .nonexistent.value }}  # Returns nothing if missing
```

✅ **Use with default:**
```
{{ .value | default "safe-default" }}
```

❌ **Complex bash in templates:**
```
{{ output "bash" "-c" "long | complex | pipe" }}
```

✅ **Use chezmoi scripts instead:**
```
run_once_setup.sh.tmpl
```
