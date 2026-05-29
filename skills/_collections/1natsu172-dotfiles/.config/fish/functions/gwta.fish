# Create new worktree with branch name
function gwta -d "Create a new git worktree and add it"
    if test (count $argv) -eq 0
        echo "Usage: gwta <branch-name> [path]"
        echo "Example: gwta feature/new-feature"
        echo "         gwta feature/new-feature ../project-feature"
        return 1
    end

    set branch_name $argv[1]

    if test (count $argv) -ge 2
        set worktree_path $argv[2]
    else
        # デフォルトのパスを生成（現在のディレクトリ名-ブランチ名）
        set current_dir (basename (pwd))
        set worktree_path "../$current_dir-$branch_name"
    end

    git worktree add "$worktree_path" "$branch_name"

    if test $status -eq 0
        # Fix remote.origin.fetch configuration for the new worktree
        pushd "$worktree_path"
        git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
        popd

        echo "Created worktree at: $worktree_path"
        echo "Fixed remote.origin.fetch configuration"
        echo "Switch to it with: cd $worktree_path"
        echo "Or use 'gwts' to select interactively"
    end
end
