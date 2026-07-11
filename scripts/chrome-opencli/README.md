# Chrome + OpenCLI + VNC 一键安装

这套脚本用于在 Debian 或 Ubuntu 服务器上安装 Google Chrome、OpenCLI 命令行和 OpenCLI Browser Bridge 扩展，并通过 VNC 提供可见的远程桌面。Chrome、虚拟显示器、窗口管理器和 VNC 都纳入 systemd 管理。

OpenCLI 扩展使用 Chrome Web Store 官方版本：

<https://chromewebstore.google.com/detail/opencli/ildkmabpimmkaediidaifkhjpohdnifk>

## 安装内容

- Google Chrome Stable
- Node.js 20 或更高版本；系统版本过低时默认安装 Node.js 22
- 全局命令 `opencli`，npm 包为 `@jackwener/opencli`
- OpenCLI Browser Bridge 扩展
- Xvfb 虚拟显示器
- Openbox 窗口管理器
- x11vnc 远程桌面
- 常用中英文字体和 emoji 字体
- 专用非 root 用户 `chrome-opencli`
- 持久 Chrome profile 和登录状态
- systemd target 与四个服务单元

Chrome 使用有头模式运行在 Xvfb 中，不使用 headless。OpenCLI 的 Manifest V3 扩展在有头 Chrome 中更可靠，也可以直接通过 VNC 查看和操作浏览器。

## 系统要求

- Debian 11 或更新版本，或 Ubuntu LTS 20.04、22.04、24.04、26.04；不自动接受已停止维护的 Ubuntu 短周期版本以及 Kali、Mint 等衍生发行版
- `amd64` / `x86_64` 架构
- systemd 正在作为 PID 1 运行
- root 或 sudo 权限
- 安装期间可以访问 apt 源、Google、NodeSource 和 npm registry
- 服务器只包含可信的本机账号；OpenCLI daemon 的 loopback HTTP 接口没有按 Linux UID 隔离

如果系统已经存在名为 `chrome-opencli` 的用户或组，安装器只会在 home、主组、nologin shell、系统 UID/GID、附加组和 UID 唯一性全部符合隔离要求时复用；否则会在修改服务前退出。

脚本固定校验 NodeSource 仓库签名主密钥指纹 `6F71F525282841EEDAF851B42F59B5F99B1BE0B4`。NodeSource 将来正式轮换密钥时，需要先核对官方公告并更新脚本，不能直接跳过校验。

Google 官方 Linux Chrome 安装包目前只覆盖这里使用的 `amd64` 架构。ARM64 机器会在修改系统前直接退出，不会自动换成 Chromium。

## 交互式安装

本地执行：

```bash
sudo bash scripts/chrome-opencli/install.sh
```

脚本启动后会依次询问：

1. 远程桌面分辨率
2. VNC 访问方式
3. VNC 端口
4. VNC 密码方式
5. 最终配置确认

推荐选项是：

- `1920x1080`
- VNC 仅监听 `127.0.0.1`
- 端口 `5900`
- 首次安装随机生成密码；重复安装保留原密码
- 保持 Chrome sandbox 开启

### 从 GitHub 下载后执行

先下载到临时文件，再交互执行：

```bash
tmp="$(mktemp)" && \
curl -fsSL https://raw.githubusercontent.com/tiaot33/my-devbox/main/scripts/chrome-opencli/install.sh -o "$tmp" && \
sudo bash "$tmp"
```

不要使用 `curl ... | sudo bash`。管道会占用标准输入，脚本无法读取交互选项，也不便于执行前审阅内容。

## VNC 连接

### 推荐：SSH 隧道

安装时选择“仅本机监听”。脚本完成后会给出类似命令：

```bash
ssh -N -L 5900:127.0.0.1:5900 user@server-ip
```

SSH 隧道建立后，VNC 客户端连接：

```text
127.0.0.1:5900
```

### 直接远程连接

安装时选择“监听所有网卡”，或无人值守安装时设置：

```bash
VNC_BIND=0.0.0.0
```

VNC 客户端随后连接 `server-ip:5900`。传统 VNC 认证和传输不等于端到端加密，不应把端口直接暴露到公网。至少使用防火墙限制来源 IP，更稳妥的做法是 SSH 隧道或 VPN。

## Chrome 扩展如何自动安装

脚本写入机器级 Chrome 托管策略：

```text
/etc/opt/chrome/policies/managed/chrome-opencli.json
```

策略使用 `ExtensionSettings` 的 `force_installed` 模式，从 Chrome Web Store 更新地址自动安装扩展 ID：

```text
ildkmabpimmkaediidaifkhjpohdnifk
```

因此 Chrome 会显示“由您的组织管理”，这是预期行为。扩展不能被该 Chrome profile 手动禁用或删除。可以在以下页面检查：

```text
chrome://policy
chrome://extensions
```

首次启动必须能访问 `clients2.google.com` 才能下载扩展。安装器会等待扩展连接，并要求 `opencli doctor` 同时出现：

```text
[OK] Extension: connected
[OK] Connectivity: connected
```

未在限定时间内建立连接时，脚本会打印 Chrome 服务状态和日志，并以失败状态退出，不会把“服务进程存在”误报成安装成功。
验证失败时，本次启动的 target 会被停止并取消开机启动，避免安装器报错后继续暴露 VNC。

## 使用 OpenCLI

先通过 VNC 打开 Chrome，在需要的网站中完成登录。登录状态保存在：

```text
/var/lib/chrome-opencli/chrome-profile
```

然后可以在服务器终端执行：

```bash
opencli --version
opencli doctor
opencli list
opencli profile list
```

例如：

```bash
opencli bilibili hot --limit 5
```

OpenCLI daemon 只监听 `127.0.0.1:19825`，并继续使用 OpenCLI 官方的 detached 生命周期，不伪装成 systemd 前台服务。安装验证和第一条 OpenCLI 浏览器命令会按官方机制自动拉起 daemon；daemon 意外退出时，后续命令也会自动恢复。停止 `chrome-opencli.target` 不会伪造 daemon 的 systemd 状态，如需同时停止它，再执行 `opencli daemon stop`。

loopback 只阻止远程网络直接访问，不能区分同机 Linux 用户。OpenCLI 当前协议使用固定请求头而不是每用户凭据，因此同机其他账号也可能操作这个已登录的 Chrome。它适合单用户服务器或所有本机用户均可信的环境，不适合共享 shell 主机。

全局 npm 安装固定使用官方 registry，并带 `--ignore-scripts`，避免以 root 执行依赖包生命周期脚本。OpenCLI 的用户目录和适配器兼容数据会在安装器随后以 `chrome-opencli` 非 root 用户运行 `opencli doctor` 时初始化；npm 的 shell completion 后安装步骤不会自动执行。

## systemd 服务

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
systemctl stop chrome-opencli.target
systemctl start chrome-opencli.target
```

查看日志：

```bash
journalctl -u chrome-opencli-browser -f
journalctl -u chrome-opencli-vnc -f
```

查看或重启 OpenCLI daemon：

```bash
opencli daemon status
opencli daemon restart
```

## 重复执行和升级

重新运行 `install.sh` 会：

- 更新 Google Chrome Stable
- 安装指定版本或最新 OpenCLI
- 重写本项目自己的 Chrome 策略和 systemd 单元
- 重启整个 target
- 再次执行端到端连接验证

不会删除：

- Chrome profile
- 网站登录状态和 Cookie
- OpenCLI 用户数据
- 已有 VNC 密码，除非交互时明确选择生成新密码或自定义密码

## 无人值守安装

无人值守模式必须显式设置 `ASSUME_YES=1`：

```bash
ASSUME_YES=1 sudo -E bash scripts/chrome-opencli/install.sh
```

默认仍采用 `127.0.0.1:5900` 和随机密码。常用环境变量：

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `ASSUME_YES` | `0` | 设为 `1` 跳过交互和确认 |
| `SCREEN_GEOMETRY` | `1920x1080` | Xvfb 和 Chrome 窗口尺寸 |
| `DISPLAY_NUM` | `99` | X display 编号 |
| `VNC_BIND` | `127.0.0.1` | VNC 的 IPv4 监听地址或主机名；服务显式禁用 IPv6 监听 |
| `VNC_PORT` | `5900` | VNC 端口 |
| `VNC_PASSWORD` | 未设置 | 未设置时保留已有密码或首次随机生成；显式空值表示无密码 |
| `OPENCLI_VERSION` | `latest` | `latest` 或不低于 `1.7.0` 的稳定语义版本，例如 `1.8.6`；旧版不具备本脚本依赖的 Browser Bridge 诊断契约 |
| `NODE_MAJOR` | `22` | 系统 Node 不满足要求时安装 `20`、`22` 或 `24` |
| `VERIFY_TIMEOUT` | `120` | 等待扩展和端到端连接的秒数，范围 30～900 |
| `CHROME_NO_SANDBOX` | `0` | 设为 `1` 添加 `--no-sandbox`，仅用于无法修复的受限容器 |

推荐保留 `OPENCLI_VERSION=latest`。Chrome Web Store 扩展会自动更新，长期固定旧 CLI 可能在扩展提高最低兼容版本后验证失败；固定版本只适合同时管理升级节奏的环境。

自定义示例：

```bash
ASSUME_YES=1 \
SCREEN_GEOMETRY=1440x900 \
VNC_BIND=0.0.0.0 \
VNC_PORT=5901 \
VNC_PASSWORD='aB3_9xQ2' \
OPENCLI_VERSION=1.8.6 \
sudo -E bash scripts/chrome-opencli/install.sh
```

明确配置无密码 VNC：

```bash
ASSUME_YES=1 VNC_PASSWORD= sudo -E bash scripts/chrome-opencli/install.sh
```

安装器只允许在 `VNC_BIND=127.0.0.1` 时使用无密码模式，并要求通过 SSH 隧道访问。对外监听时必须使用恰好 8 位的密码。
无密码模式不会在重复安装时自动保留；下次未再次显式选择无密码时，脚本会恢复为随机密码。

## 文件和数据

| 路径 | 内容 |
| --- | --- |
| `/var/lib/chrome-opencli/chrome-profile` | Chrome profile、Cookie 和网站登录状态 |
| `/var/lib/chrome-opencli/.opencli` | OpenCLI 配置和用户数据 |
| `/etc/chrome-opencli/environment` | systemd 公共环境配置 |
| `/etc/chrome-opencli/Xauthority` | X11 MIT-MAGIC-COOKIE，阻止同机其他用户直接接管虚拟显示器 |
| `/etc/chrome-opencli/vnc.pass` | x11vnc 密码文件 |
| `/etc/chrome-opencli/vnc-password.txt` | root-only 的 VNC 明文密码，供重装时保留和安装结果显示 |
| `/etc/opt/chrome/policies/managed/chrome-opencli.json` | OpenCLI 扩展强制安装策略 |
| `/usr/local/libexec/chrome-opencli-prepare-display` | 启动 Xvfb 前检查 display 占用并清理失效锁 |
| `/usr/local/libexec/chrome-opencli-wait-display` | 等待 X display 通过认证并真正可连接 |

## 卸载

默认卸载服务和 Chrome 策略，但保留 profile、登录状态、VNC 配置、Chrome 软件包和全局 OpenCLI：

```bash
sudo bash scripts/chrome-opencli/uninstall.sh
```

彻底删除 profile、登录状态和 VNC 密码；专用用户和组仅在确认为本脚本创建时一并删除：

```bash
sudo bash scripts/chrome-opencli/uninstall.sh --purge-data
```

同时卸载 Google Chrome 和全局 OpenCLI npm 包：

```bash
sudo bash scripts/chrome-opencli/uninstall.sh --purge-data --remove-packages
```

`--purge-data` 不可恢复，执行前应备份 `/var/lib/chrome-opencli`。

## 排查

### 扩展没有连接

```bash
opencli doctor
systemctl status chrome-opencli-browser.service
journalctl -u chrome-opencli-browser -n 100 --no-pager
systemctl restart chrome-opencli-browser.service
```

再通过 VNC 检查 `chrome://policy` 和 `chrome://extensions`。如果策略存在但扩展一直未安装，通常是服务器无法访问 Chrome Web Store 更新服务。

### Chrome 服务反复重启

先查看日志，不要直接禁用 sandbox：

```bash
journalctl -u chrome-opencli-browser -n 100 --no-pager
```

某些限制很强的 LXC 环境不允许 Chrome sandbox 工作。只有在已理解隔离风险、且无法调整宿主机或容器权限时，才使用：

```bash
CHROME_NO_SANDBOX=1 sudo -E bash scripts/chrome-opencli/install.sh
```

### VNC 无法连接

```bash
systemctl status chrome-opencli-vnc.service
journalctl -u chrome-opencli-vnc -n 100 --no-pager
```

默认只监听本机，远程客户端必须先建立 SSH 隧道。如果选择直接监听，还要检查云安全组和主机防火墙。

## 主要风险

- VNC 直连公网会暴露浏览器桌面和网站登录态。
- VNC 传统密码最多有效使用前 8 个字符，脚本因此只允许 1～8 位。
- Chrome 托管策略是机器级配置，会影响同机所有 Google Chrome 用户。
- 扩展拥有浏览器自动化所需的高权限，任何能使用本机 OpenCLI daemon 或控制 VNC 的用户都应视为能操作该 Chrome profile。
- Chrome 使用 `--password-store=basic` 避免无桌面密钥环弹窗，因此必须把 `/var/lib/chrome-opencli` 当作高敏感数据保护和备份。
- `CHROME_NO_SANDBOX=1` 会明显降低浏览器进程隔离能力。
- 删除持久 profile 会永久丢失未同步的登录状态和浏览器数据。
