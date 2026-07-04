# hermes-init

Debian / Ubuntu 上的 Hermes Agent 初始化脚本。

脚本面向 root 运行场景。它只安装运行官方 Hermes 安装器所需的最小系统依赖，然后调用官方安装器完成 Hermes Agent、Python、Node.js、uv、ripgrep、ffmpeg、虚拟环境和 `hermes` 命令配置。本脚本额外负责 API Server 配置、Dashboard systemd 服务和 `hermes-setup` 辅助命令。

## 适用环境

- 目标系统：Ubuntu / Debian。
- 推荐系统：Ubuntu 26 / Debian 13。
- 运行权限：必须以 root 身份运行。
- 网络要求：需要访问 APT 源、GitHub、Node.js、Python / PyPI、Hermes 官方安装脚本等外部地址。

## 使用方法

本地运行：

```bash
bash hermes-init.sh
```

远程执行：

```bash
bash <(curl --proto '=https' --tlsv1.2 -fsSL https://raw.githubusercontent.com/tiaot33/my-devbox/main/scripts/hermes-init/hermes-init.sh)
```

脚本会在执行 Hermes 官方安装器前提示确认。建议先审阅脚本和官方安装器内容，再继续安装。

## 安装流程

1. 检查当前用户是否为 root。
2. 读取 `/etc/os-release`，对非推荐系统给出提示。
3. 交互式配置 API Server 和 Dashboard 的监听地址、端口。
4. 执行 `apt-get update`。
5. 安装最小系统依赖。
6. 写入 `/etc/default/hermes`。
7. 下载并执行 `https://hermes-agent.nousresearch.com/install.sh`。
8. 根据官方安装器实际产物解析 `hermes` 命令路径。
9. 更新 `/root/.hermes/.env` 中的 `API_SERVER_*` 配置。
10. 创建并启动 `hermes-dashboard.service`。
11. 创建 `/usr/bin/hermes-setup`，用于后续配置 model provider 和 gateway。
12. 清理 APT 缓存。

## 最小系统依赖

脚本只显式安装以下 APT 包：

```text
ca-certificates curl git openssh-client
openssl sed mawk xz-utils
```

说明：

- `curl`：下载官方安装器。
- `git` / `openssh-client`：供官方安装器克隆或更新 Hermes 仓库。
- `openssl`：生成 API Server key。
- `sed` / `mawk`：脚本更新 `.env` 配置时使用。
- `xz-utils`：支持官方安装器解压 `.tar.xz` 运行时包。

Python、Node.js、uv、ripgrep、ffmpeg、Playwright / Chromium 相关内容交给 Hermes 官方安装器处理，本脚本不再手工安装。

## Hermes 安装布局

新 root 安装默认遵循官方布局：

| 类型 | 路径 |
| --- | --- |
| Hermes 代码目录 | `/usr/local/lib/hermes-agent` |
| `hermes` 命令 | `/usr/local/bin/hermes` |
| Hermes 数据目录 | `/root/.hermes` |

如果官方安装器检测到既有 `/root/.hermes/hermes-agent` 用户级安装，可能会沿用旧布局。脚本会在安装后解析实际 `hermes` 路径，并据此写入 Dashboard service 和 `hermes-setup`。

## 交互式配置项

脚本启动后会询问以下配置项，直接回车使用默认值。

| 配置项 | 默认 | 写入位置 |
| --- | --- | --- |
| API Server 监听地址 | `127.0.0.1` | `/root/.hermes/.env` |
| API Server 端口 | `8642` | `/root/.hermes/.env` |
| Dashboard 监听地址 | `127.0.0.1` | `hermes-dashboard.service` |
| Dashboard 端口 | `9119` | `hermes-dashboard.service` |

`API_SERVER_KEY` 首次运行时自动生成；重跑脚本会复用已有 key，只更新 API Server host / port / enabled 配置，不覆盖 `.env` 中的其它 Hermes 配置。

## 生成的文件

| 文件 | 作用 |
| --- | --- |
| `/etc/default/hermes` | systemd 服务环境变量 |
| `/root/.hermes/.env` | API Server 配置；保留已有其它配置 |
| `/etc/systemd/system/hermes-dashboard.service` | Dashboard systemd 服务 |
| `/usr/bin/hermes-setup` | 重新运行 `hermes setup` 的辅助命令 |
| `/etc/profile.d/hermes-hint.sh` | root 登录提示 |

## 安装后

配置模型 provider 和 gateway：

```bash
hermes-setup
```

查看 Dashboard 服务状态：

```bash
systemctl status hermes-dashboard
```

查看 Hermes 自检：

```bash
hermes doctor
```

## 边界与风险

- 本脚本会运行 Hermes 官方安装器，但不会接管官方安装器内部的 Python、Node.js、uv、浏览器依赖安装策略。
- 本脚本会创建 Dashboard systemd 服务；这部分是本脚本额外提供的，不是官方安装器默认行为。
- 如果机器上已有 legacy root-user 安装，官方安装器可能沿用 `/root/.hermes/hermes-agent`，脚本会兼容该路径，但新环境建议使用官方 root 布局。
- 本脚本会更新 `/root/.hermes/.env` 中 `API_SERVER_*` 键；其它键会保留。
