# Chrome + OpenCLI + VNC 一键安装

这套脚本在 Debian/Ubuntu 服务器上安装：

- Google Chrome Stable
- OpenCLI 命令行
- OpenCLI Browser Bridge 扩展
- Xvfb、Openbox 和 x11vnc
- systemd target 与四个服务

Chrome 使用专用非 root 账号和持久 profile。VNC 默认只监听 `127.0.0.1`，远程访问建议走 SSH 隧道。

## 系统要求

- Debian 11 或更新版本
- Ubuntu LTS 20.04、22.04、24.04 或 26.04
- `amd64` / `x86_64`
- systemd 作为 PID 1
- root 或 sudo 权限
- 可访问 apt 源、Google、NodeSource、npm 和 Chrome Web Store

Google Chrome 的 Linux 安装包在本方案中只支持 `amd64`，ARM64 会在修改系统前退出。

## 安装

```bash
sudo bash scripts/chrome-opencli/install.sh
```

脚本会依次询问：

1. 桌面分辨率
2. VNC 监听方式
3. VNC 端口
4. VNC 密码
5. 最终确认

推荐保持默认值：`1920x1080`、`127.0.0.1:5900` 和随机密码。重复安装会保留 Chrome profile、网站登录状态和已有 VNC 密码。

从 GitHub 下载时先保存脚本，再交互执行：

```bash
tmp="$(mktemp)" && \
curl -fsSL https://raw.githubusercontent.com/tiaot33/my-devbox/main/scripts/chrome-opencli/install.sh -o "$tmp" && \
sudo bash "$tmp"
```

不要使用 `curl ... | sudo bash`，管道会占用交互输入。

## VNC 连接

默认只监听本机。在自己的电脑上建立 SSH 隧道：

```bash
ssh -N -L 5900:127.0.0.1:5900 user@server-ip
```

然后让 VNC 客户端连接：

```text
127.0.0.1:5900
```

需要直接连接时，安装期间选择“监听所有网卡”。对外监听必须使用恰好 8 位密码，并使用防火墙或 VPN 限制来源 IP。

## 无人值守安装

必须显式设置 `ASSUME_YES=1`：

```bash
ASSUME_YES=1 sudo -E bash scripts/chrome-opencli/install.sh
```

可覆盖的配置只有：

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `SCREEN_GEOMETRY` | `1920x1080` | 桌面分辨率 |
| `VNC_BIND` | `127.0.0.1` | VNC 监听地址 |
| `VNC_PORT` | `5900` | VNC 端口 |
| `VNC_PASSWORD` | 未设置 | 首次随机生成，重装保留；显式置空表示无密码 |

例如：

```bash
ASSUME_YES=1 \
SCREEN_GEOMETRY=1440x900 \
VNC_BIND=0.0.0.0 \
VNC_PORT=5901 \
VNC_PASSWORD='aB3_9xQ2' \
sudo -E bash scripts/chrome-opencli/install.sh
```

无密码模式只允许 `VNC_BIND=127.0.0.1`：

```bash
ASSUME_YES=1 VNC_PASSWORD= sudo -E bash scripts/chrome-opencli/install.sh
```

## Chrome 扩展与 OpenCLI

脚本通过 `/etc/opt/chrome/policies/managed/chrome-opencli.json` 强制安装 [OpenCLI Browser Bridge](https://chromewebstore.google.com/detail/opencli/ildkmabpimmkaediidaifkhjpohdnifk)。Chrome 会显示“由您的组织管理”，这是预期行为。

通过 VNC 在 Chrome 中登录网站后，可以在服务器终端执行：

```bash
opencli --version
opencli doctor
opencli list
```

OpenCLI 会按需启动本地 daemon，不单独伪装成 systemd 服务。

## 服务管理

安装后创建：

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

持久数据位于：

```text
/var/lib/chrome-opencli/chrome-profile
/var/lib/chrome-opencli/.opencli
/etc/chrome-opencli
```

## 卸载

删除服务和 Chrome 策略，保留 profile、账号和已安装软件：

```bash
sudo bash scripts/chrome-opencli/uninstall.sh
```

删除 profile、配置以及由安装器创建的账号：

```bash
sudo bash scripts/chrome-opencli/uninstall.sh --purge-data
```

同时卸载 Chrome 和 OpenCLI：

```bash
sudo bash scripts/chrome-opencli/uninstall.sh --purge-data --remove-packages
```

`--purge-data` 不可恢复，执行前应备份 `/var/lib/chrome-opencli`。

## 排查与安全

扩展或 Chrome 连接失败：

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

需要注意：

- VNC 直连不提供端到端加密。
- Chrome 托管策略是机器级配置，会影响同机所有 Google Chrome 用户。
- OpenCLI daemon 使用 loopback 端口，不区分同机 Linux 用户；不适合不可信的共享 shell 主机。
- `/var/lib/chrome-opencli` 包含网站登录状态，应按高敏感数据保护。
- 不要禁用 Chrome sandbox。
