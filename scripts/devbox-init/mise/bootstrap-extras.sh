#!/usr/bin/env bash
# Idempotent extras that mise cannot declare: ble.sh, nerd font, git defaults,
# user-owned shell stubs, herdr.
set -uo pipefail

log()  { printf '\n\033[1;34m▶ %s\033[0m\n' "$*"; }
warn() { printf '  \033[1;33m⚠  %s\033[0m\n' "$*" >&2; }
step() { printf '  \033[36m▸ %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✔ %s\033[0m\n' "$*"; }

download() {
  curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --retry-connrefused "$1" -o "$2" && [ -s "$2" ]
}

mkdir -p \
  "$HOME/.local/bin" \
  "$HOME/.local/src" \
  "$HOME/.local/share/fonts" \
  "$HOME/.config/shell" \
  "$HOME/.config/atuin" \
  "$HOME/.config/lazygit" \
  "$HOME/.config/nvim" \
  "$HOME/.cache"

# ── 用户可改的 shell 文件：只在缺失时创建 ───────────────────────────────────

if [ ! -e "$HOME/.config/shell/functions.sh" ]; then
  cat > "$HOME/.config/shell/functions.sh" <<'EOF'
# ~/.config/shell/functions.sh
# 用户自定义函数。mise bootstrap 只在文件不存在时创建，后续不会覆盖。
EOF
  ok "已创建 ~/.config/shell/functions.sh"
fi

if [ ! -e "$HOME/.config/shell/local.sh" ]; then
  cat > "$HOME/.config/shell/local.sh" <<'EOF'
# ~/.config/shell/local.sh
# 用户自定义 alias、环境变量和 shell 设置。mise bootstrap 只在文件不存在时创建，后续不会覆盖。
EOF
  ok "已创建 ~/.config/shell/local.sh"
fi

# ── ble.sh ──────────────────────────────────────────────────────────────────

log "ble.sh"
if [ -s "$HOME/.local/share/blesh/ble.sh" ]; then
  skip_ble=1
  ok "ble.sh 已安装"
else
  skip_ble=0
fi
if [ "$skip_ble" = "0" ]; then
  step "clone + make install ..."
  rm -rf "$HOME/.local/src/ble.sh"
  if git clone --recursive --depth 1 --shallow-submodules \
      https://github.com/akinomyoga/ble.sh.git "$HOME/.local/src/ble.sh" &&
     make -C "$HOME/.local/src/ble.sh" install PREFIX="$HOME/.local" &&
     [ -s "$HOME/.local/share/blesh/ble.sh" ]; then
    ok "ble.sh 已安装"
  else
    warn "ble.sh 安装失败"
  fi
fi

# ── ComicShannsMono Nerd Font ───────────────────────────────────────────────

log "ComicShannsMono Nerd Font"
font_marker="$HOME/.local/share/fonts/ComicShannsMonoNerdFont-Regular.otf"
if [ -f "$font_marker" ] || ls "$HOME/.local/share/fonts"/ComicShannsMono* >/dev/null 2>&1; then
  ok "字体已存在"
else
  font_zip=$(mktemp /tmp/ComicShannsMono.XXXXXX.zip)
  if download https://github.com/ryanoasis/nerd-fonts/releases/latest/download/ComicShannsMono.zip "$font_zip"; then
    if unzip -o "$font_zip" -d "$HOME/.local/share/fonts" >/dev/null; then
      fc-cache -fv "$HOME/.local/share/fonts" >/dev/null 2>&1 || true
      ok "字体已安装"
    else
      warn "字体解压失败"
    fi
  else
    warn "字体下载失败"
  fi
  rm -f "$font_zip"
fi

# ── herdr ───────────────────────────────────────────────────────────────────

log "herdr"
if command -v herdr >/dev/null 2>&1 || [ -x "$HOME/.local/bin/herdr" ]; then
  ok "herdr 已安装"
else
  tmp=$(mktemp /tmp/herdr-install.XXXXXX)
  if download https://herdr.dev/install.sh "$tmp"; then
    if sh "$tmp"; then
      ok "herdr 已安装"
    else
      warn "herdr 安装脚本返回非零退出码"
    fi
  else
    warn "herdr 安装脚本下载失败"
  fi
  rm -f "$tmp"
fi

# ── Git 全局默认 ────────────────────────────────────────────────────────────

log "git config --global"
git config --global init.defaultBranch main || true
git config --global color.ui auto || true
git config --global core.editor "nvim" || true
git config --global core.excludesfile "$HOME/.gitignore_global" || true
git config --global pull.rebase false || true
git config --global fetch.prune true || true
git config --global rerere.enabled true || true
git config --global diff.algorithm histogram || true
git config --global merge.conflictstyle zdiff3 || true
git config --global push.autoSetupRemote true || true
git config --global column.ui auto || true
git config --global help.autocorrect 1 || true
git config --global rebase.autosquash true || true
git config --global rebase.autostash true || true
git config --global tag.sort version:refname || true
if command -v delta >/dev/null 2>&1; then
  git config --global core.pager "delta" || true
  git config --global interactive.diffFilter "delta --color-only" || true
  git config --global delta.navigate true || true
  git config --global delta.side-by-side true || true
fi
ok "git 全局配置已写入"
