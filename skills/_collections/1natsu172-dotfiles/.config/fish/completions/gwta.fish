# Completions for gwta command

# Function to get clean branch names
function __gwta_get_branches
    git branch --all 2>/dev/null | string replace -r '^\s*\*?\s*' '' | string replace -r '^remotes/origin/' '' | string match -v 'HEAD*' | sort -u
end

# Complete branch names for the first argument
complete -c gwta -n __fish_use_subcommand -f -a "(__gwta_get_branches)" -d "Git branch"

# Complete directory paths for the second argument
complete -c gwta -n "test (count (commandline -opc)) -eq 2" -xa "(__fish_complete_directories)" -d "Worktree path"
