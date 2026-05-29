# Cross-Platform Dotfiles

> Chezmoi-managed dotfiles supporting Windows, WSL2, Arch Linux (KDE & Sway)

## ⚡ Quick Start

```bash
# 1. Install chezmoi (if not already installed)
sh -c "$(curl -fsLS get.chezmoi.io)"

# 2. Initialize from this repository
chezmoi init https://github.com/YOUR_USERNAME/dotfiles.git

# 3. Preview what will be applied
chezmoi diff

# 4. Apply dotfiles
chezmoi apply -v
```

---

## 🖥️ Supported Platforms

| Platform | Detection | Key Features |
|----------|-----------|--------------|
| **Windows** | Native Windows | WezTerm → WSL2 → Zellij |
| **WSL2 (Ubuntu)** | `WSL_DISTRO_NAME` env | clip.exe clipboard, Windows interop |
| **Arch Desktop (KDE)** | `XDG_CURRENT_DESKTOP` | wl-copy clipboard, KDE integration |
| **Arch Laptop (Sway)** | `XDG_CURRENT_DESKTOP` | wl-copy clipboard, Sway keybindings |

---

## 📁 File Structure

```
.
├── .chezmoi.yaml.tmpl          # Platform detection & data
├── .chezmoiignore.tmpl         # Platform-specific ignores
├── run_once_install-zellij-plugin.sh  # One-time setup
│
├── dot_config/
│   ├── fish/
│   │   ├── config.fish.tmpl    # Shell configuration
│   │   └── env.fish.tmpl       # Environment secrets
│   │
│   ├── wezterm/
│   │   └── wezterm.lua.tmpl    # Terminal configuration
│   │
│   ├── zellij/
│   │   ├── config.kdl.tmpl     # Multiplexer configuration
│   │   └── layouts/
│   │       └── dev.kdl         # Development layout
│   │
│   └── nvim/
│       └── lua/plugins/
│           └── smart-splits.lua # Neovim navigation
│
└── dot_ssh/
    └── config.tmpl             # SSH configuration
```

---

## 🔧 Configuration

### Platform Detection

The `.chezmoi.yaml.tmpl` auto-detects your platform:

```yaml
platform:
  id: "arch-sway"        # Composite identifier
  is_windows: false
  is_linux: true
  is_wsl: false
  is_arch: true
  is_wayland: true
  is_sway: true
```

### Machine-Specific Settings

Edit `~/.config/chezmoi/chezmoi.yaml` for machine-specific overrides:

```yaml
data:
  machine:
    type: "personal"     # or "work"
    role: "laptop"       # or "desktop", "server"
  
  remote:
    enabled: true
    desktop_host: "desktop"
    desktop_ip: "192.168.1.100"
    desktop_user: "youruser"
```

### API Keys (Secrets)

Set via environment variables (never hardcode):

```bash
export GITHUB_TOKEN="ghp_..."
export ANTHROPIC_API_KEY="sk-ant-..."
export OPENAI_API_KEY="sk-..."
```

---

## 🎯 Key Features

### 1. WezTerm + Zellij Integration

- **WezTerm** = GPU rendering only (no tabs/panes)
- **Zellij** = All multiplexing (tabs, panes, sessions)
- Seamless navigation with `Ctrl+hjkl`

### 2. Cross-Platform Clipboard

| Platform | Copy Command |
|----------|--------------|
| WSL2 | `clip.exe` |
| Wayland | `wl-copy` |
| X11 | `xclip` |
| macOS | `pbcopy` |

### 3. Remote Desktop Workflow

From laptop/WSL2, SSH to desktop with auto-Zellij:

```bash
ssh desktop          # Auto-attaches to Zellij session
ssh desktop-raw      # Raw SSH (for scp, rsync)
ssh desktop-code     # Attaches to "code" session in ~/workspace
```

### 4. Session Persistence

Zellij sessions survive disconnects:
- Auto-serialization every 1 second
- `on_force_close: detach` (never lose work)
- Resurrect with `zellij attach -c main`

---

## ⌨️ Keybindings

### Zellij (Normal Mode)

| Key | Action |
|-----|--------|
| `Ctrl+h/j/k/l` | Navigate (Neovim-aware) |
| `Alt+h/j/k/l` | Navigate (quick, non-aware) |
| `Alt+n` | New pane |
| `Alt+-` | Split horizontal |
| `Alt+\` | Split vertical |
| `Alt+w` | Close pane |
| `Alt+z` | Toggle fullscreen |
| `Alt+f` | Toggle floating |
| `Alt+1-5` | Go to tab |
| `Alt+[/]` | Prev/next tab |
| `Alt+Shift+H/J/K/L` | Resize pane |
| `Ctrl+a` | Pane mode |
| `Ctrl+t` | Tab mode |
| `Ctrl+f` | Scroll mode |
| `Ctrl+s` | Session manager |
| `Ctrl+g` | Lock mode |
| `Alt+d` | Detach |

### Neovim

| Key | Action |
|-----|--------|
| `Ctrl+h/j/k/l` | Navigate splits (crosses to Zellij) |
| `Alt+h/j/k/l` | Resize Neovim splits |
| `<leader>sh/j/k/l` | Swap buffers |

### Fish Shell

| Command | Action |
|---------|--------|
| `zj [name]` | Attach/create session |
| `y [path]` | Yazi file manager (cd on exit) |
| `zjl` | List sessions |
| `zjk <name>` | Kill session |
| `zproject` | Session named after git repo |
| `desktop` | SSH to desktop (if enabled) |

---

## 🚀 Per-Platform Setup

### Windows

1. Install [WezTerm](https://wezterm.org)
2. Install WSL2 with Ubuntu
3. In WSL2: `chezmoi init && chezmoi apply`
4. WezTerm auto-launches into WSL2 Zellij

### WSL2 (Ubuntu)

```bash
# Install dependencies
sudo apt install fish zellij fzf ripgrep bat eza zoxide

# Apply dotfiles
chezmoi apply -v

# Set fish as default shell
chsh -s /usr/bin/fish
```

### Arch Linux (Desktop/Laptop)

```bash
# Install dependencies
yay -S fish zellij wezterm fzf ripgrep bat eza zoxide neovim yazi

# Apply dotfiles
chezmoi apply -v

# Set fish as default shell
chsh -s /usr/bin/fish
```

### Arch Linux (Sway Laptop) - Additional Setup

```bash
# Dark mode theming packages
yay -S qt5ct qt6ct adwaita-qt5 adwaita-qt6 xdg-desktop-portal-gtk

# Apply dotfiles (includes theme configs)
chezmoi apply -v

# Log out and back in for environment.d to take effect
```

**Dark mode is configured automatically via:**
- `~/.config/gtk-3.0/settings.ini` / `gtk-4.0/settings.ini`
- `~/.config/qt5ct/qt5ct.conf` / `qt6ct/qt6ct.conf`
- `~/.config/environment.d/theme.conf` (systemd user environment)
- `gsettings` (set by run_once script)

---

## 🔒 Security Notes

1. **Never commit secrets** - Use environment variables
2. **env.fish is templated** - Secrets come from `$ENV` vars
3. **SSH keys** - Add with `chezmoi add --encrypt ~/.ssh/id_ed25519`
4. **API keys** - Set in shell, not in config files

---

## 🐛 Troubleshooting

### Plugin not found

```bash
# Re-run the setup script
bash ~/.local/share/chezmoi/run_once_install-zellij-plugin.sh --force
```

### Clipboard not working

```bash
# WSL2: Ensure clip.exe is accessible
which clip.exe

# Wayland: Install wl-clipboard
yay -S wl-clipboard

# X11: Install xclip
yay -S xclip
```

### Platform detection wrong

```bash
# Check what chezmoi detects
chezmoi data | grep platform

# Force re-apply
chezmoi apply -v --force
```

### SSH ControlMaster issues

```bash
# Remove stale sockets
rm -rf ~/.ssh/sockets/*

# Or disable multiplexing temporarily
ssh -o ControlMaster=no desktop
```

---

## 📝 Customization

### Add New Machine Type

Edit `.chezmoi.yaml.tmpl`:

```go-template
{{- if contains "myserver" $hostname -}}
{{-   $machineRole = "server" -}}
{{- end -}}
```

### Add New Platform

1. Add detection in `.chezmoi.yaml.tmpl`
2. Add conditions in relevant `.tmpl` files
3. Update `.chezmoiignore.tmpl` if needed

### Change Theme

Edit `.chezmoi.yaml.tmpl`:

```yaml
terminal:
  theme: "catppuccin-mocha"  # Change from tokyo-night-storm
```

---

## 📚 Resources

- [Chezmoi Documentation](https://www.chezmoi.io/)
- [Zellij Documentation](https://zellij.dev/documentation/)
- [WezTerm Documentation](https://wezterm.org/docs/)
- [smart-splits.nvim](https://github.com/mrjones2014/smart-splits.nvim)
- [vim-zellij-navigator](https://github.com/hiasr/vim-zellij-navigator)
