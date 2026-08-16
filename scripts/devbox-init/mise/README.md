# devbox-init / mise

Debian / Ubuntu 无头开发环境，**软件一律由 [mise](https://mise.jdx.dev/) 管理**。

一条命令把干净的服务器或容器初始化为：系统基础包 + 现代 CLI + Node / Python / Go / Bun / Deno + 终端增强 + 统一 dotfiles。

旧入口 `../devbox-init.sh` 和 `../devbox-lang.sh` 仍可运行，但不再作为推荐路径维护。

---

## 1. 适用环境

- **目标系统**：Ubuntu / Debian（读取 `/etc/os-release`；其它发行版仅尽力而为）。
- **权限**：以 root 运行，或以普通用户运行但具备 `sudo`。
- **网络**：需要访问外网（mise 安装器、APT、GitHub / aqua 工具源）。

---

## 2. 使用方法

### 推荐：从 GitHub 下载并执行

```bash
bash <(wget -qO- https://raw.githubusercontent.com/tiaot33/my-devbox/main/scripts/devbox-init/mise/install.sh)
```

需要 sudo 装系统包时也可以：

```bash
sudo bash <(wget -qO- https://raw.githubusercontent.com/tiaot33/my-devbox/main/scripts/devbox-init/mise/install.sh)
```

> 建议先打开 raw 链接审阅脚本，再执行远程脚本。

完成后开启新的 SSH 会话，或：

```bash
source ~/.bashrc
```

### 本地运行

在本仓库中：

```bash
bash scripts/devbox-init/mise/install.sh
# 或
sudo bash scripts/devbox-init/mise/install.sh
```

`install.sh` 会：

1. 用 APT 装 `ca-certificates` `curl` `git`（mise 的鸡生蛋依赖）
2. 按官方方式安装 [mise](https://mise.run)（`~/.local/bin/mise`）
3. 把本目录接到 `~/.config/mise/`（全局生效；否则工具只在仓库目录里进 PATH）
4. 执行 `mise bootstrap --yes --update --force-dotfiles`
5. 配置 `en_US.UTF-8` locale

远程一键安装时，脚本会把本仓库浅克隆到 `~/.local/src/my-devbox`。可用 `DEVBOX_REPO_URL` 覆盖仓库地址。

---

## 3. 改什么、怎么重跑

真正的清单在 [`mise.toml`](./mise.toml)。它被软链到 `~/.config/mise/config.toml`。

| 想做的事 | 做法 |
| --- | --- |
| 少装一门语言 | 注释掉 `[tools]` 里对应行，然后 `mise bootstrap --yes --only tools` |
| 加一个 CLI | 在 `[tools]` 加一行，例如 `tokei = "latest"`，再 `--only tools` |
| 只刷新 dotfiles | `mise bootstrap --yes --only dotfiles --force-dotfiles` |
| 只跑 ble.sh / 字体 / git 默认 | `mise bootstrap --yes --only task` |
| 看缺了什么 | `mise run doctor` 或 `mise bootstrap status --missing` |
| 升级已声明工具 | `mise run update` |
| 拉取配置仓库并重跑 bootstrap | `mise run sync` |

个人 alias 和函数放在：

- `~/.config/shell/local.sh`（不会覆盖）
- `~/.config/shell/functions.sh`（不会覆盖）

`~/.bashrc.generated`、`aliases.sh`、tmux/vim/starship 等生成文件**重跑会覆盖**。

---

## 4. 装了什么

### 系统包（`[bootstrap.packages]`，APT）

`build-essential`、`cmake`、`git`、`curl`、`locales`、`tmux`、`vim`、`fontconfig` 等基础包，以及 `unattended-upgrades`、`ncdu`。

编译原生绑定时需要的头文件也在这里：`libssl-dev` `zlib1g-dev` `libffi-dev` `libbz2-dev` `libreadline-dev` `libsqlite3-dev` `liblzma-dev`。

远程排障：`openssh-client` `rsync` `lsof` `psmisc` `strace` `iputils-ping` `mtr-tiny`。

不走第三方 APT 源。`gh` / `eza` / `ripgrep` / `neovim` 等版本化 CLI 都在 `[tools]`。

### 工具与语言（`[tools]`，mise）

- **CLI**：`eza` `bat` `fd` `ripgrep` `fzf` `btop` `dust` `duf` `delta` `hunk` `lazygit` `gh` `starship` `zoxide` `atuin` `neovim` `direnv` `shellcheck` `shfmt` `fastfetch` `jq` `yq` `xh` `usage` `carapace`
- **语言**：Node LTS（mise 装 pnpm/yarn；typescript/tsx/eslint/prettier）、Python + uv + ruff、Go + gopls/goimports/staticcheck/dlv/air、Bun、Deno

精确版本写在同目录的 [`mise.lock`](./mise.lock)。`install.sh` 会把它软链到 `~/.config/mise/mise.lock`。改完 `[tools]` 或想抬 `latest` 时，在这台 Debian/Ubuntu 上跑 `mise lock --platform linux-x64,linux-arm64`（或 `mise run update`）再提交 lock。

### 工作站任务（`mise run`）

| 任务 | 作用 |
| --- | --- |
| `update` | `mise upgrade` + 只装缺的 `[tools]` |
| `doctor` | `mise doctor` 和 bootstrap 缺项 |
| `sync` | `git pull --ff-only` 配置仓库，再完整 bootstrap |

### 声明式装不下的（`[tasks.bootstrap]`）

ble.sh、ComicShannsMono Nerd Font、herdr、git 全局默认、用户 shell 占位文件。

---

## 5. 副作用

- 目标用户默认 shell 改为 `/bin/bash`。
- 覆盖写入 `~/.bashrc.generated` 以及 tmux / vim / starship / atuin / lazygit 等生成配置。
- `~/.bashrc` 会追加 mise activate 块和 `source ~/.bashrc.generated`。
- `alias cd='z'` 改变交互习惯。
- `carapace` 接管已装 CLI 的参数补全；`mise` / `mise run` 另走 `mise completion bash`。
- 写入一组 git 全局默认（editor、pull、diff、delta pager）。
- 启用 `unattended-upgrades` 与 `en_US.UTF-8`。
