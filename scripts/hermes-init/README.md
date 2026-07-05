# hermes-init

Debian / Ubuntu 上的 Hermes 初始化脚本集合。

目录中有两份脚本：

| 脚本 | 职责 |
| --- | --- |
| `hermes-init.sh` | 安装基础维护工具、GitHub CLI、uv、Starship、lazygit、lazyssh、ble.sh，并配置 root 交互 shell |
| `hermes-agent-install.sh` | 安装 Hermes 必需依赖，运行官方安装器，配置 API Server、shell 补全和 `hermes-setup` |

两份脚本都要求以 root 身份运行，可以按需单独执行。

## 适用环境

- 目标系统：Debian / Ubuntu。
- 推荐系统：Ubuntu 26 / Debian 13。
- 运行权限：root。
- 网络要求：
  - 两份脚本都需要访问 APT 源。
  - `hermes-init.sh` 还需要访问 GitHub CLI APT 源、GitHub Release、uv 安装脚本和 Starship 安装脚本。
  - `hermes-agent-install.sh` 还需要访问 Hermes 官方安装脚本，以及官方安装器内部使用的外部资源。

非 Ubuntu 26 / Debian 13 系统不会被强制拦截，脚本只会给出提示。其它 Debian / Ubuntu 版本通常可运行，但结果取决于系统包名和外部安装器兼容性。

## 使用方法

安装外部维护环境：

```bash
bash hermes-init.sh
```

远程安装外部维护环境：

```bash
bash <(curl --proto '=https' --tlsv1.2 -fsSL https://raw.githubusercontent.com/tiaot33/my-devbox/main/scripts/hermes-init/hermes-init.sh)
```

安装 Hermes Agent：

```bash
bash hermes-agent-install.sh
```

远程安装 Hermes Agent：

```bash
bash <(curl --proto '=https' --tlsv1.2 -fsSL https://raw.githubusercontent.com/tiaot33/my-devbox/main/scripts/hermes-init/hermes-agent-install.sh)
```

查看帮助：

```bash
bash hermes-init.sh --help
bash hermes-agent-install.sh --help
```

`hermes-agent-install.sh` 会在运行 Hermes 官方安装器前二次确认。建议先审阅本脚本和官方安装器，再继续安装。

## hermes-init.sh 安装内容

`hermes-init.sh` 面向“偶尔需要人工登录维护”的 root 环境，只做低侵入增强，不安装 Hermes，也不修改 `/root/.hermes/.env`。

APT 包清单：

```text
ca-certificates curl wget gnupg
locales tzdata bash-completion man-db
build-essential pkg-config make gawk
git openssh-client
less tree vim nano tmux htop jq
unzip zip tar xz-utils zstd gzip file
iproute2 dnsutils
ripgrep fzf
shellcheck shfmt
bat fd-find btop
```

第三方工具：

| 工具 | 安装方式 | 失败处理 |
| --- | --- | --- |
| `gh` | GitHub CLI 官方 APT 源 | 记录到 summary，不阻断后续步骤 |
| `uv` / `uvx` | `https://astral.sh/uv/install.sh`，安装到 `/usr/local/bin` | 记录到 summary，不阻断后续步骤 |
| `starship` | `https://starship.rs/install.sh`，安装到 `/usr/local/bin` | 记录到 summary，不阻断后续步骤 |
| `lazygit` | 从 `jesseduffield/lazygit` 最新 GitHub Release 下载二进制 | 记录到 summary，不阻断后续步骤 |
| `lazyssh` | 从 `Adembc/lazyssh` 最新 GitHub Release 下载二进制 | 记录到 summary，不阻断后续步骤 |
| `ble.sh` | clone `akinomyoga/ble.sh` 后 `make install PREFIX=/root/.local` | 记录到 summary，不阻断后续步骤 |

基础 APT 工具安装失败会直接退出，因为后续步骤依赖这些基础能力。

## root shell 配置

`hermes-init.sh` 会写入 `/etc/profile.d/hermes-shell.sh`，只对 root 的交互 bash 生效：

- 非 root 用户不生效。
- 非交互 shell 不生效。
- 非 bash shell 不生效。
- 设置 `LANG`、`PATH`、`EDITOR`、`VISUAL`、`PAGER`、`LESS`、`BAT_PAGER`。
- 加载 `/etc/bash_completion`。
- 加载 fzf 的 bash key binding 和 completion。
- 检测到 ble.sh 时加载 ble.sh。
- 检测到 Starship 时启用 `starship init bash`。

脚本只添加低风险 alias：

```bash
alias l='ls -lah'
alias ll='ls -alF'
alias la='ls -A'
alias path='printf "%s\n" ${PATH//:/ }'
alias bat='batcat'   # 仅当 batcat 存在
alias fd='fdfind'    # 仅当 fdfind 存在
alias rgrep='rg'     # 仅当 rg 存在
```

脚本不会重写 `ls`、`cd`、`rm`、`cp`、`mv`、`top`、`vim` 等常用命令，也不会接管 shell history。

## root dotfiles

`hermes-init.sh` 会写入：

| 文件 | 作用 |
| --- | --- |
| `/root/.inputrc` | readline 补全、大小写忽略、历史搜索 |
| `/root/.vimrc` | Vim 基础编辑设置 |
| `/root/.tmux.conf` | tmux 鼠标、历史长度、vi mode 和常用分屏绑定 |
| `/root/.blerc` | ble.sh 自动补全和菜单样式 |

这些文件会被脚本直接覆盖。它们只面向当前 root 维护体验，不是完整开发机 dotfiles。

## Locale

`hermes-init.sh` 会尝试启用并生成 `en_US.UTF-8`：

- 如 `/etc/locale.gen` 中存在被注释的 `en_US.UTF-8 UTF-8`，会取消注释。
- 运行 `locale-gen en_US.UTF-8`。
- 运行 `update-locale LANG=en_US.UTF-8`。

这样可以减少远程 shell、编辑器和 CLI 工具的 locale 警告。

## GitHub CLI

`hermes-init.sh` 通过 GitHub CLI 官方 APT 源安装 `gh`：

1. 创建 `/etc/apt/keyrings`。
2. 下载 key 到 `/etc/apt/keyrings/githubcli-archive-keyring.gpg`。
3. 写入 `/etc/apt/sources.list.d/github-cli.list`。
4. 执行 `apt-get update`。
5. 安装 `gh`。

如果检测到系统已有 `gh`，脚本会跳过安装，不改动已有命令。

## uv 和 Starship

`uv` 安装命令等价于：

```bash
UV_INSTALL_DIR=/usr/local/bin UV_NO_MODIFY_PATH=1 sh "$tmp"
```

`Starship` 安装命令等价于：

```bash
sh "$tmp" -y -b /usr/local/bin
```

脚本禁止 uv 安装器修改 shell profile，Starship 也只在 `/etc/profile.d/hermes-shell.sh` 中对 root 交互 bash 启用。

## hermes-agent-install.sh 安装流程

`hermes-agent-install.sh` 的执行流程：

1. 检查参数，只接受 `-h` / `--help`。
2. 读取 `/etc/os-release`，对非推荐系统给出提示。
3. 检查当前用户是否为 root。
4. 交互式配置 API Server host、port，以及是否跳过浏览器安装。
5. 执行 `apt-get update`。
6. 安装 Hermes 必需依赖。
7. 创建并保护 `/root/.hermes`。
8. 下载 Hermes 官方安装器。
9. 确认后执行官方安装器，并传入 `--skip-setup --hermes-home /root/.hermes`。
10. 如果选择跳过浏览器安装，额外传入 `--skip-browser`。
11. 解析实际 `hermes` 命令路径。
12. 写入 Git system `safe.directory`，兼容 root 下的 Hermes 仓库。
13. 生成 bash / zsh / fish 静态补全文件。
14. 更新 `/root/.hermes/.env` 中的 API Server 配置。
15. 创建 `/usr/bin/hermes-setup`。
16. 写入 root 登录提示。
17. 清理 APT 缓存。

Hermes 官方安装器失败时，脚本会打印 summary 并退出。

## Hermes 必需依赖

`hermes-agent-install.sh` 显式安装以下 APT 包：

```text
ca-certificates curl wget git openssh-client
openssl sed mawk gawk xz-utils
bash-completion
```

说明：

- `curl` / `wget`：下载外部资源。
- `git` / `openssh-client`：供官方安装器拉取或更新 Hermes 仓库。
- `openssl`：生成 `API_SERVER_KEY`。
- `sed` / `mawk` / `gawk`：读取和更新 `.env`。
- `xz-utils`：支持官方安装器解压 `.tar.xz` 运行时包。
- `bash-completion`：加载 `/etc/bash_completion.d/hermes`。

Python、Node.js、uv、ffmpeg、Playwright / Chromium 相关内容由 Hermes 官方安装器处理，本脚本不复制官方安装器内部逻辑。

## 交互配置

`hermes-agent-install.sh` 启动后会询问：

| 配置项 | 可选值 / 默认值 | 写入位置 |
| --- | --- | --- |
| API Server 监听地址 | `1) 127.0.0.1`，`2) 0.0.0.0`；默认 `1` | `/root/.hermes/.env` |
| API Server 端口 | 默认 `8642`，范围 `1-65535` | `/root/.hermes/.env` |
| 跳过浏览器安装 | 默认 `N` | 选择 `y` 时传给官方安装器 |

`.env` 更新规则：

- `API_SERVER_ENABLED=true`。
- `API_SERVER_HOST` 使用交互选择值。
- `API_SERVER_PORT` 使用交互输入值。
- `API_SERVER_KEY` 首次运行自动生成。
- 重跑脚本会复用已有 `API_SERVER_KEY`。
- `.env` 中其它键会保留。
- `/root/.hermes/.env` 权限会设置为 `600`。

选择 `0.0.0.0` 会让 API Server 监听所有网卡。是否能被外部访问，还取决于防火墙、云安全组和 Hermes 自身启动方式。

## Hermes 安装布局

新 root 安装默认遵循官方布局：

| 类型 | 路径 |
| --- | --- |
| Hermes 代码目录 | `/usr/local/lib/hermes-agent` |
| `hermes` 命令 | `/usr/local/bin/hermes` |
| Hermes 数据目录 | `/root/.hermes` |

如果官方安装器检测到既有用户级安装，可能沿用旧布局：

| 类型 | 路径 |
| --- | --- |
| Hermes 代码目录 | `/root/.hermes/hermes-agent` |
| `hermes` 命令 | `/root/.local/bin/hermes` |
| Hermes 数据目录 | `/root/.hermes` |

脚本会根据安装后的实际命令路径生成 `hermes-setup`。

## 生成或修改的文件

`hermes-init.sh` 可能生成或修改：

| 文件 | 作用 |
| --- | --- |
| `/etc/profile.d/hermes-shell.sh` | root 交互 bash 增强 |
| `/etc/locale.gen` | 启用 `en_US.UTF-8 UTF-8` |
| `/etc/default/locale` | 设置 `LANG=en_US.UTF-8` |
| `/root/.inputrc` | readline 配置 |
| `/root/.vimrc` | Vim 配置 |
| `/root/.tmux.conf` | tmux 配置 |
| `/root/.blerc` | ble.sh 配置 |
| `/etc/apt/keyrings/githubcli-archive-keyring.gpg` | GitHub CLI APT 源 key |
| `/etc/apt/sources.list.d/github-cli.list` | GitHub CLI APT 源 |
| `/usr/local/bin/uv` | uv 命令 |
| `/usr/local/bin/uvx` | uvx 命令 |
| `/usr/local/bin/starship` | Starship 命令 |
| `/usr/local/bin/lazygit` | lazygit 命令 |
| `/usr/local/bin/lazyssh` | lazyssh 命令 |
| `/root/.local/share/blesh/ble.sh` | ble.sh 入口 |
| `/root/.local/src/ble.sh` | ble.sh 源码目录 |

`hermes-agent-install.sh` 可能生成或修改：

| 文件 | 作用 |
| --- | --- |
| `/root/.hermes` | Hermes 数据目录 |
| `/root/.hermes/.env` | API Server 配置 |
| `/usr/bin/hermes-setup` | 重新运行 `hermes setup` 的辅助命令 |
| `/etc/profile.d/hermes-hint.sh` | root 登录提示 |
| `/etc/bash_completion.d/hermes` | Hermes bash 补全 |
| `/usr/local/share/zsh/site-functions/_hermes` | Hermes zsh 补全 |
| `/usr/share/fish/vendor_completions.d/hermes.fish` | Hermes fish 补全 |
| Git system config | 添加 Hermes 仓库 `safe.directory` |

## 安装后使用

配置模型 provider 和 gateway：

```bash
hermes-setup
```

查看 Hermes 自检：

```bash
hermes doctor
```

查看 API Server 配置：

```bash
grep '^API_SERVER_' /root/.hermes/.env
```

## 幂等性

- 已存在 `gh`、`uv`、`starship`、`lazygit`、`lazyssh` 时，`hermes-init.sh` 会跳过对应安装。
- 已存在 `/root/.local/share/blesh/ble.sh` 时，`hermes-init.sh` 会跳过 ble.sh 安装。
- root dotfiles、profile、completion、`hermes-setup` 会被重新写入。
- `hermes-agent-install.sh` 重跑时会保留已有 `API_SERVER_KEY`，但会更新 API Server host / port / enabled。
- Hermes Agent 是否复用既有安装由官方安装器决定。

## 边界与风险

- `hermes-agent-install.sh` 会运行外部官方安装器：`https://hermes-agent.nousresearch.com/install.sh`。
- API Server 选择 `0.0.0.0` 时，需要自行确认网络暴露面和访问控制。
- `hermes-init.sh` 会覆盖 `/root/.inputrc`、`/root/.vimrc`、`/root/.tmux.conf`、`/root/.blerc`。
- `hermes-init.sh` 不创建 `bat -> batcat` 或 `fd -> fdfind` 软链接，只在交互 shell 中添加 alias。
- `hermes-agent-install.sh` 不创建 systemd 服务；服务安装和管理交给 Hermes 官方命令或官方安装器。
- shell 补全依赖当前 `hermes completion` 输出；某个 shell 补全生成失败只会记录到 summary，不阻断主安装。
- 两份脚本都会执行 `apt-get autoremove` 和 `apt-get autoclean`。
- 两份脚本都不安装 `eza`、`zoxide`、Atuin、direnv、duf、ncdu、fastfetch、Nerd Font 或完整 devbox dotfiles。
