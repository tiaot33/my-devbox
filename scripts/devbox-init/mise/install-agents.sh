#!/usr/bin/env bash
# 可选 coding agent 预设。默认不装；由 install.sh 或 `mise run agents` 按选择安装。
#
# mise 没有单独的「coding agent」功能，能进 registry 的按普通工具装到
# ~/.config/mise/conf.d/coding-agents.toml（不写仓库 mise.toml）。
# 不在 registry 的（kimi、cursor）走官方安装脚本。
#
#   bash install-agents.sh
#   bash install-agents.sh --agents claude,grok
#   bash install-agents.sh --list
#   bash install-agents.sh --prompt          # 只询问，把选中的 id 打到 stdout
set -uo pipefail

log()  { printf '\n\033[1;34m▶ %s\033[0m\n' "$*" >&2; }
warn() { printf '  \033[1;33m⚠  %s\033[0m\n' "$*" >&2; }
step() { printf '  \033[36m▸ %s\033[0m\n' "$*" >&2; }
ok()   { printf '  \033[32m✔ %s\033[0m\n' "$*" >&2; }
skip() { printf '  \033[90m— %s (跳过)\033[0m\n' "$*" >&2; }

SELECTED_FILE="${DEVBOX_AGENTS_STATE:-$HOME/.config/mise/coding-agents.selected}"
CONF_D="${DEVBOX_AGENTS_MISE_CONF:-$HOME/.config/mise/conf.d/coding-agents.toml}"

# id|显示名|厂商|主命令|安装方式|mise shorthand 或官方 URL
# 安装方式: mise = 写入 conf.d 后 mise install；curl = 官方安装脚本
# 目录只收已经在用的那些；copilot / hermes 等先不加。
AGENTS_CATALOG=(
  "pi|Pi|earendil|pi|mise|pi"
  "omp|Oh My Pi|can1357|omp|mise|oh-my-pi"
  "claude|Claude Code|Anthropic|claude|mise|claude"
  "codex|Codex CLI|OpenAI|codex|mise|codex"
  "kimi|Kimi Code|Moonshot|kimi|curl|https://code.kimi.com/kimi-code/install.sh"
  "opencode|OpenCode|Anomaly|opencode|mise|opencode"
  "cursor|Cursor CLI|Anysphere|cursor-agent|curl|https://cursor.com/install"
  "antigravity-cli|Antigravity CLI|Google|agy|mise|antigravity-cli"
  "grok|Grok Build|xAI|grok|mise|grok"
)

usage() {
  cat <<'EOF'
用法:
  bash install-agents.sh
  bash install-agents.sh --agents claude,grok
  bash install-agents.sh --agents all
  bash install-agents.sh --no-agents
  bash install-agents.sh --list
  bash install-agents.sh --prompt

不指定 --agents 且在终端里运行时，会列出预设让你勾选。直接回车 = 一个都不装。
非交互（管道、CI）且未指定选择时，默认不装。

参数:
  --agents IDS    逗号或空格分隔的 id / 编号 / all / none
  --no-agents     明确不装（与 --agents none 相同）
  --force         已安装也再装一遍
  --list          打印预设目录后退出
  --prompt        只询问，选中的 id 打到 stdout（供 install.sh 使用）
  -h, --help      显示帮助

环境变量:
  DEVBOX_AGENTS   未传 --agents 时使用，格式同 --agents
EOF
}

download() {
  curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --retry-connrefused "$1" -o "$2" && [ -s "$2" ]
}

catalog_field() {
  printf '%s' "$1" | cut -d'|' -f"$2"
}

catalog_line_by_id() {
  local id="$1" line
  for line in "${AGENTS_CATALOG[@]}"; do
    if [ "$(catalog_field "$line" 1)" = "$id" ]; then
      printf '%s\n' "$line"
      return 0
    fi
  done
  return 1
}

all_ids() {
  local line
  for line in "${AGENTS_CATALOG[@]}"; do
    catalog_field "$line" 1
  done
}

agent_on_path() {
  local bin="$1"
  if command -v "$bin" >/dev/null 2>&1; then
    return 0
  fi
  [ -x "$HOME/.local/bin/$bin" ] && return 0
  [ -x "$HOME/.grok/bin/$bin" ] && return 0
  [ -x "$HOME/.opencode/bin/$bin" ] && return 0
  [ -x "$HOME/.kimi-code/bin/$bin" ] && return 0
  return 1
}

prepare_user_env() {
  mkdir -p "$HOME/.local/bin" "$HOME/.config/mise/conf.d"
  export PATH="$HOME/.local/bin:$HOME/.grok/bin:$HOME/.opencode/bin:$HOME/.kimi-code/bin:${HOME}/.local/share/mise/shims:${PATH:-}"
  if command -v mise >/dev/null 2>&1; then
    eval "$(mise env -s bash 2>/dev/null)" || true
  fi
}

print_catalog() {
  local i=1 line id name vendor bins kind installed
  printf '  %-3s %-18s %-16s %-12s %-6s %s\n' "#" "id" "名称" "厂商" "方式" "状态" >&2
  for line in "${AGENTS_CATALOG[@]}"; do
    id="$(catalog_field "$line" 1)"
    name="$(catalog_field "$line" 2)"
    vendor="$(catalog_field "$line" 3)"
    bins="$(catalog_field "$line" 4)"
    kind="$(catalog_field "$line" 5)"
    installed=""
    if agent_on_path "$bins"; then
      installed="已安装"
    fi
    printf '  %-3s %-18s %-16s %-12s %-6s %s\n' "$i)" "$id" "$name" "$vendor" "$kind" "$installed" >&2
    i=$((i + 1))
  done
  printf '\n' >&2
  printf '  mise = 官方 registry，写入 ~/.config/mise/conf.d/coding-agents.toml\n' >&2
  printf '  curl = 不在 registry，走官方安装脚本（kimi、cursor）\n' >&2
}

PARSE_ERRORS=()
SELECTED_IDS=()

# 解析用户输入。成功时写入 SELECTED_IDS；失败时写入 PARSE_ERRORS。
parse_selection() {
  local raw="$1" token ids=() n line id seen
  PARSE_ERRORS=()
  SELECTED_IDS=()
  raw="${raw//,/ }"
  # shellcheck disable=SC2086
  set -- $raw
  if [ "$#" -eq 0 ]; then
    return 0
  fi
  for token in "$@"; do
    case "$token" in
      a|A|all|ALL)
        ids=()
        for line in "${AGENTS_CATALOG[@]}"; do
          ids+=("$(catalog_field "$line" 1)")
        done
        break
        ;;
      none|NONE|skip|SKIP|-)
        ids=()
        break
        ;;
      *[!0-9]*)
        if catalog_line_by_id "$token" >/dev/null; then
          ids+=("$token")
        else
          PARSE_ERRORS+=("$token")
        fi
        ;;
      *)
        n="$token"
        if [ "$n" -ge 1 ] && [ "$n" -le "${#AGENTS_CATALOG[@]}" ]; then
          line="${AGENTS_CATALOG[$((n - 1))]}"
          ids+=("$(catalog_field "$line" 1)")
        else
          PARSE_ERRORS+=("$token")
        fi
        ;;
    esac
  done

  if [ "${#PARSE_ERRORS[@]}" -gt 0 ]; then
    return 1
  fi

  for line in "${AGENTS_CATALOG[@]}"; do
    id="$(catalog_field "$line" 1)"
    seen=0
    for token in "${ids[@]+"${ids[@]}"}"; do
      if [ "$token" = "$id" ]; then
        seen=1
        break
      fi
    done
    if [ "$seen" = 1 ]; then
      SELECTED_IDS+=("$id")
    fi
  done
  return 0
}

emit_selected() {
  printf '%s\n' "${SELECTED_IDS[*]-}"
}

prompt_selection() {
  local reply tries=0
  printf '\n' >&2
  printf '  可选 coding agents（默认不装，直接回车跳过）:\n\n' >&2
  print_catalog
  printf '  输入编号或 id，逗号/空格分隔；a=全部；回车=不装\n' >&2
  while [ "$tries" -lt 3 ]; do
    printf '  > ' >&2
    if ! IFS= read -r reply; then
      reply=""
    fi
    if parse_selection "$reply"; then
      emit_selected
      return 0
    fi
    warn "无法识别: ${PARSE_ERRORS[*]-}"
    tries=$((tries + 1))
  done
  warn "选择无效，按不安装处理"
  SELECTED_IDS=()
  printf '\n'
}

record_selected() {
  local id="$1" tmp
  mkdir -p "$(dirname "$SELECTED_FILE")"
  touch "$SELECTED_FILE"
  if grep -Fqx "$id" "$SELECTED_FILE" 2>/dev/null; then
    return 0
  fi
  tmp="$(mktemp)"
  cat "$SELECTED_FILE" > "$tmp"
  printf '%s\n' "$id" >> "$tmp"
  mv "$tmp" "$SELECTED_FILE"
}

# 按已记录 + 本次要装的 mise 项重写本机 conf.d，不碰仓库 mise.toml。
rewrite_mise_conf() {
  local id line kind spec ids=() seen
  mkdir -p "$(dirname "$CONF_D")"
  if [ -f "$SELECTED_FILE" ]; then
    while IFS= read -r id; do
      [ -n "$id" ] || continue
      ids+=("$id")
    done < "$SELECTED_FILE"
  fi
  for id in "$@"; do
    ids+=("$id")
  done

  {
    printf '%s\n' '# Generated by scripts/devbox-init/mise/install-agents.sh'
    printf '%s\n' '# Machine-local optional agents. Not the repo mise.toml.'
    printf '%s\n' '[tools]'
    for line in "${AGENTS_CATALOG[@]}"; do
      id="$(catalog_field "$line" 1)"
      kind="$(catalog_field "$line" 5)"
      spec="$(catalog_field "$line" 6)"
      [ "$kind" = "mise" ] || continue
      seen=0
      for token in "${ids[@]+"${ids[@]}"}"; do
        if [ "$token" = "$id" ]; then
          seen=1
          break
        fi
      done
      [ "$seen" = 1 ] || continue
      if printf '%s' "$spec" | grep -q ':'; then
        printf '"%s" = "latest"\n' "$spec"
      else
        printf '%s = "latest"\n' "$spec"
      fi
    done
  } > "$CONF_D"
}

install_curl_agent() {
  local name="$1" url="$2" tmp rc
  tmp="$(mktemp /tmp/devbox-agent.XXXXXX)"
  if ! download "$url" "$tmp"; then
    rm -f "$tmp"
    warn "$name: 安装脚本下载失败 ($url)"
    return 1
  fi
  step "$name: 运行官方安装器 ..."
  if PREFIX="${PREFIX:-$HOME/.local}" bash "$tmp" </dev/null; then
    rc=0
  else
    rc=1
    warn "$name: 官方安装器返回非零退出码"
  fi
  rm -f "$tmp"
  return "$rc"
}

install_mise_agents() {
  if ! command -v mise >/dev/null 2>&1; then
    warn "找不到 mise，无法安装 registry 里的 agents"
    return 1
  fi
  step "mise install（conf.d/coding-agents.toml）..."
  mise trust "$HOME/.config/mise/config.toml" >/dev/null 2>&1 || true
  mise trust "$CONF_D" >/dev/null 2>&1 || true
  MISE_YES=1 mise install --yes
}

MODE="install"
FORCE=0
AGENTS_SPEC=""
AGENTS_SPEC_SET=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --list)
      MODE="list"
      shift
      ;;
    --prompt)
      MODE="prompt"
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --no-agents)
      AGENTS_SPEC="none"
      AGENTS_SPEC_SET=1
      shift
      ;;
    --agents)
      if [ "$#" -lt 2 ]; then
        printf '\033[1;31m✘ --agents 需要一个参数\033[0m\n' >&2
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

case "$MODE" in
  list)
    print_catalog
    exit 0
    ;;
  prompt)
    if [ "$AGENTS_SPEC_SET" = 1 ]; then
      if ! parse_selection "$AGENTS_SPEC"; then
        printf '\033[1;31m✘ 无法识别: %s\033[0m\n' "${PARSE_ERRORS[*]-}" >&2
        exit 2
      fi
      emit_selected
      exit 0
    fi
    if [ -t 0 ] && [ -t 1 ]; then
      prompt_selection
    else
      printf '\n'
    fi
    exit 0
    ;;
esac

# ── install ────────────────────────────────────────────────────────────────

if [ "$AGENTS_SPEC_SET" = 0 ]; then
  if [ -t 0 ] && [ -t 1 ]; then
    prompt_selection >/dev/null
  else
    skip "非交互且未指定 --agents / DEVBOX_AGENTS，不安装 coding agents"
    exit 0
  fi
elif ! parse_selection "$AGENTS_SPEC"; then
  printf '\033[1;31m✘ 无法识别: %s\033[0m\n' "${PARSE_ERRORS[*]-}" >&2
  printf '  可用 id: %s\n' "$(all_ids | tr '\n' ' ')" >&2
  exit 2
fi

if [ "${#SELECTED_IDS[@]}" -eq 0 ]; then
  skip "未选择 coding agents"
  exit 0
fi

prepare_user_env

PENDING_MISE=()
TRACK_MISE=()
FAILED=0

for id in "${SELECTED_IDS[@]}"; do
  line="$(catalog_line_by_id "$id")" || { warn "未知 agent: $id"; FAILED=$((FAILED + 1)); continue; }
  name="$(catalog_field "$line" 2)"
  bins="$(catalog_field "$line" 4)"
  kind="$(catalog_field "$line" 5)"
  src="$(catalog_field "$line" 6)"

  log "$name ($id)"
  if [ "$FORCE" = 0 ] && agent_on_path "$bins"; then
    ok "$name 已安装"
    record_selected "$id"
    if [ "$kind" = "mise" ]; then
      TRACK_MISE+=("$id")
    fi
    continue
  fi

  case "$kind" in
    mise)
      PENDING_MISE+=("$id")
      TRACK_MISE+=("$id")
      ;;
    curl)
      if install_curl_agent "$name" "$src" && agent_on_path "$bins"; then
        ok "$name 已安装"
        record_selected "$id"
      else
        warn "$name: 安装后未检测到命令 $bins"
        FAILED=$((FAILED + 1))
      fi
      ;;
    *)
      warn "$name: 未知安装方式 $kind"
      FAILED=$((FAILED + 1))
      ;;
  esac
done

if [ "${#TRACK_MISE[@]}" -gt 0 ]; then
  rewrite_mise_conf "${TRACK_MISE[@]}"
fi

if [ "${#PENDING_MISE[@]}" -gt 0 ]; then
  if install_mise_agents; then
    prepare_user_env
    for id in "${PENDING_MISE[@]}"; do
      line="$(catalog_line_by_id "$id")"
      name="$(catalog_field "$line" 2)"
      bins="$(catalog_field "$line" 4)"
      if agent_on_path "$bins"; then
        ok "$name 已安装"
        record_selected "$id"
      else
        warn "$name: mise install 后未检测到命令 $bins"
        FAILED=$((FAILED + 1))
      fi
    done
  else
    warn "mise install 失败"
    FAILED=$((FAILED + ${#PENDING_MISE[@]}))
  fi
fi

if [ "$FAILED" -gt 0 ]; then
  warn "$FAILED 个 coding agent 安装失败"
  exit 1
fi
exit 0
