# Chezmoi Template Variables Setup

This repository uses chezmoi templates for managing dotfiles with variable substitution.

## Configuration Files

### `.chezmoi.yaml.tmpl` (Tracked in Git)
This file defines the template variables structure and pulls sensitive values from environment variables. This approach keeps secrets out of git.

### `chezmoi.yaml.example` (Reference Only)
Example configuration showing the complete structure with placeholder values.

## Setup Instructions

### Option 1: Use Environment Variables (Recommended)
The `.chezmoi.yaml.tmpl` file is configured to read API keys and sensitive data from environment variables:

```bash
export GITHUB_TOKEN="ghp_your_token"
export OPENAI_API_KEY="sk-your-key"
export ANTHROPIC_API_KEY="sk-ant-your-key"
export TIVALY_API_KEY="your-key"
export DATABASE_URL="postgresql://..."
export REDIS_URL="redis://..."
```

### Option 2: Use Local Config File (Alternative)
Create a local chezmoi config file with your actual values:

```bash
# Copy the example to your chezmoi config directory
mkdir -p ~/.config/chezmoi
cp chezmoi.yaml.example ~/.config/chezmoi/chezmoi.yaml

# Edit with your actual values
$EDITOR ~/.config/chezmoi/chezmoi.yaml
```

**Important:** The `~/.config/chezmoi/chezmoi.yaml` file is NOT tracked in git and will override values from `.chezmoi.yaml.tmpl`.

## Template Variables Reference

### Machine Settings
- `machine.type`: "personal" or "work"
- `machine.hostname`: Auto-detected from system

### Shell Configuration
- `shell.editor`: Default editor (e.g., "nvim")
- `shell.term`: Terminal type (e.g., "xterm-256color")
- `shell.gpg_tty`: Enable GPG TTY (boolean)

### Paths
- `paths.pnpm_home`: PNPM installation directory
- `paths.add_paths`: List of directories to add to PATH

### SSH Keys
- `ssh.keys`: List of SSH key filenames to load on login

### FZF Colors
- `fzf.colors.*`: Color scheme for fzf (currently Catppuccin Mocha)

### API Keys (Sensitive)
- `api.github_token`: GitHub personal access token
- `api.openai_key`: OpenAI API key
- `api.anthropic_key`: Anthropic API key
- `api.tivaly_key`: Tivaly API key

### Database URLs (Sensitive)
- `database.postgres_url`: PostgreSQL connection string
- `database.redis_url`: Redis connection string

## Testing Your Configuration

After setting up your configuration, test it:

```bash
# Preview what will be applied
chezmoi diff

# Apply the configuration
chezmoi apply

# Check if templates are rendering correctly
chezmoi execute-template '{{ .shell.editor }}'
```

## Customization

### Changing Machine Type
Edit `.chezmoi.yaml.tmpl` and modify the hostname detection logic:

```yaml
{{- if eq .chezmoi.hostname "your-work-machine" -}}
{{-   $machineType = "work" -}}
{{- end -}}
```

### Adding New Variables
1. Add the variable to `.chezmoi.yaml.tmpl`
2. Update this documentation
3. Use it in your templates: `{{ .your.new.variable }}`

### Changing Color Scheme
Modify the `fzf.colors` section in `.chezmoi.yaml.tmpl` or your local config.

## Security Notes

- Never commit `~/.config/chezmoi/chezmoi.yaml` to git
- Use environment variables for sensitive data when possible
- The `.chezmoiignore` file prevents accidental tracking of sensitive files
- API keys and tokens should have appropriate scopes/permissions
