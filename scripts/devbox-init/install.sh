#!/usr/bin/env bash
# =============================================================================
# devbox-init — 用 mise 初始化 Debian/Ubuntu 无头开发机
#
#   装 mise → 把本目录接到 ~/.config/mise/conf.d → mise bootstrap
#   coding agents 默认不装，装机时选择；之后用 mise use -g / mise unuse -g
#
#   运行:   bash install.sh
#           sudo bash install.sh
#           bash install.sh --agents claude,grok
#           bash <(wget -qO- https://raw.githubusercontent.com/tiaot33/my-devbox/main/scripts/devbox-init/install.sh)
# =============================================================================

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export APT_LISTCHANGES_FRONTEND=none

REPO_URL="${DEVBOX_REPO_URL:-https://github.com/tiaot33/my-devbox.git}"
MISE_INSTALL_URL="${MISE_INSTALL_URL:-https://mise.run}"
# 与 mise.toml min_version.hard 对齐。低于这个版本读不懂本仓库的 bootstrap。
MISE_MIN_VERSION="${MISE_MIN_VERSION:-2026.7.0}"

log()  { printf '\n\033[1;34m▶ %s\033[0m\n' "$*"; }
warn() { printf '  \033[1;33m⚠  %s\033[0m\n' "$*" >&2; }
step() { printf '  \033[36m▸ %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✔ %s\033[0m\n' "$*"; }

usage() {
  cat <<'EOF'
用法:
  bash install.sh
  sudo bash install.sh
  bash install.sh --agents claude,grok
  bash install.sh --no-agents

远程一键:
  bash <(wget -qO- https://raw.githubusercontent.com/tiaot33/my-devbox/main/scripts/devbox-init/install.sh)
  DEVBOX_AGENTS=claude,grok bash <(wget -qO- https://raw.githubusercontent.com/tiaot33/my-devbox/main/scripts/devbox-init/install.sh)

环境变量:
  DEVBOX_REPO_URL     覆盖 git 仓库地址（远程安装时克隆用）
  MISE_INSTALL_URL    覆盖 mise 安装器地址，默认 https://mise.run
  DEVBOX_AGENTS       要装的 coding agent id，逗号分隔；all=全部；none=不装
                      未设置且在终端里运行时，会在 bootstrap 之前询问

参数:
  --agents IDS        同 DEVBOX_AGENTS（覆盖环境变量）
  --no-agents         明确不装 coding agents
EOF
}

AGENTS_SPEC=""
AGENTS_SPEC_SET=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --no-agents)
      AGENTS_SPEC="none"
      AGENTS_SPEC_SET=1
      shift
      ;;
    --agents)
      if [ "$#" -lt 2 ]; then
        printf '\033[1;31m✘ --agents 需要一个参数\033[0m\n' >&2
        usage >&2
        exit 2
      fi
      AGENTS_SPEC="$2"
      AGENTS_SPEC_SET=1
      shift 2
      ;;
    --agents=*)
      AGENTS_SPEC="${1#*=}"
      AGENTS_SPEC_SET=1
      shift
      ;;
    *)
      printf '\033[1;31m✘ 未知参数: %s\033[0m\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ "$AGENTS_SPEC_SET" = 0 ] && [ -n "${DEVBOX_AGENTS+x}" ]; then
  AGENTS_SPEC="$DEVBOX_AGENTS"
  AGENTS_SPEC_SET=1
fi

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
printf '  ║  %-50s  ║\n' "🛠️  devbox-init"
printf '  ║  %-50s  ║\n' "   系统包 · CLI · 语言 · 可选 coding agents"
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
# 够新就跳过。过旧（例如 2026.6.x）读不懂这份 bootstrap，再走官方安装器。
MISE_VER="$($AS_USER "export PATH=\"\$HOME/.local/bin:\$PATH\"
  command -v mise >/dev/null 2>&1 || exit 0
  mise --version 2>/dev/null" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
if [ -n "$MISE_VER" ] && [ "$(printf '%s\n%s\n' "$MISE_VER" "$MISE_MIN_VERSION" | sort -V | tail -1)" = "$MISE_VER" ]; then
  ok "mise $MISE_VER 已满足 (>= $MISE_MIN_VERSION)，跳过安装"
else
  if [ -n "$MISE_VER" ]; then
    step "mise $MISE_VER < $MISE_MIN_VERSION，升级 ..."
  else
    step "未检测到 mise，走官方安装器 ..."
  fi
  $AS_USER "export PATH=\"\$HOME/.local/bin:\$PATH\"
    curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --retry-connrefused \"$MISE_INSTALL_URL\" | sh
    command -v mise >/dev/null 2>&1
    mise --version || true"
  ok "mise 可用"
fi

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
    # 这份浅克隆归安装器管。mise 以前写 lock 会把工作区弄脏，
    # pull --ff-only 失败后再用旧副本，就会继续装仓库里已经删掉的包。
    $AS_USER "set -euo pipefail
      dir=\"\$HOME/.local/src/my-devbox\"
      git -C \"\$dir\" fetch --depth 1 origin
      branch=\$(git -C \"\$dir\" rev-parse --abbrev-ref HEAD)
      if [ \"\$branch\" = HEAD ]; then
        branch=main
      fi
      if git -C \"\$dir\" show-ref --verify --quiet \"refs/remotes/origin/\$branch\"; then
        git -C \"\$dir\" reset --hard \"origin/\$branch\"
      else
        git -C \"\$dir\" reset --hard origin/main
      fi"
    ok "已对齐 $CLONE_DIR 到 origin"
  else
    $AS_USER "git clone --depth 1 $(printf '%q' "$REPO_URL") \"\$HOME/.local/src/my-devbox\""
    ok "已克隆到 $CLONE_DIR"
  fi
  SRC="$CLONE_DIR/scripts/devbox-init"
  [ -f "$SRC/mise.toml" ] || { printf '  \033[1;31m✘ 克隆结果里找不到 %s/mise.toml\033[0m\n' "$SRC" >&2; exit 1; }
fi

# ── 选择 coding agents（在漫长的 bootstrap 之前问，默认不装） ───────────────

AGENT_SCRIPT="$SRC/install-agents.sh"
if [ ! -f "$AGENT_SCRIPT" ]; then
  warn "找不到 $AGENT_SCRIPT，跳过 coding agents"
  AGENTS_SPEC=""
  AGENTS_SPEC_SET=1
elif [ "$AGENTS_SPEC_SET" = 0 ]; then
  # 用 /dev/tty：菜单在 $(...) 里也不能丢。wget|bash 时 stdin 也不是终端。
  if [ -r /dev/tty ] || [ -t 0 ]; then
    log "🤖 选择 coding agents"
    AGENTS_SPEC="$(bash "$AGENT_SCRIPT" --prompt)"
    AGENTS_SPEC_SET=1
  else
    step "非交互且未指定 --agents / DEVBOX_AGENTS，跳过 coding agents"
    AGENTS_SPEC=""
    AGENTS_SPEC_SET=1
  fi
else
  AGENTS_SPEC="$(bash "$AGENT_SCRIPT" --prompt --agents "$AGENTS_SPEC")"
fi
if [ -n "${AGENTS_SPEC:-}" ]; then
  ok "将安装: $AGENTS_SPEC"
else
  ok "不安装 coding agents"
fi

# ── 接到全局 config（否则工具只在仓库目录里生效） ──────────────────────────

log "🔗 连接到 ~/.config/mise"
$AS_USER "set -euo pipefail
  mkdir -p \"\$HOME/.config/mise/conf.d\" \"\$HOME/.local/bin\" \"\$HOME/.local/src\" \"\$HOME/.local/share/fonts\" \"\$HOME/.config\" \"\$HOME/.cache\"
  relink() {
    src=\$1 dest=\$2
    # ln -sfn 无法替换同名真目录，会在里面再链一层。
    if [ -L \"\$dest\" ] || [ ! -e \"\$dest\" ]; then
      ln -sfn \"\$src\" \"\$dest\"
    else
      rm -rf \"\$dest\"
      ln -sfn \"\$src\" \"\$dest\"
    fi
  }
  relink $(printf '%q' "$SRC/mise.toml") \"\$HOME/.config/mise/conf.d/00-devbox.toml\"
  # mise 按 config 所在目录解析 source=；toml 在 conf.d/ 里，dotfiles 必须在旁边。
  relink $(printf '%q' "$SRC/dotfiles") \"\$HOME/.config/mise/conf.d/dotfiles\"
  relink $(printf '%q' "$SRC/dotfiles") \"\$HOME/.config/mise/dotfiles\"
  relink $(printf '%q' "$SRC/bootstrap-extras.sh") \"\$HOME/.config/mise/bootstrap-extras.sh\"
  cfg=\"\$HOME/.config/mise/config.toml\"
  if [ -L \"\$cfg\" ]; then
    rm -f \"\$cfg\"
  fi
  if [ ! -e \"\$cfg\" ]; then
    cat > \"\$cfg\" <<'EOF_MISE_USER'
# User-global tools (coding agents, extra CLIs).
# Workstation defaults: ~/.config/mise/conf.d/00-devbox.toml
# Add/remove: mise use -g <tool> / mise unuse -g <tool>
EOF_MISE_USER
  fi"
ok "$DISPATCHER_HOME/.config/mise/conf.d/00-devbox.toml → $SRC/mise.toml"

# ── mise bootstrap ──────────────────────────────────────────────────────────

log "🚀 mise bootstrap"
$AS_USER "export PATH=\"\$HOME/.local/bin:\$PATH\"
  export MISE_YES=1
  mise trust \"\$HOME/.config/mise/config.toml\" || true
  mise trust \"\$HOME/.config/mise/conf.d/00-devbox.toml\" || true
  mise -C \"\$HOME\" bootstrap --yes --update --force-dotfiles"
ok "mise bootstrap 完成"

# ── coding agents（需要 bootstrap 之后的 node / uv） ────────────────────────

if [ -n "${AGENTS_SPEC:-}" ] && [ -f "$AGENT_SCRIPT" ]; then
  log "🤖 安装 coding agents: $AGENTS_SPEC"
  if [ "$DISPATCHER" = "$(id -un)" ]; then
    bash "$AGENT_SCRIPT" --agents "$AGENTS_SPEC" || warn "部分 coding agents 安装失败"
  else
    sudo -H -u "$DISPATCHER" bash "$AGENT_SCRIPT" --agents "$AGENTS_SPEC" || warn "部分 coding agents 安装失败"
  fi
fi

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
printf '  配置文件: %s/.config/mise/conf.d/00-devbox.toml\n' "$DISPATCHER_HOME"
printf '  用户工具: %s/.config/mise/config.toml\n' "$DISPATCHER_HOME"
printf '  源目录:   %s\n' "$SRC"
if [ -n "${AGENTS_SPEC:-}" ]; then
  printf '  agents:   %s\n\n' "$AGENTS_SPEC"
else
  printf '  agents:   （未安装）\n\n'
fi
printf '  让 shell 立即生效:\n'
printf '     \033[1msource ~/.bashrc\033[0m\n\n'
printf '  增删工作站工具: 编辑 %s/mise.toml 的 [tools]，然后:\n' "$SRC"
printf '     \033[1mmise bootstrap --yes --only tools\033[0m\n\n'
printf '  以后增删 coding agents（不要再跑本脚本）:\n'
printf '     \033[1mmise use -g claude omp\033[0m\n'
printf '     \033[1mmise unuse -g claude\033[0m\n'
printf '     \033[1mmise ls\033[0m\n\n'
printf '  个人 alias / 环境变量（不会被覆盖）:\n'
printf '     ~/.config/shell/local.sh\n'
