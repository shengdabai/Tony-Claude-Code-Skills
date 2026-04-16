export PATH="/usr/local/sbin:$PATH"

# added by travis gem
[ -f /Users/1natsu/.travis/travis.sh ] && source /Users/1natsu/.travis/travis.sh

[ -f ~/.fzf.bash ] && source ~/.fzf.bash
. "$HOME/.cargo/env"
