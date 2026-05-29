if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi
. "$HOME/.cargo/env"

export GPG_TTY=$(tty)
