#!/usr/bin/env bash
# mise 声明不了的 extras：GitHub CLI 官方源、uv、starship、
# lazygit / lazyssh GitHub Release、ble.sh、locale。
# 行为和 hermes-init.sh 对齐：已装则跳过，单项失败不阻断后续。
set -euo pipefail

export PATH="/usr/local/bin:/root/.local/bin:$PATH"

log()   { printf '\n\033[1;34m▶ %s\033[0m\n' "$*"; }
warn()  { printf '  \033[1;33m⚠ %s\033[0m\n' "$*" >&2; }
step()  { printf '  \033[36m▸ %s\033[0m\n' "$*"; }
ok()    { printf '  \033[32m✔ %s\033[0m\n' "$*"; }
skip()  { printf '  \033[90m— %s (跳过)\033[0m\n' "$*"; }

download() {
  curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --retry-connrefused "$1" -o "$2" && [ -s "$2" ]
}

skip_if_command_exists() {
  local label="$1" command_name="$2" command_path
  if command_path="$(command -v "$command_name" 2>/dev/null)"; then
    skip "$label 已安装: $command_path"
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
    return 1
  fi

  if [ -f "$list" ]; then
    skip "GitHub CLI 仓库已存在"
    return 0
  fi

  if ! install -m 0755 -d /etc/apt/keyrings; then
    warn "GitHub CLI: /etc/apt/keyrings 创建失败"
    return 1
  fi

  if ! download "https://cli.github.com/packages/githubcli-archive-keyring.gpg" "$key_dest"; then
    warn "GitHub CLI: 密钥下载失败"
    return 1
  fi
  chmod 0644 "$key_dest"

  if ! printf 'deb [arch=%s signed-by=%s] https://cli.github.com/packages stable main\n' "$arch" "$key_dest" >"$list"; then
    warn "GitHub CLI: source list 写入失败"
    return 1
  fi

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
    return 1
  fi

  if apt-get install -y --no-install-recommends gh; then
    ok "GitHub CLI 已安装"
    return 0
  fi

  warn "GitHub CLI: gh 安装失败"
  return 1
}

install_uv() {
  local uv_tmp
  if skip_if_command_exists "uv" uv; then
    return 0
  fi

  uv_tmp="$(mktemp /tmp/uv-installer.XXXXXX)" || {
    warn "uv: mktemp 失败"
    return 1
  }

  if download "https://astral.sh/uv/install.sh" "$uv_tmp"; then
    step "安装 uv 到 /usr/local/bin ..."
    if UV_INSTALL_DIR=/usr/local/bin UV_NO_MODIFY_PATH=1 sh "$uv_tmp"; then
      ok "uv 已安装"
      rm -f "$uv_tmp"
      return 0
    fi
    warn "uv 安装失败"
  else
    warn "uv: 下载失败"
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
    return 1
  }

  if download "https://starship.rs/install.sh" "$starship_tmp"; then
    step "安装 Starship 到 /usr/local/bin ..."
    if sh "$starship_tmp" -y -b /usr/local/bin; then
      ok "Starship 已安装"
      rm -f "$starship_tmp"
      return 0
    fi
    warn "Starship 安装失败"
  else
    warn "Starship: 下载失败"
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
      return 1
      ;;
  esac

  version="$(curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --retry-connrefused \
    https://api.github.com/repos/jesseduffield/lazygit/releases/latest |
    sed -n 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/p' |
    head -n 1)"
  if [ -z "$version" ]; then
    warn "lazygit: 未能获取最新版本号"
    return 1
  fi

  tmpdir="$(mktemp -d /tmp/lazygit.XXXXXX)" || {
    warn "lazygit: mktemp 失败"
    return 1
  }
  archive="$tmpdir/lazygit.tar.gz"
  url="https://github.com/jesseduffield/lazygit/releases/download/v${version}/lazygit_${version}_Linux_${lazygit_arch}.tar.gz"

  if ! download "$url" "$archive"; then
    warn "lazygit: 下载失败 ($url)"
    rm -rf "$tmpdir"
    return 1
  fi
  if ! tar -xzf "$archive" -C "$tmpdir" lazygit; then
    warn "lazygit: 解压失败"
    rm -rf "$tmpdir"
    return 1
  fi
  if ! install -m 0755 "$tmpdir/lazygit" /usr/local/bin/lazygit; then
    warn "lazygit: 写入 /usr/local/bin/lazygit 失败"
    rm -rf "$tmpdir"
    return 1
  fi

  rm -rf "$tmpdir"
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
      return 1
      ;;
  esac

  tag="$(curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --retry-connrefused \
    https://api.github.com/repos/Adembc/lazyssh/releases/latest |
    sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' |
    head -n 1)"
  if [ -z "$tag" ]; then
    warn "lazyssh: 未能获取最新版本号"
    return 1
  fi

  tmpdir="$(mktemp -d /tmp/lazyssh.XXXXXX)" || {
    warn "lazyssh: mktemp 失败"
    return 1
  }
  archive="$tmpdir/lazyssh.tar.gz"
  url="https://github.com/Adembc/lazyssh/releases/download/${tag}/lazyssh_Linux_${lazyssh_arch}.tar.gz"

  if ! download "$url" "$archive"; then
    warn "lazyssh: 下载失败 ($url)"
    rm -rf "$tmpdir"
    return 1
  fi
  if ! tar -xzf "$archive" -C "$tmpdir" lazyssh; then
    warn "lazyssh: 解压失败"
    rm -rf "$tmpdir"
    return 1
  fi
  if ! install -m 0755 "$tmpdir/lazyssh" /usr/local/bin/lazyssh; then
    warn "lazyssh: 写入 /usr/local/bin/lazyssh 失败"
    rm -rf "$tmpdir"
    return 1
  fi

  rm -rf "$tmpdir"
  ok "lazyssh 已安装"
}

install_blesh() {
  if [ -s /root/.local/share/blesh/ble.sh ]; then
    skip "ble.sh 已安装: /root/.local/share/blesh/ble.sh"
    return 0
  fi

  mkdir -p /root/.local/src /root/.local/share
  rm -rf /root/.local/src/ble.sh.new
  if git clone --recursive --depth 1 --shallow-submodules https://github.com/akinomyoga/ble.sh.git /root/.local/src/ble.sh.new &&
    make -C /root/.local/src/ble.sh.new install PREFIX=/root/.local &&
    [ -s /root/.local/share/blesh/ble.sh ]; then
    rm -rf /root/.local/src/ble.sh
    mv /root/.local/src/ble.sh.new /root/.local/src/ble.sh
    ok "ble.sh 已安装"
    return 0
  fi

  rm -rf /root/.local/src/ble.sh.new
  warn "ble.sh: 安装或检测失败"
  return 1
}

configure_locale() {
  if grep -q '^# *en_US.UTF-8 UTF-8' /etc/locale.gen 2>/dev/null; then
    sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
    ok "/etc/locale.gen 已启用 en_US.UTF-8 UTF-8"
  fi

  if locale-gen en_US.UTF-8 >/dev/null 2>&1; then
    ok "locale: en_US.UTF-8"
  else
    warn "locale-gen en_US.UTF-8 失败"
  fi

  if update-locale LANG=en_US.UTF-8 >/dev/null 2>&1; then
    ok "/etc/default/locale (LANG=en_US.UTF-8)"
  else
    warn "update-locale LANG=en_US.UTF-8 失败"
  fi
}

if [ "$(id -u)" -ne 0 ]; then
  printf '\033[1;31m✘ extras 请以 root 运行\033[0m\n' >&2
  exit 1
fi

log "Locale"
configure_locale

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
