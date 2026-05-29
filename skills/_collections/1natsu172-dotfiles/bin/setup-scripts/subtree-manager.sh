#!/usr/bin/env bash

set -euo pipefail

#====================================
# CONFIGURATION SECTION
#====================================
# Define all subtrees managed in this repository
# Format: "<category> <config_key> <git_url> <branch> <target_path>"
readonly SUBTREE_CONFIGS=(
    # "claude-agents claude-agents-wshobson https://github.com/wshobson/agents.git main .claude/agents/external/wshobson/agents"
    # "claude-slash-commands claude-slash-commands-wshobson https://github.com/wshobson/commands.git main .claude/commands/external/wshobson/commands"
    "test-own testing-subtree https://github.com/1natsu-vacation/subtree-test-children.git main .subtree-testing/subtree-test-children"
    # Add more subtrees here in the future:
    # "agents claude-agents-foo https://github.com/foo/agents.git main .claude/agents/external/foo/agents"
    # "themes ui-themes-awesome https://github.com/awesome/themes.git main .themes/external/awesome/themes"
)
#====================================

# Check if a subtree exists by checking if the prefix directory exists and has git history
subtree_exists() {
    local target_path="$1"
    [[ -d "$target_path" ]] && git log --oneline "$target_path" >/dev/null 2>&1
}

# Find subtree configuration by config key
find_subtree_config() {
    local config_key="$1"
    
    for entry in "${SUBTREE_CONFIGS[@]}"; do
        read -r category key git_url branch target_path <<< "$entry"
        if [[ "$key" == "$config_key" ]]; then
            echo "$category $git_url $branch $target_path"
            return 0
        fi
    done
    
    return 1
}

# List all configured subtrees and their status
list_subtrees() {
    echo "$(tput setaf 3)Managed Subtrees:$(tput sgr0)"
    echo "================="
    
    # Simple approach: sort by category then display
    {
        for entry in "${SUBTREE_CONFIGS[@]}"; do
            read -r category config_key git_url branch target_path <<< "$entry"
            echo "$category|$entry"
        done
    } | sort | {
        local current_category=""
        while IFS='|' read -r category entry; do
            read -r cat config_key git_url branch target_path <<< "$entry"
            
            # Show category header if changed
            if [[ "$category" != "$current_category" ]]; then
                echo
                echo "$(tput setaf 6)[$category]$(tput sgr0)"
                current_category="$category"
            fi
            
            # Extract author/repo from git_url for display
            author_repo=$(echo "$git_url" | sed -n 's|.*github\.com/\([^/]*/[^/]*\)\.git.*|\1|p')
            
            if subtree_exists "$target_path"; then
                echo "  $(tput setaf 2)✓$(tput sgr0) $config_key"
            else
                echo "  $(tput setaf 1)✗$(tput sgr0) $config_key"
            fi
            echo "    ├─ Repository: $author_repo"
            echo "    ├─ URL: $git_url#$branch"
            echo "    └─ Path: $target_path"
            echo
        done
    }
}

# Add a configured subtree (from SUBTREE_CONFIGS)
add_configured_subtree() {
    local config_key="$1"
    
    # Find the subtree configuration
    local config_result
    if ! config_result=$(find_subtree_config "$config_key"); then
        echo "$(tput setaf 1)Error: Subtree '$config_key' not found in SUBTREE_CONFIGS$(tput sgr0)"
        echo "Available subtrees:"
        for entry in "${SUBTREE_CONFIGS[@]}"; do
            read -r _ key _ _ _ <<< "$entry"
            echo "  - $key"
        done
        return 1
    fi
    
    read -r category git_url branch target_path <<< "$config_result"
    
    # Extract author/repo from git_url for display
    author_repo=$(echo "$git_url" | sed -n 's|.*github\.com/\([^/]*/[^/]*\)\.git.*|\1|p')

    echo "$(tput setaf 3)Adding subtree: $config_key$(tput sgr0)"
    echo "Category: $category"
    echo "Repository: $author_repo"
    echo "URL: $git_url#$branch"
    echo "Target: $target_path"
    echo
    
    # Ensure the parent directory exists
    mkdir -p "$(dirname "$target_path")"
    
    if git subtree add --prefix="$target_path" "$git_url" "$branch" --squash; then
        echo
        echo "$(tput setaf 2)Successfully added $config_key as subtree. ✔︎$(tput sgr0)"
    else
        echo "$(tput setaf 1)Failed to add $config_key subtree. ✗$(tput sgr0)"
        return 1
    fi

    return 0
}

# Update a specific subtree
update_subtree() {
    local config_key="$1"
    
    # Find the subtree configuration
    local config_result
    if ! config_result=$(find_subtree_config "$config_key"); then
        echo "$(tput setaf 1)Error: Subtree '$config_key' not found in configuration$(tput sgr0)"
        echo "Available subtrees:"
        for entry in "${SUBTREE_CONFIGS[@]}"; do
            read -r _ key _ _ _ <<< "$entry"
            echo "  - $key"
        done
        return 1
    fi
    
    read -r category git_url branch target_path <<< "$config_result"
    
    if ! subtree_exists "$target_path"; then
        echo "$(tput setaf 1)Error: Subtree '$config_key' does not exist at $target_path$(tput sgr0)"
        echo "Use 'add' command to add it first, or check the path."
        return 1
    fi
    
    # Extract author/repo from git_url for display
    author_repo=$(echo "$git_url" | sed -n 's|.*github\.com/\([^/]*/[^/]*\)\.git.*|\1|p')
    
    echo "$(tput setaf 3)Updating subtree: $config_key$(tput sgr0)"
    echo "Category: $category"
    echo "Repository: $author_repo"
    echo "From: $git_url#$branch"
    echo "To: $target_path"
    echo
    
    # Capture subtree pull output to check if update occurred
    local pull_output
    if pull_output=$(git subtree pull --prefix="$target_path" "$git_url" "$branch" --squash \
        -m "chore: update $config_key subtree from $author_repo

From: $git_url#$branch
Path: $target_path
Category: $category" 2>&1); then
        echo
        echo "$pull_output"
        
        # Check if subtree was actually updated
        if echo "$pull_output" | grep -q "Subtree is already at commit"; then
            echo "$(tput setaf 3)No updates available for $config_key. Already up to date. ✔︎$(tput sgr0)"
        else
            echo "$(tput setaf 2)Successfully updated $config_key. ✔︎$(tput sgr0)"
        fi
    else
        echo "$(tput setaf 1)Failed to update $config_key. ✗$(tput sgr0)"
        echo "$pull_output"
        return 1
    fi

    return 0
}

# Add all configured subtrees
add_all_subtrees() {
    echo "$(tput setaf 3)Adding all configured subtrees...$(tput sgr0)"
    echo
    
    local added_count=0
    local skipped_count=0
    local error_count=0
    
    for entry in "${SUBTREE_CONFIGS[@]}"; do
        read -r _ config_key _ _ target_path <<< "$entry"
        
        if subtree_exists "$target_path"; then
            echo "$(tput setaf 2)✓ $config_key already exists, skipping$(tput sgr0)"
            ((skipped_count++))
        else
            if add_configured_subtree "$config_key"; then
                ((added_count++))
            else
                ((error_count++))
            fi
        fi
        echo "----------------------------------------"
    done
    
    echo
    if [[ $error_count -eq 0 ]]; then
        echo "$(tput setaf 2)Summary: $added_count added, $skipped_count skipped. ✔︎$(tput sgr0)"
    else
        echo "$(tput setaf 1)$error_count errors occurred. ✗$(tput sgr0)"
        echo "$(tput setaf 2)Summary: $added_count added, $skipped_count skipped.$(tput sgr0)"
        return 1
    fi
    
    return 0
}

# Update all configured subtrees
update_all_subtrees() {
    echo "$(tput setaf 3)Updating all managed subtrees...$(tput sgr0)"
    echo
    
    local updated_count=0
    local error_count=0
    
    for entry in "${SUBTREE_CONFIGS[@]}"; do
        read -r _ config_key _ _ _ <<< "$entry"
        
        if update_subtree "$config_key"; then
            ((updated_count++))
        else
            ((error_count++))
        fi
        echo "----------------------------------------"
    done
    
    echo
    if [[ $error_count -eq 0 ]]; then
        echo "$(tput setaf 2)All $updated_count subtrees updated successfully. ✔︎$(tput sgr0)"
    else
        echo "$(tput setaf 1)$error_count errors occurred during updates. ✗$(tput sgr0)"
        echo "$(tput setaf 2)$updated_count subtrees updated successfully. ✔︎$(tput sgr0)"
        return 1
    fi
    
    return 0
}

# Display usage information
show_usage() {
    echo "Subtree Manager"
    echo "==============="
    echo
    echo "A configuration-driven tool for managing git subtrees in your repository."
    echo
    echo "Usage: $0 <command> [arguments]"
    echo
    echo "Commands:"
    echo "  list                    List all configured subtrees and their status"
    echo "  add <config_key>        Add a specific configured subtree"
    echo "  add-all                 Add all configured subtrees (skip existing)"
    echo "  update <config_key>     Update a specific subtree"
    echo "  update-all              Update all configured subtrees"
    echo "  help                    Show this help message"
    echo
    echo "Workflow:"
    echo "  1. Edit SUBTREE_CONFIGS array in this script to add subtree configuration"
    echo "  2. Run 'add <config_key>' or 'add-all' to create the actual subtrees"
    echo "  3. Use 'update <config_key>' or 'update-all' to pull upstream changes"
    echo
    echo "Examples:"
    echo "  $0 list                          # Show status of all configured subtrees"
    echo "  $0 add claude-agents-wshobson    # Add the claude-agents-wshobson subtree if not exists"
    echo "  $0 add-all                       # Add all configured subtrees (safe to re-run)"
    echo "  $0 update claude-agents-wshobson # Update claude-agents-wshobson from upstream"
    echo "  $0 update-all                    # Update all existing subtrees"
}

# Command line interface
case "${1:-}" in
    "list")
        list_subtrees
        ;;
    "add")
        if [[ $# -ne 2 ]]; then
            echo "$(tput setaf 1)Error: 'add' requires 1 argument$(tput sgr0)"
            echo "Usage: $0 add <config_key>"
            exit 1
        fi
        add_configured_subtree "$2"
        ;;
    "add-all")
        add_all_subtrees
        ;;
    "update")
        if [[ $# -ne 2 ]]; then
            echo "$(tput setaf 1)Error: 'update' requires 1 argument$(tput sgr0)"
            echo "Usage: $0 update <config_key>"
            exit 1
        fi
        update_subtree "$2"
        ;;
    "update-all")
        update_all_subtrees
        ;;
    "help"|"-h"|"--help")
        show_usage
        ;;
    "")
        echo "$(tput setaf 1)Error: No command specified$(tput sgr0)"
        echo
        show_usage
        exit 1
        ;;
    *)
        echo "$(tput setaf 1)Error: Unknown command '$1'$(tput sgr0)"
        echo
        show_usage
        exit 1
        ;;
esac
