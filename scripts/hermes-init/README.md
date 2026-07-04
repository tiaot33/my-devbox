# hermes-init

Debian / Ubuntu 上的 Hermes 初始化脚本。

支持 Ubuntu 26 / Debian 13，需要以 root 身份运行。脚本会安装 Hermes 运行所需依赖、命令行工具、Node.js、uv、Python 工具链、Hermes Agent，并配置 API Server、Dashboard systemd 服务和 `hermes-setup` 命令。

## 使用方法

```bash
bash hermes-init.sh
```

远程执行：

```bash
bash <(curl --proto '=https' --tlsv1.2 -fsSL https://raw.githubusercontent.com/tiaot33/my-devbox/main/scripts/hermes-init/hermes-init.sh)
```

## 安装内容

Hermes 必需依赖：

```text
ca-certificates curl git openssh-client procps
gcc g++ make cmake libffi-dev xz-utils
openssl
```

命令行工具：

```text
jq wget unzip zip tar gzip bzip2 file less
vim nano
iproute2 iputils-ping dnsutils net-tools
rsync
```

搜索、文件查找和测速工具：

```text
ripgrep fd-find hyperfine
```

其中 `fd-find` 在 Debian / Ubuntu 上的命令名是 `fdfind`，脚本会在 `/root/.local/bin/fd` 创建兼容软链。

Hermes Agent 相关安装和配置：

- 直接以 root 运行，不创建 `hermes` 用户。
- Hermes home 固定为 `/root/.hermes`。
- Node.js 通过交互式对话选择版本，支持 `26` / `lts` / `latest`，默认 `26`；使用官方 Node.js Linux 二进制包安装到 `/usr/local/lib/nodejs`，并把 `node` / `npm` / `npx` / `corepack` 链接到 `/usr/local/bin`。
- 默认安装 `uv`。
- 安装 Hermes Agent 时会确保系统存在 `python3`。
- Python 通过交互式对话选择版本，默认 `3.14`；使用 `uv` 安装，同时默认安装 `ruff`。
- 写入 `/etc/default/hermes`。
- 下载并执行 `https://hermes-agent.nousresearch.com/install.sh`，执行前要求确认。
- API Server 通过交互式对话配置监听地址，默认 `127.0.0.1:8642`。
- Dashboard 通过交互式对话配置监听地址，默认 `127.0.0.1:9119`，由 `hermes-dashboard.service` 管理。
- 创建 `/usr/bin/hermes-setup`，用于后续配置 model provider 和 gateway。

## 交互式配置项

脚本启动后会依次询问 4 个配置项，直接回车使用默认值。

| 配置项 | 默认 | 作用 |
| --- | --- | --- |
| API Server 监听地址 | `127.0.0.1:8642` | 写入 `/root/.hermes/.env` |
| Dashboard 监听地址 | `127.0.0.1:9119` | 写入 `hermes-dashboard.service` |
| Python 版本 | `3.14` | 传给 `uv python install` |
| Node.js 版本 | `26` | 支持 `26` / `lts` / `latest` |
