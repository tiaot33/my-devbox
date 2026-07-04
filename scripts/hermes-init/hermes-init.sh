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

启动后按提示配置:
  API Server 监听地址，默认 127.0.0.1:8642
  Dashboard 监听地址，默认 127.0.0.1:9119
  Python 版本，默认 3.14
  Node.js 版本，默认 26，可选 26 / lts / latest
EOF
}

TARGET_HOME="/root"
HERMES_HOME="$TARGET_HOME/.hermes"
HERMES_AGENT_DIR="$HERMES_HOME/hermes-agent"
HERMES_API_HOST=""
HERMES_API_PORT=""
HERMES_DASHBOARD_HOST=""
HERMES_DASHBOARD_PORT=""
PYTHON_VERSION=""
NODE_VERSION=""
export PATH="$TARGET_HOME/.local/bin:$PATH"

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

is_valid_port() {
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
  esac
  [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

is_valid_ipv4() {
  local a b c d extra octet
  IFS=. read -r a b c d extra <<EOF
$1
EOF
  [ -z "${extra:-}" ] || return 1
  for octet in "$a" "$b" "$c" "$d"; do
    case "$octet" in
      ''|*[!0-9]*) return 1 ;;
    esac
    [ "$((10#$octet))" -le 255 ] || return 1
  done
}

is_valid_listen_address() {
  local value="$1" host port
  case "$value" in
    *:*) ;;
    *) return 1 ;;
  esac

  host="${value%:*}"
  port="${value##*:}"
  is_valid_ipv4 "$host" || return 1
  is_valid_port "$port"
}

prompt_value() {
  local label="$1" default_value="$2" value
  printf '%s [%s]: ' "$label" "$default_value" >&2
  IFS= read -r value || exit 1
  if [ -z "$value" ]; then
    printf '%s\n' "$default_value"
  else
    printf '%s\n' "$value"
  fi
}

prompt_listen_address() {
  local label="$1" default_value="$2" value
  while true; do
    value="$(prompt_value "$label" "$default_value")"
    if is_valid_listen_address "$value"; then
      printf '%s\n' "$value"
      return 0
    fi
    warn "格式应为 IPv4:端口，例如 $default_value；端口范围 1-65535"
  done
}

prompt_python_version() {
  local value
  while true; do
    value="$(prompt_value "Python 版本" "3.14")"
    if [[ "$value" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]; then
      printf '%s\n' "$value"
      return 0
    fi
    warn "Python 版本格式应类似 3.14 或 3.13"
  done
}

prompt_node_version() {
  local value
  while true; do
    value="$(prompt_value "Node.js 版本 (26/lts/latest)" "26")"
    case "$value" in
      26|lts|latest)
        printf '%s\n' "$value"
        return 0
        ;;
      *)
        warn "Node.js 版本只支持: 26 / lts / latest"
        ;;
    esac
  done
}

configure_interactively() {
  local api dashboard
  log "交互配置"
  api="$(prompt_listen_address "API Server 监听地址" "127.0.0.1:8642")"
  dashboard="$(prompt_listen_address "Dashboard 监听地址" "127.0.0.1:9119")"
  PYTHON_VERSION="$(prompt_python_version)"
  NODE_VERSION="$(prompt_node_version)"

  HERMES_API_HOST="${api%:*}"
  HERMES_API_PORT="${api##*:}"
  HERMES_DASHBOARD_HOST="${dashboard%:*}"
  HERMES_DASHBOARD_PORT="${dashboard##*:}"
}

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

apt_install_required() {
  if apt-get install -y --no-install-recommends "$@"; then
    summary_add installed "Hermes 必需依赖：$*"
    return 0
  fi

  summary_add failed "Hermes 必需依赖安装失败：$*"
  return 1
}

apt_install_optional() {
  local pkg
  for pkg in "$@"; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
      summary_add skipped "$pkg 已安装"
      continue
    fi

    if apt-get install -y --no-install-recommends "$pkg"; then
      summary_add installed "$pkg"
    else
      summary_add failed "$pkg 安装失败"
      warn "跳过安装: $pkg"
    fi
  done
}

ensure_user_bin() {
  mkdir -p "$TARGET_HOME/.local/bin"
}

link_if_executable() {
  local src="$1" dest="$2"
  [ -x "$src" ] || return 0

  ln -sf "$src" "$dest"
  summary_add installed "$dest -> $src"
}

download() {
  curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --retry-connrefused "$1" -o "$2" && [ -s "$2" ]
}

download_and_run() {
  local name="$1" url="$2" interp="$3"
  shift 3
  local tmp status
  tmp=$(mktemp /tmp/hermes-init.XXXXXX) || {
    warn "$name: mktemp 失败"
    return 1
  }

  if ! download "$url" "$tmp"; then
    rm -f "$tmp"
    warn "$name: 下载失败"
    return 1
  fi

  if "$interp" "$tmp" "$@"; then
    status=0
  else
    status=$?
  fi

  rm -f "$tmp"
  return "$status"
}

install_uv() {
  step "安装 uv ..."
  download_and_run "uv" "https://astral.sh/uv/install.sh" sh
  export PATH="$TARGET_HOME/.local/bin:$PATH"
  command -v uv >/dev/null 2>&1
}

install_node() {
  local arch node_arch index selected version archive url install_dir tmpdir

  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) node_arch="x64" ;;
    aarch64|arm64) node_arch="arm64" ;;
    armv7l) node_arch="armv7l" ;;
    *)
      warn "Node.js: 不支持的架构 $arch"
      return 1
      ;;
  esac

  step "解析 Node.js 版本 ($NODE_VERSION) ..."
  index="$(mktemp /tmp/node-index.XXXXXX)" || return 1
  if ! download "https://nodejs.org/dist/index.json" "$index"; then
    rm -f "$index"
    warn "Node.js: 版本索引下载失败"
    return 1
  fi

  selected="$(NODE_VERSION="$NODE_VERSION" python3 - "$index" <<'PY'
import json
import os
import sys

target = os.environ["NODE_VERSION"]
with open(sys.argv[1], encoding="utf-8") as f:
    releases = json.load(f)

if target == "26":
    match = next((r for r in releases if r["version"].startswith("v26.")), None)
elif target == "lts":
    match = next((r for r in releases if r.get("lts")), None)
elif target == "latest":
    match = releases[0] if releases else None
else:
    match = None

if not match:
    raise SystemExit(1)

print(match["version"])
PY
  )" || {
    rm -f "$index"
    warn "Node.js: 找不到匹配版本 $NODE_VERSION"
    return 1
  }
  rm -f "$index"

  version="${selected#v}"
  archive="node-v${version}-linux-${node_arch}.tar.xz"
  url="https://nodejs.org/dist/v${version}/${archive}"
  tmpdir="$(mktemp -d /tmp/node-install.XXXXXX)" || return 1

  step "下载 Node.js v$version ($node_arch) ..."
  if ! download "$url" "$tmpdir/$archive"; then
    rm -rf "$tmpdir"
    warn "Node.js: 下载失败 $url"
    return 1
  fi

  step "安装 Node.js 到 /usr/local/lib/nodejs ..."
  mkdir -p /usr/local/lib/nodejs
  tar -xJf "$tmpdir/$archive" -C /usr/local/lib/nodejs
  install_dir="/usr/local/lib/nodejs/node-v${version}-linux-${node_arch}"
  ln -sf "$install_dir/bin/node" /usr/local/bin/node
  ln -sf "$install_dir/bin/npm" /usr/local/bin/npm
  ln -sf "$install_dir/bin/npx" /usr/local/bin/npx
  [ -x "$install_dir/bin/corepack" ] && ln -sf "$install_dir/bin/corepack" /usr/local/bin/corepack
  rm -rf "$tmpdir"

  npm config set prefix /usr/local --global
  command -v corepack >/dev/null 2>&1 && corepack enable || true
  node --version
  npm --version
}

install_python_tools() {
  step "安装 Python 运行时 ..."
  export PATH="$TARGET_HOME/.local/bin:$PATH"
  uv python install "$PYTHON_VERSION"

  step "安装 Python 工具链 (ruff) ..."
  uv tool install ruff || true
}

write_service_environment() {
  step "写入 /etc/default/hermes ..."
  cat >/etc/default/hermes <<EOF
HOME=/root
HERMES_HOME=$HERMES_HOME
PATH=/root/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
UV_CACHE_DIR=/root/.cache/uv
EOF
}

confirm_external_installer() {
  warn "即将运行第三方安装器: https://hermes-agent.nousresearch.com/install.sh"
  warn "该安装器来自外部地址。请先审阅代码，再决定是否继续。"
  printf '继续安装 Hermes Agent? [y/N]: '
  local confirm
  IFS= read -r confirm || exit 1
  case "$confirm" in
    y|Y|yes|YES|Yes) ;;
    *)
      printf '已取消安装。\n'
      exit 10
      ;;
  esac
}

install_hermes_agent() {
  local installer status
  installer=$(mktemp /tmp/hermes-installer.XXXXXX) || {
    warn "Hermes installer: mktemp 失败"
    return 1
  }

  step "下载 Hermes Agent installer ..."
  if ! download "https://hermes-agent.nousresearch.com/install.sh" "$installer"; then
    rm -f "$installer"
    warn "Hermes Agent installer 下载失败"
    return 1
  fi

  step "执行 Hermes Agent installer ..."
  export HOME=/root
  export HERMES_HOME
  export PATH="/root/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  export UV_CACHE_DIR=/root/.cache/uv
  export npm_config_yes=true
  if bash "$installer" --skip-setup --hermes-home "$HERMES_HOME" --dir "$HERMES_AGENT_DIR"; then
    status=0
  else
    status=$?
  fi
  rm -f "$installer"
  return "$status"
}

configure_api_server() {
  local api_key
  mkdir -p "$HERMES_HOME"
  api_key="$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | cut -c1-32)"
  cat >"$HERMES_HOME/.env" <<EOF
API_SERVER_ENABLED=true
API_SERVER_HOST=$HERMES_API_HOST
API_SERVER_PORT=$HERMES_API_PORT
API_SERVER_KEY=$api_key
EOF
  chmod 600 "$HERMES_HOME/.env"
}

create_dashboard_service() {
  step "写入 hermes-dashboard.service ..."
  cat >/etc/systemd/system/hermes-dashboard.service <<EOF
[Unit]
Description=Hermes Agent Web Dashboard
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
UMask=0077
WorkingDirectory=/root
ExecStart=/root/.local/bin/hermes dashboard --host $HERMES_DASHBOARD_HOST --port $HERMES_DASHBOARD_PORT --no-open
EnvironmentFile=/etc/default/hermes
Restart=on-failure
RestartSec=5
ProtectProc=invisible
ProcSubset=pid

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable -q --now hermes-dashboard
}

create_setup_helper() {
  step "写入 /usr/bin/hermes-setup ..."
  cat >/usr/bin/hermes-setup <<'SETUP'
#!/usr/bin/env bash
set -a
. /etc/default/hermes
set +a
/root/.local/bin/hermes setup
chmod 700 /root/.hermes 2>/dev/null || true
if systemctl --user list-unit-files hermes-gateway.service >/dev/null 2>&1; then
  systemctl --user enable --now hermes-gateway || true
fi
echo "Hermes setup complete."
SETUP
  chmod +x /usr/bin/hermes-setup
}

configure_login_hint() {
  cat >/etc/profile.d/hermes-hint.sh <<'HINT'
if [ "$(id -u)" -eq 0 ]; then
  echo "  Run 'hermes-setup' to configure your model provider and gateway server."
fi
HINT
}

printf '\033[1;37m\n'
printf '  ╔════════════════════════════════════════════════════╗\n'
printf '  ║  %-50s  ║\n' "Hermes 初始化"
printf '  ║  %-50s  ║\n' "   依赖 · Node · uv · Agent · systemd"
printf '  ╚════════════════════════════════════════════════════╝\n'
printf '\033[0m'

configure_interactively

log "运行用户: \033[1mroot\033[0m (主目录: $TARGET_HOME)"

log "APT 更新"
step "apt-get update ..."
apt-get update

HERMES_REQUIRED_PACKAGES=(
  ca-certificates curl git openssh-client procps
  gcc g++ make cmake libffi-dev xz-utils
  openssl
)

log "Hermes 必需依赖"
step "安装 ${#HERMES_REQUIRED_PACKAGES[@]} 个必需包 ..."
apt_install_required "${HERMES_REQUIRED_PACKAGES[@]}" || exit 1
ok "Hermes 必需依赖安装完成"

BASIC_PACKAGES=(
  jq wget unzip zip tar gzip bzip2 file less
  vim nano
  iproute2 iputils-ping dnsutils net-tools
  rsync
)

log "命令行工具"
step "安装 ${#BASIC_PACKAGES[@]} 个软件包 ..."
apt_install_optional "${BASIC_PACKAGES[@]}"
ok "命令行工具安装完成"

PERF_PACKAGES=(
  ripgrep fd-find hyperfine
)

log "ripgrep / fd-find / hyperfine"
step "安装 ${#PERF_PACKAGES[@]} 个软件包 ..."
apt_install_optional "${PERF_PACKAGES[@]}"

ensure_user_bin
link_if_executable /usr/bin/fdfind "$TARGET_HOME/.local/bin/fd"
ok "ripgrep / fd-find / hyperfine 安装完成"

log "uv"
if install_uv; then
  summary_add installed "uv"
  ok "uv 安装完成"
else
  summary_add failed "uv 安装失败"
fi

log "Python"
apt_install_required python3 || exit 1
ok "Python 已就绪"

log "Node.js"
if install_node; then
  summary_add installed "Node.js ($NODE_VERSION)"
  ok "Node.js 安装完成"
else
  summary_add failed "Node.js 安装失败"
  exit 1
fi

if ! command -v uv >/dev/null 2>&1; then
  warn "Hermes Agent 依赖 uv，但当前找不到 uv"
  summary_add failed "Hermes Agent 依赖 uv，当前找不到 uv"
  exit 1
fi

log "Python 工具链"
install_python_tools
summary_add installed "Python $PYTHON_VERSION / ruff"
ok "Python 工具链安装完成"

log "服务环境"
mkdir -p "$TARGET_HOME/.local/bin" "$TARGET_HOME/.cache/uv" "$HERMES_HOME"
chmod 700 "$HERMES_HOME"
write_service_environment

log "Hermes Agent"
confirm_external_installer
install_hermes_agent
chmod 700 "$HERMES_HOME"
git config --system --add safe.directory "$HERMES_AGENT_DIR" 2>/dev/null || true
summary_add installed "Hermes Agent"
ok "Hermes Agent 安装完成"

log "API Server"
configure_api_server
summary_add installed "API Server: $HERMES_API_HOST:$HERMES_API_PORT"
ok "API Server 已配置: $HERMES_API_HOST:$HERMES_API_PORT"

log "Dashboard Service"
create_dashboard_service
summary_add installed "Dashboard Service: $HERMES_DASHBOARD_HOST:$HERMES_DASHBOARD_PORT"
ok "Dashboard Service 已启动: $HERMES_DASHBOARD_HOST:$HERMES_DASHBOARD_PORT"

log "Setup Helper"
create_setup_helper
configure_login_hint
summary_add installed "hermes-setup"
ok "运行 hermes-setup 配置模型 provider 和 gateway"

log "清理 APT 缓存"
apt-get autoremove -y >/dev/null 2>&1 || true
apt-get autoclean -y >/dev/null 2>&1 || true
ok "清理完成"

printf '\n\033[1;32mHermes 初始化完成\033[0m\n\n'
summary_print_list "已安装 / 已配置" "${SUMMARY_INSTALLED[@]}"
summary_print_list "已跳过" "${SUMMARY_SKIPPED[@]}"
summary_print_list "失败项" "${SUMMARY_FAILED[@]}"

if [ "${#SUMMARY_FAILED[@]}" -gt 0 ]; then
  exit 1
fi
