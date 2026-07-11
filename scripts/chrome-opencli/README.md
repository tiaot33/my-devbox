# 在服务器上安装 Chrome + OpenCLI + VNC

这套脚本为 Debian/Ubuntu 服务器安装并配置：

- Google Chrome Stable
- OpenCLI 命令行和 OpenCLI Browser Bridge 扩展
- Xvfb、Openbox、x11vnc
- 一组 systemd 服务

Chrome 运行在专用的非 root 账号下，并使用持久化 profile。VNC 默认只监听
`127.0.0.1`，建议通过 SSH 隧道连接。

## 系统要求

- Debian 11 或更高版本，或 Ubuntu LTS 20.04、22.04、24.04、26.04
- `amd64` / `x86_64` 架构
- systemd 作为 PID 1
- root 或 sudo 权限
- 能访问 apt 软件源、Google、NodeSource、npm 和 Chrome Web Store

本方案使用 Google Chrome 官方 `amd64` 安装包。ARM64 系统会在修改系统前退出。

## 安装

在仓库根目录运行：

```bash
sudo bash scripts/chrome-opencli/install.sh
```

安装程序会依次询问桌面分辨率、VNC 监听地址、端口和密码，确认后开始安装。
推荐使用默认配置：

- 分辨率：`1920x1080`
- VNC 地址：`127.0.0.1:5900`
- VNC 密码：首次安装时随机生成

安装完成后，终端会显示 VNC 密码和连接方式。密码也会保存在
`/etc/chrome-opencli/vnc-password.txt`，仅 root 可读。

重复运行安装脚本会重新生成配置并更新 Chrome 和 OpenCLI，同时保留 Chrome
profile、网站登录状态和已有 VNC 密码。

### 直接下载安装

安装脚本地址：

<https://raw.githubusercontent.com/tiaot33/my-devbox/main/scripts/chrome-opencli/install.sh>

下载安装并进入交互配置：

```bash
tmp="$(mktemp)" && \
  wget -qO "$tmp" https://raw.githubusercontent.com/tiaot33/my-devbox/main/scripts/chrome-opencli/install.sh && \
  sudo bash "$tmp"
```

建议先打开上面的链接审阅脚本。不要使用 `wget ... | sudo bash`，因为管道会占用
安装程序需要的交互输入。

## 连接 VNC

默认配置只允许服务器本机连接。在自己的电脑上建立 SSH 隧道：

```bash
ssh -N -L 5900:127.0.0.1:5900 user@server-ip
```

然后让 VNC 客户端连接：

```text
127.0.0.1:5900
```

如果安装时修改了 `VNC_PORT`，请将命令中的两个 `5900` 和客户端端口一并替换。

如需直接连接服务器，可在安装时选择“监听所有网卡”。此时 VNC 密码必须恰好为
8 位，并且必须通过防火墙或 VPN 限制来源 IP。VNC 直连本身不提供端到端加密。

## 无人值守安装

非交互环境必须显式设置 `ASSUME_YES=1`：

```bash
ASSUME_YES=1 sudo -E bash scripts/chrome-opencli/install.sh
```

可通过以下环境变量覆盖配置：

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `SCREEN_GEOMETRY` | `1920x1080` | 桌面分辨率 |
| `VNC_BIND` | `127.0.0.1` | VNC 监听地址 |
| `VNC_PORT` | `5900` | VNC 端口 |
| `VNC_PASSWORD` | 未设置 | 首次随机生成，重复安装时保留；显式置空表示无密码 |

无密码 VNC 只允许监听 `127.0.0.1`：

```bash
ASSUME_YES=1 VNC_PASSWORD= sudo -E bash scripts/chrome-opencli/install.sh
```

## 使用 OpenCLI

安装脚本通过 Chrome 托管策略强制安装
[OpenCLI Browser Bridge](https://chromewebstore.google.com/detail/opencli/ildkmabpimmkaediidaifkhjpohdnifk)。
因此 Chrome 会显示“由您的组织管理”，属于预期行为。

通过 VNC 在 Chrome 中登录目标网站后，可在服务器终端执行：

```bash
opencli --version
opencli doctor
opencli list
```

OpenCLI daemon 由命令行按需启动，不作为独立的 systemd 服务运行。

## 管理服务

安装程序会创建一个 target 和四个服务：

```text
chrome-opencli.target
chrome-opencli-xvfb.service
chrome-opencli-openbox.service
chrome-opencli-browser.service
chrome-opencli-vnc.service
```

常用命令：

```bash
systemctl status chrome-opencli.target
systemctl restart chrome-opencli.target
journalctl -u chrome-opencli-browser -f
journalctl -u chrome-opencli-vnc -f
```

持久化数据和配置位于：

```text
/var/lib/chrome-opencli/chrome-profile
/var/lib/chrome-opencli/.opencli
/etc/chrome-opencli
```

## 故障排查

扩展未连接或 OpenCLI 无法访问 Chrome：

```bash
opencli doctor
systemctl status chrome-opencli-browser.service
journalctl -u chrome-opencli-browser -n 100 --no-pager
```

VNC 无法连接：

```bash
systemctl status chrome-opencli-vnc.service
journalctl -u chrome-opencli-vnc -n 100 --no-pager
```

## 卸载

删除 systemd 服务和 Chrome 托管策略，保留账号、配置、Chrome profile 和已安装
软件：

```bash
sudo bash scripts/chrome-opencli/uninstall.sh
```

同时删除 Chrome profile、配置，以及由安装程序创建的账号和用户组：

```bash
sudo bash scripts/chrome-opencli/uninstall.sh --purge-data
```

`--purge-data` 不可恢复。执行前请备份 `/var/lib/chrome-opencli` 和
`/etc/chrome-opencli`。

两种卸载方式都会保留 Google Chrome 和全局安装的 `opencli` 命令。如需删除，
请使用系统包管理器和 npm 分别卸载。

## 安全说明

- Chrome 托管策略是机器级配置，会影响同一台机器上的所有 Google Chrome 用户。
- OpenCLI daemon 使用 loopback 端口，不隔离同机 Linux 用户，不适合不可信的共享
  shell 主机。
- `/var/lib/chrome-opencli` 包含网站登录状态，应按敏感数据保护。
- 不要禁用 Chrome sandbox。
