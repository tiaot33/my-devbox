# devbox-init / mise

Debian / Ubuntu 无头开发机：一条命令装好系统包、现代 CLI、语言工具链和 dotfiles。**软件一律由 [mise](https://mise.jdx.dev/) 声明式管理**。

Coding agent（Claude Code、Codex、Grok Build 等）是**可选预设**，默认一个都不装。装机时勾选，或之后 `mise run agents`。

旧入口 `../devbox-init.sh` 和 `../devbox-lang.sh` 仍可运行，但不再作为推荐路径维护。新机器请走本目录的 `install.sh`。

---

## 1. 适用环境

- **系统**：Ubuntu / Debian（读 `/etc/os-release`；其它发行版仅尽力而为）。
- **权限**：以目标用户运行且具备 `sudo`，或以 root 运行（会装到 `SUDO_USER` 的主目录）。
- **网络**：需要访问外网（mise 安装器、APT、GitHub / aqua）。
- **架构**：x86_64 / aarch64。

---

## 2. 怎么安装

建议先打开 raw 链接审阅脚本，再执行远程脚本。

### 干净机器（推荐）

```bash
bash <(wget -qO- https://raw.githubusercontent.com/tiaot33/my-devbox/main/scripts/devbox-init/mise/install.sh)
```

需要 sudo 装系统包时：

```bash
sudo bash <(wget -qO- https://raw.githubusercontent.com/tiaot33/my-devbox/main/scripts/devbox-init/mise/install.sh)
```

非交互、或已经想好装哪些 agent：

```bash
DEVBOX_AGENTS=claude,grok bash <(wget -qO- https://raw.githubusercontent.com/tiaot33/my-devbox/main/scripts/devbox-init/mise/install.sh)
# 或
bash scripts/devbox-init/mise/install.sh --agents claude,codex
bash scripts/devbox-init/mise/install.sh --no-agents
```

远程安装会把本仓库浅克隆到 `~/.local/src/my-devbox`。可用 `DEVBOX_REPO_URL` 覆盖仓库地址。

### 本仓库已在磁盘上

```bash
bash scripts/devbox-init/mise/install.sh
# 或
sudo bash scripts/devbox-init/mise/install.sh
```

### 安装脚本做了什么

1. 用 APT 装 `ca-certificates` `curl` `git`（装 mise 之前的依赖）
2. 按官方方式安装 [mise](https://mise.run) 到 `~/.local/bin/mise`
3. 把本目录接到 `~/.config/mise/`（`config.toml` → `mise.toml`，以及 `dotfiles/`、`bootstrap-extras.sh`、`install-agents.sh`）
4. 在终端里询问要装哪些 coding agents（直接回车 = 不装）。非交互且未设 `DEVBOX_AGENTS` / `--agents` 时跳过
5. 执行 `mise bootstrap --yes --update --force-dotfiles`
6. 按选择安装 coding agents
7. 配置 `en_US.UTF-8`

### 装完立刻生效

开一个新的 SSH 会话，或：

```bash
source ~/.bashrc
```

第一次进交互 shell 时，PATH 里应有 `mise`、`eza`、`nvim`、`node` 等。`mise run doctor` 可以确认缺项。

---

## 3. 装了什么

清单只有 [`mise.toml`](./mise.toml)。`install.sh` 把它软链到 `~/.config/mise/config.toml`，所以工具在任意目录都进 PATH。`latest` / `lts` 每次安装或升级都按当时解析，不锁版本。

### 系统包（APT）

不走第三方 APT 源。版本化 CLI 不放这里。

| 类别 | 包 |
| --- | --- |
| 基础 | `sudo` `ca-certificates` `curl` `wget` `gnupg` `locales` `tzdata` `bash-completion` `man-db` `fontconfig` |
| 编译 | `build-essential` `pkg-config` `make` `cmake` `gawk` |
| 归档 | `git` `unzip` `zip` `tar` `xz-utils` `zstd` `gzip` `file` `less` `tree` |
| 编辑 / 会话 | `vim` `nano` `tmux` `htop` |
| 原生绑定头文件 | `libssl-dev` `zlib1g-dev` `libffi-dev` `libbz2-dev` `libreadline-dev` `libsqlite3-dev` `liblzma-dev` |
| 远程排障 | `iproute2` `dnsutils` `openssh-client` `rsync` `lsof` `psmisc` `strace` `iputils-ping` `mtr-tiny` |
| 维护 | `unattended-upgrades` `ncdu` |

另外会写入 `/etc/apt/apt.conf.d/20auto-upgrades`，打开无人值守安全更新。

### CLI（mise `[tools]`）

| 用途 | 命令 |
| --- | --- |
| 文件 / 搜索 | `eza` `bat` `fd` `ripgrep` `fzf` `tree`（APT） |
| 系统观察 | `btop` `dust` `duf` `ncdu`（APT） |
| Git | `gh` `lazygit` `delta` `hunk` |
| HTTP / 数据 | `curl`（APT） `xh` `jq` `yq` |
| 编辑 | `neovim`（`vim`/`vi` 指向它） |
| 终端 | `starship` `zoxide` `atuin` `tmux`（APT） |
| 环境 | `direnv` `mise` |
| 补全 | `carapace` `usage` |
| 检查 / 格式 | `shellcheck` `shfmt` |
| 其它 | `fastfetch` |

`hunk` 是终端 diff 审阅（`hunk diff` / `hunk show`）。`carapace` 管已装 CLI 的参数补全；`mise` / `mise run` 另走 `mise completion bash`。

### 语言

| 运行时 | 附带 |
| --- | --- |
| Node LTS | pnpm、yarn；全局 `typescript` `tsx` `eslint` `prettier` |
| Python | `uv` `ruff` |
| Go | `gopls` `goimports` `staticcheck` `dlv` `air` |
| Bun、Deno | — |

`gopls` / `goimports` / `dlv` 走 mise 的 go backend（`go install`）。aqua 不支持 `go_install` 包，而且 delve 1.27 的 GitHub release 没有 linux 预编译包。`staticcheck` 和 `air` 仍走 aqua。

版本管理只走 mise，不再装 fnm / nvm / pyenv。

### 声明式装不下的（`mise run bootstrap` / extras）

ble.sh、ComicShannsMono Nerd Font、[herdr](https://herdr.dev)、一组 git 全局默认、以及只在缺失时创建的 `~/.config/shell/local.sh` 和 `functions.sh`。

herdr 是 agent multiplexer，始终安装。具体 coding agent 见下一节，默认不装。

### Coding agents（可选预设）

mise **没有单独的 coding-agent 功能**。官方做法就是把它们当普通工具：[registry](https://mise.jdx.dev/registry.html) 里有 shorthand，写进 `[tools]`，`mise install`。Getting Started 也用 `npm:@anthropic-ai/claude-code` 当 backend 例子。

仓库默认的 `mise.toml` **不声明任何 agent**。选中的项写到本机：

`~/.config/mise/conf.d/coding-agents.toml`

这是 mise 的 [conf.d](https://mise.jdx.dev/configuration.html#mise-toml) 片段，只对这台机器生效，不会改仓库清单。默认零安装。

当前目录只收已经在用的这些。copilot / hermes 等先不加。

| id | 命令 | 怎么装 |
| --- | --- | --- |
| `pi` | `pi` | mise registry `pi`（aqua:earendil-works/pi） |
| `omp` | `omp` | mise registry `oh-my-pi` |
| `claude` | `claude` | mise registry `claude` |
| `codex` | `codex` | mise registry `codex` |
| `kimi` | `kimi` | 官方脚本（不在 registry） |
| `opencode` | `opencode` | mise registry `opencode` |
| `cursor` | `cursor-agent` | 官方脚本（不在 registry） |
| `antigravity-cli` | `agy` | mise registry `antigravity-cli` |
| `grok` | `grok` | mise registry `grok` |

```bash
# 装机时指定
bash install.sh --agents claude,grok
DEVBOX_AGENTS=all bash install.sh
bash install.sh --no-agents

# 装好之后再补
mise run agents
bash ~/.config/mise/install-agents.sh --list
bash ~/.config/mise/install-agents.sh --agents claude,codex
```

已装的会跳过（`--force` 才重装）。登录和 API key 留给各 CLI。`grok` / `cursor` 都可能再提供一个 `agent` 入口，本目录用 `grok` / `cursor-agent` 判断。

选中记录在 `~/.config/mise/coding-agents.selected`。

### 工作站任务

| 命令 | 作用 |
| --- | --- |
| `mise run update` | 按 toml 把已装工具升到当前最新 |
| `mise run doctor` | `mise doctor` + bootstrap 缺项 |
| `mise run sync` | 把配置仓库对齐到 origin，再完整 bootstrap |
| `mise run agents` | 选择并安装 coding agent 预设 |

---

## 4. 安装之后平常怎么用

这是**全局工作站**，不是「每个 git 仓库一份工具链」。`cd` 到哪，Node / Python / Go 都是这份清单里的版本。某个项目要钉别的版本，在那个仓库自己放 `mise.toml`，会叠在全局配置上面。

### 终端习惯

| 你打的 | 实际是 |
| --- | --- |
| `cd foo` 或 `z foo` | [zoxide](https://github.com/ajeetdsouza/zoxide) 模糊跳转（`alias cd='z'`） |
| `ls` / `ll` / `l` | `eza` |
| `vim` / `vi` | `nvim` |
| Tab 补全 | carapace（多数 CLI）+ `mise completion` |
| 上方向键 / 历史 | atuin（关掉了用上键搜历史，避免和 ble.sh 抢） |
| `git diff` | delta 当 pager |
| `hunk diff` | 交互审阅工作区（含未跟踪文件） |
| `lazygit` | Git TUI |
| `mise run …` | 工作站任务 |

个人 alias、环境变量、函数放这里，**bootstrap 不会覆盖**：

- `~/.config/shell/local.sh`
- `~/.config/shell/functions.sh`

不要改 `~/.bashrc.generated`、`aliases.sh`、tmux/vim/starship 等生成文件——重跑会盖掉。

### 日常命令

```bash
mise ls                 # 当前生效的工具版本
mise run doctor         # 缺包、缺工具、配置是否可信
gh auth login           # 第一次用 GitHub CLI
hunk diff               # 审当前改动
lazygit
```

脚本或 CI 里不要依赖 `mise activate`（它挂在 prompt 上）。用：

```bash
mise exec -- node -v
mise run doctor
```

### 改这份清单

真正的开关是仓库里的 [`mise.toml`](./mise.toml)。

| 想做的事 | 做法 |
| --- | --- |
| 少装一门语言 | 注释掉 `[tools]` 对应行，然后 `mise bootstrap --yes --only tools` |
| 加一个 CLI | 在 `[tools]` 加一行例如 `tokei = "latest"`，提交，机器上 `mise run sync` 或重跑 `install.sh` |
| 只刷新 dotfiles | `mise bootstrap --yes --only dotfiles --force-dotfiles` |
| 只跑 ble.sh / 字体 / git 默认 | `mise bootstrap --yes --only task` |
| 补装 coding agents | `mise run agents` 或 `bash ~/.config/mise/install-agents.sh --agents …` |

---

## 5. 怎么更新

两件事分开：

| 你想做的 | 命令 |
| --- | --- |
| 仓库里的 `mise.toml` / dotfiles 变了 | 再跑一遍 `install.sh`，或 `mise run sync` |
| 已装工具升到当前最新 | `mise run update` |

远程安装的机器，配置在 `~/.local/src/my-devbox`。`install.sh` 和 `mise run sync` 都会把它 `reset --hard` 到 origin，然后 bootstrap。不要在这份克隆里手改。

清单要改就改 GitHub 上的 [`mise.toml`](./mise.toml)，提交后各机器同步。

mise 自己：

```bash
mise self-update
```

本配置要求 mise ≥ `2026.7.0`。包管理器装的 mise 往往偏旧，官方安装器支持 `self-update`。

---

## 6. 副作用

- 目标用户默认 shell 改为 `/bin/bash`。
- `~/.bashrc` 会追加 mise activate 和 `source ~/.bashrc.generated`。
- 覆盖写入 `~/.bashrc.generated` 以及 tmux / vim / starship / atuin / lazygit 等生成配置。
- `alias cd='z'` 改变交互习惯。
- 写入一组 git 全局默认（editor、pull、diff、delta pager）。
- 启用 `unattended-upgrades` 与 `en_US.UTF-8`。
- 选中的 coding agents 多数写进本机 `~/.config/mise/conf.d/coding-agents.toml`；kimi / cursor 跑官方安装器。本脚本不替它们登录或写 API key。
