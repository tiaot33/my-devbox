#!/usr/bin/env bash
# =============================================================================
# devbox-init/mise — 用 mise 初始化 Debian/Ubuntu 无头开发机
#
#   装 mise → 把本目录接到 ~/.config/mise → mise bootstrap
#
#   运行:   bash install.sh
#           sudo bash install.sh
#           bash <(wget -qO- https://raw.githubusercontent.com/tiaot33/my-devbox/main/scripts/devbox-init/mise/install.sh)
# =============================================================================

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export APT_LISTCHANGES_FRONTEND=none

REPO_URL="${DEVBOX_REPO_URL:-https://github.com/tiaot33/my-devbox.git}"
MISE_INSTALL_URL="${MISE_INSTALL_URL:-https://mise.run}"

log()  { printf '\n\033[1;34m▶ %s\033[0m\n' "$*"; }
warn() { printf '  \033[1;33m⚠  %s\033[0m\n' "$*" >&2; }
step() { printf '  \033[36m▸ %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✔ %s\033[0m\n' "$*"; }

usage() {
  cat <<'EOF'
用法:
  bash install.sh
  sudo bash install.sh

远程一键:
  bash <(wget -qO- https://raw.githubusercontent.com/tiaot33/my-devbox/main/scripts/devbox-init/mise/install.sh)

环境变量:
  DEVBOX_REPO_URL     覆盖 git 仓库地址（远程安装时克隆用）
  MISE_INSTALL_URL    覆盖 mise 安装器地址，默认 https://mise.run
EOF
}

while [ "$#" -gt 0 ]; do
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
done

# ── 环境检测 ────────────────────────────────────────────────────────────────

# shellcheck disable=SC1091
[ -r /etc/os-release ] && . /etc/os-release
case "${ID:-}" in
  ubuntu|debian) ;;
  *) warn "当前系统: ${PRETTY_NAME:-unknown OS}；脚本预期 Debian/Ubuntu，结果可能不完整" ;;
esac

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

if [ "$DISPATCHER" = "$(id -un)" ]; then
  AS_USER="bash -lc"
else
  AS_USER="sudo -H -u $DISPATCHER bash -lc"
fi

printf '\033[1;37m\n'
printf '  ╔════════════════════════════════════════════════════╗\n'
printf '  ║  %-50s  ║\n' "🛠️  devbox-init / mise"
printf '  ║  %-50s  ║\n' "   系统包 · CLI · 语言工具链 · dotfiles"
printf '  ╚════════════════════════════════════════════════════╝\n'
printf '\033[0m'

log "📋 目标用户: \033[1m$DISPATCHER\033[0m (主目录: $DISPATCHER_HOME)"

# ── 鸡生蛋：curl / git / ca-certificates ────────────────────────────────────

log "📦 安装 mise 之前的系统依赖"
step "apt-get update ..."
$SUDO apt-get update
step "安装 ca-certificates curl git ..."
$SUDO apt-get install -y --no-install-recommends ca-certificates curl git
ok "基础依赖已就绪"

# ── 安装 mise ───────────────────────────────────────────────────────────────

log "🧰 安装 / 升级 mise"
# 官方安装器可重跑；已有旧版时也会升到当前，避免 2026.6.x 读不懂这份 bootstrap。
$AS_USER "export PATH=\"\$HOME/.local/bin:\$PATH\"
  curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --retry-connrefused \"$MISE_INSTALL_URL\" | sh
  command -v mise >/dev/null 2>&1
  mise --version || true"
ok "mise 可用"

# ── 解析配置源 ──────────────────────────────────────────────────────────────

log "📁 解析 mise 配置源"
SRC=""
SCRIPT_PATH="${BASH_SOURCE[0]:-}"
if [ -n "$SCRIPT_PATH" ] && [ -f "$SCRIPT_PATH" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
  if [ -f "$SCRIPT_DIR/mise.toml" ] && $AS_USER "test -r $(printf '%q' "$SCRIPT_DIR/mise.toml")"; then
    SRC="$SCRIPT_DIR"
    ok "使用本地配置: $SRC"
  fi
fi

if [ -z "$SRC" ]; then
  CLONE_DIR="$DISPATCHER_HOME/.local/src/my-devbox"
  step "从 $REPO_URL 获取配置 ..."
  $AS_USER "mkdir -p \"\$HOME/.local/src\""
  if [ -d "$CLONE_DIR/.git" ]; then
    if $AS_USER "git -C \"\$HOME/.local/src/my-devbox\" pull --ff-only"; then
      ok "已更新 $CLONE_DIR"
    else
      warn "git pull --ff-only 失败，继续使用已有副本"
    fi
  else
    $AS_USER "git clone --depth 1 $(printf '%q' "$REPO_URL") \"\$HOME/.local/src/my-devbox\""
    ok "已克隆到 $CLONE_DIR"
  fi
  SRC="$CLONE_DIR/scripts/devbox-init/mise"
  [ -f "$SRC/mise.toml" ] || { printf '  \033[1;31m✘ 克隆结果里找不到 %s/mise.toml\033[0m\n' "$SRC" >&2; exit 1; }
fi

# ── 接到全局 config（否则工具只在仓库目录里生效） ──────────────────────────

log "🔗 连接到 ~/.config/mise"
$AS_USER "mkdir -p \"\$HOME/.config/mise\" \"\$HOME/.local/bin\" \"\$HOME/.local/src\" \"\$HOME/.local/share/fonts\" \"\$HOME/.config\" \"\$HOME/.cache\"
  ln -sfn $(printf '%q' "$SRC/mise.toml") \"\$HOME/.config/mise/config.toml\"
  ln -sfn $(printf '%q' "$SRC/dotfiles") \"\$HOME/.config/mise/dotfiles\"
  ln -sfn $(printf '%q' "$SRC/bootstrap-extras.sh") \"\$HOME/.config/mise/bootstrap-extras.sh\"
  if [ -f $(printf '%q' "$SRC/mise.lock") ]; then
    ln -sfn $(printf '%q' "$SRC/mise.lock") \"\$HOME/.config/mise/mise.lock\"
  fi"
ok "$DISPATCHER_HOME/.config/mise/config.toml → $SRC/mise.toml"

# ── mise bootstrap ──────────────────────────────────────────────────────────

log "🚀 mise bootstrap"
$AS_USER "export PATH=\"\$HOME/.local/bin:\$PATH\"
  export MISE_YES=1
  mise trust \"\$HOME/.config/mise/config.toml\" || true
  mise -C \"\$HOME\" bootstrap --yes --update --force-dotfiles"
ok "mise bootstrap 完成"

# ── locale（需要 root；packages 阶段之后 locales 已在） ─────────────────────

log "🌐 Locale — en_US.UTF-8"
if [ -f /etc/locale.gen ] && grep -q '^# *en_US.UTF-8 UTF-8' /etc/locale.gen; then
  $SUDO sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
fi
if $SUDO locale-gen en_US.UTF-8 >/dev/null 2>&1; then
  ok "locale-gen en_US.UTF-8 完成"
else
  warn "locale-gen en_US.UTF-8 失败"
fi
if $SUDO update-locale LANG=en_US.UTF-8 >/dev/null 2>&1; then
  ok "en_US.UTF-8 已配置"
else
  warn "update-locale LANG=en_US.UTF-8 失败"
fi

printf '\n\033[1;32m'
printf '  ╔════════════════════════════════════════════════════╗\n'
printf '  ║  %-50s ║\n' "✨ mise 开发环境已就绪"
printf '  ╚════════════════════════════════════════════════════╝\n'
printf '\033[0m\n'

printf '  目标用户: %s\n' "$DISPATCHER"
printf '  配置文件: %s/.config/mise/config.toml\n' "$DISPATCHER_HOME"
printf '  源目录:   %s\n\n' "$SRC"
printf '  让 shell 立即生效:\n'
printf '     \033[1msource ~/.bashrc\033[0m\n\n'
printf '  增删工具: 编辑 %s/mise.toml 的 [tools]，然后:\n' "$SRC"
printf '     \033[1mmise bootstrap --yes --only tools\033[0m\n\n'
printf '  个人 alias / 环境变量（不会被覆盖）:\n'
printf '     ~/.config/shell/local.sh\n'
