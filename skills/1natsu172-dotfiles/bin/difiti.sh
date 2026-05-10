#!/usr/bin/env zsh

difiti() {
  local from_commit to_commit from_hash to_hash

  from_commit=$(git log --oneline --decorate -100 --color=always | \
    fzf \
      --ansi \
      --header "> difit $TO $FROM~1" \
      --prompt "Select $FROM>" \
      --preview 'git log --oneline --decorate --color=always -1 {1}' \
      --preview-window=top:3:wrap
  ) || return
  from_hash="${from_commit%% *}"

  to_commit=$(git log --oneline --decorate -100 --color=always $from_hash~1.. | \
    fzf \
      --ansi \
      --header "> difit $TO $from_hash~1" \
      --prompt "Select $TO>" \
      --preview 'git log --oneline --decorate --color=always -1 {1}' \
      --preview-window=top:3:wrap
  ) || return
  to_hash="${to_commit%% *}"

  difit "$to_hash" "$from_hash~1"
}

# スクリプトが直接実行された場合に関数を呼び出す
if [[ "${(%):-%x}" == "${0}" ]]; then
  difiti "$@"
fi