#!/usr/bin/env bash
set -Eeuo pipefail
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
unset NODE_OPTIONS NODE_PATH NPM_CONFIG_PREFIX NPM_CONFIG_REGISTRY NPM_CONFIG_USERCONFIG

APP_USER="chrome-opencli"
APP_GROUP="chrome-opencli"
APP_HOME="/var/lib/chrome-opencli"
CONFIG_DIR="/etc/chrome-opencli"
POLICY_FILE="/etc/opt/chrome/policies/managed/chrome-opencli.json"

PURGE_DATA=0
REMOVE_PACKAGES=0

log() {
  printf '[chrome-opencli-uninstall] %s\n' "$*"
}

die() {
  printf '[chrome-opencli-uninstall] ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
用法：sudo bash uninstall.sh [选项]

选项：
  --purge-data       删除 Chrome profile、登录状态和 VNC 密码；仅删除本脚本创建的用户和组。
  --remove-packages  同时卸载 @jackwener/opencli 和 google-chrome-stable。
  -h, --help         显示帮助。

未指定 --purge-data 时会保留 /var/lib/chrome-opencli 和 /etc/chrome-opencli。
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --purge-data) PURGE_DATA=1 ;;
      --remove-packages) REMOVE_PACKAGES=1 ;;
      -h|--help) usage; exit 0 ;;
      *) die "未知选项: $1" ;;
    esac
    shift
  done
}

require_root() {
  [ "$(id -u)" -eq 0 ] || die "请以 root 执行，例如：sudo bash uninstall.sh"
}

daemon_is_listening() {
  if command -v ss >/dev/null 2>&1; then
    [ -n "$(ss -ltnH | awk '$4 ~ /:19825$/ { print; exit }')" ]
    return
  fi
  (exec 3<>/dev/tcp/127.0.0.1/19825) 2>/dev/null
}

stop_services() {
  log "正在停止并禁用服务"
  systemctl disable --now chrome-opencli.target >/dev/null 2>&1 || true
  systemctl stop \
    chrome-opencli-browser.service \
    chrome-opencli-vnc.service \
    chrome-opencli-openbox.service \
    chrome-opencli-xvfb.service \
    chrome-opencli-daemon.service >/dev/null 2>&1 || true

  if ! id "$APP_USER" >/dev/null 2>&1; then
    return
  fi

  if command -v opencli >/dev/null 2>&1; then
    runuser -u "$APP_USER" -- env -i \
      HOME="$APP_HOME" \
      OPENCLI_CONFIG_DIR="${APP_HOME}/.opencli" \
      PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
      LANG=C.UTF-8 \
      NO_COLOR=1 \
      TERM=dumb \
      opencli daemon stop >/dev/null 2>&1 || true
  fi

  local attempt
  for ((attempt = 0; attempt < 30; attempt++)); do
    if ! daemon_is_listening; then
      return
    fi
    sleep 0.2
  done
  die "TCP 端口 19825 仍被占用；请先停止 OpenCLI daemon 后重试"
}

remove_units_and_policy() {
  log "正在删除 systemd 单元和 OpenCLI Chrome 策略"
  rm -f \
    /etc/systemd/system/chrome-opencli.target \
    /etc/systemd/system/chrome-opencli-daemon.service \
    /etc/systemd/system/chrome-opencli-xvfb.service \
    /etc/systemd/system/chrome-opencli-openbox.service \
    /etc/systemd/system/chrome-opencli-browser.service \
    /etc/systemd/system/chrome-opencli-vnc.service \
    /usr/local/libexec/chrome-opencli-prepare-display \
    /usr/local/libexec/chrome-opencli-wait-display \
    "$POLICY_FILE"
  systemctl daemon-reload
  systemctl reset-failed >/dev/null 2>&1 || true
}

purge_data() {
  [ "$PURGE_DATA" = "1" ] || return

  log "正在删除持久 Chrome profile 和 chrome-opencli 配置"
  local user_origin="existing"
  local group_origin="existing"
  local expected_uid=""
  local expected_gid=""
  if [ -r "${CONFIG_DIR}/user-origin" ]; then
    user_origin="$(tr -d '\r\n' < "${CONFIG_DIR}/user-origin")"
  fi
  if [ -r "${CONFIG_DIR}/group-origin" ]; then
    group_origin="$(tr -d '\r\n' < "${CONFIG_DIR}/group-origin")"
  fi
  if [ -r "${CONFIG_DIR}/user-id" ]; then
    expected_uid="$(tr -d '\r\n' < "${CONFIG_DIR}/user-id")"
  fi
  if [ -r "${CONFIG_DIR}/group-id" ]; then
    expected_gid="$(tr -d '\r\n' < "${CONFIG_DIR}/group-id")"
  fi

  if [ "$user_origin" = "created" ] && id "$APP_USER" >/dev/null 2>&1; then
    [ -n "$expected_uid" ] || die "缺少 ${APP_USER} 的 UID 记录，拒绝删除账号"
    [ "$(id -u "$APP_USER")" = "$expected_uid" ] || \
      die "${APP_USER} 当前 UID 与安装记录不一致"
    userdel "$APP_USER"
  fi
  if [ "$group_origin" = "created" ] && getent group "$APP_GROUP" >/dev/null; then
    [ -n "$expected_gid" ] || die "缺少 ${APP_GROUP} 的 GID 记录，拒绝删除组"
    [ "$(getent group "$APP_GROUP" | cut -d: -f3)" = "$expected_gid" ] || \
      die "${APP_GROUP} 当前 GID 与安装记录不一致"
    groupdel "$APP_GROUP"
  fi
  rm -rf -- "$APP_HOME" "$CONFIG_DIR"
}

remove_packages() {
  [ "$REMOVE_PACKAGES" = "1" ] || return

  log "正在卸载 OpenCLI 和 Google Chrome Stable"
  if command -v npm >/dev/null 2>&1; then
    NPM_CONFIG_USERCONFIG=/dev/null npm uninstall \
      --global \
      --prefix /usr/local \
      --ignore-scripts \
      --registry=https://registry.npmjs.org/ \
      @jackwener/opencli
  fi
  DEBIAN_FRONTEND=noninteractive apt-get purge -y google-chrome-stable
}

print_result() {
  printf '\n卸载完成。\n'
  if [ "$PURGE_DATA" = "0" ]; then
    printf '已保留数据：\n  %s\n  %s\n' "$APP_HOME" "$CONFIG_DIR"
  fi
  if [ "$REMOVE_PACKAGES" = "0" ]; then
    printf 'Google Chrome 和全局 opencli 命令仍保留。\n'
  fi
}

main() {
  parse_args "$@"
  require_root
  command -v systemctl >/dev/null 2>&1 || die "需要 systemctl"
  stop_services
  remove_units_and_policy
  purge_data
  remove_packages
  print_result
}

if [ -z "${BASH_SOURCE[0]:-}" ] || [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
