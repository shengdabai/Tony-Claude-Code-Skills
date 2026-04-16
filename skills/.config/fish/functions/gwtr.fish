# Remove worktree using fzf
function gwtr -d "Remove a git worktree using fzf"
    if not type -q fzf
        echo "Error: fzf is not installed. Please install fzf first."
        return 1
    end

    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "Error: Not in a git repository."
        return 1
    end

    # 現在のworktreeは除外して表示
    set current_worktree (pwd)
    set selected_worktree (git worktree list | grep -v "^$current_worktree " | fzf --height=40% --reverse --border --prompt="Select worktree to remove: " | awk '{print $1}')

    if test -n "$selected_worktree"
        echo "Removing worktree: $selected_worktree"
        git worktree remove "$selected_worktree"
    end
end
