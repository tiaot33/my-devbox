#!/usr/bin/env bash
# =============================================================================
# devbox-init — Debian/Ubuntu 无头开发环境初始化脚本
#
#   安装系统包 · 字体 · Starship 提示符 · 终端工具 · dotfiles · Git 配置
#
#   运行:   bash devbox-init.sh
#           sudo bash devbox-init.sh
#
#   语言工具链 (Node / Python / Go / Bun / Deno) 请单独运行 devbox-lang.sh
# =============================================================================

set -uo pipefail
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export APT_LISTCHANGES_FRONTEND=none

# ── 输出辅助函数 ────────────────────────────────────────────────────────────

log()   { printf '\n\033[1;34m▶ %s\033[0m\n'  "$*"; }
warn()  { printf '  \033[1;33m⚠  %s\033[0m\n' "$*" >&2; }
step()  { printf '  \033[36m▸ %s\033[0m\n'  "$*"; }
ok()    { printf '  \033[32m✔ %s\033[0m\n'  "$*"; }
skip()  { printf '  \033[90m— %s (跳过)\033[0m\n' "$*"; }

download() {
  curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --retry-connrefused "$1" -o "$2" && [ -s "$2" ]
}

# ── 环境检测 ────────────────────────────────────────────────────────────────

# shellcheck disable=SC1091
[ -r /etc/os-release ] && . /etc/os-release
case "${ID:-}" in
  ubuntu|debian) ;;
  *) warn "当前系统: ${PRETTY_NAME:-unknown OS}；脚本预期 Debian/Ubuntu，结果可能不完整" ;;
esac

# ── 权限上下文 ──────────────────────────────────────────────────────────────

if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
else
  command -v sudo >/dev/null 2>&1 || { printf '  \033[1;31m✘ sudo 未安装\033[0m\n' >&2; exit 1; }
  SUDO="sudo"
fi

DISPATCHER="${SUDO_USER:-${USER:-$(id -un)}}"
id "$DISPATCHER" >/dev/null 2>&1 || DISPATCHER="$(id -un)"
DISPATCHER_HOME="$(getent passwd "$DISPATCHER" | cut -d: -f6)"
[ -n "$DISPATCHER_HOME" ] || DISPATCHER_HOME="$HOME"
DISPATCHER_GROUP="$(id -gn "$DISPATCHER")"

if [ "$DISPATCHER" = "$(id -un)" ]; then
  AS_USER="bash -lc"
else
  AS_USER="sudo -H -u $DISPATCHER bash -lc"
fi

# ── 辅助函数 ────────────────────────────────────────────────────────────────

SUMMARY_PACKAGES=()
SUMMARY_TOOLS=()
SUMMARY_SYSTEM=()
SUMMARY_DIRS=()
SUMMARY_FILES=()
SUMMARY_LINKS=()
SUMMARY_SKIPPED=()
SUMMARY_FAILED=()
SUMMARY_EDIT_HINTS=()
APT_PACKAGES_CONFIRMED=()
APT_PACKAGES_FAILED=()

summary_add() {
  local section="$1" item="$2"
  case "$section" in
    packages) SUMMARY_PACKAGES+=("$item") ;;
    tools) SUMMARY_TOOLS+=("$item") ;;
    system) SUMMARY_SYSTEM+=("$item") ;;
    dirs) SUMMARY_DIRS+=("$item") ;;
    files) SUMMARY_FILES+=("$item") ;;
    links) SUMMARY_LINKS+=("$item") ;;
    skipped) SUMMARY_SKIPPED+=("$item") ;;
    failed) SUMMARY_FAILED+=("$item") ;;
    edit) SUMMARY_EDIT_HINTS+=("$item") ;;
  esac
}

summary_add_each() {
  local section="$1" item
  shift
  for item in "$@"; do
    summary_add "$section" "$item"
  done
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

apt_install_optional() {
  local pkg
  for pkg in "$@"; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
      APT_PACKAGES_CONFIRMED+=("$pkg")
      continue
    fi
    if $SUDO apt-get install -y --no-install-recommends "$pkg"; then
      APT_PACKAGES_CONFIRMED+=("$pkg")
    else
      APT_PACKAGES_FAILED+=("$pkg")
      warn "apt 包跳过: $pkg"
    fi
  done
}

ensure_dir_user() {
  $SUDO mkdir -p "$@"
  $SUDO chown -R "$DISPATCHER:$DISPATCHER_GROUP" "$@" 2>/dev/null || true
  summary_add_each dirs "$@"
}

append_line_once() {
  local file="$1" line="$2"
  $SUDO touch "$file"
  if ! grep -Fqx "$line" "$file" 2>/dev/null; then
    printf '\n%s\n' "$line" | $SUDO tee -a "$file" >/dev/null
    summary_add files "$file (追加: $line)"
  else
    summary_add skipped "$file (入口已存在，未重复追加)"
  fi
  $SUDO chown "$DISPATCHER:$DISPATCHER_GROUP" "$file" 2>/dev/null || true
}

write_user_file() {
  local tmp dest
  tmp=$(mktemp) || { warn "mktemp 失败"; return 1; }
  cat > "$tmp"
  for dest in "$@"; do
    if $SUDO install -m 0644 "$tmp" "$dest"; then
      $SUDO chown "$DISPATCHER:$DISPATCHER_GROUP" "$dest"
      summary_add files "$dest (覆盖写入)"
    else
      summary_add failed "$dest: 写入失败"
    fi
  done
  rm -f "$tmp"
}

write_user_file_once() {
  local tmp dest="$1"
  tmp=$(mktemp) || { warn "mktemp 失败"; return 1; }
  cat > "$tmp"
  if [ -e "$dest" ]; then
    rm -f "$tmp"
    summary_add skipped "$dest (已存在，未覆盖)"
    return 0
  fi
  if $SUDO install -m 0644 "$tmp" "$dest"; then
    $SUDO chown "$DISPATCHER:$DISPATCHER_GROUP" "$dest"
    summary_add files "$dest (首次创建，后续不覆盖)"
  else
    summary_add failed "$dest: 写入失败"
  fi
  rm -f "$tmp"
}

download_and_run() {
  local name="$1" url="$2" interp="$3"; shift 3
  local tmp
  tmp=$(mktemp /tmp/devbox-init.XXXXXX)
  trap 'rm -f "$tmp"' RETURN
  if curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --retry-connrefused "$url" -o "$tmp" && [ -s "$tmp" ]; then
    if $AS_USER "$interp \"$tmp\" $*"; then
      return 0
    fi
    warn "$name: 安装脚本返回非零退出码"
    return 1
  else
    warn "$name: 下载失败"
    return 1
  fi
}

add_apt_repo() {
  local name="$1" key_url="$2" key_dest="$3" repo_line="$4" mode="${5:-}"
  local list="/etc/apt/sources.list.d/${name}.list"
  [ -f "$list" ] && { skip "$name 仓库已存在"; summary_add skipped "$list (仓库已存在，未改动)"; return 0; }
  local key
  key=$(mktemp) || { warn "$name: mktemp 失败"; summary_add failed "$name APT 仓库: mktemp 失败"; return 1; }
  trap 'rm -f "$key"' RETURN
  if ! download "$key_url" "$key"; then
    warn "$name: 密钥下载失败"
    summary_add failed "$name APT 仓库: 密钥下载失败"
    return 1
  fi
  if [ "$mode" = "dearmor" ]; then
    $SUDO rm -f "$key_dest"
    $SUDO gpg --dearmor -o "$key_dest" "$key" || { warn "$name: 密钥转换失败"; summary_add failed "$name APT 仓库: 密钥转换失败"; return 1; }
    $SUDO chmod 0644 "$key_dest"
  else
    if ! $SUDO install -m 0644 "$key" "$key_dest"; then
      warn "$name: 密钥写入失败"
      summary_add failed "$name APT 仓库: 密钥写入失败"
      return 1
    fi
  fi
  if ! printf '%s\n' "$repo_line" | $SUDO tee "$list" >/dev/null; then
    warn "$name: source list 写入失败"
    summary_add failed "$name APT 仓库: source list 写入失败"
    return 1
  fi
  summary_add system "$key_dest"
  summary_add system "$list"
  ok "$name 仓库已添加"
}

install_lazygit() {
  local arch lazygit_arch version url tmpdir archive
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) lazygit_arch="x86_64" ;;
    aarch64|arm64) lazygit_arch="arm64" ;;
    armv7l|armhf) lazygit_arch="armv7" ;;
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

  tmpdir="$(mktemp -d /tmp/lazygit.XXXXXX)" || { warn "lazygit: mktemp 失败"; return 1; }
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
  if ! $SUDO install -m 0755 "$tmpdir/lazygit" /usr/local/bin/lazygit; then
    warn "lazygit: 写入 /usr/local/bin/lazygit 失败"
    summary_add failed "lazygit: 写入 /usr/local/bin/lazygit 失败"
    rm -rf "$tmpdir"
    return 1
  fi

  rm -rf "$tmpdir"
  summary_add tools "lazygit: /usr/local/bin/lazygit"
  ok "lazygit 已安装"
}

# ═══════════════════════════════════════════════════════════════════════════
# 开始安装
# ═══════════════════════════════════════════════════════════════════════════

printf '\033[1;37m\n'
printf '  ╔════════════════════════════════════════════════════╗\n'
printf '  ║  %-50s  ║\n' "🛠️  devbox-init 开发环境初始化"
printf '  ║  %-50s  ║\n' "   系统包 · 字体 · 终端工具 · dotfiles"
printf '  ╚════════════════════════════════════════════════════╝\n'
printf '\033[0m'

log "📋 目标用户: \033[1m$DISPATCHER\033[0m (主目录: $DISPATCHER_HOME)"

# ═══════════════════════════════════════════════════════════════════════════
# 📦 APT 基础包
# ═══════════════════════════════════════════════════════════════════════════
log "📦 APT 更新 & 基础包"
step "apt-get update ..."
$SUDO apt-get update

CORE_PACKAGES=(
  sudo ca-certificates curl wget gnupg
  locales tzdata bash-completion man-db
  fontconfig
  build-essential pkg-config make gawk
  git
  unzip zip tar xz-utils zstd gzip file less tree
  vim nano tmux htop jq
  iproute2 dnsutils
)
step "安装基础包 (${#CORE_PACKAGES[@]} 个) ..."
if $SUDO apt-get install -y --no-install-recommends "${CORE_PACKAGES[@]}"; then
  summary_add packages "基础 APT 包：${CORE_PACKAGES[*]}"
  ok "基础包安装完成"
else
  summary_add failed "基础 APT 包安装失败：${CORE_PACKAGES[*]}"
  warn "基础包安装失败"
fi

OPTIONAL_PACKAGES=(
  neovim fzf ripgrep fd-find
  bat shellcheck shfmt direnv
  btop ncdu duf du-dust git-delta fastfetch
)
step "安装可选包 (${#OPTIONAL_PACKAGES[@]} 个) ..."
apt_install_optional "${OPTIONAL_PACKAGES[@]}"
ok "可选包步骤完成"

# ═══════════════════════════════════════════════════════════════════════════
# 🔒 自动安全更新
# ═══════════════════════════════════════════════════════════════════════════
log "🔒 自动安全更新 (unattended-upgrades)"
step "安装 unattended-upgrades ..."
apt_install_optional unattended-upgrades
if dpkg -s unattended-upgrades >/dev/null 2>&1; then
  $SUDO tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null <<'EOF_AUTO_UPGRADES'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF_AUTO_UPGRADES
  summary_add system "/etc/apt/apt.conf.d/20auto-upgrades"
  ok "unattended-upgrades 已启用"
else
  summary_add skipped "unattended-upgrades 未安装成功，未写入 /etc/apt/apt.conf.d/20auto-upgrades"
  skip "unattended-upgrades 安装失败，跳过"
fi

# ═══════════════════════════════════════════════════════════════════════════
# 🌐 Locale
# ═══════════════════════════════════════════════════════════════════════════
log "🌐 Locale — en_US.UTF-8"
if grep -q '^# *en_US.UTF-8 UTF-8' /etc/locale.gen 2>/dev/null; then
  $SUDO sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
  summary_add system "/etc/locale.gen (启用 en_US.UTF-8 UTF-8)"
fi
if $SUDO locale-gen en_US.UTF-8 >/dev/null 2>&1; then
  ok "locale-gen en_US.UTF-8 完成"
else
  summary_add failed "locale-gen en_US.UTF-8 失败"
  warn "locale-gen en_US.UTF-8 失败"
fi
if $SUDO update-locale LANG=en_US.UTF-8 >/dev/null 2>&1; then
  summary_add system "/etc/default/locale (LANG=en_US.UTF-8)"
  ok "en_US.UTF-8 已配置"
else
  summary_add failed "update-locale LANG=en_US.UTF-8 失败"
  warn "update-locale LANG=en_US.UTF-8 失败"
fi

# ═══════════════════════════════════════════════════════════════════════════
# 🔑 第三方 APT 仓库
# ═══════════════════════════════════════════════════════════════════════════
log "🔑 第三方 APT 仓库 — GitHub CLI · eza"
$SUDO install -m 0755 -d /etc/apt/keyrings
summary_add dirs "/etc/apt/keyrings"
ARCH="$(dpkg --print-architecture 2>/dev/null || true)"

add_apt_repo github-cli https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  /etc/apt/keyrings/githubcli-archive-keyring.gpg \
  "deb [arch=$ARCH signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main"

add_apt_repo gierens https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
  /etc/apt/keyrings/gierens.gpg \
  "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" dearmor

step "apt-get update ..."
if ! $SUDO apt-get update; then
  warn "第三方仓库 apt update 失败"
  summary_add failed "第三方仓库 apt update 失败"
fi
step "安装 gh · eza ..."
apt_install_optional gh eza
ok "GitHub CLI & eza 步骤完成"

# ═══════════════════════════════════════════════════════════════════════════
# 🐙 lazygit
# ═══════════════════════════════════════════════════════════════════════════
log "🐙 lazygit — Git TUI"
step "安装 lazygit 到 /usr/local/bin ..."
install_lazygit

# ═══════════════════════════════════════════════════════════════════════════
# 📁 用户目录 & 兼容软链接
# ═══════════════════════════════════════════════════════════════════════════
log "📁 用户目录 & 兼容软链接"
ensure_dir_user "$DISPATCHER_HOME/.local/bin" "$DISPATCHER_HOME/.local/src" \
  "$DISPATCHER_HOME/.local/share/fonts" "$DISPATCHER_HOME/.config" \
  "$DISPATCHER_HOME/.cache"
ok "目录已创建"

if [ -x /usr/bin/batcat ]; then
  $SUDO ln -sf /usr/bin/batcat "$DISPATCHER_HOME/.local/bin/bat"
  $SUDO chown -h "$DISPATCHER:$DISPATCHER_GROUP" "$DISPATCHER_HOME/.local/bin/bat" 2>/dev/null || true
  summary_add links "$DISPATCHER_HOME/.local/bin/bat -> /usr/bin/batcat"
  step "batcat → bat"
fi
if [ -x /usr/bin/fdfind ]; then
  $SUDO ln -sf /usr/bin/fdfind "$DISPATCHER_HOME/.local/bin/fd"
  $SUDO chown -h "$DISPATCHER:$DISPATCHER_GROUP" "$DISPATCHER_HOME/.local/bin/fd" 2>/dev/null || true
  summary_add links "$DISPATCHER_HOME/.local/bin/fd -> /usr/bin/fdfind"
  step "fdfind → fd"
fi

# ═══════════════════════════════════════════════════════════════════════════
# 🚀 Starship 提示符
# ═══════════════════════════════════════════════════════════════════════════
log "🚀 Starship 提示符"
starship_tmp=$(mktemp)
if download https://starship.rs/install.sh "$starship_tmp"; then
  step "安装 Starship 到 /usr/local/bin ..."
  if $SUDO sh "$starship_tmp" -y -b /usr/local/bin; then
    if command -v starship >/dev/null 2>&1; then
      summary_add tools "Starship: $(command -v starship)"
    else
      summary_add tools "Starship: 安装器执行成功，当前 PATH 未检测到 starship"
    fi
  else
    warn "Starship 安装失败"
    summary_add failed "Starship: 安装失败"
  fi
else
  warn "Starship: 下载失败"
  summary_add failed "Starship: 下载失败"
fi
rm -f "$starship_tmp"

step "生成预设配置 ..."
# shellcheck disable=SC2016
if ! $AS_USER 'mkdir -p "$HOME/.config" &&
  command -v starship >/dev/null 2>&1 &&
  starship preset nerd-font-symbols -o "$HOME/.config/starship.toml"'; then
  warn "Starship 预设生成失败"
  summary_add failed "Starship: 预设配置生成失败"
fi
step "追加性能参数 ..."
if [ -f "$DISPATCHER_HOME/.config/starship.toml" ]; then
  tmp=$(mktemp) || { warn "mktemp 失败"; rm -f "$tmp"; }
  { printf 'add_newline = true\nscan_timeout = 10\n\n'; cat "$DISPATCHER_HOME/.config/starship.toml"; } > "$tmp"
  $SUDO install -m 0644 "$tmp" "$DISPATCHER_HOME/.config/starship.toml"
  $SUDO chown "$DISPATCHER:$DISPATCHER_GROUP" "$DISPATCHER_HOME/.config/starship.toml" 2>/dev/null || true
  summary_add files "$DISPATCHER_HOME/.config/starship.toml (生成并覆盖写入)"
  rm -f "$tmp"
fi
ok "Starship 配置完成"

# ═══════════════════════════════════════════════════════════════════════════
# 🔤 ComicShannsMono Nerd Font
# ═══════════════════════════════════════════════════════════════════════════
log "🔤 ComicShannsMono Nerd Font"
font_zip=$(mktemp /tmp/ComicShannsMono.XXXXXX.zip)
if download https://github.com/ryanoasis/nerd-fonts/releases/latest/download/ComicShannsMono.zip "$font_zip"; then
  step "解压字体 ..."
  if $SUDO unzip -o "$font_zip" -d "$DISPATCHER_HOME/.local/share/fonts" >/dev/null; then
    $SUDO chown -R "$DISPATCHER:$DISPATCHER_GROUP" "$DISPATCHER_HOME/.local/share/fonts" 2>/dev/null || true
    # shellcheck disable=SC2016
    $AS_USER 'fc-cache -fv "$HOME/.local/share/fonts" >/dev/null || true'
    summary_add files "$DISPATCHER_HOME/.local/share/fonts/ (解压 ComicShannsMono.zip)"
    ok "字体安装完成"
  else
    warn "字体解压失败"
    summary_add failed "ComicShannsMono Nerd Font: 解压失败"
  fi
else
  warn "字体下载失败"
  summary_add failed "ComicShannsMono Nerd Font: 下载失败"
fi
rm -f "$font_zip"

# ═══════════════════════════════════════════════════════════════════════════
# 🧩 终端工具 — zoxide · Atuin · Herdr · ble.sh
# ═══════════════════════════════════════════════════════════════════════════
log "🧩 终端工具 — zoxide · Atuin · Herdr · ble.sh"

step "安装 zoxide (智能 cd) ..."
# shellcheck disable=SC2016
if download_and_run "zoxide" "https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh" sh &&
  $AS_USER 'test -x "$HOME/.local/bin/zoxide" || command -v zoxide >/dev/null 2>&1'; then
  summary_add tools "zoxide: 命令已检测到"
else
  summary_add failed "zoxide: 安装后未检测到命令"
fi

step "安装 Atuin (shell 历史) ..."
# shellcheck disable=SC2016
if download_and_run "Atuin" "https://setup.atuin.sh" sh --non-interactive &&
  $AS_USER 'test -x "$HOME/.atuin/bin/atuin" || command -v atuin >/dev/null 2>&1'; then
  summary_add tools "Atuin: 命令已检测到"
else
  summary_add failed "Atuin: 安装后未检测到命令"
fi

step "安装 Herdr (agent multiplexer) ..."
# shellcheck disable=SC2016
if download_and_run "Herdr" "https://herdr.dev/install.sh" sh &&
  $AS_USER 'test -x "$HOME/.local/bin/herdr" || command -v herdr >/dev/null 2>&1'; then
  summary_add tools "Herdr: 命令已检测到"
else
  summary_add failed "Herdr: 安装后未检测到命令"
fi

step "安装 ble.sh (bash 增强) ..."
# shellcheck disable=SC2016
if $AS_USER '
  rm -rf "$HOME/.local/src/ble.sh"
  git clone --recursive --depth 1 --shallow-submodules https://github.com/akinomyoga/ble.sh.git "$HOME/.local/src/ble.sh" &&
  make -C "$HOME/.local/src/ble.sh" install PREFIX="$HOME/.local" &&
  test -s "$HOME/.local/share/blesh/ble.sh"
'; then
  summary_add tools "ble.sh: $DISPATCHER_HOME/.local/share/blesh/ble.sh"
else
  summary_add failed "ble.sh: 安装或检测失败"
fi
ok "终端工具步骤完成"

# ═══════════════════════════════════════════════════════════════════════════
# 📝 Dotfiles
# ═══════════════════════════════════════════════════════════════════════════
log "📝 Dotfiles — bash · tmux · vim · git · editorconfig"
ensure_dir_user "$DISPATCHER_HOME/.config/starship" "$DISPATCHER_HOME/.config/atuin" "$DISPATCHER_HOME/.config/nvim" "$DISPATCHER_HOME/.config/shell"

step "写入 ~/.bashrc.generated ..."
write_user_file "$DISPATCHER_HOME/.bashrc.generated" <<'EOF_BASHRC'
# ~/.bashrc.generated - 由 devbox-init 生成
# 请不要手改此文件；重新运行初始化脚本会覆盖。
# 个人自定义请放到 ~/.config/shell/local.sh。

[[ $- != *i* ]] && return

# ── 环境变量 ─────────────────────────────────────────────────────────────────

export LANG=${LANG:-en_US.UTF-8}
export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
export XDG_CACHE_HOME=${XDG_CACHE_HOME:-$HOME/.cache}
export XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
if [[ -z ${TERM:-} || ${TERM:-} == dumb ]]; then
  export TERM=xterm-256color
fi
export PATH="$HOME/.local/bin:$HOME/.atuin/bin:$PATH"

if command -v nvim >/dev/null 2>&1; then
  export EDITOR=nvim
else
  export EDITOR=vim
fi
export VISUAL="$EDITOR"
export PAGER=less
if less --help 2>&1 | grep -q -- '--mouse'; then
  export LESS='-R -F -X -i -M --mouse --wheel-lines=3'
else
  export LESS='-R -F -X -i -M'
fi
export BAT_PAGER=less
if command -v batcat >/dev/null 2>&1; then
  export MANPAGER="sh -c 'col -bx | batcat -l man -p'"
elif command -v bat >/dev/null 2>&1; then
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
else
  export MANPAGER='less -R'
fi

# ── Shell 行为 ───────────────────────────────────────────────────────────────

export HISTSIZE=200000
export HISTFILESIZE=400000
export HISTCONTROL=ignoreboth:erasedups
export HISTTIMEFORMAT='%F %T  '
export HISTIGNORE='ls:ll:la:lt:l:history:exit:clear:bg:fg:cd:z:atuin'
shopt -s histappend cmdhist checkwinsize globstar autocd dirspell 2>/dev/null || true
stty -ixon 2>/dev/null || true
bind 'set bell-style none' 2>/dev/null || true

# ── 补全 ─────────────────────────────────────────────────────────────────────

if [ -f /etc/bash_completion ]; then
  source /etc/bash_completion
fi

if [ -f /usr/share/doc/fzf/examples/key-bindings.bash ]; then
  source /usr/share/doc/fzf/examples/key-bindings.bash
fi
if [ -f /usr/share/doc/fzf/examples/completion.bash ]; then
  source /usr/share/doc/fzf/examples/completion.bash
fi
if command -v fd >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --follow --exclude .git 2>/dev/null'
elif command -v fdfind >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='fdfind --type f --strip-cwd-prefix --hidden --follow --exclude .git 2>/dev/null'
else
  export FZF_DEFAULT_COMMAND='find . -type f 2>/dev/null'
fi
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# ── 工具集成 (加载顺序很重要) ─────────────────────────────────────────────────

# ble.sh — 必须在其他集成之前加载
if [[ -s "$HOME/.local/share/blesh/ble.sh" ]]; then
  source -- "$HOME/.local/share/blesh/ble.sh" --attach=none
fi

# direnv
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook bash)"
fi

# zoxide — 智能 cd
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init bash)"
  alias cd='z'
fi

# Atuin — shell 历史搜索
if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init bash --disable-up-arrow)"
fi

# Starship — 命令行提示符 (必须最后加载)
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi

# ── 别名 & 实用函数 ─────────────────────────────────────────────────────────

[ -f "$HOME/.config/shell/aliases.sh" ]   && source "$HOME/.config/shell/aliases.sh"
[ -f "$HOME/.config/shell/functions.sh" ] && source "$HOME/.config/shell/functions.sh"
[ -f "$HOME/.config/shell/local.sh" ]     && source "$HOME/.config/shell/local.sh"

# ── SSH 登录 ─────────────────────────────────────────────────────────────────

if [[ -n ${SSH_CONNECTION-} ]]; then
  if command -v fastfetch >/dev/null 2>&1; then
    fastfetch
  fi
fi

# ble.sh — 在所有交互式设置之后附加
[[ ! ${BLE_VERSION-} ]] || ble-attach
EOF_BASHRC

# shellcheck disable=SC2016
append_line_once "$DISPATCHER_HOME/.bashrc" '[ -f "$HOME/.bashrc.generated" ] && source "$HOME/.bashrc.generated"'
ok "$DISPATCHER_HOME/.bashrc.generated → $DISPATCHER_HOME/.bashrc"

step "写入 ~/.config/shell/aliases.sh ..."
write_user_file "$DISPATCHER_HOME/.config/shell/aliases.sh" <<'EOF_ALIASES'
# ~/.config/shell/aliases.sh - 由 devbox-init 生成
# 请不要手改此文件；重新运行初始化脚本会覆盖。
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
EOF_ALIASES
ok "$DISPATCHER_HOME/.config/shell/aliases.sh 已写入"

step "创建用户自定义 shell 文件 ..."
write_user_file_once "$DISPATCHER_HOME/.config/shell/functions.sh" <<'EOF_FUNCTIONS'
# ~/.config/shell/functions.sh
# 用户自定义函数。devbox-init 只在文件不存在时创建，后续不会覆盖。
EOF_FUNCTIONS
write_user_file_once "$DISPATCHER_HOME/.config/shell/local.sh" <<'EOF_LOCAL'
# ~/.config/shell/local.sh
# 用户自定义 alias、环境变量和 shell 设置。devbox-init 只在文件不存在时创建，后续不会覆盖。
EOF_LOCAL
ok "$DISPATCHER_HOME/.config/shell/functions.sh · $DISPATCHER_HOME/.config/shell/local.sh 已就绪"

step "写入 ~/.tmux.conf ..."
write_user_file "$DISPATCHER_HOME/.tmux.conf" <<'EOF_TMUX'
set -g mouse on
set -g history-limit 100000
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -s set-clipboard external
set -g default-terminal "tmux-256color"
set -g escape-time 10
set -g focus-events on
setw -g mode-keys vi
bind r source-file ~/.tmux.conf \; display-message 'tmux config reloaded'
bind | split-window -h
bind - split-window -v
EOF_TMUX
ok "$DISPATCHER_HOME/.tmux.conf 已写入"

step "写入 ~/.vimrc ..."
write_user_file "$DISPATCHER_HOME/.vimrc" "$DISPATCHER_HOME/.config/nvim/init.vim" <<'EOF_VIM'
set nocompatible
set encoding=utf-8
set number
set relativenumber
set hidden
set mouse=a
set ignorecase
set smartcase
set incsearch
set hlsearch
set tabstop=4
set shiftwidth=4
set expandtab
set autoindent
set wildmenu
set laststatus=2
syntax on
filetype plugin indent on
EOF_VIM
ok "$DISPATCHER_HOME/.vimrc · $DISPATCHER_HOME/.config/nvim/init.vim 已写入"

step "写入 ~/.inputrc ..."
write_user_file "$DISPATCHER_HOME/.inputrc" <<'EOF_INPUTRC'
set completion-ignore-case on
set show-all-if-ambiguous on
set show-all-if-unmodified on
set mark-symlinked-directories on
set colored-stats on
set colored-completion-prefix on
set menu-complete-display-prefix on
"\e[A": history-search-backward
"\e[B": history-search-forward
EOF_INPUTRC
ok "$DISPATCHER_HOME/.inputrc 已写入"

step "写入 ~/.editorconfig ..."
write_user_file "$DISPATCHER_HOME/.editorconfig" <<'EOF_EDITORCONFIG'
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space
indent_size = 2

[*.{go,py,rs,java}]
indent_size = 4

[Makefile]
indent_style = tab
EOF_EDITORCONFIG
ok "$DISPATCHER_HOME/.editorconfig 已写入"

step "写入 ~/.gitignore_global ..."
write_user_file "$DISPATCHER_HOME/.gitignore_global" <<'EOF_GITIGNORE'
.DS_Store
Thumbs.db
*.swp
*.swo
*~
.env
.env.*
!.env.example
.vscode/
.idea/
__pycache__/
.pytest_cache/
.mypy_cache/
.ruff_cache/
node_modules/
dist/
build/
target/
EOF_GITIGNORE
ok "$DISPATCHER_HOME/.gitignore_global 已写入"

step "写入 ~/.blerc ..."
write_user_file "$DISPATCHER_HOME/.blerc" <<'EOF_BLERC'
bleopt complete_auto_complete=1
bleopt complete_menu_complete=1
bleopt complete_menu_style=desc
bleopt edit_abbrev=1 2>/dev/null || true
bleopt prompt_eol_mark='↵'
bleopt complete_limit_auto=2000
bleopt complete_menu_maxlines=10
bleopt complete_ignore_case=1 2>/dev/null || true
bleopt history_share=1
ble-face auto_complete='fg=240,underline,italic'
EOF_BLERC
ok "$DISPATCHER_HOME/.blerc 已写入"

step "写入 ~/.config/atuin/config.toml ..."
write_user_file "$DISPATCHER_HOME/.config/atuin/config.toml" <<'EOF_ATUIN'
style = "compact"
inline_height = 20
show_help = false
enter_accept = true
filter_mode = "global"
search_mode = "daemon-fuzzy"

[daemon]
enabled = true
autostart = true
EOF_ATUIN
ok "$DISPATCHER_HOME/.config/atuin/config.toml 已写入"
ok "所有 dotfiles 写入完成"

# ═══════════════════════════════════════════════════════════════════════════
# 🔧 Git 默认配置
# ═══════════════════════════════════════════════════════════════════════════
log "🔧 Git 默认配置"
$AS_USER 'git config --global init.defaultBranch main || true'
$AS_USER 'git config --global color.ui auto || true'
$AS_USER 'git config --global core.editor "nvim" || true'
# shellcheck disable=SC2016
$AS_USER 'git config --global core.excludesfile "$HOME/.gitignore_global" || true'
$AS_USER 'git config --global pull.rebase false || true'
$AS_USER 'git config --global fetch.prune true || true'
$AS_USER 'git config --global rerere.enabled true || true'
$AS_USER 'git config --global diff.algorithm histogram || true'
$AS_USER 'git config --global merge.conflictstyle zdiff3 || true'
$AS_USER 'git config --global push.autoSetupRemote true || true'
$AS_USER 'git config --global column.ui auto || true'
$AS_USER 'git config --global help.autocorrect 1 || true'
$AS_USER 'git config --global rebase.autosquash true || true'
$AS_USER 'git config --global rebase.autostash true || true'
$AS_USER 'git config --global tag.sort version:refname || true'
$AS_USER 'if command -v delta >/dev/null 2>&1; then
  git config --global core.pager "delta"
  git config --global interactive.diffFilter "delta --color-only"
  git config --global delta.navigate true
  git config --global delta.side-by-side true
fi || true'
if [ -f "$DISPATCHER_HOME/.gitconfig" ]; then
  summary_add files "$DISPATCHER_HOME/.gitconfig (git config --global)"
else
  summary_add skipped "$DISPATCHER_HOME/.gitconfig (git config --global 后未检测到文件)"
fi
ok "Git 配置完成"

# ═══════════════════════════════════════════════════════════════════════════
# 🧹 清理
# ═══════════════════════════════════════════════════════════════════════════
log "🧹 清理"
step "apt autoremove & autoclean ..."
$SUDO apt-get autoremove -y >/dev/null 2>&1 || true
$SUDO apt-get autoclean -y >/dev/null 2>&1 || true
ok "清理完成"

# ═══════════════════════════════════════════════════════════════════════════
# 安装完成
# ═══════════════════════════════════════════════════════════════════════════

printf '\n\033[1;32m'
printf '  ╔════════════════════════════════════════════════════╗\n'
printf '  ║  %-50s ║\n' "✨ 系统初始化完成！"
printf '  ╚════════════════════════════════════════════════════╝\n'
printf '\033[0m\n'

if [ "${#APT_PACKAGES_CONFIRMED[@]}" -gt 0 ]; then
  summary_add packages "附加 APT 包：${APT_PACKAGES_CONFIRMED[*]}"
fi
if [ "${#APT_PACKAGES_FAILED[@]}" -gt 0 ]; then
  summary_add failed "APT 包安装失败或跳过：${APT_PACKAGES_FAILED[*]}"
fi

summary_add edit "$DISPATCHER_HOME/.config/shell/local.sh：个人 alias、环境变量、shell 设置；脚本后续不会覆盖"
summary_add edit "$DISPATCHER_HOME/.config/shell/functions.sh：个人 shell 函数；脚本后续不会覆盖"
summary_add edit "$DISPATCHER_HOME/.config/shell/aliases.sh：devbox 默认 alias；重新运行脚本会覆盖"
summary_add edit "$DISPATCHER_HOME/.bashrc.generated：devbox shell 主配置；重新运行脚本会覆盖"
summary_add edit "$DISPATCHER_HOME/.config/starship.toml：Starship 提示符配置；重新运行脚本可能覆盖"
summary_add edit "$DISPATCHER_HOME/.config/atuin/config.toml：Atuin 配置；重新运行脚本会覆盖"
summary_add edit "$DISPATCHER_HOME/.tmux.conf：tmux 配置；重新运行脚本会覆盖"
summary_add edit "$DISPATCHER_HOME/.vimrc 和 $DISPATCHER_HOME/.config/nvim/init.vim：Vim/Neovim 配置；重新运行脚本会覆盖"
summary_add edit "$DISPATCHER_HOME/.gitconfig：Git 全局配置"
summary_add edit "$DISPATCHER_HOME/.gitignore_global：Git 全局忽略文件；重新运行脚本会覆盖"

printf '  目标用户: %s\n' "$DISPATCHER"
printf '  用户目录: %s\n\n' "$DISPATCHER_HOME"

summary_print_list "📦 已确认存在的包" "${SUMMARY_PACKAGES[@]}"
summary_print_list "🧩 终端工具结果" "${SUMMARY_TOOLS[@]}"
summary_print_list "🛠️ 系统配置改动" "${SUMMARY_SYSTEM[@]}"
summary_print_list "📁 已确认存在的目录" "${SUMMARY_DIRS[@]}"
summary_print_list "📝 主动写入或修改的用户文件" "${SUMMARY_FILES[@]}"
summary_print_list "🔗 主动创建的软链接" "${SUMMARY_LINKS[@]}"
summary_print_list "— 未改动/跳过" "${SUMMARY_SKIPPED[@]}"
summary_print_list "⚠ 失败或未确认成功" "${SUMMARY_FAILED[@]}"
summary_print_list "✏️ 后续想改配置，看这里" "${SUMMARY_EDIT_HINTS[@]}"

printf '  语言工具链 Node / Python / Go / Bun / Deno 不在本脚本内；需要时单独运行:\n'
printf '     \033[1mbash devbox-lang.sh\033[0m\n\n'
printf '  让 shell 配置立即生效:\n'
printf '     \033[1msource ~/.bashrc\033[0m\n'
