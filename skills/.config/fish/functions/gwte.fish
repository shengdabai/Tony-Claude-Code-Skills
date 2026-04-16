function gwte --description 'Git WorkTree Executor - Execute commands on git worktrees'
    # Path to the shell script
    set script_path (dirname (status --current-filename))/../../../bin/gwte.sh

    # Check if script exists
    if not test -f $script_path
        echo "Error: gwte.sh script not found at $script_path"
        return 1
    end

    # Execute the shell script with all arguments passed through
    $script_path $argv
end
