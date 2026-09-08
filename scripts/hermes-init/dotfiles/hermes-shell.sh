# 只增强 root 的交互 bash。非交互命令、脚本和其它用户不受影响。
[ "$(id -u)" -eq 0 ] || return 0 2>/dev/null || exit 0
[ -n "${BASH_VERSION:-}" ] || return 0 2>/dev/null || exit 0
case "$-" in
  *i*) ;;
  *) return 0 2>/dev/null || exit 0 ;;
esac
[ -z "${HERMES_SHELL_PROFILE_LOADED:-}" ] || return 0 2>/dev/null || exit 0
export HERMES_SHELL_PROFILE_LOADED=1

export LANG=${LANG:-en_US.UTF-8}
export PATH="/root/.local/bin:/usr/local/bin:$PATH"
export EDITOR=vim
export VISUAL="$EDITOR"
export PAGER=less
export LESS='-R -F -X -i -M'
export BAT_PAGER=less

[ -f /etc/bash_completion ] && . /etc/bash_completion

if [ -f /usr/share/doc/fzf/examples/key-bindings.bash ]; then
  . /usr/share/doc/fzf/examples/key-bindings.bash
fi
if [ -f /usr/share/doc/fzf/examples/completion.bash ]; then
  . /usr/share/doc/fzf/examples/completion.bash
fi

if [ -s /root/.local/share/blesh/ble.sh ]; then
  . /root/.local/share/blesh/ble.sh --attach=none
fi

alias l='ls -lah'
alias ll='ls -alF'
alias la='ls -A'
alias path='printf "%s\n" ${PATH//:/ }'
command -v batcat >/dev/null 2>&1 && alias bat='batcat'
command -v fdfind >/dev/null 2>&1 && alias fd='fdfind'
command -v rg >/dev/null 2>&1 && alias rgrep='rg'

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi

if [ -n "${BLE_VERSION:-}" ]; then
  ble-attach
fi
