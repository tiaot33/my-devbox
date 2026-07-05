#!/usr/bin/env bash

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export APT_LISTCHANGES_FRONTEND=none

log()   { printf '\n\033[1;34m▶ %s\033[0m\n' "$*"; }
warn()  { printf '  \033[1;33m⚠ %s\033[0m\n' "$*" >&2; }
step()  { printf '  \033[36m▸ %s\033[0m\n' "$*"; }
ok()    { printf '  \033[32m✔ %s\033[0m\n' "$*"; }
skip()  { printf '  \033[90m— %s (跳过)\033[0m\n' "$*"; }

usage() {
  cat <<'EOF'
用法:
  bash hermes-init.sh

安装内容:
  基础系统工具
  人工维护工具
  GitHub CLI
  uv
  Starship
  lazygit / lazyssh / ble.sh / btop
  root 低侵入交互 shell 增强
EOF
}

export PATH="/usr/local/bin:/root/.local/bin:$PATH"

SUMMARY_INSTALLED=()
SUMMARY_SKIPPED=()
SUMMARY_FAILED=()

os_release_value() {
  local key="$1"
  [ -r /etc/os-release ] || return 1
  awk -F= -v key="$key" '
    $1 == key {
      value = substr($0, length(key) + 2)
      gsub(/^"/, "", value)
      gsub(/"$/, "", value)
      print value
      exit
    }
  ' /etc/os-release
}

if [ "$#" -gt 0 ]; then
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf '\033[1;31m✘ 未知参数: %s\033[0m\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
fi

OS_ID="$(os_release_value ID || true)"
OS_VERSION_ID="$(os_release_value VERSION_ID || true)"
OS_PRETTY_NAME="$(os_release_value PRETTY_NAME || printf 'unknown OS')"
case "$OS_ID:$OS_VERSION_ID" in
  ubuntu:26.*|debian:13*) ;;
  ubuntu:*|debian:*) warn "当前系统: $OS_PRETTY_NAME；推荐使用 Ubuntu 26 / Debian 13" ;;
  *) warn "当前系统: $OS_PRETTY_NAME；脚本预期 Debian/Ubuntu，结果可能不完整" ;;
esac

if [ "$(id -u)" -ne 0 ]; then
  printf '\033[1;31m✘ 请直接以 root 身份运行\033[0m\n' >&2
  exit 1
fi

summary_add() {
  local section="$1" item="$2"
  case "$section" in
    installed) SUMMARY_INSTALLED+=("$item") ;;
    skipped) SUMMARY_SKIPPED+=("$item") ;;
    failed) SUMMARY_FAILED+=("$item") ;;
  esac
}

summary_print_list() {
  local title="$1" item
  shift
  [ "$#" -gt 0 ] || return 0
  printf '  %s\n' "$title"
  for item in "$@"; do
    printf '     - %s\n' "$item"
  done
  printf '\n'
}

print_summary() {
  summary_print_list "已安装 / 已配置" "${SUMMARY_INSTALLED[@]}"
  summary_print_list "已跳过" "${SUMMARY_SKIPPED[@]}"
  summary_print_list "失败项" "${SUMMARY_FAILED[@]}"
}

apt_install_required() {
  local label="$1"
  shift
  if apt-get install -y --no-install-recommends "$@"; then
    summary_add installed "$label：$*"
    return 0
  fi

  summary_add failed "$label 安装失败：$*"
  return 1
}

write_root_file() {
  local dest="$1" mode="${2:-0644}" tmp
  tmp="$(mktemp)" || {
    warn "$dest: mktemp 失败"
    summary_add failed "$dest: mktemp 失败"
    return 1
  }
  cat >"$tmp"
  if install -m "$mode" "$tmp" "$dest"; then
    summary_add installed "$dest"
  else
    warn "$dest: 写入失败"
    summary_add failed "$dest: 写入失败"
  fi
  rm -f "$tmp"
}

download() {
  curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --retry-connrefused "$1" -o "$2" && [ -s "$2" ]
}

skip_if_command_exists() {
  local label="$1" command_name="$2" command_path
  if command_path="$(command -v "$command_name" 2>/dev/null)"; then
    skip "$label 已安装: $command_path"
    summary_add skipped "$label: $command_path (已安装，未改动)"
    return 0
  fi
  return 1
}

add_github_cli_repo() {
  local arch list key_dest
  list="/etc/apt/sources.list.d/github-cli.list"
  key_dest="/etc/apt/keyrings/githubcli-archive-keyring.gpg"

  if ! arch="$(dpkg --print-architecture)"; then
    warn "GitHub CLI: 无法识别系统架构"
    summary_add failed "GitHub CLI APT 仓库: 无法识别系统架构"
    return 1
  fi

  if [ -f "$list" ]; then
    skip "GitHub CLI 仓库已存在"
    summary_add skipped "$list (仓库已存在，未改动)"
    return 0
  fi

  if ! install -m 0755 -d /etc/apt/keyrings; then
    warn "GitHub CLI: /etc/apt/keyrings 创建失败"
    summary_add failed "GitHub CLI APT 仓库: /etc/apt/keyrings 创建失败"
    return 1
  fi
  summary_add installed "/etc/apt/keyrings"

  if ! download "https://cli.github.com/packages/githubcli-archive-keyring.gpg" "$key_dest"; then
    warn "GitHub CLI: 密钥下载失败"
    summary_add failed "GitHub CLI APT 仓库: 密钥下载失败"
    return 1
  fi
  chmod 0644 "$key_dest"

  if ! printf 'deb [arch=%s signed-by=%s] https://cli.github.com/packages stable main\n' "$arch" "$key_dest" >"$list"; then
    warn "GitHub CLI: source list 写入失败"
    summary_add failed "GitHub CLI APT 仓库: source list 写入失败"
    return 1
  fi

  summary_add installed "$key_dest"
  summary_add installed "$list"
  ok "GitHub CLI 仓库已添加"
}

install_github_cli() {
  if skip_if_command_exists "GitHub CLI" gh; then
    return 0
  fi

  add_github_cli_repo || return 1

  step "apt-get update ..."
  if ! apt-get update; then
    warn "GitHub CLI: apt-get update 失败"
    summary_add failed "GitHub CLI: apt-get update 失败"
    return 1
  fi

  if apt-get install -y --no-install-recommends gh; then
    summary_add installed "GitHub CLI: gh"
    return 0
  fi

  warn "GitHub CLI: gh 安装失败"
  summary_add failed "GitHub CLI: gh 安装失败"
  return 1
}

install_uv() {
  local uv_tmp
  if skip_if_command_exists "uv" uv; then
    return 0
  fi

  uv_tmp="$(mktemp /tmp/uv-installer.XXXXXX)" || {
    warn "uv: mktemp 失败"
    summary_add failed "uv: mktemp 失败"
    return 1
  }

  if download "https://astral.sh/uv/install.sh" "$uv_tmp"; then
    step "安装 uv 到 /usr/local/bin ..."
    if UV_INSTALL_DIR=/usr/local/bin UV_NO_MODIFY_PATH=1 sh "$uv_tmp"; then
      if command -v uv >/dev/null 2>&1; then
        summary_add installed "uv: $(command -v uv)"
      else
        summary_add installed "uv: 安装器执行成功，当前 PATH 未检测到 uv"
      fi
      rm -f "$uv_tmp"
      return 0
    fi
    warn "uv 安装失败"
    summary_add failed "uv: 安装失败"
  else
    warn "uv: 下载失败"
    summary_add failed "uv: 下载失败"
  fi

  rm -f "$uv_tmp"
  return 1
}

install_starship() {
  local starship_tmp
  if skip_if_command_exists "Starship" starship; then
    return 0
  fi

  starship_tmp="$(mktemp /tmp/starship-installer.XXXXXX)" || {
    warn "Starship: mktemp 失败"
    summary_add failed "Starship: mktemp 失败"
    return 1
  }

  if download "https://starship.rs/install.sh" "$starship_tmp"; then
    step "安装 Starship 到 /usr/local/bin ..."
    if sh "$starship_tmp" -y -b /usr/local/bin; then
      if command -v starship >/dev/null 2>&1; then
        summary_add installed "Starship: $(command -v starship)"
      else
        summary_add installed "Starship: 安装器执行成功，当前 PATH 未检测到 starship"
      fi
      rm -f "$starship_tmp"
      return 0
    fi
    warn "Starship 安装失败"
    summary_add failed "Starship: 安装失败"
  else
    warn "Starship: 下载失败"
    summary_add failed "Starship: 下载失败"
  fi

  rm -f "$starship_tmp"
  return 1
}

install_lazygit() {
  local arch lazygit_arch version url tmpdir archive
  if skip_if_command_exists "lazygit" lazygit; then
    return 0
  fi

  arch="$(uname -m)"
  case "$arch" in
    x86_64 | amd64) lazygit_arch="x86_64" ;;
    aarch64 | arm64) lazygit_arch="arm64" ;;
    armv7l | armhf) lazygit_arch="armv7" ;;
    *)
      warn "lazygit: 不支持的架构 $arch"
      summary_add failed "lazygit: 不支持的架构 $arch"
      return 1
      ;;
  esac

  version="$(curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --retry-connrefused \
    https://api.github.com/repos/jesseduffield/lazygit/releases/latest |
    sed -n 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/p' |
    head -n 1)"
  if [ -z "$version" ]; then
    warn "lazygit: 未能获取最新版本号"
    summary_add failed "lazygit: 未能获取最新版本号"
    return 1
  fi

  tmpdir="$(mktemp -d /tmp/lazygit.XXXXXX)" || {
    warn "lazygit: mktemp 失败"
    summary_add failed "lazygit: mktemp 失败"
    return 1
  }
  archive="$tmpdir/lazygit.tar.gz"
  url="https://github.com/jesseduffield/lazygit/releases/download/v${version}/lazygit_${version}_Linux_${lazygit_arch}.tar.gz"

  if ! download "$url" "$archive"; then
    warn "lazygit: 下载失败 ($url)"
    summary_add failed "lazygit: 下载失败"
    rm -rf "$tmpdir"
    return 1
  fi
  if ! tar -xzf "$archive" -C "$tmpdir" lazygit; then
    warn "lazygit: 解压失败"
    summary_add failed "lazygit: 解压失败"
    rm -rf "$tmpdir"
    return 1
  fi
  if ! install -m 0755 "$tmpdir/lazygit" /usr/local/bin/lazygit; then
    warn "lazygit: 写入 /usr/local/bin/lazygit 失败"
    summary_add failed "lazygit: 写入 /usr/local/bin/lazygit 失败"
    rm -rf "$tmpdir"
    return 1
  fi

  rm -rf "$tmpdir"
  summary_add installed "lazygit: /usr/local/bin/lazygit"
  ok "lazygit 已安装"
}

install_lazyssh() {
  local arch lazyssh_arch tag url tmpdir archive
  if skip_if_command_exists "lazyssh" lazyssh; then
    return 0
  fi

  arch="$(uname -m)"
  case "$arch" in
    x86_64 | amd64) lazyssh_arch="x86_64" ;;
    aarch64 | arm64) lazyssh_arch="arm64" ;;
    *)
      warn "lazyssh: 不支持的架构 $arch"
      summary_add failed "lazyssh: 不支持的架构 $arch"
      return 1
      ;;
  esac

  tag="$(curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --retry-connrefused \
    https://api.github.com/repos/Adembc/lazyssh/releases/latest |
    sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' |
    head -n 1)"
  if [ -z "$tag" ]; then
    warn "lazyssh: 未能获取最新版本号"
    summary_add failed "lazyssh: 未能获取最新版本号"
    return 1
  fi

  tmpdir="$(mktemp -d /tmp/lazyssh.XXXXXX)" || {
    warn "lazyssh: mktemp 失败"
    summary_add failed "lazyssh: mktemp 失败"
    return 1
  }
  archive="$tmpdir/lazyssh.tar.gz"
  url="https://github.com/Adembc/lazyssh/releases/download/${tag}/lazyssh_Linux_${lazyssh_arch}.tar.gz"

  if ! download "$url" "$archive"; then
    warn "lazyssh: 下载失败 ($url)"
    summary_add failed "lazyssh: 下载失败"
    rm -rf "$tmpdir"
    return 1
  fi
  if ! tar -xzf "$archive" -C "$tmpdir" lazyssh; then
    warn "lazyssh: 解压失败"
    summary_add failed "lazyssh: 解压失败"
    rm -rf "$tmpdir"
    return 1
  fi
  if ! install -m 0755 "$tmpdir/lazyssh" /usr/local/bin/lazyssh; then
    warn "lazyssh: 写入 /usr/local/bin/lazyssh 失败"
    summary_add failed "lazyssh: 写入 /usr/local/bin/lazyssh 失败"
    rm -rf "$tmpdir"
    return 1
  fi

  rm -rf "$tmpdir"
  summary_add installed "lazyssh: /usr/local/bin/lazyssh"
  ok "lazyssh 已安装"
}

install_blesh() {
  if [ -s /root/.local/share/blesh/ble.sh ]; then
    skip "ble.sh 已安装: /root/.local/share/blesh/ble.sh"
    summary_add skipped "ble.sh: /root/.local/share/blesh/ble.sh (已安装，未改动)"
    return 0
  fi

  mkdir -p /root/.local/src /root/.local/share
  rm -rf /root/.local/src/ble.sh.new
  if git clone --recursive --depth 1 --shallow-submodules https://github.com/akinomyoga/ble.sh.git /root/.local/src/ble.sh.new &&
    make -C /root/.local/src/ble.sh.new install PREFIX=/root/.local &&
    [ -s /root/.local/share/blesh/ble.sh ]; then
    rm -rf /root/.local/src/ble.sh
    mv /root/.local/src/ble.sh.new /root/.local/src/ble.sh
    summary_add installed "ble.sh: /root/.local/share/blesh/ble.sh"
    ok "ble.sh 已安装"
    return 0
  fi

  rm -rf /root/.local/src/ble.sh.new
  warn "ble.sh: 安装或检测失败"
  summary_add failed "ble.sh: 安装或检测失败"
  return 1
}

configure_shell_profile() {
  write_root_file /etc/profile.d/hermes-shell.sh <<'SHELL_PROFILE'
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
SHELL_PROFILE

  if [ ! -f /root/.bashrc ]; then
    : >/root/.bashrc
    chmod 0644 /root/.bashrc
    summary_add installed "/root/.bashrc"
  fi

  if grep -q 'BEGIN hermes-init shell profile' /root/.bashrc 2>/dev/null; then
    summary_add skipped "/root/.bashrc (hermes-init 加载块已存在，未改动)"
    return 0
  fi

  cat >>/root/.bashrc <<'BASHRC'

# BEGIN hermes-init shell profile
if [ -r /etc/profile.d/hermes-shell.sh ]; then
  . /etc/profile.d/hermes-shell.sh
fi
# END hermes-init shell profile
BASHRC
  summary_add installed "/root/.bashrc (追加 hermes-init 加载块)"
}

configure_root_dotfiles() {
  write_root_file /root/.inputrc <<'INPUTRC'
set completion-ignore-case on
set show-all-if-ambiguous on
set show-all-if-unmodified on
set mark-symlinked-directories on
set colored-stats on
set colored-completion-prefix on
"\e[A": history-search-backward
"\e[B": history-search-forward
INPUTRC

  write_root_file /root/.vimrc <<'VIMRC'
set nocompatible
set encoding=utf-8
set number
set ignorecase
set smartcase
set incsearch
set hlsearch
set tabstop=4
set shiftwidth=4
set expandtab
set autoindent
syntax on
filetype plugin indent on
VIMRC

  write_root_file /root/.tmux.conf <<'TMUX'
set -g mouse on
set -g history-limit 100000
set -g default-terminal "tmux-256color"
set -g escape-time 10
setw -g mode-keys vi
bind r source-file ~/.tmux.conf \; display-message 'tmux config reloaded'
bind | split-window -h
bind - split-window -v
TMUX

  write_root_file /root/.blerc <<'BLERC'
bleopt complete_auto_complete=1
bleopt complete_menu_complete=1
bleopt complete_menu_style=desc
bleopt complete_limit_auto=2000
bleopt complete_menu_maxlines=10
bleopt complete_ignore_case=1 2>/dev/null || true
bleopt history_share=1
ble-face auto_complete='fg=240,underline,italic'
BLERC
}

configure_locale() {
  if grep -q '^# *en_US.UTF-8 UTF-8' /etc/locale.gen 2>/dev/null; then
    sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
    summary_add installed "/etc/locale.gen (启用 en_US.UTF-8 UTF-8)"
  fi

  if locale-gen en_US.UTF-8 >/dev/null 2>&1; then
    summary_add installed "locale: en_US.UTF-8"
  else
    warn "locale-gen en_US.UTF-8 失败"
    summary_add failed "locale-gen en_US.UTF-8 失败"
  fi

  if update-locale LANG=en_US.UTF-8 >/dev/null 2>&1; then
    summary_add installed "/etc/default/locale (LANG=en_US.UTF-8)"
  else
    warn "update-locale LANG=en_US.UTF-8 失败"
    summary_add failed "update-locale LANG=en_US.UTF-8 失败"
  fi
}

printf '\033[1;37m\n'
printf '  ╔════════════════════════════════════════════════════╗\n'
printf '  ║  %-50s  ║\n' "Hermes 外部环境"
printf '  ║  %-50s  ║\n' "   维护工具 · GitHub CLI · uv · Shell"
printf '  ╚════════════════════════════════════════════════════╝\n'
printf '\033[0m'

log "APT 更新"
step "apt-get update ..."
apt-get update

MAINTENANCE_PACKAGES=(
  ca-certificates curl wget gnupg
  locales tzdata bash-completion man-db
  build-essential pkg-config make gawk
  git openssh-client
  less tree vim nano tmux htop jq
  unzip zip tar xz-utils zstd gzip file
  iproute2 dnsutils
  ripgrep fzf
  shellcheck shfmt
  bat fd-find btop
)

log "人工维护工具"
step "安装 ${#MAINTENANCE_PACKAGES[@]} 个维护工具包 ..."
apt_install_required "人工维护工具" "${MAINTENANCE_PACKAGES[@]}" || exit 1
ok "人工维护工具安装完成"

log "Locale"
configure_locale
ok "locale 配置步骤完成"

log "GitHub CLI"
install_github_cli || true

log "uv"
install_uv || true

log "Starship"
install_starship || true

log "Terminal TUI Tools"
install_lazygit || true
install_lazyssh || true
install_blesh || true

log "Shell Profile"
configure_shell_profile
ok "root 交互 shell 增强已配置"

log "Root Dotfiles"
configure_root_dotfiles
ok "root 低侵入 dotfiles 已配置"

log "清理 APT 缓存"
apt-get autoremove -y >/dev/null 2>&1 || true
apt-get autoclean -y >/dev/null 2>&1 || true
ok "清理完成"

printf '\n\033[1;32mHermes 外部环境初始化完成\033[0m\n\n'
print_summary
