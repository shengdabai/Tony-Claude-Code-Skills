#!/usr/bin/env bash
set -euo pipefail

TARGET_BRANCH=$1

results=$(
  git for-each-ref refs/heads/ "--format=%(refname:short)" |
    while read -r branch; do
      mergeBase=$(git merge-base $TARGET_BRANCH $branch)

      if [[ $(git cherry $TARGET_BRANCH $(git commit-tree $(git rev-parse $branch\^{tree}) -p $mergeBase -m _)) == "-"* ]]; then
        echo "$branch"
      fi

    done
)

echo "$results"
