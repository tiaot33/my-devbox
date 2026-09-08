#!/usr/bin/env bash
# =============================================================================
# hermes-init — 用 mise bootstrap 初始化 Hermes 维护环境
#
#   装 mise → 把本目录接到 ~/.config/mise/conf.d → mise bootstrap
#   不声明 [tools]，不装多版本运行时。
#
#   运行:   bash install.sh
#           bash <(wget -qO- https://raw.githubusercontent.com/tiaot33/my-devbox/main/scripts/hermes-init/install.sh)
#
#   原版脚本仍可用: bash hermes-init.sh
# =============================================================================

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export APT_LISTCHANGES_FRONTEND=none

REPO_URL="${HERMES_REPO_URL:-https://github.com/tiaot33/my-devbox.git}"
MISE_INSTALL_URL="${MISE_INSTALL_URL:-https://mise.run}"
MISE_MIN_VERSION="${MISE_MIN_VERSION:-2026.7.0}"

log()  { printf '\n\033[1;34m▶ %s\033[0m\n' "$*"; }
warn() { printf '  \033[1;33m⚠  %s\033[0m\n' "$*" >&2; }
step() { printf '  \033[36m▸ %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✔ %s\033[0m\n' "$*"; }

usage() {
  cat <<'EOF'
用法:
  bash install.sh

远程一键:
  bash <(wget -qO- https://raw.githubusercontent.com/tiaot33/my-devbox/main/scripts/hermes-init/install.sh)

环境变量:
  HERMES_REPO_URL     覆盖 git 仓库地址（远程安装时克隆用）
  MISE_INSTALL_URL    覆盖 mise 安装器地址，默认 https://mise.run

原版脚本（不装 mise）:
  bash hermes-init.sh
EOF
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

# shellcheck disable=SC1091
[ -r /etc/os-release ] && . /etc/os-release
case "${ID:-}:${VERSION_ID:-}" in
  ubuntu:26.*|debian:13*) ;;
  ubuntu:*|debian:*) warn "当前系统: ${PRETTY_NAME:-unknown OS}；推荐使用 Ubuntu 26 / Debian 13" ;;
  *) warn "当前系统: ${PRETTY_NAME:-unknown OS}；脚本预期 Debian/Ubuntu，结果可能不完整" ;;
esac

if [ "$(id -u)" -ne 0 ]; then
  printf '\033[1;31m✘ 请直接以 root 身份运行\033[0m\n' >&2
  exit 1
fi

export PATH="/root/.local/bin:/usr/local/bin:$PATH"

printf '\033[1;37m\n'
printf '  ╔════════════════════════════════════════════════════╗\n'
printf '  ║  %-50s  ║\n' "Hermes 外部环境 (mise bootstrap)"
printf '  ║  %-50s  ║\n' "   维护工具 · GitHub CLI · uv · Shell"
printf '  ╚════════════════════════════════════════════════════╝\n'
printf '\033[0m'

log "APT 更新"
step "apt-get update ..."
apt-get update
step "安装 ca-certificates curl git ..."
apt-get install -y --no-install-recommends ca-certificates curl git
ok "基础依赖已就绪"

log "安装 / 升级 mise"
MISE_VER="$(
  if command -v mise >/dev/null 2>&1; then
    mise --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true
  fi
)"
if [ -n "$MISE_VER" ] && [ "$(printf '%s\n%s\n' "$MISE_VER" "$MISE_MIN_VERSION" | sort -V | tail -1)" = "$MISE_VER" ]; then
  ok "mise $MISE_VER 已满足 (>= $MISE_MIN_VERSION)，跳过安装"
else
  if [ -n "$MISE_VER" ]; then
    step "mise $MISE_VER < $MISE_MIN_VERSION，升级 ..."
  else
    step "未检测到 mise，走官方安装器 ..."
  fi
  curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --retry-connrefused "$MISE_INSTALL_URL" | sh
  command -v mise >/dev/null 2>&1
  mise --version || true
  ok "mise 可用"
fi

log "解析 mise 配置源"
SRC=""
SCRIPT_PATH="${BASH_SOURCE[0]:-}"
if [ -n "$SCRIPT_PATH" ] && [ -f "$SCRIPT_PATH" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
  if [ -f "$SCRIPT_DIR/mise.toml" ]; then
    SRC="$SCRIPT_DIR"
    ok "使用本地配置: $SRC"
  fi
fi

if [ -z "$SRC" ]; then
  CLONE_DIR="/root/.local/src/my-devbox"
  step "从 $REPO_URL 获取配置 ..."
  mkdir -p /root/.local/src
  if [ -d "$CLONE_DIR/.git" ]; then
    git -C "$CLONE_DIR" fetch --depth 1 origin
    branch="$(git -C "$CLONE_DIR" rev-parse --abbrev-ref HEAD)"
    if [ "$branch" = HEAD ]; then
      branch=main
    fi
    if git -C "$CLONE_DIR" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
      git -C "$CLONE_DIR" reset --hard "origin/$branch"
    else
      git -C "$CLONE_DIR" reset --hard origin/main
    fi
    ok "已对齐 $CLONE_DIR 到 origin"
  else
    git clone --depth 1 "$REPO_URL" "$CLONE_DIR"
    ok "已克隆到 $CLONE_DIR"
  fi
  SRC="$CLONE_DIR/scripts/hermes-init"
  [ -f "$SRC/mise.toml" ] || { printf '  \033[1;31m✘ 克隆结果里找不到 %s/mise.toml\033[0m\n' "$SRC" >&2; exit 1; }
fi

log "连接到 ~/.config/mise"
mkdir -p /root/.config/mise/conf.d /root/.local/bin /root/.local/src /root/.config
relink() {
  src=$1 dest=$2
  if [ -L "$dest" ] || [ ! -e "$dest" ]; then
    ln -sfn "$src" "$dest"
  else
    rm -rf "$dest"
    ln -sfn "$src" "$dest"
  fi
}
relink "$SRC/mise.toml" /root/.config/mise/conf.d/00-hermes.toml
relink "$SRC/dotfiles" /root/.config/mise/conf.d/dotfiles
relink "$SRC/bootstrap-extras.sh" /root/.config/mise/bootstrap-extras.sh
cfg=/root/.config/mise/config.toml
if [ -L "$cfg" ]; then
  rm -f "$cfg"
fi
if [ ! -e "$cfg" ]; then
  cat >"$cfg" <<'EOF_MISE_USER'
# Hermes 维护环境不声明 [tools]。
# 工作站清单: ~/.config/mise/conf.d/00-hermes.toml
# 日常: mise bootstrap
EOF_MISE_USER
fi
ok "/root/.config/mise/conf.d/00-hermes.toml → $SRC/mise.toml"

log "mise bootstrap"
export MISE_YES=1
mise trust /root/.config/mise/config.toml || true
mise trust /root/.config/mise/conf.d/00-hermes.toml || true
mise -C /root bootstrap --yes --update --force-dotfiles
ok "mise bootstrap 完成"

printf '\n\033[1;32m'
printf '  ╔════════════════════════════════════════════════════╗\n'
printf '  ║  %-50s ║\n' "Hermes 外部环境已就绪"
printf '  ╚════════════════════════════════════════════════════╝\n'
printf '\033[0m\n'

printf '  配置文件: /root/.config/mise/conf.d/00-hermes.toml\n'
printf '  源目录:   %s\n\n' "$SRC"
printf '  让 shell 立即生效:\n'
printf '     \033[1msource ~/.bashrc\033[0m\n\n'
printf '  以后同步 / 检查:\n'
printf '     \033[1mmise bootstrap --yes --update --force-dotfiles\033[0m\n'
printf '     \033[1mmise run doctor\033[0m\n\n'
printf '  安装 Hermes Agent（仍走原脚本）:\n'
printf '     \033[1mbash %s/hermes-agent-install.sh\033[0m\n' "$SRC"
