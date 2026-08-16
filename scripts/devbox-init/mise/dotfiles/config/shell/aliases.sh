# ~/.config/shell/aliases.sh - 由 scripts/devbox-init/mise 生成
# 请不要手改此文件；重新运行 mise bootstrap 会覆盖。
# 个人 alias 请放到 ~/.config/shell/local.sh。

# ── 导航 ──

alias ..='cd ..'
alias ...='cd ../..'
alias -- -='cd -'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias diff='diff --color=auto'
alias mkdir='mkdir -pv'
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -I'
alias ip='ip -color=auto'
alias path='printf "%s\n" ${PATH//:/ }'
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons=auto --group-directories-first'
  alias l='eza -lah --icons=auto --group-directories-first --git'
  alias ll='eza -lah --header --icons=auto --group-directories-first --git'
  alias la='eza -a --icons=auto --group-directories-first'
  alias lt='eza --tree --level=2 --icons=auto --group-directories-first'
else
  alias l='ls -lah'
  alias ll='ls -alF'
  alias la='ls -A'
fi

if command -v bat >/dev/null 2>&1; then
  alias catp='bat --paging=never --style=plain'
  alias catn='bat --paging=never --style=numbers'
fi

command -v rg >/dev/null 2>&1 && alias rgrep='rg'
command -v btop >/dev/null 2>&1 && alias top='btop'
command -v duf >/dev/null 2>&1 && alias df='duf'
command -v dust >/dev/null 2>&1 && alias dud='dust'
command -v delta >/dev/null 2>&1 && alias gd='git diff'
command -v nvim >/dev/null 2>&1 && alias vim='nvim' && alias vi='nvim'
command -v kubectl >/dev/null 2>&1 && alias k='kubectl'
