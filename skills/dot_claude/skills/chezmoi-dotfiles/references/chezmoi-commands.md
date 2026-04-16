# Chezmoi Commands Quick Reference

Essential chezmoi commands with explanations of when and how to use each.

## Core Workflow Commands

### `chezmoi init`

**Initialize chezmoi on a new machine or first-time setup**

```bash
# Initialize empty repository
chezmoi init

# Initialize from existing GitHub repo
chezmoi init https://github.com/username/dotfiles.git

# Initialize and apply immediately
chezmoi init --apply https://github.com/username/dotfiles.git
```

**When to use:**
- First time using chezmoi on any machine
- Setting up dotfiles on a new computer
- Cloning your dotfiles from a repository

### `chezmoi add`

**Add a file to chezmoi management**

```bash
# Add a single file
chezmoi add ~/.bashrc

# Add a directory (recursively)
chezmoi add ~/.config/nvim

# Add with encryption
chezmoi add --encrypt ~/.ssh/id_ed25519

# Add as template
chezmoi add --template ~/.gitconfig

# Force re-add (overwrite source with current state)
chezmoi add --force ~/.bashrc

# Add and apply immediately
chezmoi add --apply ~/.zshrc
```

**When to use:**
- Adding a new dotfile to track
- When you've manually edited a file and want to update the source
- Converting a file to use encryption or templates

**Important:** `chezmoi add` copies the file from your home directory to the source directory. Any future edits should be made with `chezmoi edit` or in the source directory.

### `chezmoi edit`

**Edit a file in the source directory**

```bash
# Edit a single file
chezmoi edit ~/.bashrc

# Edit multiple files
chezmoi edit ~/.bashrc ~/.zshrc

# Edit an encrypted file (decrypts temporarily)
chezmoi edit ~/.ssh/id_ed25519

# Edit and apply immediately
chezmoi edit --apply ~/.bashrc
```

**When to use:**
- Making changes to a file chezmoi already manages
- Preferred over directly editing files in your home directory
- Editing encrypted files safely

**Why use `edit` instead of modifying files directly?**
- Ensures changes are saved in the source directory
- Maintains single source of truth
- Handles encryption/decryption automatically
- Prevents drift between source and target

### `chezmoi apply`

**Apply changes from source directory to home directory**

```bash
# Apply all changes
chezmoi apply

# Apply with verbose output
chezmoi apply -v

# Dry run (show what would change)
chezmoi apply --dry-run

# Apply specific file
chezmoi apply ~/.bashrc

# Interactive mode (ask for each change)
chezmoi apply --interactive
```

**When to use:**
- After editing files in the source directory
- After pulling updates from a remote repository
- To sync your current state with the chezmoi source

### `chezmoi diff`

**Show differences between source and target**

```bash
# Show all differences
chezmoi diff

# Show diff for specific file
chezmoi diff ~/.bashrc

# Use different diff tool
chezmoi diff --use-builtin-diff
```

**When to use:**
- Before applying changes to preview what will happen
- To see if any files have drifted from the source
- Debugging why a file isn't updating as expected

### `chezmoi status`

**Show status of files (what would change)**

```bash
# Show all file statuses
chezmoi status

# Show status with more detail
chezmoi status -v
```

**Output symbols:**
- ` ` (space) - File is up to date
- `A` - File will be added
- `M` - File will be modified
- `D` - File will be deleted
- `?` - File is not managed by chezmoi

**When to use:**
- Quick check of what would change
- Faster than `chezmoi diff` for seeing which files are affected
- Identifying unmanaged files

## Source Directory Commands

### `chezmoi cd`

**Change to the chezmoi source directory**

```bash
# Open shell in source directory
chezmoi cd

# Execute command in source directory
chezmoi cd -- git status
```

**When to use:**
- Need to run git commands on your dotfiles
- Bulk operations on source files
- Manual file organization in source directory

### `chezmoi source`

**Print the source directory path**

```bash
# Show source directory path
chezmoi source path

# Use in scripts
cd "$(chezmoi source path)"
```

**When to use:**
- Scripting operations on the source directory
- Need to know where chezmoi stores your dotfiles

### `chezmoi managed`

**List all files managed by chezmoi**

```bash
# List all managed files
chezmoi managed

# Count managed files
chezmoi managed | wc -l

# Check if specific file is managed
chezmoi managed | grep ".bashrc"
```

**When to use:**
- Verifying what files chezmoi is tracking
- Checking if `.chezmoiignore` is working correctly
- Auditing your dotfiles coverage

## Update and Sync Commands

### `chezmoi update`

**Pull changes from remote and apply**

```bash
# Update from remote repo
chezmoi update

# Update with verbose output
chezmoi update -v

# Update without applying
chezmoi update --apply=false
```

**When to use:**
- Syncing dotfiles across multiple machines
- After pushing changes from another machine
- Regular updates from your dotfiles repository

**Note:** Equivalent to: `cd $(chezmoi source path) && git pull && chezmoi apply`

### `chezmoi git`

**Run git commands in source directory**

```bash
# Check status
chezmoi git status

# Commit changes
chezmoi git commit -m "Update bashrc"

# Push to remote
chezmoi git push

# Pull from remote
chezmoi git pull

# View log
chezmoi git log
```

**When to use:**
- Version controlling your dotfiles
- Committing and pushing changes
- Viewing history without `chezmoi cd`

## Inspection Commands

### `chezmoi cat`

**Print the target contents of a file**

```bash
# Show what would be applied
chezmoi cat ~/.bashrc

# Show decrypted content
chezmoi cat ~/.ssh/id_ed25519

# Show rendered template
chezmoi cat ~/.gitconfig
```

**When to use:**
- Preview what a template would generate
- View decrypted file contents without applying
- Debugging template rendering

### `chezmoi verify`

**Verify that target files match source**

```bash
# Verify all files
chezmoi verify

# Verify specific file
chezmoi verify ~/.bashrc
```

**When to use:**
- Checking if any files have been modified outside chezmoi
- Auditing system state
- After manual file edits to see what changed

**Exit codes:**
- `0` - All files match
- `1` - Some files don't match

## Removal Commands

### `chezmoi remove`

**Remove files from chezmoi management**

```bash
# Remove file from chezmoi (keeps file in home directory)
chezmoi forget ~/.bashrc  # Preferred alias

# Remove file from both chezmoi and home directory
chezmoi remove ~/.bashrc
```

**When to use:**
- Stop tracking a file with chezmoi
- Removing a file you no longer want managed

**Warning:** `chezmoi remove` deletes the file from your home directory! Use `chezmoi forget` to only stop tracking.

### `chezmoi unmanaged`

**List files not managed by chezmoi**

```bash
# List all unmanaged files in home directory
chezmoi unmanaged

# Limit to specific directory
chezmoi unmanaged ~/.config
```

**When to use:**
- Finding files you might want to add to chezmoi
- Identifying configuration files you've forgotten about
- Cleanup and organization

## Template and Data Commands

### `chezmoi data`

**Print template data**

```bash
# Show all template data
chezmoi data

# Show as JSON
chezmoi data --format=json
```

**When to use:**
- Debugging template issues
- Seeing what variables are available
- Verifying custom data from `chezmoi.yaml`

### `chezmoi execute-template`

**Execute a template string**

```bash
# Test template syntax
chezmoi execute-template "{{ .chezmoi.hostname }}"

# Test complex expressions
chezmoi execute-template "{{ if eq .chezmoi.os \"linux\" }}Linux{{ else }}Other{{ end }}"
```

**When to use:**
- Testing template syntax before using in files
- Debugging template expressions
- Learning template functions

## Encryption Commands

### Encrypted File Operations

```bash
# Add encrypted file
chezmoi add --encrypt ~/.ssh/id_ed25519

# Edit encrypted file
chezmoi edit ~/.ssh/id_ed25519

# View encrypted file
chezmoi cat ~/.ssh/id_ed25519

# Re-encrypt file with new key
chezmoi add --encrypt --force ~/.ssh/id_ed25519
```

**When to use:**
- Managing sensitive files (private keys, credentials)
- Safely storing secrets in version control
- Updating encrypted files

## Configuration Commands

### `chezmoi doctor`

**Check for potential issues**

```bash
# Run diagnostics
chezmoi doctor
```

**When to use:**
- Troubleshooting chezmoi setup
- Verifying installation
- Before asking for help (provides useful debug info)

### `chezmoi upgrade`

**Upgrade chezmoi to latest version**

```bash
# Upgrade chezmoi
chezmoi upgrade
```

**When to use:**
- Getting latest features
- Fixing known bugs
- Regular maintenance

## Advanced Workflows

### Initial Setup on New Machine

```bash
# 1. Install chezmoi
sh -c "$(curl -fsLS get.chezmoi.io)"

# 2. Initialize and apply dotfiles
chezmoi init --apply https://github.com/username/dotfiles.git

# 3. Verify everything applied correctly
chezmoi verify
```

### Making Changes

```bash
# 1. Edit the file
chezmoi edit ~/.bashrc

# 2. Preview changes
chezmoi diff

# 3. Apply changes
chezmoi apply -v

# 4. Commit and push
chezmoi cd
git add .
git commit -m "Update bashrc"
git push
```

### Alternative: Edit and Apply in One Step

```bash
chezmoi edit --apply ~/.bashrc
```

### Syncing Changes to Other Machines

```bash
# Pull and apply changes
chezmoi update -v
```

### Adding Multiple Files

```bash
# Add entire config directory
chezmoi add ~/.config/nvim

# Review what was added
chezmoi cd
git status

# Commit
git add .
git commit -m "Add neovim config"
git push
```

### Converting File to Template

```bash
# 1. Add as template
chezmoi add --template ~/.gitconfig

# 2. Edit template to use variables
chezmoi edit ~/.gitconfig

# 3. Apply to test
chezmoi apply ~/.gitconfig

# 4. Verify result
chezmoi cat ~/.gitconfig
```

### Handling Secrets

```bash
# 1. Add with encryption
chezmoi add --encrypt ~/.aws/credentials

# 2. Verify it's encrypted in source
chezmoi cd
ls -la | grep credentials

# 3. Edit encrypted file
chezmoi edit ~/.aws/credentials

# 4. Commit (encrypted version)
chezmoi git add .
chezmoi git commit -m "Update AWS credentials"
chezmoi git push
```

## Troubleshooting Commands

### Why isn't my file updating?

```bash
# 1. Check if file is managed
chezmoi managed | grep filename

# 2. Check if it's ignored
cat $(chezmoi source path)/.chezmoiignore | grep filename

# 3. Check the diff
chezmoi diff ~/.filename

# 4. Check template rendering
chezmoi cat ~/.filename

# 5. Force re-add
chezmoi add --force ~/.filename
```

### Reset a file to source state

```bash
# Remove local changes
chezmoi apply --force ~/.bashrc
```

### See what chezmoi would do without doing it

```bash
# Dry run
chezmoi apply --dry-run --verbose
```

## Quick Reference Table

| Task | Command |
|------|---------|
| First time setup | `chezmoi init` |
| Clone from GitHub | `chezmoi init --apply https://github.com/user/dotfiles.git` |
| Add file | `chezmoi add ~/.bashrc` |
| Add directory | `chezmoi add ~/.config/nvim` |
| Edit file | `chezmoi edit ~/.bashrc` |
| Apply changes | `chezmoi apply -v` |
| Preview changes | `chezmoi diff` |
| Check status | `chezmoi status` |
| Update from remote | `chezmoi update -v` |
| Git commit | `chezmoi git commit -m "message"` |
| Git push | `chezmoi git push` |
| List managed | `chezmoi managed` |
| Add encrypted | `chezmoi add --encrypt ~/.ssh/id_rsa` |
| Add template | `chezmoi add --template ~/.gitconfig` |
| View template output | `chezmoi cat ~/.gitconfig` |
| Source directory | `chezmoi cd` |
| Verify state | `chezmoi verify` |
| Diagnostics | `chezmoi doctor` |

## Command Flags Reference

### Common Flags (work with most commands)

- `-v, --verbose` - Verbose output
- `-n, --dry-run` - Show what would happen without doing it
- `--force` - Force operation without prompts
- `--source-path` - Specify custom source directory

### Apply-specific Flags

- `-i, --interactive` - Ask before each change
- `--include` - Include only specific entries
- `--exclude` - Exclude specific entries

## Best Practices

1. **Always preview before applying:** Use `chezmoi diff` or `--dry-run`
2. **Use verbose mode when learning:** `-v` flag shows what's happening
3. **Commit regularly:** Small, focused commits are easier to manage
4. **Test templates:** Use `chezmoi cat` before applying
5. **Back up encryption keys:** Store age keys securely and separately
