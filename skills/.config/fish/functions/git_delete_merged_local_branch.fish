
# Ref: delete normal_merged_branches: https://stackoverflow.com/questions/6127328/how-do-i-delete-all-git-branches-which-have-been-merged
# Ref: delete squash_merged_branches: https://stackoverflow.com/questions/43489303/how-can-i-delete-all-git-branches-which-have-been-squash-and-merge-via-github
function git_delete_merged_local_branch -d "Delete all merged local branches"
  set -f script_dir (dirname (status --file))

  set -f default_branch_name (git symbolic-ref refs/remotes/origin/HEAD --short | xargs basename)

  echo default_branch_name: "$default_branch_name"

  if test (count $argv) -eq 0
    set -f ignore_branch "(^\*|$default_branch_name)"
  else
    set -f ignore_branch "(^\*|$default_branch_name|$argv[1])"
  end

  echo ignore_branch regex: "$ignore_branch"

  set -f normal_merged_branches (git branch --merged)

  echo normal_merged_branches: "$normal_merged_branches"

  set -f squash_merged_branches (sh $script_dir/__my_scripts/get_git_squash_merged_branch.sh $default_branch_name)

  echo squash_merged_branches: "$squash_merged_branches"


  echo "Try delete no needed remotes" && git fetch -p

  echo "Try delete branches that normal_merged_branches" && echo "$normal_merged_branches" | grep -vE $ignore_branch | xargs git branch -d

  echo "Try delete branches that squash_merged_branches" && echo "$squash_merged_branches" | grep -vE $ignore_branch | xargs git branch -D
end