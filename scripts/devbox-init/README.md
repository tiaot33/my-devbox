# devbox-init

Debian / Ubuntu 无头（headless）开发环境一键引导脚本。

一条命令把一台干净的服务器或容器，初始化为带有现代命令行工具、多语言工具链与统一 dotfiles 的开发机。

---

## 1. 适用环境

- **目标系统**：Ubuntu / Debian（读取 `/etc/os-release` 判定；其它发行版仅尽力而为并告警）。
- **权限**：以 root 运行，或以普通用户运行但具备 `sudo`（二者皆可，脚本自动适配）。
- **网络**：需要访问外网，过程中会从多个官方源下载安装脚本与软件包。

---

## 2. 使用方法

```bash
bash devbox-init.sh
# 或
sudo bash devbox-init.sh
```

完成后开启新的 SSH 会话，或执行 `source ~/.bashrc` 生效。

### 单独安装语言工具链

只想安装或刷新语言工具链（Node / Python / Go / Bun / Deno），而无需运行整套初始化时，可使用自包含的 `devbox-lang.sh`——它与主脚本互不依赖：

```bash
bash devbox-lang.sh
# 或
sudo bash devbox-lang.sh
```

默认会先进入交互式选择菜单，可选择安装 Node.js / Python / Go / Bun / Deno 中的一个或多个语言环境。若要在脚本、CI 或远程初始化命令中跳过交互并直接安装全部语言环境，使用：

```bash
bash devbox-lang.sh --all
# 或
sudo bash devbox-lang.sh --all
```

各语言可用下方 `INSTALL_*` 开关单独控制。例如只安装 Go：

```bash
INSTALL_NODE=0 INSTALL_PYTHON=0 INSTALL_BUN=0 INSTALL_DENO=0 bash devbox-lang.sh
```

> 该脚本把语言工具链装入目标用户家目录，并为已安装的工具写入 bash 自动补全（`uv`/`uvx`、`fnm`、`mise`、`deno`、`npm`、`bun`，追加到 `~/.bashrc` 的 `devbox-lang: shell completions` 标记块，重跑会刷新；未安装者自动跳过）。补全块会按需把相关 bin 目录注入 `PATH`，但除此之外不写入其他 dotfiles。若未运行过 `devbox-init.sh`，安装后仍建议自行确保相应目录（如 `~/.local/bin`、`~/.local/share/fnm`、`~/go/bin`、`~/.bun/bin`、`~/.deno/bin`）已在 `PATH` 中，或运行 `devbox-init.sh` 获取完整 shell 集成（`mise`/`npm` 补全亦依赖其中的版本管理器初始化）。

### 环境变量开关

所有开关默认开启（`1`），设为 `0` 即跳过对应步骤：

| 变量 | 默认 | 适用脚本 | 作用 |
| --- | --- | --- | --- |
| `INSTALL_NODE_TOOLS` | `1` | 两者 | Node 全局工具（pnpm、yarn、typescript 等） |
| `INSTALL_GO_TOOLS` | `1` | 两者 | Go 工具（gopls、dlv、lazygit 等） |
| `INSTALL_NODE` | `1` | `devbox-lang.sh` | fnm + Node.js LTS |
| `INSTALL_PYTHON` | `1` | `devbox-lang.sh` | uv + Python 及其工具 |
| `INSTALL_GO` | `1` | `devbox-lang.sh` | mise + Go latest |
| `INSTALL_BUN` | `1` | `devbox-lang.sh` | Bun |
| `INSTALL_DENO` | `1` | `devbox-lang.sh` | Deno |

`INSTALL_NODE_TOOLS` / `INSTALL_GO_TOOLS` 两脚本通用；`INSTALL_NODE` 等语言级总开关仅 `devbox-lang.sh` 识别（主脚本会忽略它们）。

示例（主脚本跳过 Node / Go 附加工具）：

```bash
INSTALL_NODE_TOOLS=0 INSTALL_GO_TOOLS=0 bash devbox-init.sh
```

---

## 3. 脚本做了什么（执行流程）

脚本按以下顺序分阶段执行。各语言工具链均以**目标用户**身份（而非 root）安装，确保归属正确。

1. **环境准备**
   - 启用严格模式 `set -uo pipefail`；创建一次性私有临时目录（`mktemp -d`），脚本退出时由 `trap` 统一清理。
   - 设置非交互模式（`DEBIAN_FRONTEND`、`NEEDRESTART_MODE`、`APT_LISTCHANGES_FRONTEND`），避免安装中途弹窗阻塞。
   - 检测操作系统、root/sudo 权限，解析目标用户（优先 `SUDO_USER`）及其家目录、用户组。

2. **APT 基础包**
   - 执行 `apt-get update`。
   - 安装核心包（必装）与可选包（失败仅告警、不中断）。

3. **Locale**：启用并生成 `en_US.UTF-8`。

4. **第三方 APT 仓库**：下载并校验 GPG key（失败则告警跳过）后添加源，随后安装：
   - GitHub CLI（`gh`）
   - `eza`（现代 `ls` 替代）

5. **用户目录与兼容软链**
   - 创建 `~/.local/bin`、`~/.local/src`、`~/.local/share/fonts`、`~/.config`、`~/.cache`、`~/go/bin`。
   - 建立 `bat → batcat`、`fd → fdfind` 软链（消除 Debian 的命名差异）。

6. **逐个安装工具链与版本管理器**（详见第 4 节）：Starship → ComicShannsMono Nerd Font → fnm/Node → uv/Python → mise/Go → SDKMAN/Java → Bun、Deno、zoxide、Atuin、ble.sh。各安装器统一「下载到文件 → 校验非空 → 执行」，失败告警而非静默跳过。

7. **写入 dotfiles**：生成统一的 shell、提示符、编辑器、Git 等配置文件（详见第 5 节）。

8. **Git 全局配置**与**默认 shell**：将默认 shell 设为 `/bin/bash`。

9. **清理**：`apt-get autoremove / autoclean`；临时文件已集中在私有目录，由退出时的 `trap` 统一清理。

---

## 4. 最终产物：安装的工具

### 4.1 核心命令行包（必装）

> 构建、网络、压缩、编辑、版本控制等基础能力。

`build-essential` `pkg-config` `make` `gawk` · `git` `openssh-client` `rsync` ·
`curl` `wget` `gnupg` · `vim` `nano` `tmux` `htop` `jq` ·
`unzip` `zip` `tar` `xz-utils` `zstd` `gzip` `bzip2` `file` `less` ·
`iproute2` `iputils-ping` `dnsutils` `net-tools` · `locales` `tzdata` `bash-completion` `man-db` `fontconfig`

### 4.2 可选命令行包（缺失仅告警）

> 现代 CLI 工具与调试 / 网络分析套件。

- **现代替代品**：`eza` `bat` `fd-find` `ripgrep` `fzf` `btop` `duf` `ncdu` `tldr` `hyperfine` `git-delta` `zoxide`(下文) `silversearcher-ag`
- **编译 / 调试**：`cmake` `ninja-build` `clang` `clangd` `clang-format` `lldb` `gdb` `valgrind`
- **系统 / 网络诊断**：`strace` `ltrace` `lsof` `sysstat` `iotop` `iftop` `mtr-tiny` `traceroute` `tcpdump` `nmap` `netcat-openbsd` `socat` `whois`
- **脚本 / 文本**：`shellcheck` `shfmt` `direnv` `entr` `httpie` `yq` `xmlstarlet` `jq`
- **其它**：`neovim` `git-lfs` `tree` `7zip` `p7zip-full`

### 4.3 语言工具链与版本管理器

> 下列语言工具链亦可用 `devbox-lang.sh` 脱离整套初始化单独安装或刷新（见第 2 节「单独安装语言工具链」）。

| 语言 / 平台 | 安装方式 | 版本 | 附带工具 |
| --- | --- | --- | --- |
| **Node.js** | `fnm` | LTS（默认） | `pnpm` `yarn`（corepack）、`typescript` `tsx` `eslint` `prettier` `nodemon` `zx` `npm-check-updates`；可用 `INSTALL_NODE_TOOLS=0` 跳过附加工具 |
| **Python** | `uv` | 3.14 → 回退 3.13 → 回退默认版本 | `ruff` `black` `mypy` `ipython` `pre-commit` `poetry` `httpie` |
| **Go** | `mise` | latest | `gopls` `goimports` `dlv` `staticcheck` `air` `lazygit`；可用 `INSTALL_GO_TOOLS=0` 跳过附加工具 |
| **Java** | `SDKMAN` | 默认稳定版 | `maven` `gradle` |
| **Bun / Deno** | 官方脚本 | latest | — |

### 4.4 其它独立工具

- **Starship**：跨 shell 提示符（装至 `/usr/local/bin`），生成 `nerd-font-symbols` 预设配置到 `~/.config/starship.toml`。
- **ComicShannsMono Nerd Font**：下载并解压到 `~/.local/share/fonts`，随后刷新字体缓存。
- **Atuin**：shell 历史记录数据库与搜索。
- **ble.sh**：Bash 行编辑增强（语法高亮、自动补全；源码编译安装至 `~/.local`）。

---

## 5. 最终产物：生成的配置文件

所有 dotfiles 归属目标用户。`~/.bashrc.generated` 由脚本生成，**重跑会覆盖**；它通过 `~/.bashrc` 中一行 `source` 引入（幂等追加，不重复）。

| 文件 | 内容要点 |
| --- | --- |
| `~/.bashrc.generated` | PATH、`EDITOR`/`PAGER`、大容量去重历史、各版本管理器初始化（fnm/mise/SDKMAN/direnv）、别名与函数、fzf/zoxide/atuin/starship/ble.sh 集成 |
| `~/.config/starship.toml` | Starship 官方 `nerd-font-symbols` 预设 |
| `~/.tmux.conf` | 鼠标支持、`vi` 模式、`|`/`-` 分屏、`prefix r` 重载 |
| `~/.vimrc` + `~/.config/nvim/init.vim` | 行号、搜索、缩进、语法高亮等基础设置 |
| `~/.inputrc` | Readline：大小写不敏感补全、历史前缀搜索 |
| `~/.editorconfig` | 统一缩进（默认 2 空格，Go/Py/Rust/Java 为 4，Makefile 用 Tab） |
| `~/.gitignore_global` | 全局忽略（`.DS_Store`、`.env`、`node_modules/`、`target/` 等） |
| `~/.blerc` | ble.sh 自动补全 / 菜单偏好 |
| `~/.config/atuin/config.toml` | Atuin 历史搜索界面与行为 |

### Shell 体验增强（来自 `~/.bashrc.generated`）

- **别名**：`ls/l/ll/la/lt`（eza）、`cat`→`bat`、`top`→`btop`、`df`→`duf`、`cd`→`z`（zoxide）、`vim`→`nvim`、`d`/`dc`（docker）、`k`（kubectl）等。
- **函数**：`mkcd` / `take`、`serve`（HTTP 服务）、`please`（sudo 上条命令）、`extract`（万能解压）。

### Git 全局默认

`init.defaultBranch=main` · `pull.rebase=false` · `fetch.prune=true` · `rerere.enabled=true` ·
`diff.algorithm=histogram` · `merge.conflictstyle=zdiff3` · `core.editor=nvim` ·
`core.excludesfile=~/.gitignore_global` · 若装有 `delta` 则配置为 pager 并启用 side-by-side。

---

## 6. 系统级变更一览

- 启用 `en_US.UTF-8` locale。
- 目标用户默认 shell 改为 `/bin/bash`。
- 新增 APT 源：GitHub CLI、eza。
- 新建用户目录、字体目录与 `bat`/`fd` 兼容软链。
- 安装 ComicShannsMono Nerd Font 到目标用户字体目录。

---

## 7. 设计特性与注意事项

- **幂等可重跑**：APT 源、`~/.bashrc` 引入行均做存在性检查；可选包已装则跳过。重复执行安全（会刷新各工具链至最新）。
- **下载健壮性**：所有远程安装器与第三方 APT key 均采用「下载到文件 → 校验非空 → 执行」模式，并启用 TLS 锁定（`--proto '=https' --tlsv1.2`）与 `--retry` 重试；下载或安装失败会输出 `[warn]` 而非被静默吞掉，便于定位哪一步未装上。
- **临时文件安全**：运行期间的临时文件集中存放于一次性私有目录（`mktemp -d`），退出时由 `trap` 统一清理；不使用固定 `/tmp` 文件名，避免符号链接抢占与残留。
- **容错优先**：可选包、第三方工具与各语言工具链安装失败仅告警（`[warn]`），不中断整体流程；核心包失败才会让对应步骤报错。
- **权限正确**：root 负责 APT 与系统配置，语言工具链以目标用户身份安装，避免家目录出现 root 文件。
- **生效方式**：脚本结束后需 `source ~/.bashrc` 或重开会话。
- **可定制**：`~/.bashrc.generated` 可直接编辑，但重跑脚本会覆盖——长期自定义建议另置文件并在 `~/.bashrc` 中单独引入。

### 副作用较大的默认行为

- **默认 shell**：脚本会把目标用户默认 shell 改为 `/bin/bash`。如果用户原本使用 zsh/fish，这会改变登录后的默认环境。
- **生成配置文件**：脚本会覆盖 `~/.bashrc.generated`、`~/.tmux.conf`、`~/.vimrc`、`~/.inputrc`、`~/.editorconfig`、`~/.gitignore_global`、`~/.blerc`、`~/.config/atuin/config.toml` 等生成文件。
- **Bash 行为变化**：`~/.bashrc.generated` 会设置大量 alias、函数、PATH、版本管理器初始化、Starship、Atuin、zoxide 和 ble.sh；其中 `alias cd='z'` 会改变 `cd` 的交互习惯。
- **Git 全局配置**：脚本会设置全局 editor、pull 策略、diff 算法、merge conflict 样式、pager 等，可能覆盖用户原有偏好。
- **第三方执行脚本**：Starship、fnm、uv、mise、SDKMAN、Bun、Deno、zoxide、Atuin 均来自远程安装脚本。脚本会先下载到临时文件并校验非空，再执行。
- **体积和耗时**：Java、Maven、Gradle、Node LTS、Python、Go、Bun、Deno 以及各类附加工具会占用明显磁盘空间，并增加初始化耗时。
- **网络诊断工具**：`tcpdump`、`nmap`、`netcat-openbsd`、`socat` 等工具在部分公司环境可能触发安全审计，应按环境要求使用。
