#!/usr/bin/env bash
set -Eeuo pipefail

# Install CloakBrowser on a clean Ubuntu/Debian LXC host.
# This is a single-file installer; it does not need a local CloakBrowser source tree.
# Run from any directory:
#   sudo bash install.sh
#
# Useful overrides:
#   VNC_PASSWORD=change-me sudo -E bash install.sh
#   VNC_PASSWORD= sudo -E bash install.sh
#   VNC_BIND=127.0.0.1 sudo -E bash install.sh
#   CDP_BIND=0.0.0.0 CDP_PORT=9222 sudo -E bash install.sh
#   CLOAKSERVE_PROXY_SERVER=http://proxy:8080 sudo -E bash install.sh
#   ENABLE_CLOAKSERVE=1 sudo -E bash install.sh
#   CLOAKBROWSER_FETCH_WIDEVINE=1 sudo -E bash install.sh

# shellcheck disable=SC2034
USER_SET_VNC_PORT="${VNC_PORT+x}"
# shellcheck disable=SC2034
USER_SET_VNC_BIND="${VNC_BIND+x}"
# shellcheck disable=SC2034
USER_SET_CDP_PORT="${CDP_PORT+x}"
# shellcheck disable=SC2034
USER_SET_CDP_BIND="${CDP_BIND+x}"
# shellcheck disable=SC2034
USER_SET_ENABLE_CLOAKSERVE="${ENABLE_CLOAKSERVE+x}"
# shellcheck disable=SC2034
USER_SET_CLOAKSERVE_HEADLESS="${CLOAKSERVE_HEADLESS+x}"
# shellcheck disable=SC2034
USER_SET_CLOAKSERVE_DATA_DIR="${CLOAKSERVE_DATA_DIR+x}"
# shellcheck disable=SC2034
USER_SET_CLOAKSERVE_IDLE_TIMEOUT="${CLOAKSERVE_IDLE_TIMEOUT+x}"
# shellcheck disable=SC2034
USER_SET_CLOAKSERVE_FINGERPRINT="${CLOAKSERVE_FINGERPRINT+x}"
# shellcheck disable=SC2034
USER_SET_CLOAKSERVE_LOCALE="${CLOAKSERVE_LOCALE+x}"
# shellcheck disable=SC2034
USER_SET_CLOAKSERVE_TIMEZONE="${CLOAKSERVE_TIMEZONE+x}"
# shellcheck disable=SC2034
USER_SET_CLOAKSERVE_PROXY_SERVER="${CLOAKSERVE_PROXY_SERVER+x}"
# shellcheck disable=SC2034
USER_SET_CLOAKSERVE_EXTRA_ARGS="${CLOAKSERVE_EXTRA_ARGS+x}"

APP_USER="${APP_USER:-cloakbrowser}"
APP_HOME="${APP_HOME:-/opt/cloakbrowser}"
APP_GROUP="${APP_GROUP:-$APP_USER}"
CLOAKSERVE_DATA_DIR_DEFAULT="${CLOAKSERVE_DATA_DIR_DEFAULT:-/var/lib/cloakbrowser/profiles}"
CLOAKSERVE_SCRIPT_URL="${CLOAKSERVE_SCRIPT_URL:-https://raw.githubusercontent.com/tiaot33/my-devbox/main/scripts/cloak-browser-scripts/cloakserve}"
DISPLAY_NUM="${DISPLAY_NUM:-99}"
DISPLAY_VALUE=":${DISPLAY_NUM}"
SCREEN_GEOMETRY="${SCREEN_GEOMETRY:-1920x1080}"
VNC_PORT="${VNC_PORT:-5900}"
VNC_BIND="${VNC_BIND:-0.0.0.0}"
CDP_PORT="${CDP_PORT:-9222}"
CDP_BIND="${CDP_BIND:-127.0.0.1}"
ENABLE_CLOAKSERVE="${ENABLE_CLOAKSERVE:-0}"
CLOAKSERVE_HEADLESS="${CLOAKSERVE_HEADLESS:-false}"
CLOAKSERVE_DATA_DIR="${CLOAKSERVE_DATA_DIR:-}"
CLOAKSERVE_IDLE_TIMEOUT="${CLOAKSERVE_IDLE_TIMEOUT:-}"
CLOAKSERVE_FINGERPRINT="${CLOAKSERVE_FINGERPRINT:-}"
CLOAKSERVE_LOCALE="${CLOAKSERVE_LOCALE:-}"
CLOAKSERVE_TIMEZONE="${CLOAKSERVE_TIMEZONE:-}"
CLOAKSERVE_PROXY_SERVER="${CLOAKSERVE_PROXY_SERVER:-}"
CLOAKSERVE_EXTRA_ARGS="${CLOAKSERVE_EXTRA_ARGS:-}"
INSTALL_JS="${INSTALL_JS:-1}"
CLOAKBROWSER_FETCH_WIDEVINE="${CLOAKBROWSER_FETCH_WIDEVINE:-0}"

log() {
  printf '[cloakbrowser-install] %s\n' "$*"
}

die() {
  printf '[cloakbrowser-install] ERROR: %s\n' "$*" >&2
  exit 1
}

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    die "please run as root, for example: sudo bash install.sh"
  fi
}

is_interactive() {
  [ -t 0 ] && [ "${ASSUME_YES:-0}" != "1" ]
}

prompt_value() {
  local var_name="$1"
  local label="$2"
  local default_value="$3"
  local value
  local user_set_var="USER_SET_${var_name}"

  if [ "${!user_set_var:-}" = "x" ]; then
    return
  fi

  if ! is_interactive; then
    printf -v "$var_name" '%s' "$default_value"
    return
  fi

  read -r -p "${label} (Enter=default) [${default_value}]: " value
  if [ -z "$value" ]; then
    value="$default_value"
  fi
  printf -v "$var_name" '%s' "$value"
}

prompt_optional_value() {
  local var_name="$1"
  local label="$2"
  local default_value="$3"
  local value
  local user_set_var="USER_SET_${var_name}"

  if [ "${!user_set_var:-}" = "x" ]; then
    return
  fi

  if ! is_interactive; then
    printf -v "$var_name" '%s' "$default_value"
    return
  fi

  read -r -p "${label} (Enter=skip/empty) [${default_value:-empty}]: " value
  if [ -z "$value" ]; then
    value="$default_value"
  fi
  printf -v "$var_name" '%s' "$value"
}

prompt_choice() {
  local var_name="$1"
  local label="$2"
  local default_value="$3"
  shift 3
  local user_set_var="USER_SET_${var_name}"

  if [ "${!user_set_var:-}" = "x" ]; then
    return
  fi

  if ! is_interactive; then
    printf -v "$var_name" '%s' "$default_value"
    return
  fi

  printf '\n%s:\n' "$label"
  local i=1 default_num=1 opts_val=()
  while [ $# -ge 2 ]; do
    opts_val+=("$1")
    printf '  %d) %s\n' "$i" "$2"
    [ "$1" = "$default_value" ] && default_num="$i"
    i=$((i + 1))
    shift 2
  done

  local choice
  read -r -p "Choose [${default_num}]: " choice
  choice="${choice:-$default_num}"
  if [ "$choice" -ge 1 ] 2>/dev/null && [ "$choice" -lt "$i" ]; then
    printf -v "$var_name" '%s' "${opts_val[$((choice - 1))]}"
  else
    printf -v "$var_name" '%s' "$default_value"
  fi
}

prompt_yes_no() {
  local var_name="$1"
  local label="$2"
  local default_value="$3"
  local value
  local default_num="2"
  local user_set_var="USER_SET_${var_name}"

  if [ "$default_value" = "1" ]; then
    default_num="1"
  fi

  if [ "${!user_set_var:-}" = "x" ]; then
    return
  fi

  if ! is_interactive; then
    printf -v "$var_name" '%s' "$default_value"
    return
  fi

  printf '\n%s:\n' "$label"
  printf '  1) Yes\n'
  printf '  2) No\n'
  read -r -p "Choose [${default_num}]: " value
  case "${value:-$default_num}" in
    1|y|Y|yes|YES) printf -v "$var_name" '1' ;;
    *) printf -v "$var_name" '0' ;;
  esac
}

prompt_confirm() {
  local label="$1"
  local default_value="$2"
  local value default_num

  if [ "$default_value" = "1" ]; then
    default_num="1"
  else
    default_num="2"
  fi

  if ! is_interactive; then
    [ "$default_value" = "1" ]
    return
  fi

  printf '\n%s:\n' "$label"
  printf '  1) Yes\n'
  printf '  2) No\n'
  read -r -p "Choose [${default_num}]: " value
  case "${value:-$default_num}" in
    1|y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

prompt_vnc_password() {
  if [ "${VNC_PASSWORD+x}" = "x" ]; then
    if [ -z "$VNC_PASSWORD" ]; then
      VNC_AUTH_MODE="none"
    else
      VNC_AUTH_MODE="password"
    fi
    return
  fi

  if ! is_interactive; then
    VNC_AUTH_MODE="random"
    return
  fi

  local choice custom_password
  printf '\nVNC password mode:\n'
  printf '  1) Generate random password\n'
  printf '  2) Enter custom password\n'
  printf '  3) No password\n'
  read -r -p 'Choose [1]: ' choice

  case "${choice:-1}" in
    2)
      read -r -s -p 'VNC password (max useful length is 8 chars): ' custom_password
      printf '\n'
      VNC_PASSWORD="$custom_password"
      if [ -z "$VNC_PASSWORD" ]; then
        VNC_AUTH_MODE="none"
      else
        VNC_AUTH_MODE="password"
      fi
      ;;
    3)
      VNC_PASSWORD=""
      VNC_AUTH_MODE="none"
      ;;
    *)
      VNC_AUTH_MODE="random"
      ;;
  esac
}

prompt_cloakserve_headless() {
  local choice default_choice

  if [ "${USER_SET_CLOAKSERVE_HEADLESS:-}" = "x" ]; then
    return
  fi

  if ! is_interactive; then
    return
  fi

  if [ "$CLOAKSERVE_HEADLESS" = "true" ]; then
    default_choice="2"
  else
    default_choice="1"
  fi

  printf '\ncloakserve browser mode:\n'
  printf '  1) Visible on VNC (recommended for debugging)\n'
  printf '  2) Headless\n'
  read -r -p "Choose [${default_choice}]: " choice

  case "${choice:-$default_choice}" in
    2) CLOAKSERVE_HEADLESS="true" ;;
    *) CLOAKSERVE_HEADLESS="false" ;;
  esac
}

prompt_config() {
  prompt_yes_no ENABLE_CLOAKSERVE "Enable cloakserve CDP service" "$ENABLE_CLOAKSERVE"
  prompt_value VNC_BIND "VNC listen address" "$VNC_BIND"
  prompt_value VNC_PORT "VNC port" "$VNC_PORT"
  prompt_vnc_password

  if [ "$ENABLE_CLOAKSERVE" = "1" ]; then
    prompt_choice CDP_BIND "CDP listen address" "$CDP_BIND" \
      "127.0.0.1" "127.0.0.1 (local only, safer)" \
      "0.0.0.0" "0.0.0.0 (all interfaces, public)"
    prompt_value CDP_PORT "CDP public port" "$CDP_PORT"
    prompt_cloakserve_headless

    if [ "${USER_SET_CLOAKSERVE_DATA_DIR:-}" != "x" ] && prompt_confirm "Use persistent cloakserve profile dir" 0; then
      prompt_value CLOAKSERVE_DATA_DIR "cloakserve profile dir" "$CLOAKSERVE_DATA_DIR_DEFAULT"
    fi

    if prompt_confirm "Configure advanced cloakserve defaults" 0; then
      prompt_optional_value CLOAKSERVE_IDLE_TIMEOUT "Stop idle cloakserve browsers after seconds" "$CLOAKSERVE_IDLE_TIMEOUT"
      prompt_optional_value CLOAKSERVE_FINGERPRINT "default fingerprint seed" "$CLOAKSERVE_FINGERPRINT"
      prompt_optional_value CLOAKSERVE_LOCALE "default locale" "$CLOAKSERVE_LOCALE"
      prompt_optional_value CLOAKSERVE_TIMEZONE "default timezone" "$CLOAKSERVE_TIMEZONE"
      prompt_optional_value CLOAKSERVE_PROXY_SERVER "default proxy server with GeoIP" "$CLOAKSERVE_PROXY_SERVER"
      prompt_optional_value CLOAKSERVE_EXTRA_ARGS "extra cloakserve/browser args" "$CLOAKSERVE_EXTRA_ARGS"
    fi
  fi
}

validate_no_whitespace() {
  local name="$1"
  local value="$2"
  if printf '%s' "$value" | grep -q '[[:space:]]'; then
    die "${name} cannot contain whitespace: ${value}"
  fi
}

validate_no_percent() {
  local name="$1"
  local value="$2"
  if printf '%s' "$value" | grep -q '%'; then
    die "${name} cannot contain percent signs because it is written to a systemd unit: ${value}"
  fi
}

validate_config() {
  validate_no_whitespace APP_USER "$APP_USER"
  validate_no_whitespace APP_GROUP "$APP_GROUP"
  validate_no_whitespace APP_HOME "$APP_HOME"
  validate_no_whitespace DISPLAY_NUM "$DISPLAY_NUM"
  validate_no_whitespace SCREEN_GEOMETRY "$SCREEN_GEOMETRY"
  validate_no_whitespace VNC_BIND "$VNC_BIND"
  validate_no_whitespace VNC_PORT "$VNC_PORT"
  validate_no_whitespace CDP_BIND "$CDP_BIND"
  validate_no_whitespace CDP_PORT "$CDP_PORT"
  validate_no_whitespace CLOAKSERVE_HEADLESS "$CLOAKSERVE_HEADLESS"
  validate_no_whitespace CLOAKSERVE_DATA_DIR "$CLOAKSERVE_DATA_DIR"
  validate_no_whitespace CLOAKSERVE_IDLE_TIMEOUT "$CLOAKSERVE_IDLE_TIMEOUT"
  validate_no_whitespace CLOAKSERVE_FINGERPRINT "$CLOAKSERVE_FINGERPRINT"
  validate_no_whitespace CLOAKSERVE_LOCALE "$CLOAKSERVE_LOCALE"
  validate_no_whitespace CLOAKSERVE_TIMEZONE "$CLOAKSERVE_TIMEZONE"
  validate_no_whitespace CLOAKSERVE_PROXY_SERVER "$CLOAKSERVE_PROXY_SERVER"
  case "$CLOAKSERVE_HEADLESS" in
    true|false) ;;
    *) die "CLOAKSERVE_HEADLESS must be true or false; got ${CLOAKSERVE_HEADLESS}" ;;
  esac
  case "$CDP_BIND" in
    127.0.0.1|localhost|0.0.0.0) ;;
    *) die "CDP_BIND must be 127.0.0.1, localhost, or 0.0.0.0; got ${CDP_BIND}" ;;
  esac
  case "$APP_HOME" in
    /*) ;;
    *) die "APP_HOME must be an absolute path; got ${APP_HOME}" ;;
  esac
  APP_HOME="$(readlink -m -- "$APP_HOME")"
  case "$APP_HOME" in
    /|/bin|/boot|/dev|/etc|/home|/lib|/lib32|/lib64|/media|/mnt|/opt|/proc|/root|/run|/sbin|/srv|/sys|/tmp|/usr|/var)
      die "APP_HOME must be a dedicated application directory, not ${APP_HOME}"
      ;;
  esac
  validate_no_percent APP_USER "$APP_USER"
  validate_no_percent APP_GROUP "$APP_GROUP"
  validate_no_percent APP_HOME "$APP_HOME"
  validate_no_percent DISPLAY_NUM "$DISPLAY_NUM"
  validate_no_percent SCREEN_GEOMETRY "$SCREEN_GEOMETRY"
  validate_no_percent VNC_BIND "$VNC_BIND"
  validate_no_percent VNC_PORT "$VNC_PORT"
}

apt_install() {
  export DEBIAN_FRONTEND=noninteractive
  local libasound_pkg="libasound2"

  apt-get update
  if ! apt-cache show libasound2 >/dev/null 2>&1 && apt-cache show libasound2t64 >/dev/null 2>&1; then
    libasound_pkg="libasound2t64"
  fi

  apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg git procps tar \
    python3 python3-venv python3-pip \
    build-essential pkg-config \
    libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 libcups2 \
    libdbus-1-3 libdrm2 libxkbcommon0 libatspi2.0-0 libxcomposite1 \
    libxdamage1 libxfixes3 libxrandr2 libgbm1 libpango-1.0-0 \
    libcairo2 "$libasound_pkg" libx11-xcb1 libfontconfig1 libx11-6 \
    libxcb1 libxext6 libxshmfence1 \
    libglib2.0-0 libgtk-3-0 libpangocairo-1.0-0 libcairo-gobject2 \
    libgdk-pixbuf-2.0-0 libxss1 libxtst6 \
    fonts-liberation fonts-noto-color-emoji fonts-unifont fonts-freefont-ttf \
    fonts-ipafont-gothic fonts-wqy-zenhei fonts-tlwg-loma-otf \
    xvfb x11vnc xauth xdotool openbox dbus-x11
}

install_node_20() {
  if command -v node >/dev/null 2>&1 && node -v | grep -Eq '^v20\.'; then
    log "Node.js 20 already installed"
    return
  fi

  log "Installing Node.js 20 from NodeSource"
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y --no-install-recommends nodejs
}

create_app_user() {
  if ! getent group "$APP_GROUP" >/dev/null; then
    groupadd --system "$APP_GROUP"
  fi

  if ! id "$APP_USER" >/dev/null 2>&1; then
    useradd --system --gid "$APP_GROUP" --home-dir "$APP_HOME" --shell /usr/sbin/nologin "$APP_USER"
  fi
}

prepare_app_dirs() {
  log "Preparing application directories"
  install -d -m 0755 -o "$APP_USER" -g "$APP_GROUP" "$APP_HOME"
  install -d -m 0750 -o "$APP_USER" -g "$APP_GROUP" /var/lib/cloakbrowser
}

run_as_app_user() {
  runuser -u "$APP_USER" -- "$@"
}

install_python_package() {
  log "Installing latest Python wrapper into ${APP_HOME}/.venv"
  run_as_app_user python3 -m venv "$APP_HOME/.venv"
  run_as_app_user "$APP_HOME/.venv/bin/python" -m pip install --upgrade pip setuptools wheel
  run_as_app_user "$APP_HOME/.venv/bin/python" -m pip install --upgrade "cloakbrowser[serve,geoip]"

  log "Pre-downloading CloakBrowser binary"
  run_as_app_user env DISPLAY="$DISPLAY_VALUE" "$APP_HOME/.venv/bin/python" -m cloakbrowser install
}

install_js_package() {
  if [ "$INSTALL_JS" != "1" ]; then
    log "Skipping JS wrapper install because INSTALL_JS=${INSTALL_JS}"
    return
  fi

  log "Installing latest JS wrapper globally"
  npm install -g cloakbrowser@latest playwright-core puppeteer-core
}

install_sdist_tools() {
  log "Installing auxiliary tools from the latest PyPI sdist"
  local tmp_dir sdist_file source_root script_dir local_cloakserve

  tmp_dir="$(mktemp -d)"
  "$APP_HOME/.venv/bin/python" -m pip download --no-binary cloakbrowser --no-deps -d "$tmp_dir" cloakbrowser
  sdist_file="$(find "$tmp_dir" -maxdepth 1 -type f -name 'cloakbrowser-*.tar.gz' | sort | tail -n 1)"
  [ -n "$sdist_file" ] || die "failed to download CloakBrowser sdist from PyPI"

  source_root="$(tar -tzf "$sdist_file" | sed -n '1s#/.*##p')"
  [ -n "$source_root" ] || die "failed to inspect CloakBrowser sdist"

  install -d -m 0755 -o "$APP_USER" -g "$APP_GROUP" "$APP_HOME/tools/bin"
  tar -xzf "$sdist_file" -C "$tmp_dir" "${source_root}/bin/fetch-widevine.py"
  install -m 0755 -o "$APP_USER" -g "$APP_GROUP" "$tmp_dir/${source_root}/bin/fetch-widevine.py" "$APP_HOME/tools/bin/fetch-widevine.py"

  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P || true)"
  local_cloakserve="${script_dir}/cloakserve"
  if [ -f "$local_cloakserve" ]; then
    install -m 0755 -o "$APP_USER" -g "$APP_GROUP" "$local_cloakserve" "$APP_HOME/tools/bin/cloakserve"
  else
    curl -fsSL "$CLOAKSERVE_SCRIPT_URL" -o "$tmp_dir/cloakserve"
    install -m 0755 -o "$APP_USER" -g "$APP_GROUP" "$tmp_dir/cloakserve" "$APP_HOME/tools/bin/cloakserve"
  fi

  rm -rf "$tmp_dir"
}

install_cli_wrappers() {
  log "Installing CLI wrappers"
  install -m 0755 /dev/stdin /usr/local/bin/cloakserve <<EOF
#!/usr/bin/env bash
set -euo pipefail
export DISPLAY="\${DISPLAY:-${DISPLAY_VALUE}}"
exec "${APP_HOME}/.venv/bin/python" "${APP_HOME}/tools/bin/cloakserve" "\$@"
EOF

  install -m 0755 /dev/stdin /usr/local/bin/cloakserve-systemd <<EOF
#!/usr/bin/env bash
set -euo pipefail
source /etc/cloakbrowser/cloakserve.conf
export DISPLAY="\${DISPLAY:-${DISPLAY_VALUE}}"
args=(--headless="\${CLOAKSERVE_HEADLESS}" --host="\${CDP_BIND}" --port="\${CDP_PORT}")
[ -n "\${CLOAKSERVE_DATA_DIR}" ] && args+=(--data-dir="\${CLOAKSERVE_DATA_DIR}")
[ -n "\${CLOAKSERVE_IDLE_TIMEOUT}" ] && args+=(--idle-timeout="\${CLOAKSERVE_IDLE_TIMEOUT}")
[ -n "\${CLOAKSERVE_FINGERPRINT}" ] && args+=(--fingerprint="\${CLOAKSERVE_FINGERPRINT}")
[ -n "\${CLOAKSERVE_LOCALE}" ] && args+=(--fingerprint-locale="\${CLOAKSERVE_LOCALE}")
[ -n "\${CLOAKSERVE_TIMEZONE}" ] && args+=(--fingerprint-timezone="\${CLOAKSERVE_TIMEZONE}")
[ -n "\${CLOAKSERVE_PROXY_SERVER}" ] && args+=(--default-proxy="\${CLOAKSERVE_PROXY_SERVER}")
if [ -n "\${CLOAKSERVE_EXTRA_ARGS}" ]; then
  # Intentional shell splitting for advanced Chromium flags supplied by the admin.
  # shellcheck disable=SC2206
  extra_args=(\${CLOAKSERVE_EXTRA_ARGS})
  args+=("\${extra_args[@]}")
fi
exec /usr/local/bin/cloakserve "\${args[@]}"
EOF

  install -m 0755 /dev/stdin /usr/local/bin/cloaktest <<EOF
#!/usr/bin/env bash
set -euo pipefail
export DISPLAY="\${DISPLAY:-${DISPLAY_VALUE}}"
"${APP_HOME}/.venv/bin/python" -m cloakbrowser info --quick
exec "${APP_HOME}/.venv/bin/python" - <<'PY'
from cloakbrowser import launch

browser = launch(headless=False)
page = browser.new_page()
page.goto("about:blank")
browser.close()
print("cloaktest: ok")
PY
EOF

  install -m 0755 /dev/stdin /usr/local/bin/fetch-widevine.py <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec "${APP_HOME}/.venv/bin/python" "${APP_HOME}/tools/bin/fetch-widevine.py" "\$@"
EOF
}

configure_vnc_password() {
  log "Configuring VNC password"
  install -d -m 0750 -o root -g "$APP_GROUP" /etc/cloakbrowser

  if [ "${VNC_AUTH_MODE:-}" = "none" ]; then
    rm -f /etc/cloakbrowser/vnc.pass /etc/cloakbrowser/vnc-password.txt
    return
  fi

  if [ "${VNC_AUTH_MODE:-}" != "random" ] && [ -z "${VNC_PASSWORD:-}" ] && [ -f /etc/cloakbrowser/vnc-password.txt ]; then
    VNC_PASSWORD="$(cat /etc/cloakbrowser/vnc-password.txt)"
  fi

  if [ -z "${VNC_PASSWORD:-}" ]; then
    # VNC authentication only uses the first 8 bytes of the password.
    VNC_PASSWORD="$(python3 -c 'import secrets, string; print("".join(secrets.choice(string.ascii_letters + string.digits) for _ in range(8)))')"
    printf '%s\n' "$VNC_PASSWORD" > /etc/cloakbrowser/vnc-password.txt
    chmod 0640 /etc/cloakbrowser/vnc-password.txt
    chown root:"$APP_GROUP" /etc/cloakbrowser/vnc-password.txt
  fi

  x11vnc -storepasswd "$VNC_PASSWORD" /etc/cloakbrowser/vnc.pass >/dev/null
  chmod 0640 /etc/cloakbrowser/vnc.pass
  chown root:"$APP_GROUP" /etc/cloakbrowser/vnc.pass
}

cleanup_legacy_dockerenv_marker() {
  install -d -m 0750 -o root -g "$APP_GROUP" /etc/cloakbrowser

  if [ -f /etc/cloakbrowser/created-dockerenv ]; then
    log "Removing /.dockerenv created by an older installer; cloakserve now supports --host directly."
    rm -f /.dockerenv /etc/cloakbrowser/created-dockerenv
  fi
}

configure_cloakserve_data_dir() {
  if [ "$ENABLE_CLOAKSERVE" != "1" ] || [ -z "$CLOAKSERVE_DATA_DIR" ]; then
    return
  fi

  log "Preparing cloakserve data dir ${CLOAKSERVE_DATA_DIR}"
  install -d -m 0750 -o "$APP_USER" -g "$APP_GROUP" "$CLOAKSERVE_DATA_DIR"
}

write_bash_var() {
  local name="$1"
  local value="$2"
  local escaped
  printf -v escaped '%q' "$value"
  printf '%s=%s\n' "$name" "$escaped"
}

write_environment() {
  cat >/etc/cloakbrowser/env <<EOF
DISPLAY=${DISPLAY_VALUE}
CLOAKBROWSER_FETCH_WIDEVINE=${CLOAKBROWSER_FETCH_WIDEVINE}
EOF
  chmod 0640 /etc/cloakbrowser/env
  chown root:"$APP_GROUP" /etc/cloakbrowser/env

  {
    write_bash_var CDP_BIND "$CDP_BIND"
    write_bash_var CDP_PORT "$CDP_PORT"
    write_bash_var CLOAKSERVE_HEADLESS "$CLOAKSERVE_HEADLESS"
    write_bash_var CLOAKSERVE_DATA_DIR "$CLOAKSERVE_DATA_DIR"
    write_bash_var CLOAKSERVE_IDLE_TIMEOUT "$CLOAKSERVE_IDLE_TIMEOUT"
    write_bash_var CLOAKSERVE_FINGERPRINT "$CLOAKSERVE_FINGERPRINT"
    write_bash_var CLOAKSERVE_LOCALE "$CLOAKSERVE_LOCALE"
    write_bash_var CLOAKSERVE_TIMEZONE "$CLOAKSERVE_TIMEZONE"
    write_bash_var CLOAKSERVE_PROXY_SERVER "$CLOAKSERVE_PROXY_SERVER"
    write_bash_var CLOAKSERVE_EXTRA_ARGS "$CLOAKSERVE_EXTRA_ARGS"
  } >/etc/cloakbrowser/cloakserve.conf
  chmod 0640 /etc/cloakbrowser/cloakserve.conf
  chown root:"$APP_GROUP" /etc/cloakbrowser/cloakserve.conf
}

write_systemd_units() {
  log "Writing systemd units"
  local vnc_auth_args="-rfbauth /etc/cloakbrowser/vnc.pass"

  if [ "${VNC_AUTH_MODE:-}" = "none" ]; then
    vnc_auth_args="-nopw"
  fi

  cat >/etc/systemd/system/cloakbrowser-xvfb.service <<EOF
[Unit]
Description=CloakBrowser virtual X display
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${APP_USER}
Group=${APP_GROUP}
EnvironmentFile=-/etc/cloakbrowser/env
ExecStartPre=/usr/bin/rm -f /tmp/.X${DISPLAY_NUM}-lock /tmp/.X11-unix/X${DISPLAY_NUM}
ExecStart=/usr/bin/Xvfb ${DISPLAY_VALUE} -screen 0 ${SCREEN_GEOMETRY}x24 -nolisten tcp
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

  cat >/etc/systemd/system/cloakbrowser-openbox.service <<EOF
[Unit]
Description=CloakBrowser lightweight window manager
Requires=cloakbrowser-xvfb.service
After=cloakbrowser-xvfb.service

[Service]
Type=simple
User=${APP_USER}
Group=${APP_GROUP}
EnvironmentFile=-/etc/cloakbrowser/env
ExecStart=/usr/bin/openbox
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

  cat >/etc/systemd/system/cloakbrowser-vnc.service <<EOF
[Unit]
Description=CloakBrowser VNC server
Requires=cloakbrowser-xvfb.service
After=cloakbrowser-xvfb.service

[Service]
Type=simple
User=${APP_USER}
Group=${APP_GROUP}
EnvironmentFile=-/etc/cloakbrowser/env
ExecStart=/usr/bin/x11vnc -display ${DISPLAY_VALUE} ${vnc_auth_args} -rfbport ${VNC_PORT} -listen ${VNC_BIND} -forever -shared -noxdamage -repeat -xkb
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

  cat >/etc/systemd/system/cloakserve.service <<EOF
[Unit]
Description=CloakBrowser CDP server
Requires=cloakbrowser-xvfb.service
After=cloakbrowser-xvfb.service network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${APP_USER}
Group=${APP_GROUP}
WorkingDirectory=${APP_HOME}
EnvironmentFile=-/etc/cloakbrowser/env
ExecStart=/usr/local/bin/cloakserve-systemd
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

}

enable_services() {
  systemctl daemon-reload
  systemctl enable --now cloakbrowser-xvfb.service cloakbrowser-openbox.service cloakbrowser-vnc.service

  if [ "$ENABLE_CLOAKSERVE" = "1" ]; then
    systemctl enable --now cloakserve.service
  else
    systemctl disable --now cloakserve.service >/dev/null 2>&1 || true
  fi
}

verify_install() {
  log "Verifying install"
  run_as_app_user env DISPLAY="$DISPLAY_VALUE" "$APP_HOME/.venv/bin/python" -m cloakbrowser info --quick
  systemctl is-active --quiet cloakbrowser-xvfb.service
  systemctl is-active --quiet cloakbrowser-openbox.service
  systemctl is-active --quiet cloakbrowser-vnc.service
  if [ "$ENABLE_CLOAKSERVE" = "1" ]; then
    systemctl is-active --quiet cloakserve.service
    curl -fsS "http://127.0.0.1:${CDP_PORT}/" >/dev/null
  fi
}

print_result() {
  local ip
  ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  [ -n "$ip" ] || ip="<lxc-ip>"

  cat <<EOF

CloakBrowser installed.

VNC:
  host: ${ip}
  bind: ${VNC_BIND}
  port: ${VNC_PORT}
  password: ${VNC_PASSWORD:-<none>}

CDP:
  service: cloakserve.service
EOF

  if [ "$ENABLE_CLOAKSERVE" = "1" ]; then
    cat <<EOF
  bind: ${CDP_BIND}
  URL: http://${CDP_BIND}:${CDP_PORT}
  default proxy: ${CLOAKSERVE_PROXY_SERVER:-<none>}
  note: CDP gives full browser control. Expose it only on trusted networks or behind SSH/reverse-proxy auth.
EOF
  else
    cat <<EOF
  status: disabled
  enable: systemctl enable --now cloakserve
EOF
  fi

  cat <<EOF
Useful commands:
  systemctl status cloakbrowser-xvfb cloakbrowser-vnc cloakserve
  journalctl -u cloakserve -f
  cloaktest
  cloakserve --headless=false --port=${CDP_PORT}

EOF
}

main() {
  require_root

  command -v apt-get >/dev/null 2>&1 || die "this installer supports Ubuntu/Debian systems with apt-get"
  command -v systemctl >/dev/null 2>&1 || die "systemd is required for this installer"

  prompt_config
  validate_config
  apt_install
  install_node_20
  create_app_user
  prepare_app_dirs
  install_python_package
  install_js_package
  install_sdist_tools
  install_cli_wrappers
  configure_vnc_password
  cleanup_legacy_dockerenv_marker
  configure_cloakserve_data_dir
  write_environment
  write_systemd_units
  enable_services
  verify_install
  print_result
}

main "$@"
