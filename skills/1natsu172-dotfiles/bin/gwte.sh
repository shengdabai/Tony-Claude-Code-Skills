#!/usr/bin/env bash

# Git WorkTree Executor
# Execute commands on git worktrees

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
COMMAND=""
DRY_RUN=false
ALL_WORKTREES=false
SELECTED_WORKTREES=()
INTERACTIVE=false

# Function to print colored output
print_color() {
  local color=$1
  shift
  echo -e "${color}$*${NC}"
}

# Function to print usage
usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Git WorkTree Executor - Execute commands on git worktrees

OPTIONS:
    -c, --command COMMAND       Command to execute on worktrees
    -d, --dry-run              Show what would be executed without running
    -a, --all                  Execute on all worktrees
    -i, --interactive          Interactive mode to select worktrees
    -h, --help                 Show this help message

EXAMPLES:
    $(basename "$0") --command "echo Hello World" --dry-run
    $(basename "$0") --command "./path/to/script.sh" --all
    $(basename "$0") --interactive --command "git status"

EOF
}

# Function to get git worktrees
get_worktrees() {
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    print_color "$RED" "Error: Not in a git repository"
    exit 1
  fi

  # Get worktree list and parse it
  git worktree list --porcelain | while IFS= read -r line; do
    if [[ $line =~ ^worktree\ (.+)$ ]]; then
      echo "${BASH_REMATCH[1]}"
    fi
  done
}

# Function to get worktree branch names
get_worktree_info() {
  local worktree_path="$1"
  local branch=""
  local commit=""

  # Get branch name and commit for this worktree
  local info
  info=$(git worktree list --porcelain | awk -v path="$worktree_path" '
        /^worktree / { current_path = substr($0, 10) }
        /^branch / && current_path == path { branch = substr($0, 8) }
        /^HEAD / && current_path == path { commit = substr($0, 6) }
        END { 
            if (branch) print branch
            else print commit
        }
    ')
  echo "$info"
}

# Function to display worktrees with selection
select_worktrees() {
  local worktrees=()
  while IFS= read -r worktree; do
    worktrees+=("$worktree")
  done < <(get_worktrees)

  if [ ${#worktrees[@]} -eq 0 ]; then
    print_color "$RED" "No worktrees found"
    exit 1
  fi

  print_color "$BLUE" "Available worktrees:"
  echo

  for i in "${!worktrees[@]}"; do
    local info
    info=$(get_worktree_info "${worktrees[$i]}")
    printf "%2d) %s %s(%s)%s\n" $((i + 1)) "${worktrees[$i]}" "$CYAN" "$info" "$NC"
  done

  echo
  print_color "$YELLOW" "Select worktrees (comma-separated numbers, 'a' for all, 'q' to quit):"
  read -r selection

  case "$selection" in
  q | Q)
    print_color "$YELLOW" "Cancelled"
    exit 0
    ;;
  a | A)
    SELECTED_WORKTREES=("${worktrees[@]}")
    ALL_WORKTREES=true
    ;;
  *)
    IFS=',' read -ra indices <<<"$selection"
    for index in "${indices[@]}"; do
      # Remove whitespace
      index=$(echo "$index" | tr -d ' ')
      if [[ "$index" =~ ^[0-9]+$ ]] && [ "$index" -ge 1 ] && [ "$index" -le ${#worktrees[@]} ]; then
        SELECTED_WORKTREES+=("${worktrees[$((index - 1))]}")
      else
        print_color "$RED" "Invalid selection: $index"
        exit 1
      fi
    done
    ;;
  esac

  if [ ${#SELECTED_WORKTREES[@]} -eq 0 ]; then
    print_color "$RED" "No worktrees selected"
    exit 1
  fi
}

# Function to execute command on worktree
execute_on_worktree() {
  local worktree_path="$1"
  local command="$2"
  local info
  info=$(get_worktree_info "$worktree_path")

  print_color "$PURPLE" "═══════════════════════════════════════════════════════════════════════════════"
  print_color "$BLUE" "Worktree: $worktree_path ($info)"
  print_color "$PURPLE" "═══════════════════════════════════════════════════════════════════════════════"

  if [ "$DRY_RUN" = true ]; then
    print_color "$YELLOW" "[DRY RUN] Would execute: $command"
    print_color "$YELLOW" "[DRY RUN] In directory: $worktree_path"
    return 0
  fi

  if [ ! -d "$worktree_path" ]; then
    print_color "$RED" "Error: Worktree directory does not exist: $worktree_path"
    return 1
  fi

  # Execute command in worktree directory
  (
    cd "$worktree_path" || exit 1
    print_color "$GREEN" "Executing: $command"
    eval "$command"
  )
  local exit_code=$?

  if [ $exit_code -eq 0 ]; then
    print_color "$GREEN" "✓ Command completed successfully"
  else
    print_color "$RED" "✗ Command failed with exit code: $exit_code"
  fi

  echo
  return $exit_code
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
  -c | --command)
    COMMAND="$2"
    shift 2
    ;;
  -d | --dry-run)
    DRY_RUN=true
    shift
    ;;
  -a | --all)
    ALL_WORKTREES=true
    shift
    ;;
  -i | --interactive)
    INTERACTIVE=true
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    print_color "$RED" "Unknown option: $1"
    usage
    exit 1
    ;;
  esac
done

# Validate required arguments
if [ -z "$COMMAND" ]; then
  print_color "$RED" "Error: Command is required"
  usage
  exit 1
fi

# Get worktrees
if [ "$INTERACTIVE" = true ]; then
  select_worktrees
elif [ "$ALL_WORKTREES" = true ]; then
  while IFS= read -r worktree; do
    SELECTED_WORKTREES+=("$worktree")
  done < <(get_worktrees)

  if [ ${#SELECTED_WORKTREES[@]} -eq 0 ]; then
    print_color "$RED" "No worktrees found"
    exit 1
  fi
else
  print_color "$RED" "Error: Must specify either --all or --interactive"
  usage
  exit 1
fi

# Display summary
echo
print_color "$BLUE" "Summary:"
print_color "$CYAN" "Command: $COMMAND"
print_color "$CYAN" "Dry run: $DRY_RUN"
print_color "$CYAN" "Selected worktrees: ${#SELECTED_WORKTREES[@]}"
echo

if [ "$DRY_RUN" = false ]; then
  print_color "$YELLOW" "Press Enter to continue or Ctrl+C to cancel..."
  read -r
fi

# Execute command on selected worktrees
failed_count=0
for worktree in "${SELECTED_WORKTREES[@]}"; do
  if ! execute_on_worktree "$worktree" "$COMMAND"; then
    ((failed_count++))
  fi
done

# Final summary
echo
print_color "$PURPLE" "═══════════════════════════════════════════════════════════════════════════════"
if [ $failed_count -eq 0 ]; then
  print_color "$GREEN" "✓ All commands completed successfully!"
else
  print_color "$RED" "✗ $failed_count command(s) failed"
  exit 1
fi
