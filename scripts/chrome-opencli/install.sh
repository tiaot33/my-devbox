#!/usr/bin/env bash
set -Eeuo pipefail
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
unset NODE_OPTIONS NODE_PATH NPM_CONFIG_PREFIX NPM_CONFIG_REGISTRY NPM_CONFIG_USERCONFIG

APP_USER="chrome-opencli"
APP_GROUP="chrome-opencli"
APP_HOME="/var/lib/chrome-opencli"
PROFILE_DIR="${APP_HOME}/chrome-profile"
OPENCLI_CONFIG_DIR="${APP_HOME}/.opencli"
CONFIG_DIR="/etc/chrome-opencli"
ENV_FILE="${CONFIG_DIR}/environment"
XAUTHORITY_FILE="${CONFIG_DIR}/Xauthority"
ACCOUNT_MARKER="${CONFIG_DIR}/managed-account"
POLICY_FILE="/etc/opt/chrome/policies/managed/chrome-opencli.json"

OPENCLI_EXTENSION_ID="ildkmabpimmkaediidaifkhjpohdnifk"
OPENCLI_EXTENSION_UPDATE_URL="https://clients2.google.com/service/update2/crx"
GOOGLE_CHROME_DEB_URL="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
NODESOURCE_KEY_URL="https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key"
NODESOURCE_KEY_FINGERPRINT="6F71F525282841EEDAF851B42F59B5F99B1BE0B4"

USER_SET_SCREEN_GEOMETRY="${SCREEN_GEOMETRY+x}"
USER_SET_VNC_BIND="${VNC_BIND+x}"
USER_SET_VNC_PORT="${VNC_PORT+x}"
VNC_PASSWORD_WAS_SET="${VNC_PASSWORD+x}"

DISPLAY_NUM=99
DISPLAY_VALUE=":${DISPLAY_NUM}"
SCREEN_GEOMETRY="${SCREEN_GEOMETRY:-1920x1080}"
VNC_BIND="${VNC_BIND:-127.0.0.1}"
VNC_PORT="${VNC_PORT:-5900}"
VNC_PASSWORD="${VNC_PASSWORD:-}"
ASSUME_YES="${ASSUME_YES:-0}"

NODE_MAJOR=22
VERIFY_TIMEOUT=120

TMP_DIR=""
VNC_AUTH_ARGS=""
STACK_TOUCHED=0

log() {
  printf '[chrome-opencli] %s\n' "$*"
}

die() {
  printf '[chrome-opencli] ERROR: %s\n' "$*" >&2
  exit 1
}

on_error() {
  local status="$?"
  printf '[chrome-opencli] ERROR: line %s failed with status %s: %s\n' "$1" "$status" "$2" >&2
}

cleanup() {
  local status="$?"
  trap - EXIT

  if [ "$status" -ne 0 ] && [ "$STACK_TOUCHED" = "1" ]; then
    systemctl disable --now chrome-opencli.target >/dev/null 2>&1 || true
    if id "$APP_USER" >/dev/null 2>&1 && command -v opencli >/dev/null 2>&1; then
      run_as_app_user opencli daemon stop >/dev/null 2>&1 || true
    fi
  fi
  if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
    rm -rf -- "$TMP_DIR"
  fi
  exit "$status"
}

trap 'on_error "$LINENO" "$BASH_COMMAND"' ERR
trap cleanup EXIT

usage() {
  cat <<'EOF'
用法：sudo bash install.sh [--help]

默认启动交互配置，依次选择桌面分辨率、VNC 监听方式、端口和密码。
无人值守安装使用 ASSUME_YES=1，并通过环境变量覆盖配置。

常用环境变量：
  SCREEN_GEOMETRY    默认 1920x1080
  VNC_BIND           默认 127.0.0.1
  VNC_PORT           默认 5900
  VNC_PASSWORD       未设置时保留旧密码或首次随机生成；显式空值表示无密码
EOF
}

parse_args() {
  [ "$#" -eq 0 ] && return
  case "$1" in
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
}

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    die "please run as root, for example: sudo bash install.sh"
  fi
}

check_platform() {
  [ -r /etc/os-release ] || die "/etc/os-release is missing"

  # shellcheck disable=SC1091
  . /etc/os-release
  local version_major
  version_major="${VERSION_ID:-}"
  version_major="${version_major%%.*}"
  case "${ID:-}" in
    debian)
      case "$version_major" in ''|*[!0-9]*) die "cannot determine the Debian version" ;; esac
      [ "$version_major" -ge 11 ] || die "Debian 11 or newer is required"
      ;;
    ubuntu)
      case "${VERSION_ID:-}" in
        20.04|22.04|24.04|26.04) ;;
        *) die "supported Ubuntu LTS versions are 20.04, 22.04, 24.04, and 26.04" ;;
      esac
      ;;
    *) die "only Debian and Ubuntu are supported (detected: ${PRETTY_NAME:-unknown})" ;;
  esac

  local arch
  arch="$(dpkg --print-architecture)"
  [ "$arch" = "amd64" ] || die "Google Chrome for Linux is only provided here for amd64; detected: ${arch}"

  command -v systemctl >/dev/null 2>&1 || die "systemctl is required"
  local init_process=""
  if [ -r /proc/1/comm ]; then
    read -r init_process < /proc/1/comm || true
  fi
  [ "$init_process" = "systemd" ] || die "systemd must be running as PID 1"
}

validate_integer_range() {
  local name="$1"
  local value="$2"
  local min="$3"
  local max="$4"

  case "$value" in
    ''|*[!0-9]*) die "${name} must be an integer" ;;
  esac
  if [ "$value" -lt "$min" ] || [ "$value" -gt "$max" ]; then
    die "${name} must be between ${min} and ${max}"
  fi
}

validate_vnc_password() {
  local value="$1"
  if [[ ! "$value" =~ ^[A-Za-z0-9._@#%+=-]{1,8}$ ]]; then
    die "VNC_PASSWORD must be 1-8 characters from A-Z, a-z, 0-9, . _ @ # % + = -"
  fi
}

is_loopback_bind() {
  case "$VNC_BIND" in
    127.0.0.1) return 0 ;;
    *) return 1 ;;
  esac
}

validate_vnc_password_for_bind() {
  local value="$1"
  if ! is_loopback_bind && [ "${#value}" -ne 8 ]; then
    die "VNC_PASSWORD must be exactly 8 characters when VNC_BIND is not 127.0.0.1"
  fi
}

is_interactive() {
  [ -t 0 ] && [ "$ASSUME_YES" != "1" ]
}

prompt_screen_geometry() {
  [ "$USER_SET_SCREEN_GEOMETRY" = "x" ] && return

  local choice custom_value
  printf '\n选择远程桌面分辨率：\n'
  printf '  1) 1920x1080（推荐）\n'
  printf '  2) 1440x900\n'
  printf '  3) 1280x720\n'
  printf '  4) 自定义\n'
  read -r -p '请选择 [1]: ' choice
  case "${choice:-1}" in
    1) SCREEN_GEOMETRY="1920x1080" ;;
    2) SCREEN_GEOMETRY="1440x900" ;;
    3) SCREEN_GEOMETRY="1280x720" ;;
    4)
      read -r -p '请输入分辨率，例如 1600x900: ' custom_value
      SCREEN_GEOMETRY="$custom_value"
      ;;
    *) SCREEN_GEOMETRY="1920x1080" ;;
  esac
}

prompt_vnc_bind() {
  [ "$USER_SET_VNC_BIND" = "x" ] && return

  local choice custom_value
  printf '\n选择 VNC 访问方式：\n'
  printf '  1) 仅本机监听，通过 SSH 隧道访问（推荐）\n'
  printf '  2) 监听所有网卡，可直接远程连接\n'
  printf '  3) 自定义监听地址\n'
  read -r -p '请选择 [1]: ' choice
  case "${choice:-1}" in
    1) VNC_BIND="127.0.0.1" ;;
    2) VNC_BIND="0.0.0.0" ;;
    3)
      read -r -p '请输入监听地址: ' custom_value
      VNC_BIND="$custom_value"
      ;;
    *) VNC_BIND="127.0.0.1" ;;
  esac
}

generate_vnc_password() {
  dd if=/dev/urandom bs=6 count=1 status=none | base64 | tr '/+' '_@'
}

prompt_vnc_password() {
  [ "$VNC_PASSWORD_WAS_SET" = "x" ] && return

  local choice first second
  printf '\n选择 VNC 密码方式：\n'
  printf '  1) 保留已有密码；首次安装时随机生成（推荐）\n'
  printf '  2) 生成一个新的随机密码\n'
  printf '  3) 自定义密码\n'
  printf '  4) 不使用密码（仅允许 VNC_BIND=127.0.0.1）\n'
  read -r -p '请选择 [1]: ' choice
  case "${choice:-1}" in
    1) ;;
    2)
      VNC_PASSWORD="$(generate_vnc_password)"
      VNC_PASSWORD_WAS_SET="x"
      ;;
    3)
      if is_loopback_bind; then
        read -r -s -p '请输入 VNC 密码（1-8 位）: ' first
      else
        read -r -s -p '请输入 VNC 密码（对外监听必须为 8 位）: ' first
      fi
      printf '\n'
      read -r -s -p '请再次输入: ' second
      printf '\n'
      [ "$first" = "$second" ] || die "两次输入的 VNC 密码不一致"
      VNC_PASSWORD="$first"
      VNC_PASSWORD_WAS_SET="x"
      ;;
    4)
      VNC_PASSWORD=""
      VNC_PASSWORD_WAS_SET="x"
      ;;
    *) ;;
  esac
}

confirm_configuration() {
  local password_mode="保留已有密码或随机生成"
  if [ "$VNC_PASSWORD_WAS_SET" = "x" ]; then
    if [ -n "$VNC_PASSWORD" ]; then
      password_mode="使用本次设置的密码"
    else
      password_mode="无密码（高风险）"
    fi
  fi

  printf '\n即将安装，配置如下：\n'
  printf '  桌面分辨率: %s\n' "$SCREEN_GEOMETRY"
  printf '  VNC 监听地址: %s\n' "$VNC_BIND"
  printf '  VNC 端口: %s\n' "$VNC_PORT"
  printf '  VNC 密码: %s\n' "$password_mode"
  if ! is_loopback_bind; then
    printf '  注意: VNC 将对网络开放，请使用防火墙或 VPN 限制来源。\n'
  fi

  local answer
  read -r -p '继续安装？[Y/n]: ' answer
  case "${answer:-y}" in
    y|Y|yes|YES) ;;
    *) printf '已取消。\n'; exit 0 ;;
  esac
}

collect_configuration() {
  case "$ASSUME_YES" in
    0|1) ;;
    *) die "ASSUME_YES must be 0 or 1" ;;
  esac

  if ! is_interactive; then
    if [ "$ASSUME_YES" != "1" ]; then
      die "未检测到交互终端；无人值守安装请设置 ASSUME_YES=1"
    fi
    return
  fi

  printf 'Chrome + OpenCLI + VNC 安装配置\n'
  prompt_screen_geometry
  prompt_vnc_bind
  if [ "$USER_SET_VNC_PORT" != "x" ]; then
    local port
    read -r -p "VNC 端口（直接回车使用 ${VNC_PORT}）: " port
    VNC_PORT="${port:-$VNC_PORT}"
  fi
  prompt_vnc_password
}

validate_config() {
  local screen_width screen_height
  validate_integer_range VNC_PORT "$VNC_PORT" 1 65535

  [[ "$SCREEN_GEOMETRY" =~ ^[0-9]+x[0-9]+$ ]] || die "SCREEN_GEOMETRY must look like 1920x1080"
  screen_width="${SCREEN_GEOMETRY%x*}"
  screen_height="${SCREEN_GEOMETRY#*x}"
  validate_integer_range SCREEN_WIDTH "$screen_width" 640 7680
  validate_integer_range SCREEN_HEIGHT "$screen_height" 480 4320

  if [[ ! "$VNC_BIND" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
    die "VNC_BIND must be an IPv4 address or hostname and cannot start with '-'"
  fi

  if [ "$VNC_PASSWORD_WAS_SET" = "x" ] && [ -n "$VNC_PASSWORD" ]; then
    validate_vnc_password "$VNC_PASSWORD"
    validate_vnc_password_for_bind "$VNC_PASSWORD"
  fi
  if [ "$VNC_PASSWORD_WAS_SET" = "x" ] && [ -z "$VNC_PASSWORD" ] && ! is_loopback_bind; then
    die "passwordless VNC is only allowed with a loopback VNC_BIND such as 127.0.0.1"
  fi
  if [ "$VNC_PASSWORD_WAS_SET" != "x" ] && ! is_loopback_bind && \
     [ -s "${CONFIG_DIR}/vnc-password.txt" ]; then
    local existing_vnc_password
    existing_vnc_password="$(tr -d '\r\n' < "${CONFIG_DIR}/vnc-password.txt")"
    validate_vnc_password "$existing_vnc_password"
    validate_vnc_password_for_bind "$existing_vnc_password"
  fi
}

apt_get() {
  DEBIAN_FRONTEND=noninteractive apt-get \
    -o DPkg::Lock::Timeout=300 \
    -o Acquire::Retries=3 \
    "$@"
}

download() {
  local url="$1"
  local output="$2"

  curl --disable --proto '=https' --proto-redir '=https' --tlsv1.2 --fail --location --silent --show-error \
    --retry 3 --retry-delay 2 --output "$output" "$url"
  [ -s "$output" ] || die "downloaded file is empty: ${url}"
}

render_file() {
  install -m 0600 /dev/stdin "${TMP_DIR}/$1"
}

stop_existing_services() {
  log "Stopping an existing chrome-opencli stack, if present"
  STACK_TOUCHED=1
  systemctl stop chrome-opencli.target >/dev/null 2>&1 || true

  if id "$APP_USER" >/dev/null 2>&1 && command -v opencli >/dev/null 2>&1; then
    run_as_app_user opencli daemon stop >/dev/null 2>&1 || true
    local attempt
    for ((attempt = 0; attempt < 30; attempt++)); do
      if ! daemon_is_listening; then
        break
      fi
      sleep 0.2
    done
  fi
  if daemon_is_listening; then
    die "TCP port 19825 is still occupied; stop the existing OpenCLI daemon before retrying"
  fi
}

daemon_is_listening() {
  [ -n "$(ss -ltnH | awk '$4 ~ /:19825$/ { print; exit }')" ]
}

install_base_packages() {
  log "Installing X11, VNC, desktop, font, and download dependencies"
  apt_get update
  apt_get install -y --no-install-recommends \
    ca-certificates \
    curl \
    dbus-x11 \
    fonts-liberation \
    fonts-noto-cjk \
    fonts-noto-color-emoji \
    gnupg \
    iproute2 \
    openbox \
    x11vnc \
    xauth \
    x11-utils \
    xvfb
}

install_google_chrome() {
  if dpkg-query -W -f='${Status}' google-chrome-stable 2>/dev/null | grep -q '^install ok installed$'; then
    log "Updating Google Chrome Stable from its configured apt repository"
    apt_get install -y --no-install-recommends google-chrome-stable
  else
    local chrome_deb="${TMP_DIR}/google-chrome-stable.deb"
    log "Downloading Google Chrome Stable"
    download "$GOOGLE_CHROME_DEB_URL" "$chrome_deb"

    [ "$(dpkg-deb -f "$chrome_deb" Package)" = "google-chrome-stable" ] || \
      die "downloaded deb is not the google-chrome-stable package"
    [ "$(dpkg-deb -f "$chrome_deb" Architecture)" = "amd64" ] || \
      die "downloaded Google Chrome package has an unexpected architecture"

    apt_get install -y --no-install-recommends "$chrome_deb"
  fi

  command -v google-chrome-stable >/dev/null 2>&1 || die "google-chrome-stable was not installed"
}

node_is_usable() {
  command -v node >/dev/null 2>&1 || return 1
  command -v npm >/dev/null 2>&1 || return 1

  local installed_major
  installed_major="$(node -p 'Number(process.versions.node.split(".")[0])' 2>/dev/null || true)"
  case "$installed_major" in
    ''|*[!0-9]*) return 1 ;;
  esac
  [ "$installed_major" -ge 20 ]
}

install_node() {
  if node_is_usable; then
    log "Using existing $(node --version) with npm $(npm --version)"
    return
  fi

  log "Installing Node.js ${NODE_MAJOR}.x from NodeSource"
  local key_source="${TMP_DIR}/nodesource-repo.gpg.key"
  local key_fingerprint
  download "$NODESOURCE_KEY_URL" "$key_source"

  install -d -m 0755 /etc/apt/keyrings
  install -d -m 0700 "${TMP_DIR}/gnupg"
  key_fingerprint="$(gpg \
    --no-options \
    --batch \
    --homedir "${TMP_DIR}/gnupg" \
    --show-keys \
    --with-colons \
    "$key_source" 2>/dev/null | awk -F: '$1 == "fpr" && first == "" { first = $10 } END { print first }')"
  [ "$key_fingerprint" = "$NODESOURCE_KEY_FINGERPRINT" ] || \
    die "NodeSource signing key fingerprint mismatch: ${key_fingerprint:-missing}"
  gpg --no-options --batch --yes --dearmor --output /etc/apt/keyrings/nodesource.gpg "$key_source"
  chmod 0644 /etc/apt/keyrings/nodesource.gpg

  install -m 0644 /dev/stdin /etc/apt/sources.list.d/nodesource.list <<EOF
deb [arch=amd64 signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main
EOF

  apt_get update
  apt_get install -y --no-install-recommends nodejs
  node_is_usable || die "OpenCLI requires Node.js >= 20 and npm"
}

install_opencli() {
  log "Installing the latest @jackwener/opencli globally"
  NPM_CONFIG_USERCONFIG=/dev/null npm install \
    --global \
    --prefix /usr/local \
    --ignore-scripts \
    --registry=https://registry.npmjs.org/ \
    @jackwener/opencli@latest
  [ -x /usr/local/bin/opencli ] || die "opencli command was not installed at /usr/local/bin/opencli"
  run_as_app_user /usr/local/bin/opencli --version >/dev/null
}

create_app_user() {
  local account_id passwd_record existing_home existing_group existing_shell

  if id "$APP_USER" >/dev/null 2>&1; then
    [ -r "$ACCOUNT_MARKER" ] || \
      die "existing user ${APP_USER} is not managed by this installer"
    account_id="$(id -u "$APP_USER"):$(id -g "$APP_USER")"
    [ "$(tr -d '\r\n' < "$ACCOUNT_MARKER")" = "$account_id" ] || \
      die "existing user ${APP_USER} no longer matches the installer record"

    passwd_record="$(getent passwd "$APP_USER")"
    IFS=: read -r _ _ _ _ _ existing_home existing_shell <<<"$passwd_record"
    existing_group="$(id -gn "$APP_USER")"
    [ "$existing_home" = "$APP_HOME" ] && \
      [ "$existing_group" = "$APP_GROUP" ] && \
      [ "$existing_shell" = "/usr/sbin/nologin" ] || \
      die "existing user ${APP_USER} has unexpected account settings"
    return
  fi

  getent group "$APP_GROUP" >/dev/null && \
    die "existing group ${APP_GROUP} is not managed by this installer"
  useradd \
    --system \
    --user-group \
    --home-dir "$APP_HOME" \
    --shell /usr/sbin/nologin \
    "$APP_USER"

  install -d -m 0750 -o root -g "$APP_GROUP" "$CONFIG_DIR"
  account_id="$(id -u "$APP_USER"):$(id -g "$APP_USER")"
  printf '%s\n' "$account_id" | \
    install -m 0644 -o root -g root /dev/stdin "$ACCOUNT_MARKER"
}

prepare_app_directories() {
  log "Preparing the persistent Chrome profile and OpenCLI state"
  install -d -m 0700 -o "$APP_USER" -g "$APP_GROUP" "$APP_HOME"
  run_as_app_user install -d -m 0700 \
    "$PROFILE_DIR" \
    "$OPENCLI_CONFIG_DIR" \
    "${APP_HOME}/Downloads"
  install -d -m 0750 -o root -g "$APP_GROUP" "$CONFIG_DIR"
}

run_as_app_user() {
  runuser -u "$APP_USER" -- env -i \
    HOME="$APP_HOME" \
    OPENCLI_CONFIG_DIR="$OPENCLI_CONFIG_DIR" \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    LANG=C.UTF-8 \
    NO_COLOR=1 \
    TERM=dumb \
    "$@"
}

render_chrome_policy() {
  render_file chrome-opencli.json <<EOF
{
  "ExtensionSettings": {
    "${OPENCLI_EXTENSION_ID}": {
      "installation_mode": "force_installed",
      "update_url": "${OPENCLI_EXTENSION_UPDATE_URL}"
    }
  }
}
EOF
}

configure_vnc_password() {
  local password_file="${CONFIG_DIR}/vnc-password.txt"
  local auth_file="${CONFIG_DIR}/vnc.pass"

  if [ "$VNC_PASSWORD_WAS_SET" = "x" ]; then
    if [ -z "$VNC_PASSWORD" ]; then
      log "Configuring passwordless VNC because VNC_PASSWORD was explicitly set to empty"
      rm -f "$password_file" "$auth_file"
      VNC_AUTH_ARGS="-nopw"
      return
    fi
  elif [ -s "$password_file" ]; then
    VNC_PASSWORD="$(tr -d '\r\n' < "$password_file")"
  else
    VNC_PASSWORD="$(generate_vnc_password)"
  fi

  validate_vnc_password "$VNC_PASSWORD"
  validate_vnc_password_for_bind "$VNC_PASSWORD"
  printf '%s\n' "$VNC_PASSWORD" | install -m 0600 -o root -g root /dev/stdin "$password_file"
  x11vnc -storepasswd "$VNC_PASSWORD" "$auth_file" >/dev/null
  chmod 0600 "$auth_file"
  chown "$APP_USER:$APP_GROUP" "$auth_file"

  VNC_AUTH_ARGS="-rfbauth ${auth_file}"
}

configure_xauthority() {
  local cookie
  cookie="$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')"
  [ "${#cookie}" -eq 32 ] || die "failed to generate an X11 authentication cookie"

  rm -f "$XAUTHORITY_FILE"
  install -m 0600 -o root -g root /dev/null "$XAUTHORITY_FILE"
  xauth -f "$XAUTHORITY_FILE" add "$DISPLAY_VALUE" MIT-MAGIC-COOKIE-1 "$cookie"
  chmod 0600 "$XAUTHORITY_FILE"
  chown "$APP_USER:$APP_GROUP" "$XAUTHORITY_FILE"
}

render_environment_file() {
  render_file environment <<EOF
DISPLAY=${DISPLAY_VALUE}
HOME=${APP_HOME}
OPENCLI_CONFIG_DIR=${OPENCLI_CONFIG_DIR}
XAUTHORITY=${XAUTHORITY_FILE}
LANG=C.UTF-8
EOF
}

render_systemd_units() {
  render_file chrome-opencli.target <<'EOF'
[Unit]
Description=Google Chrome, OpenCLI, and VNC stack
Wants=chrome-opencli-xvfb.service chrome-opencli-openbox.service chrome-opencli-browser.service chrome-opencli-vnc.service

[Install]
WantedBy=multi-user.target
EOF

  render_file chrome-opencli-xvfb.service <<EOF
[Unit]
Description=Chrome OpenCLI virtual X display
PartOf=chrome-opencli.target

[Service]
Type=simple
User=${APP_USER}
Group=${APP_GROUP}
EnvironmentFile=${ENV_FILE}
ExecStart=/usr/bin/Xvfb ${DISPLAY_VALUE} -screen 0 ${SCREEN_GEOMETRY}x24 -nolisten tcp -auth ${XAUTHORITY_FILE}
ExecStartPost=/usr/bin/timeout 30 /bin/sh -c 'until /usr/bin/xdpyinfo >/dev/null 2>&1; do /usr/bin/sleep 0.2; done'
Restart=always
RestartSec=2
EOF

  render_file chrome-opencli-openbox.service <<EOF
[Unit]
Description=Chrome OpenCLI window manager
Requires=chrome-opencli-xvfb.service
After=chrome-opencli-xvfb.service
PartOf=chrome-opencli.target

[Service]
Type=simple
User=${APP_USER}
Group=${APP_GROUP}
EnvironmentFile=${ENV_FILE}
ExecStart=/usr/bin/openbox --sm-disable
Restart=always
RestartSec=2
EOF

  render_file chrome-opencli-browser.service <<EOF
[Unit]
Description=Google Chrome with OpenCLI Browser Bridge
Documentation=https://chromewebstore.google.com/detail/opencli/${OPENCLI_EXTENSION_ID}
Requires=chrome-opencli-xvfb.service chrome-opencli-openbox.service
After=chrome-opencli-xvfb.service chrome-opencli-openbox.service network-online.target
Wants=network-online.target
PartOf=chrome-opencli.target

[Service]
Type=simple
User=${APP_USER}
Group=${APP_GROUP}
WorkingDirectory=${APP_HOME}
EnvironmentFile=${ENV_FILE}
Environment=XDG_RUNTIME_DIR=/run/chrome-opencli
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
RuntimeDirectory=chrome-opencli
RuntimeDirectoryMode=0700
UMask=0077
ExecStart=/usr/bin/dbus-run-session -- /usr/bin/google-chrome-stable --user-data-dir=${PROFILE_DIR} --no-first-run --no-default-browser-check --disable-dev-shm-usage --disable-session-crashed-bubble --password-store=basic --window-size=${SCREEN_GEOMETRY/x/,} about:blank
Restart=always
RestartSec=3
TimeoutStopSec=30
EOF

  render_file chrome-opencli-vnc.service <<EOF
[Unit]
Description=Chrome OpenCLI VNC server
Requires=chrome-opencli-xvfb.service
After=chrome-opencli-xvfb.service
PartOf=chrome-opencli.target

[Service]
Type=simple
User=${APP_USER}
Group=${APP_GROUP}
EnvironmentFile=${ENV_FILE}
ExecStart=/usr/bin/x11vnc -display ${DISPLAY_VALUE} -auth ${XAUTHORITY_FILE} ${VNC_AUTH_ARGS} -rfbport ${VNC_PORT} -no6 -listen ${VNC_BIND} -forever -shared -noxdamage -repeat -xkb
Restart=always
RestartSec=2
EOF
}

install_rendered_files() {
  local unit
  log "Installing Chrome policy and systemd units"
  install -d -m 0755 /etc/opt/chrome/policies/managed
  install -m 0644 "${TMP_DIR}/chrome-opencli.json" "$POLICY_FILE"
  install -m 0640 -o root -g "$APP_GROUP" "${TMP_DIR}/environment" "$ENV_FILE"
  for unit in \
    chrome-opencli.target \
    chrome-opencli-xvfb.service \
    chrome-opencli-openbox.service \
    chrome-opencli-browser.service \
    chrome-opencli-vnc.service; do
    install -m 0644 "${TMP_DIR}/${unit}" "/etc/systemd/system/${unit}"
  done
}

assert_services_active() {
  local unit
  for unit in \
    chrome-opencli-xvfb.service \
    chrome-opencli-openbox.service \
    chrome-opencli-browser.service \
    chrome-opencli-vnc.service; do
    if ! systemctl is-active --quiet "$unit"; then
      systemctl --no-pager --full status "$unit" >&2 || true
      journalctl --no-pager -u "$unit" -n 80 >&2 || true
      die "${unit} is not active"
    fi
  done
}

verify_services() {
  log "Verifying services and the OpenCLI browser connection"
  assert_services_active

  local deadline doctor_output=""
  deadline=$((SECONDS + VERIFY_TIMEOUT))
  while [ "$SECONDS" -lt "$deadline" ]; do
    doctor_output="$(run_as_app_user opencli doctor 2>&1 || true)"
    if grep -q '^\[OK\] Extension: connected' <<<"$doctor_output" && \
       grep -q '^\[OK\] Connectivity: connected' <<<"$doctor_output"; then
      printf '%s\n' "$doctor_output"
      return
    fi
    sleep 3
  done

  printf '%s\n' "$doctor_output" >&2
  printf 'VNC password file: %s/vnc-password.txt (readable by root only)\n' "$CONFIG_DIR" >&2
  systemctl --no-pager --full status chrome-opencli-browser.service >&2 || true
  journalctl --no-pager -u chrome-opencli-browser.service -n 100 >&2 || true
  die "OpenCLI extension did not connect within ${VERIFY_TIMEOUT}s; check Chrome Web Store connectivity and chrome://policy"
}

print_result() {
  local server_ip
  server_ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  [ -n "$server_ip" ] || server_ip="<server-ip>"
  printf '\n安装完成。\nVNC 密码: %s\n' "${VNC_PASSWORD:-<none>}"

  if is_loopback_bind; then
    printf 'SSH 隧道:\n  ssh -N -L %s:127.0.0.1:%s <ssh-user>@%s\n' \
      "$VNC_PORT" "$VNC_PORT" "$server_ip"
    printf 'VNC 地址: 127.0.0.1:%s\n' "$VNC_PORT"
  else
    printf 'VNC 地址: %s:%s\n' "$server_ip" "$VNC_PORT"
    printf '警告: 请使用防火墙或 VPN 限制来源。\n'
  fi
}

main() {
  parse_args "$@"
  require_root
  check_platform
  collect_configuration
  validate_config
  if is_interactive; then
    confirm_configuration
  fi
  TMP_DIR="$(mktemp -d -t chrome-opencli.XXXXXX)"

  create_app_user
  prepare_app_directories
  install_base_packages
  stop_existing_services
  install_google_chrome
  install_node
  install_opencli
  render_chrome_policy
  configure_vnc_password
  configure_xauthority
  render_environment_file
  render_systemd_units
  install_rendered_files
  systemctl daemon-reload
  systemctl start chrome-opencli.target
  verify_services
  systemctl enable chrome-opencli.target >/dev/null
  STACK_TOUCHED=0
  print_result
}

if [ -z "${BASH_SOURCE[0]:-}" ] || [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
