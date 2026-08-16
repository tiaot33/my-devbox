#!/usr/bin/env bash
# 入口已上移到 ../install.sh。本文件留给旧的 raw URL。
set -euo pipefail
SCRIPT_PATH="${BASH_SOURCE[0]:-}"
if [ -n "$SCRIPT_PATH" ] && [ -f "$SCRIPT_PATH" ]; then
  HERE="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
  if [ -f "$HERE/../install.sh" ]; then
    exec bash "$HERE/../install.sh" "$@"
  fi
fi
NEW_URL="${DEVBOX_INSTALL_URL:-https://raw.githubusercontent.com/tiaot33/my-devbox/main/scripts/devbox-init/install.sh}"
exec bash <(curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --retry-connrefused "$NEW_URL") "$@"
