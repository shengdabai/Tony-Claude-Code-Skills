# Fish completions for gwte (Git WorkTree Executor)

# Complete options
complete -c gwte -s c -l command -d 'Command to execute on worktrees' -r
complete -c gwte -s d -l dry-run -d 'Show what would be executed without running'
complete -c gwte -s a -l all -d 'Execute on all worktrees'
complete -c gwte -s i -l interactive -d 'Interactive mode to select worktrees'
complete -c gwte -s h -l help -d 'Show help message'

# Complete common git commands when using --command
complete -c gwte -n '__fish_seen_subcommand_from --command -c' -a status -d 'Show git status'
complete -c gwte -n '__fish_seen_subcommand_from --command -c' -a pull -d 'Pull changes'
complete -c gwte -n '__fish_seen_subcommand_from --command -c' -a push -d 'Push changes'
complete -c gwte -n '__fish_seen_subcommand_from --command -c' -a fetch -d 'Fetch changes'
complete -c gwte -n '__fish_seen_subcommand_from --command -c' -a log -d 'Show git log'
complete -c gwte -n '__fish_seen_subcommand_from --command -c' -a diff -d 'Show git diff'
complete -c gwte -n '__fish_seen_subcommand_from --command -c' -a branch -d 'Show branches'
