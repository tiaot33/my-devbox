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
  API Server 监听地址，默认 127.0.0.1，可选 127.0.0.1 / 0.0.0.0
  API Server 端口，默认 8642
  是否跳过浏览器安装，默认否
EOF
}

TARGET_HOME="/root"
HERMES_HOME="$TARGET_HOME/.hermes"
HERMES_AGENT_DIR="/usr/local/lib/hermes-agent"
HERMES_BIN="/usr/local/bin/hermes"
HERMES_API_HOST=""
HERMES_API_PORT=""
HERMES_SKIP_BROWSER=false
export PATH="/usr/local/bin:$TARGET_HOME/.local/bin:$PATH"

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

prompt_listen_host() {
  local label="$1" default_choice="$2" value
  while true; do
    printf '%s:\n' "$label" >&2
    printf '  1) 127.0.0.1\n' >&2
    printf '  2) 0.0.0.0\n' >&2
    printf '请选择 [%s]: ' "$default_choice" >&2
    IFS= read -r value || exit 1
    [ -n "$value" ] || value="$default_choice"
    case "$value" in
      1)
        printf '127.0.0.1\n'
        return 0
        ;;
      2)
        printf '0.0.0.0\n'
        return 0
        ;;
      *)
        warn "请选择 1 或 2"
        ;;
    esac
  done
}

prompt_port() {
  local label="$1" default_value="$2" value
  while true; do
    value="$(prompt_value "$label" "$default_value")"
    if is_valid_port "$value"; then
      printf '%s\n' "$value"
      return 0
    fi
    warn "端口范围应为 1-65535"
  done
}

prompt_skip_browser() {
  local value
  while true; do
    printf '跳过浏览器安装? [y/N]: ' >&2
    IFS= read -r value || exit 1
    case "$value" in
      ''|n|N|no|NO|No)
        printf 'false\n'
        return 0
        ;;
      y|Y|yes|YES|Yes)
        printf 'true\n'
        return 0
        ;;
      *)
        warn "请输入 y 或 n"
        ;;
    esac
  done
}

configure_interactively() {
  log "交互配置"
  HERMES_API_HOST="$(prompt_listen_host "API Server 监听地址" "1")"
  HERMES_API_PORT="$(prompt_port "API Server 端口" "8642")"
  HERMES_SKIP_BROWSER="$(prompt_skip_browser)"
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

download() {
  curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --retry-connrefused "$1" -o "$2" && [ -s "$2" ]
}

resolve_hermes_bin() {
  if [ -x /usr/local/bin/hermes ]; then
    HERMES_BIN="/usr/local/bin/hermes"
    HERMES_AGENT_DIR="/usr/local/lib/hermes-agent"
  elif [ -x "$TARGET_HOME/.local/bin/hermes" ]; then
    HERMES_BIN="$TARGET_HOME/.local/bin/hermes"
    HERMES_AGENT_DIR="$HERMES_HOME/hermes-agent"
    warn "检测到既有用户级 Hermes 安装，官方安装器沿用: $HERMES_AGENT_DIR"
  else
    warn "找不到 hermes 命令，后续服务可能无法启动"
  fi
}

env_get() {
  local file="$1" key="$2"
  [ -f "$file" ] || return 0
  awk -F= -v key="$key" '$1 == key { value = substr($0, length(key) + 2) } END { print value }' "$file"
}

env_set() {
  local file="$1" key="$2" value="$3"
  if grep -qE "^${key}=" "$file" 2>/dev/null; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$file"
  else
    printf '%s=%s\n' "$key" "$value" >>"$file"
  fi
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
  local install_args=("--skip-setup" "--hermes-home" "$HERMES_HOME")
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
  export PATH="/usr/local/bin:/root/.local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin"
  export npm_config_yes=true
  if [ "$HERMES_SKIP_BROWSER" = true ]; then
    install_args+=("--skip-browser")
  fi
  if bash "$installer" "${install_args[@]}"; then
    status=0
  else
    status=$?
  fi
  rm -f "$installer"
  return "$status"
}

configure_api_server() {
  local env_file api_key
  mkdir -p "$HERMES_HOME"
  env_file="$HERMES_HOME/.env"
  touch "$env_file"
  api_key="$(env_get "$env_file" API_SERVER_KEY)"
  if [ -z "$api_key" ]; then
    api_key="$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | cut -c1-32)"
  fi
  env_set "$env_file" API_SERVER_ENABLED true
  env_set "$env_file" API_SERVER_HOST "$HERMES_API_HOST"
  env_set "$env_file" API_SERVER_PORT "$HERMES_API_PORT"
  env_set "$env_file" API_SERVER_KEY "$api_key"
  chmod 600 "$env_file"
}

create_setup_helper() {
  step "写入 /usr/bin/hermes-setup ..."
  cat >/usr/bin/hermes-setup <<SETUP
#!/usr/bin/env bash
$HERMES_BIN setup
chmod 700 /root/.hermes 2>/dev/null || true
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
printf '  ║  %-50s  ║\n' "   依赖 · 官方安装器 · API Server"
printf '  ╚════════════════════════════════════════════════════╝\n'
printf '\033[0m'

configure_interactively

log "运行用户: \033[1mroot\033[0m (主目录: $TARGET_HOME)"

log "APT 更新"
step "apt-get update ..."
apt-get update

HERMES_REQUIRED_PACKAGES=(
  ca-certificates curl git openssh-client
  openssl sed mawk xz-utils
)

log "Hermes 必需依赖"
step "安装 ${#HERMES_REQUIRED_PACKAGES[@]} 个必需包 ..."
apt_install_required "${HERMES_REQUIRED_PACKAGES[@]}" || exit 1
ok "Hermes 必需依赖安装完成"

log "Hermes Home"
mkdir -p "$HERMES_HOME"
chmod 700 "$HERMES_HOME"

log "Hermes Agent"
confirm_external_installer
install_hermes_agent
resolve_hermes_bin
chmod 700 "$HERMES_HOME"
git config --system --add safe.directory "$HERMES_AGENT_DIR" 2>/dev/null || true
summary_add installed "Hermes Agent"
if [ "$HERMES_SKIP_BROWSER" = true ]; then
  summary_add skipped "Hermes 浏览器安装 (--skip-browser)"
fi
ok "Hermes Agent 安装完成"

log "API Server"
configure_api_server
summary_add installed "API Server: $HERMES_API_HOST:$HERMES_API_PORT"
ok "API Server 已配置: $HERMES_API_HOST:$HERMES_API_PORT"

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
