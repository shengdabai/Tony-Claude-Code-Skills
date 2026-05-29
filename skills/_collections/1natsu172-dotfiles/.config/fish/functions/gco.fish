function gco --wraps "git switch" --description "alias git branch create or switch if exist"
  if test (count $argv) -eq 1
    git switch $argv[1] 2>/dev/null || git switch -c $argv[1];
  else if test (count $argv) -eq 2
    git switch $argv[1] 2>/dev/null || git switch -c $argv[1] $argv[2];
  else
    echo "Usage: gco <branch-name> [start-point]"
    return 1
  end
end
