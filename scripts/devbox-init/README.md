# devbox-init

Debian / Ubuntu 无头开发环境初始化。

**推荐入口**：[`mise/`](./mise/) — 系统包、CLI、语言工具链和 dotfiles 全部交给 [mise](https://mise.jdx.dev/) 声明式管理。Coding agent 是可选预设，默认不装。

```bash
bash <(wget -qO- https://raw.githubusercontent.com/tiaot33/my-devbox/main/scripts/devbox-init/mise/install.sh)
```

本地：

```bash
bash scripts/devbox-init/mise/install.sh
```

完成后 `source ~/.bashrc` 或重开 SSH 会话。清单、开关和重跑方式见 [mise/README.md](./mise/README.md)。

---

## 旧脚本（可用，不再作为推荐路径维护）

| 脚本 | 作用 |
| --- | --- |
| [`devbox-init.sh`](./devbox-init.sh) | APT + 终端增强 + 手写 dotfiles |
| [`devbox-lang.sh`](./devbox-lang.sh) | fnm / uv / mise / Bun / Deno 语言工具链 |

```bash
bash <(wget -qO- https://raw.githubusercontent.com/tiaot33/my-devbox/main/scripts/devbox-init/devbox-init.sh)
bash <(wget -qO- https://raw.githubusercontent.com/tiaot33/my-devbox/main/scripts/devbox-init/devbox-lang.sh)
```

新机器请走 `mise/install.sh`。这两份脚本会继续留在仓库里，但新的软件清单只改 `mise/mise.toml`。
