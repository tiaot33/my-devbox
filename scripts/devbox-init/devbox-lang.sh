#!/usr/bin/env bash
# =============================================================================
# devbox-lang — Debian/Ubuntu 多语言开发工具链一键安装脚本
#
#   支持: Node.js (fnm) / Python (uv) / Go (mise) / Bun / Deno
#
#   运行:   bash devbox-lang.sh
#           sudo bash devbox-lang.sh
#           bash devbox-lang.sh --all
#
#   环境变量 (设为 0 跳过对应组件):
#     INSTALL_NODE  / INSTALL_NODE_TOOLS
#     INSTALL_PYTHON
#     INSTALL_GO    / INSTALL_GO_TOOLS
#     INSTALL_BUN   / INSTALL_DENO
#
#   示例 — 只装 Go:
#     INSTALL_NODE=0 INSTALL_PYTHON=0 INSTALL_BUN=0 INSTALL_DENO=0 bash devbox-lang.sh
# =============================================================================

set -uo pipefail

# ── 输出辅助函数 ────────────────────────────────────────────────────────────

log()   { printf '\n\033[1;34m▶ %s\033[0m\n'  "$*"; }       # 蓝色节标题
warn()  { printf '  \033[1;33m⚠  %s\033[0m\n' "$*" >&2; }   # 黄色警告
step()  { printf '  \033[36m▸ %s\033[0m\n'  "$*"; }          # 青色子步骤
ok()    { printf '  \033[32m✔ %s\033[0m\n'  "$*"; }          # 绿色成功
skip()  { printf '  \033[90m— %s (跳过)\033[0m\n' "$*"; }     # 灰色跳过

usage() {
  cat <<'EOF'
用法:
  bash devbox-lang.sh           交互选择要安装的语言环境
  bash devbox-lang.sh --all     非交互安装全部语言环境

仍可使用 INSTALL_* 环境变量跳过组件，例如:
  INSTALL_NODE=0 INSTALL_PYTHON=0 INSTALL_BUN=0 INSTALL_DENO=0 bash devbox-lang.sh
EOF
}

INSTALL_ALL_NONINTERACTIVE=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --all)
      INSTALL_ALL_NONINTERACTIVE=1
      ;;
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
  shift
done

set_all_languages() {
  INSTALL_NODE=1
  INSTALL_PYTHON=1
  INSTALL_GO=1
  INSTALL_BUN=1
  INSTALL_DENO=1
  : "${INSTALL_NODE_TOOLS:=1}"
  : "${INSTALL_GO_TOOLS:=1}"
}

language_env_overrides_present() {
  [ "${INSTALL_NODE+x}" ] || [ "${INSTALL_PYTHON+x}" ] || [ "${INSTALL_GO+x}" ] || \
    [ "${INSTALL_BUN+x}" ] || [ "${INSTALL_DENO+x}" ]
}

apply_language_selection() {
  local selection="$1" item selected=0

  case "$selection" in
    ""|a|A|all|ALL|全部)
      set_all_languages
      return 0
      ;;
    q|Q|quit|QUIT|退出)
      printf '已取消安装。\n'
      exit 0
      ;;
  esac

  INSTALL_NODE=0
  INSTALL_PYTHON=0
  INSTALL_GO=0
  INSTALL_BUN=0
  INSTALL_DENO=0

  for item in $selection; do
    case "$item" in
      1|node|Node|NODE)
        INSTALL_NODE=1
        selected=1
        ;;
      2|python|Python|PYTHON|py|PY)
        INSTALL_PYTHON=1
        selected=1
        ;;
      3|go|Go|GO)
        INSTALL_GO=1
        selected=1
        ;;
      4|bun|Bun|BUN)
        INSTALL_BUN=1
        selected=1
        ;;
      5|deno|Deno|DENO)
        INSTALL_DENO=1
        selected=1
        ;;
      *)
        warn "无法识别选项: $item"
        return 1
        ;;
    esac
  done

  [ "$selected" = "1" ]
}

prompt_language_selection() {
  local selection

  if [ ! -t 0 ]; then
    warn "当前不是交互式终端；请使用 --all，或用 INSTALL_* 环境变量指定要安装的组件"
    exit 2
  fi

  printf '\n\033[1;37m请选择要安装的语言环境:\033[0m\n'
  printf '  1) Node.js (fnm + LTS + Node 工具链)\n'
  printf '  2) Python  (uv + Python + ruff)\n'
  printf '  3) Go      (mise + Go + Go 工具链)\n'
  printf '  4) Bun\n'
  printf '  5) Deno\n'
  printf '  a) 全部\n'
  printf '  q) 退出\n'
  printf '\n可输入多个编号，用空格分隔；直接回车默认安装全部。\n'

  while true; do
    printf '选择: '
    if ! IFS= read -r selection; then
      printf '\n已取消安装。\n'
      exit 1
    fi
    if apply_language_selection "$selection"; then
      break
    fi
  done
}

print_selected_languages() {
  local selected=""
  [ "${INSTALL_NODE:-1}" = "1" ] && selected="${selected} Node.js"
  [ "${INSTALL_PYTHON:-1}" = "1" ] && selected="${selected} Python"
  [ "${INSTALL_GO:-1}" = "1" ] && selected="${selected} Go"
  [ "${INSTALL_BUN:-1}" = "1" ] && selected="${selected} Bun"
  [ "${INSTALL_DENO:-1}" = "1" ] && selected="${selected} Deno"

  if [ -n "$selected" ]; then
    log "🧭 将安装:${selected}"
  else
    log "🧭 未选择任何语言环境"
  fi
}

# ── 环境检测 ────────────────────────────────────────────────────────────────

# 确认是 Debian/Ubuntu 系列，其他发行版仅告警不中断
[ -r /etc/os-release ] && . /etc/os-release
case "${ID:-}" in
  ubuntu|debian) ;;
  *) warn "当前系统: ${PRETTY_NAME:-unknown OS}；脚本预期 Debian/Ubuntu，结果可能不完整" ;;
esac

# curl 是下载安装脚本的必需工具
if ! command -v curl >/dev/null 2>&1; then
  printf '\033[1;31m✘ curl 未安装，请先执行: apt-get install -y curl\033[0m\n' >&2
  exit 1
fi

# ── 确定目标用户 ────────────────────────────────────────────────────────────
#
# 优先使用 SUDO_USER（sudo 场景下装到原始用户目录），
# 否则取当前用户。最终计算 AS_USER 变量：同用户直接跑，跨用户用 sudo 切换。

DISPATCHER="${SUDO_USER:-${USER:-$(id -un)}}"
id "$DISPATCHER" >/dev/null 2>&1 || DISPATCHER="$(id -un)"
DISPATCHER_HOME="$(getent passwd "$DISPATCHER" | cut -d: -f6)"
[ -n "$DISPATCHER_HOME" ] || DISPATCHER_HOME="$HOME"

if [ "$DISPATCHER" = "$(id -un)" ]; then
  AS_USER="bash -lc"                          # 当前用户直接以 login shell 执行
else
  AS_USER="sudo -H -u $DISPATCHER bash -lc"    # sudo 切换到目标用户执行
fi

# ── 远程安装脚本下载 & 执行 ─────────────────────────────────────────────────
#
# 参数: 名称 下载地址 解释器 [额外参数...]
# 每次调用用独立临时文件，执行结束后显式清理

download_and_run() {
  local name="$1" url="$2" interp="$3"; shift 3
  local tmp
  tmp=$(mktemp /tmp/devbox-lang.XXXXXX)
  if curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --retry-connrefused "$url" -o "$tmp" && [ -s "$tmp" ]; then
    $AS_USER "$interp \"$tmp\" $*" || warn "$name: 安装脚本返回非零退出码"
  else
    warn "$name: 下载失败，跳过安装"
  fi
  rm -f "$tmp"
}

remove_legacy_bashrc_blocks() {
  cat <<'SCRIPT_EOF' | $AS_USER 'bash -s'
set -u
bashrc="$HOME/.bashrc"
[ -f "$bashrc" ] || exit 0

remove_block() {
  local marker="$1" endmarker="$2" tmp
  grep -qF "$marker" "$bashrc" 2>/dev/null || return 0
  tmp=$(mktemp) || exit 0
  sed "\|$marker|,\|$endmarker|d" "$bashrc" > "$tmp" && cat "$tmp" > "$bashrc"
  rm -f "$tmp"
}

remove_block "# >>> devbox-lang: language environment >>>" "# <<< devbox-lang: language environment <<<"
remove_block "# >>> devbox-lang: shell completions >>>" "# <<< devbox-lang: shell completions <<<"
SCRIPT_EOF
}

write_bashrc_block() {
  local name="$1" block_file
  block_file=$(mktemp /tmp/devbox-lang-bashrc.XXXXXX) || { warn "$name: mktemp 失败"; return 1; }
  cat > "$block_file"
  chmod 0644 "$block_file"

  $AS_USER "DEVBOX_LANG_BLOCK='$name' DEVBOX_LANG_BLOCK_FILE='$block_file' bash -s" <<'SCRIPT_EOF'
set -u
bashrc="$HOME/.bashrc"
marker="# >>> devbox-lang: ${DEVBOX_LANG_BLOCK} >>>"
endmarker="# <<< devbox-lang: ${DEVBOX_LANG_BLOCK} <<<"

touch "$bashrc" 2>/dev/null || exit 0
if grep -qF "$marker" "$bashrc" 2>/dev/null; then
  tmp=$(mktemp) || exit 0
  sed "\|$marker|,\|$endmarker|d" "$bashrc" > "$tmp" && cat "$tmp" > "$bashrc"
  rm -f "$tmp"
fi

{
  printf '\n%s\n' "$marker"
  cat "$DEVBOX_LANG_BLOCK_FILE"
  printf '%s\n' "$endmarker"
} >> "$bashrc"
SCRIPT_EOF

  rm -f "$block_file"
}

# ═══════════════════════════════════════════════════════════════════════════
# 开始安装
# ═══════════════════════════════════════════════════════════════════════════

printf '\033[1;37m\n'
printf '  ╔════════════════════════════════════════════════════╗\n'
printf '  ║  %-50s  ║\n' "🧰 devbox-lang 语言工具链安装"
printf '  ║  %-50s  ║\n' "   Node.js · Python · Go · Bun · Deno"
printf '  ╚════════════════════════════════════════════════════╝\n'
printf '\033[0m'

log "📋 目标用户: \033[1m$DISPATCHER\033[0m (主目录: $DISPATCHER_HOME)"

if [ "$INSTALL_ALL_NONINTERACTIVE" = "1" ]; then
  set_all_languages
elif ! language_env_overrides_present; then
  prompt_language_selection
fi
print_selected_languages

# ── 准备工作：创建通用目录，清理旧版全局 shell 配置 ──────────────────────────
$AS_USER 'mkdir -p "$HOME/.local/bin" "$HOME/.local/share"'
remove_legacy_bashrc_blocks

# ═══════════════════════════════════════════════════════════════════════════
# 📦 Node.js — 通过 fnm 管理版本
# ═══════════════════════════════════════════════════════════════════════════
if [ "${INSTALL_NODE:-1}" = "1" ]; then
  log "📦 Node.js — fnm 版本管理器"
  step "安装 fnm ..."
  download_and_run "fnm" "https://fnm.vercel.app/install" bash --skip-shell

  step "安装 Node.js LTS ..."
  $AS_USER '
    export PATH="$HOME/.local/share/fnm:$PATH"
    if command -v fnm >/dev/null 2>&1; then
      eval "$(fnm env --use-on-cd --shell bash)"
      fnm install --lts || true
      fnm use --lts || true
      fnm default lts-latest || true
      node --version || true
      npm --version || true
    fi
  '

  if [ "${INSTALL_NODE_TOOLS:-1}" = "1" ]; then
    step "安装 Node 工具链 (pnpm, yarn, tsc, tsx, eslint, prettier) ..."
    $AS_USER '
      export PATH="$HOME/.local/share/fnm:$PATH"
      if command -v fnm >/dev/null 2>&1; then
        eval "$(fnm env --use-on-cd --shell bash)"
        if command -v corepack >/dev/null 2>&1; then
          corepack enable || true
          corepack prepare pnpm@latest --activate || true
          corepack prepare yarn@stable --activate || true
        fi
        command -v npm >/dev/null 2>&1 && npm install -g typescript tsx eslint prettier || true
      fi
    '
    ok "Node 工具链安装完成"
  fi

  step "写入 Node.js shell 环境 ..."
  write_bashrc_block "node" <<'EOF_NODE_BASHRC'
export PNPM_HOME=${PNPM_HOME:-$HOME/.local/share/pnpm}

for __d in "$HOME/.local/share/fnm" "$PNPM_HOME"; do
  case ":$PATH:" in *":$__d:"*) ;; *) PATH="$__d:$PATH";; esac
done
unset __d

command -v fnm >/dev/null 2>&1 && eval "$(fnm env --use-on-cd --shell bash 2>/dev/null)"
command -v fnm >/dev/null 2>&1 && eval "$(fnm completions --shell bash 2>/dev/null)"
command -v npm >/dev/null 2>&1 && eval "$(npm completion 2>/dev/null)"
EOF_NODE_BASHRC
  ok "Node.js shell 环境已写入 ~/.bashrc"
else
  skip "Node.js"
fi

# ═══════════════════════════════════════════════════════════════════════════
# 🐍 Python — 通过 uv 管理版本和工具
# ═══════════════════════════════════════════════════════════════════════════
if [ "${INSTALL_PYTHON:-1}" = "1" ]; then
  log "🐍 Python — uv 版本 & 工具管理"
  step "安装 uv ..."
  download_and_run "uv" "https://astral.sh/uv/install.sh" sh

  step "安装 Python 运行时 ..."
  $AS_USER '
    export PATH="$HOME/.local/bin:$PATH"
    if command -v uv >/dev/null 2>&1; then
      uv python install 3.14 || uv python install 3.13 || uv python install || true
    fi
  '

  step "安装 Python 工具链 (ruff — lint & format) ..."
  $AS_USER '
    export PATH="$HOME/.local/bin:$PATH"
    if command -v uv >/dev/null 2>&1; then
      uv tool install ruff || true
    fi
  '
  ok "Python 工具链安装完成"

  step "写入 Python shell 环境 ..."
  write_bashrc_block "python" <<'EOF_PYTHON_BASHRC'
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH";; esac

command -v uv >/dev/null 2>&1 && eval "$(uv generate-shell-completion bash 2>/dev/null)"
command -v uvx >/dev/null 2>&1 && eval "$(uvx --generate-shell-completion bash 2>/dev/null)"
EOF_PYTHON_BASHRC
  ok "Python shell 环境已写入 ~/.bashrc"
else
  skip "Python"
fi

# ═══════════════════════════════════════════════════════════════════════════
# ⚙️  Go — 通过 mise 管理版本
# ═══════════════════════════════════════════════════════════════════════════
if [ "${INSTALL_GO:-1}" = "1" ]; then
  log "⚙️  Go — mise 版本管理器"
  step "创建 Go 工具目录 ..."
  $AS_USER 'mkdir -p "$HOME/go/bin"'

  step "安装 mise ..."
  download_and_run "mise" "https://mise.run" sh

  step "安装 Go 最新版 ..."
  $AS_USER '
    export PATH="$HOME/.local/bin:$PATH"
    if command -v mise >/dev/null 2>&1; then
      mise use -g go@latest || true
      mise use -g usage || true
      eval "$(mise activate bash)"
      go version || true
    fi
  '

  if [ "${INSTALL_GO_TOOLS:-1}" = "1" ]; then
    step "安装 Go 工具链 (gopls, goimports, dlv, staticcheck) ..."
    $AS_USER '
      export PATH="$HOME/.local/bin:$HOME/go/bin:$PATH"
      if command -v mise >/dev/null 2>&1; then eval "$(mise activate bash)"; fi
      if command -v go >/dev/null 2>&1; then
        go install golang.org/x/tools/gopls@latest || true
        go install golang.org/x/tools/cmd/goimports@latest || true
        go install github.com/go-delve/delve/cmd/dlv@latest || true
        go install honnef.co/go/tools/cmd/staticcheck@latest || true
      fi
    '
    ok "Go 工具链安装完成"
  fi

  step "写入 Go shell 环境 ..."
  write_bashrc_block "go" <<'EOF_GO_BASHRC'
export GOPATH=${GOPATH:-$HOME/go}

for __d in "$HOME/.local/bin" "$HOME/go/bin"; do
  case ":$PATH:" in *":$__d:"*) ;; *) PATH="$__d:$PATH";; esac
done
unset __d

command -v mise >/dev/null 2>&1 && eval "$(mise activate bash 2>/dev/null)"
command -v mise >/dev/null 2>&1 && eval "$(mise completion bash 2>/dev/null)"
EOF_GO_BASHRC
  ok "Go shell 环境已写入 ~/.bashrc"
else
  skip "Go"
fi

# ═══════════════════════════════════════════════════════════════════════════
# 🍞 Bun
# ═══════════════════════════════════════════════════════════════════════════
if [ "${INSTALL_BUN:-1}" = "1" ]; then
  log "🍞 Bun — 快速 JS 运行时"
  step "安装 Bun ..."
  download_and_run "Bun" "https://bun.com/install" bash

  step "下载 bash 补全 ..."
  $AS_USER 'mkdir -p "$HOME/.bun"
    if curl --proto "=https" --tlsv1.2 -fsSL --retry 3 --retry-connrefused \
      "https://raw.githubusercontent.com/oven-sh/bun/main/completions/bun.bash" \
      -o "$HOME/.bun/_bun.bash" 2>/dev/null; then
      [ -s "$HOME/.bun/_bun.bash" ]
    else
      false
    fi
  ' || warn "Bun: bash 补全下载失败"

  step "写入 Bun shell 环境 ..."
  write_bashrc_block "bun" <<'EOF_BUN_BASHRC'
case ":$PATH:" in *":$HOME/.bun/bin:"*) ;; *) PATH="$HOME/.bun/bin:$PATH";; esac

[ -s "$HOME/.bun/_bun.bash" ] && source "$HOME/.bun/_bun.bash"
EOF_BUN_BASHRC
  ok "Bun shell 环境已写入 ~/.bashrc"
else
  skip "Bun"
fi

# ═══════════════════════════════════════════════════════════════════════════
# 🦕 Deno
# ═══════════════════════════════════════════════════════════════════════════
if [ "${INSTALL_DENO:-1}" = "1" ]; then
  log "🦕 Deno — 安全 JS/TS 运行时"
  command -v unzip >/dev/null 2>&1 || warn "unzip 未安装，Deno 安装可能失败"

  step "安装 Deno ..."
  download_and_run "Deno" "https://deno.land/install.sh" sh

  step "写入 Deno shell 环境 ..."
  write_bashrc_block "deno" <<'EOF_DENO_BASHRC'
case ":$PATH:" in *":$HOME/.deno/bin:"*) ;; *) PATH="$HOME/.deno/bin:$PATH";; esac

command -v deno >/dev/null 2>&1 && eval "$(deno completions bash 2>/dev/null)"
EOF_DENO_BASHRC
  ok "Deno shell 环境已写入 ~/.bashrc"
else
  skip "Deno"
fi

# ═══════════════════════════════════════════════════════════════════════════
# 安装完成
# ═══════════════════════════════════════════════════════════════════════════

printf '\n\033[1;32m'
printf '  ╔════════════════════════════════════════════════════╗\n'
printf '  ║  %-50s ║\n' "✨ 安装完成！"
printf '  ╚════════════════════════════════════════════════════╝\n'
printf '\033[0m\n'

cat <<EOF_SUMMARY
  🔧 已安装语言的环境变量和 bash 补全已写入 ~/.bashrc
     标记块按语言拆分，例如 "devbox-lang: node"、"devbox-lang: go"

  🚀 执行 \033[1msource ~/.bashrc\033[0m 或新开终端即可使用
EOF_SUMMARY
