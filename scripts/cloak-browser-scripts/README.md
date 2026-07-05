# Ubuntu / Debian LXC 单文件安装说明

本文档说明如何在干净的 Ubuntu / Debian LXC 虚拟机里安装 CloakBrowser 运行环境，并开启 VNC 远程桌面。

脚本位置：

```bash
scripts/cloak-browser-scripts/install.sh
```

这个脚本是单文件安装器，不需要本地存在 CloakBrowser 源码仓库，也不需要 `pyproject.toml`、`cloakbrowser/`、`bin/`、`examples/` 或 `js/` 目录。

## 它会安装什么

脚本会安装：

- Chromium / CloakBrowser 运行依赖
- 常用字体和 emoji 字体
- Python venv
- 最新版 `cloakbrowser[serve,geoip]` Python wrapper
- CloakBrowser 浏览器二进制
- Node.js 20
- 最新版 npm `cloakbrowser` JS wrapper、`playwright-core`、`puppeteer-core`
- Xvfb 虚拟显示器
- Openbox 轻量窗口管理器
- x11vnc 远程桌面
- `cloakserve`、`cloaktest`、`fetch-widevine.py` 命令
- systemd 服务

默认安装目录：

```bash
/opt/cloakbrowser
```

## 使用方法

### 推荐：从 GitHub 下载并执行

主脚本下载地址：

<https://raw.githubusercontent.com/tiaot33/my-devbox/main/scripts/cloak-browser-scripts/install.sh>

一条命令自动下载并执行：

```bash
sudo bash <(wget -qO- https://raw.githubusercontent.com/tiaot33/my-devbox/main/scripts/cloak-browser-scripts/install.sh)
```

> 建议先打开上面的 GitHub raw 链接审阅脚本内容，再执行远程脚本。

无人值守安装也可以直接传环境变量：

```bash
ASSUME_YES=1 sudo -E bash <(wget -qO- https://raw.githubusercontent.com/tiaot33/my-devbox/main/scripts/cloak-browser-scripts/install.sh)
```

### 本地运行

在任意目录执行：

```bash
sudo bash scripts/cloak-browser-scripts/install.sh
```

脚本会交互式询问配置项。安装完成后会输出 VNC 地址、端口和密码。

## 默认行为

默认行为偏向普通使用场景：

- 启用 Xvfb
- 启用 VNC
- 不启用 `cloakserve`
- VNC 默认监听 `0.0.0.0:5900`
- VNC 默认随机生成 8 位密码
- CDP 默认配置为 `127.0.0.1:9222`，但只有启用 `cloakserve` 时才生效
- 每次运行脚本都会尝试安装或升级到最新 CloakBrowser wrapper

普通 Python / JS 脚本直接运行 CloakBrowser 不需要 `cloakserve`。只有外部程序需要通过 CDP 远程连接浏览器时，才需要启用它。

## 交互配置项

脚本会询问：

```text
Enable cloakserve CDP service
VNC listen address
VNC port
VNC password mode
```

如果启用 `cloakserve`，还会继续询问：

```text
CDP listen address
CDP public port
cloakserve browser mode
Use persistent cloakserve profile dir
Configure advanced cloakserve defaults
```

只有选择配置高级默认项时，脚本才会继续询问：

```text
Stop idle cloakserve browsers after seconds
default fingerprint seed
default locale
default timezone
default proxy server with GeoIP
extra cloakserve/browser args
```

脚本使用仓库内维护的 `cloakserve`，支持默认 fingerprint、locale、timezone、proxy + GeoIP。配置 `CLOAKSERVE_PROXY_SERVER` 后，服务端会把它作为每个新浏览器进程的默认 proxy，并自动按这个 proxy 做 GeoIP 推导；客户端仍然连接普通 CDP URL，不需要手写 query 参数。

## VNC 密码

VNC 密码有三种模式：

1. 随机生成密码
2. 手动输入密码
3. 无密码

无人值守安装时可以这样指定：

```bash
VNC_PASSWORD=yourpass sudo -E bash scripts/cloak-browser-scripts/install.sh
```

如果明确要无密码：

```bash
VNC_PASSWORD= sudo -E bash scripts/cloak-browser-scripts/install.sh
```

VNC 协议传统认证只使用前 8 个字符，脚本随机生成的密码也是 8 位。

无密码 VNC 风险很高，只建议在受信任内网、SSH 隧道或临时调试时使用。

## cloakserve / CDP

`cloakserve` 会启动一个 CDP 服务，供外部 Playwright / Puppeteer / 其他自动化程序连接。

示例：

```python
browser = pw.chromium.connect_over_cdp("http://host:9222")
```

带代理时，安装时配置默认 proxy：

```bash
ENABLE_CLOAKSERVE=1 \
CLOAKSERVE_PROXY_SERVER=http://proxy:8080 \
sudo -E bash scripts/cloak-browser-scripts/install.sh
```

客户端照常连接普通 CDP URL：

```python
browser = pw.chromium.connect_over_cdp("http://127.0.0.1:9222")
```

这样 `cloakserve` 会按这个 proxy 做 GeoIP 推导，并把 timezone、locale 和 WebRTC IP 一起注入到对应 fingerprint 的浏览器进程里。

普通脚本运行不需要它：

```python
from cloakbrowser import launch

browser = launch(headless=False)
page = browser.new_page()
page.goto("https://example.com")
```

启用 `cloakserve`：

```bash
ENABLE_CLOAKSERVE=1 sudo -E bash scripts/cloak-browser-scripts/install.sh
```

默认 CDP 地址是：

```text
127.0.0.1:9222
```

如果需要对外监听：

```bash
ENABLE_CLOAKSERVE=1 CDP_BIND=0.0.0.0 CDP_PORT=9222 sudo -E bash scripts/cloak-browser-scripts/install.sh
```

仓库内维护的 `cloakserve` 支持 `--host` 参数。安装器会把 `CDP_BIND` 写入 systemd 启动参数，不再通过创建 `/.dockerenv` 伪装 Docker 环境来改变监听地址。重新运行新版安装器时，如果发现旧版本安装器创建过 `/etc/cloakbrowser/created-dockerenv` 标记，会清理对应的历史 `/.dockerenv`。

## data-dir 和 idle-timeout

`cloakserve` 默认不由安装器显式设置 `--data-dir`。交互安装时，只有选择使用持久 profile 目录，脚本才会继续询问目录路径，并给出推荐值：

```bash
/var/lib/cloakbrowser/profiles
```

也可以手动覆盖：

```bash
CLOAKSERVE_DATA_DIR=/var/lib/cloakbrowser/profiles
CLOAKSERVE_IDLE_TIMEOUT=300
```

完整示例：

```bash
ENABLE_CLOAKSERVE=1 \
CLOAKSERVE_DATA_DIR=/var/lib/cloakbrowser/profiles \
CLOAKSERVE_IDLE_TIMEOUT=300 \
sudo -E bash scripts/cloak-browser-scripts/install.sh
```

含义：

- `CLOAKSERVE_DATA_DIR`：每个 fingerprint seed 的 profile 存放目录
- `CLOAKSERVE_IDLE_TIMEOUT`：CDP 断开后多少秒清理对应 Chrome 进程和 profile
- `CLOAKSERVE_FINGERPRINT`：未在连接 URL 里传 `fingerprint` 时使用的默认 seed
- `CLOAKSERVE_LOCALE`：未在连接 URL 里传 `locale` 时使用的默认 locale，例如 `en-US`
- `CLOAKSERVE_TIMEZONE`：未在连接 URL 里传 `timezone` 时使用的默认 timezone，例如 `America/New_York`

`CLOAKSERVE_DATA_DIR` 留空则安装器不写 `--data-dir`，使用 `cloakserve` 自身默认行为。

## 常用无人值守示例

只安装 VNC，随机密码：

```bash
ASSUME_YES=1 sudo -E bash scripts/cloak-browser-scripts/install.sh
```

VNC 只监听本机：

```bash
ASSUME_YES=1 VNC_BIND=127.0.0.1 sudo -E bash scripts/cloak-browser-scripts/install.sh
```

VNC 无密码：

```bash
ASSUME_YES=1 VNC_PASSWORD= sudo -E bash scripts/cloak-browser-scripts/install.sh
```

只安装 Python 运行环境，不安装全局 JS wrapper：

```bash
ASSUME_YES=1 INSTALL_JS=0 sudo -E bash scripts/cloak-browser-scripts/install.sh
```

启用 CDP，但只允许本机连接：

```bash
ASSUME_YES=1 ENABLE_CLOAKSERVE=1 CDP_BIND=127.0.0.1 sudo -E bash scripts/cloak-browser-scripts/install.sh
```

启用 CDP 并对外监听：

```bash
ASSUME_YES=1 ENABLE_CLOAKSERVE=1 CDP_BIND=0.0.0.0 sudo -E bash scripts/cloak-browser-scripts/install.sh
```

带 GeoIP 代理连接和自动清理：

```bash
ASSUME_YES=1 \
ENABLE_CLOAKSERVE=1 \
CDP_BIND=127.0.0.1 \
CLOAKSERVE_IDLE_TIMEOUT=300 \
CLOAKSERVE_PROXY_SERVER=http://proxy:8080 \
sudo -E bash scripts/cloak-browser-scripts/install.sh
```

## systemd 服务

安装后会创建这些服务：

```bash
cloakbrowser-xvfb.service
cloakbrowser-openbox.service
cloakbrowser-vnc.service
cloakserve.service
```

查看状态：

```bash
systemctl status cloakbrowser-xvfb cloakbrowser-openbox cloakbrowser-vnc cloakserve
```

查看日志：

```bash
journalctl -u cloakbrowser-vnc -f
journalctl -u cloakserve -f
```

重启服务：

```bash
systemctl restart cloakbrowser-xvfb cloakbrowser-openbox cloakbrowser-vnc
systemctl restart cloakserve
```

## 验证安装

查看 CloakBrowser 信息：

```bash
/opt/cloakbrowser/.venv/bin/python -m cloakbrowser info --quick
```

运行测试命令：

```bash
cloaktest
```

检查 VNC 是否监听：

```bash
ss -lntp | grep 5900
```

如果启用了 `cloakserve`，检查 CDP：

```bash
curl http://127.0.0.1:9222/json/version
```

## 网络依赖

安装过程需要访问：

- apt 源
- NodeSource
- PyPI
- npm registry
- CloakBrowser 浏览器二进制下载地址

`fetch-widevine.py` 来自 PyPI sdist；`cloakserve` 使用本仓库维护的版本，远程单文件安装时会从 GitHub raw 下载。

## 主要风险

- VNC 无密码会让任何能访问端口的人控制桌面。
- CDP 对外暴露后，连接者可以完全控制浏览器，不应直接暴露到公网。
- 安装过程需要访问多个外部源；网络受限环境需要提前放通。
- 脚本需要 systemd；没有 systemd 的极简 LXC 不适用。
