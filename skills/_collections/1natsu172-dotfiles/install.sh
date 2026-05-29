#!/usr/bin/env bash
DOT_DIRECTORY="${HOME}/dotfiles"
SPECIFY_FILES="Brewfile Brewfile.lock.json AGENTS.md" # 複数ファイルは""の中に半角スペース空けで入力しましょう

# ドットファイルとドットファイル以外の特定ファイルを回す
for f in .??* ${SPECIFY_FILES}; do
  # ルートにシンボリックリンクは貼りたくない無視したいファイルやディレクトリはこんな風に追加してね
  [[ ${f} = ".git" ]] && continue
  [[ ${f} = ".github" ]] && continue
  [[ ${f} = ".gitignore" ]] && continue
  [[ ${f} = ".gitmodules" ]] && continue
  [[ ${f} = ".DS_Store" ]] && continue
  [[ ${f} = ".travis.yml" ]] && continue
  [[ ${f} = ".direnv" ]] && continue
  [[ ${f} = ".envrc" ]] && continue
  ln -snfv "${DOT_DIRECTORY}/${f}" "${HOME}/${f}"
done

# Make bin directory executable
if [[ -d "${DOT_DIRECTORY}/bin" ]]; then
  chmod +x "${DOT_DIRECTORY}"/bin/*
  echo "$(tput setaf 3)Made bin scripts executable$(tput sgr0)"
fi

echo "$(tput setaf 2)Deploy dotfiles complete!. ✔︎$(tput sgr0)"
