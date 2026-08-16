# devbox-init / mise

Debian / Ubuntu 无头开发机：一条命令装好系统包、现代 CLI、语言工具链和 dotfiles。**软件一律由 [mise](https://mise.jdx.dev/) 声明式管理**。

旧入口 `../devbox-init.sh` 和 `../devbox-lang.sh` 仍可运行，但不再作为推荐路径维护。新机器请走本目录的 `install.sh`。

---

## 1. 适用环境

- **系统**：Ubuntu / Debian（读 `/etc/os-release`；其它发行版仅尽力而为）。
- **权限**：以目标用户运行且具备 `sudo`，或以 root 运行（会装到 `SUDO_USER` 的主目录）。
- **网络**：需要访问外网（mise 安装器、APT、GitHub / aqua）。
- **架构**：`mise.lock` 锁了 `linux-x64` 和 `linux-arm64`。

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
3. 把本目录接到 `~/.config/mise/`：
   - `config.toml` → `mise.toml`
   - `mise.lock`、`dotfiles/`、`bootstrap-extras.sh`
4. 执行 `mise bootstrap --yes --update --force-dotfiles`
5. 配置 `en_US.UTF-8`

### 装完立刻生效

开一个新的 SSH 会话，或：

```bash
source ~/.bashrc
```

第一次进交互 shell 时，PATH 里应有 `mise`、`eza`、`nvim`、`node` 等。`mise run doctor` 可以确认缺项。

---

## 3. 装了什么

清单在 [`mise.toml`](./mise.toml)，精确版本在 [`mise.lock`](./mise.lock)。`install.sh` 把它们软链到 `~/.config/mise/`，所以工具在任意目录都进 PATH。

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

### 工作站任务

| 命令 | 作用 |
| --- | --- |
| `mise run update` | 按 toml 范围升级已声明工具，并刷新 lock |
| `mise run doctor` | `mise doctor` + bootstrap 缺项 |
| `mise run sync` | `git pull --ff-only` 配置仓库，再完整 bootstrap |

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
| 加一个 CLI | 加一行例如 `tokei = "latest"`，再 `--only tools`，然后 `mise lock --platform linux-x64,linux-arm64` 并提交 lock |
| 只刷新 dotfiles | `mise bootstrap --yes --only dotfiles --force-dotfiles` |
| 只跑 ble.sh / 字体 / git 默认 | `mise bootstrap --yes --only task` |

---

## 5. 怎么升级

锁住之后，`mise.toml` 里的 `latest` / `lts` **不会自己往前走**。装机和 `mise install` 都按 `mise.lock`。

### 这台机器上的工具

```bash
mise run update
```

等于 `mise upgrade`（按范围解析、改 lock、装上新版本）再补齐缺的 `[tools]`。

只升某一个：

```bash
mise upgrade node uv
```

### 配置仓库也更新了（推荐的多机流程）

1. 一台机器 `mise run update`，或在能跑 mise 的地方刷新 lock
2. 看 `git diff scripts/devbox-init/mise/mise.lock`
3. 提交
4. 其它已装机器：

```bash
mise run sync
```

`sync` 会定位 `~/.config/mise/config.toml` 指向的仓库、`git pull --ff-only`，再完整 bootstrap（含 `--force-dotfiles`）。

不要两台机器各自 `mise upgrade` 却不提交 lock，否则又会漂。

### 只改 lock、不在本机安装

适合在 macOS 上维护这份 Linux lock：

```bash
cd scripts/devbox-init/mise
mise lock --bump --platform linux-x64,linux-arm64
```

不改 `mise.toml`，不安装。提交后服务器上 `mise run sync` 或 `mise install`。

### 升级 mise 自己

```bash
mise self-update
```

本配置要求 mise ≥ `2026.7.0`（`min_version`）。包管理器装的 mise 往往偏旧，官方安装器支持 `self-update`。

### 三种升级命令

| 命令 | 改 toml | 改 lock | 安装 |
| --- | --- | --- | --- |
| `mise run update` / `mise upgrade` | 否 | 是 | 是 |
| `mise lock --bump --platform linux-x64,linux-arm64` | 否 | 是 | 否 |
| `mise upgrade --bump` | 会改前缀 pin | 是 | 是 |

这份清单几乎全是 `latest` / `lts`，日常用前两种，不要用 `--bump` 去改 toml。

---

## 6. 副作用

- 目标用户默认 shell 改为 `/bin/bash`。
- `~/.bashrc` 会追加 mise activate 和 `source ~/.bashrc.generated`。
- 覆盖写入 `~/.bashrc.generated` 以及 tmux / vim / starship / atuin / lazygit 等生成配置。
- `alias cd='z'` 改变交互习惯。
- 写入一组 git 全局默认（editor、pull、diff、delta pager）。
- 启用 `unattended-upgrades` 与 `en_US.UTF-8`。
