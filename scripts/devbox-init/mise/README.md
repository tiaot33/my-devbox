# devbox-init / mise

Debian / Ubuntu 无头开发机：一条命令装好系统包、现代 CLI、语言工具链和 dotfiles。**软件一律由 [mise](https://mise.jdx.dev/) 声明式管理**。

Coding agent（Claude Code、Codex、Grok Build 等）是**可选预设**，默认一个都不装。装机时勾选；之后只用 `mise use -g` / `mise unuse -g`，不要再跑装机脚本。

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

终端里会在 bootstrap 之前问要装哪些 coding agents，直接回车 = 一个都不装。已经想好、或不想被问：

```bash
DEVBOX_AGENTS=claude,omp,grok bash <(wget -qO- https://raw.githubusercontent.com/tiaot33/my-devbox/main/scripts/devbox-init/mise/install.sh)
bash scripts/devbox-init/mise/install.sh --agents claude,codex
bash scripts/devbox-init/mise/install.sh --no-agents
```

`DEVBOX_AGENTS` / `--agents` 接受 id 或 `all` / `none`。远程安装会把本仓库浅克隆到 `~/.local/src/my-devbox`。可用 `DEVBOX_REPO_URL` 覆盖仓库地址。

### 本仓库已在磁盘上

```bash
bash scripts/devbox-init/mise/install.sh
# 或
sudo bash scripts/devbox-init/mise/install.sh
```

### 安装脚本做了什么

1. 用 APT 装 `ca-certificates` `curl` `git`（装 mise 之前的依赖）
2. 已有 [mise](https://mise.run) 且 ≥ `2026.7.0` 则跳过，否则装到 `~/.local/bin/mise`
3. 接到 `~/.config/mise/`：仓库 [`mise.toml`](./mise.toml) → `conf.d/00-devbox.toml`，`dotfiles/` 链到 `conf.d/dotfiles`（mise 按 toml 所在目录解析 source）；`config.toml` 是可写文件，给 `mise use -g` 用
4. 询问要装哪些 coding agents（非交互且未指定则跳过）
5. 执行 `mise bootstrap --yes --update --force-dotfiles`
6. 按选择执行 `mise use -g`（cursor 走官方安装器）
7. 配置 `en_US.UTF-8`

### 装完立刻生效

开一个新的 SSH 会话，或：

```bash
source ~/.bashrc
```

第一次进交互 shell 时，PATH 里应有 `mise`、`eza`、`nvim`、`node` 等。`mise run doctor` 可以确认缺项。

---

## 3. 装了什么

工作站默认清单在仓库 [`mise.toml`](./mise.toml)，装机后软链到 `~/.config/mise/conf.d/00-devbox.toml`，所以工具在任意目录都进 PATH。`latest` / `lts` 每次安装或升级都按当时解析，不锁版本。

个人加的全局工具（含 coding agents）不进仓库，写在本机 `~/.config/mise/config.toml`。

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

herdr 是 agent multiplexer，始终安装。具体 coding agent 默认不装，见下一节。

### Coding agents（可选）

mise 没有单独的 coding-agent 功能，就是普通工具。装机时勾选的那些会 `mise use -g` 写进本机 `config.toml`。

| id | 命令 | 之后怎么管 |
| --- | --- | --- |
| `pi` | `pi` | `mise use -g pi` |
| `omp` | `omp` | `mise use -g omp`（`[tool_alias]` → `oh-my-pi`） |
| `claude` | `claude` | `mise use -g claude` |
| `codex` | `codex` | `mise use -g codex` |
| `kimi` | `kimi` | `mise use -g kimi`（`[tool_alias]` → npm 包） |
| `opencode` | `opencode` | `mise use -g opencode` |
| `cursor` | `cursor-agent` | 不在 mise registry；装机时装一次，之后 `cursor-agent update` |
| `antigravity-cli` | `agy` | `mise use -g antigravity-cli` |
| `grok` | `grok` | `mise use -g grok` |

登录和 API key 留给各 CLI。`grok` / `cursor` 都可能再提供一个 `agent` 入口，用 `grok` / `cursor-agent`。

### 工作站任务

| 命令 | 作用 |
| --- | --- |
| `mise run update` | 按 toml 把已装工具升到当前最新 |
| `mise run doctor` | `mise doctor` + bootstrap 缺项 |
| `mise run sync` | 把配置仓库对齐到 origin，再完整 bootstrap |

---

## 4. 安装之后平常怎么用

这是**全局工作站**，不是「每个 git 仓库一份工具链」。`cd` 到哪，Node / Python / Go 都是这份清单里的版本。某个项目要钉别的版本，在那个仓库自己放 `mise.toml`，会叠在全局配置上面。

装机脚本用过一次就不用了。日常只跟 mise 打交道。

### 两份配置

| 路径 | 改它等于 | 怎么改 |
| --- | --- | --- |
| `~/.config/mise/conf.d/00-devbox.toml` | 仓库 [`mise.toml`](./mise.toml) | 改 GitHub 上的清单，各机器 `mise run sync` |
| `~/.config/mise/config.toml` | 这台机器自己的全局工具 | `mise use -g` / `mise unuse -g` |

不要手改软链过去的 `00-devbox.toml`。远程安装的机器，源仓库在 `~/.local/src/my-devbox`，`sync` 会把它 `reset --hard` 到 origin。

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

### coding agents

```bash
mise use -g claude omp grok     # 补装
mise unuse -g claude            # 从本机全局配置里去掉
mise ls                         # 看当前生效的
mise upgrade                    # 已声明的升到当前 latest
```

可用 id 见上面的表。`omp` / `kimi` 已经做了短名 alias。`cursor` 不走 mise，用 `cursor-agent update`。

### 改工作站默认清单

真正的开关是仓库里的 [`mise.toml`](./mise.toml)。

| 想做的事 | 做法 |
| --- | --- |
| 少装一门语言 | 注释掉 `[tools]` 对应行，提交，机器上 `mise run sync` |
| 加一个全员都要的 CLI | 在 `[tools]` 加一行例如 `tokei = "latest"`，提交，`mise run sync` |
| 只给这台机器加一个 CLI | `mise use -g tokei` |
| 只刷新 dotfiles | `mise bootstrap --yes --only dotfiles --force-dotfiles` |
| 只跑 ble.sh / 字体 / git 默认 | `mise bootstrap --yes --only task` |

---

## 5. 怎么更新

两件事分开：

| 你想做的 | 命令 |
| --- | --- |
| 仓库里的 `mise.toml` / dotfiles 变了 | `mise run sync`（或再跑一遍 `install.sh`） |
| 已装工具升到当前最新 | `mise run update` |
| 只升某个 agent / CLI | `mise upgrade claude` |

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
- 选中的 coding agents 写进本机 `~/.config/mise/config.toml`。cursor 不在 registry，走官方安装器。不替它们登录或写 API key。
