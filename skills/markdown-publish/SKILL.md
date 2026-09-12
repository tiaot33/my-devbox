---
name: markdown-publish
description: >
  发布 Markdown 为公开 URL（JotBird 单页、Gist、GitHub 仓库渲染页、
  Docsify 笔记站、MkDocs 文档站、Quartz/Obsidian）。在用户要分享 .md、
  一次性甩链接、把笔记目录做成侧栏站、把 docs 做成可搜索文档站、
  发布 Obsidian 库、只要 GitHub 渲染页，或只问 JotBird/Gist/Docsify/
  MkDocs/Quartz/GitHub Pages 选哪条时使用。纯 HTML 转 static-html-publish。
---

# Markdown 发布

把已有 `.md` 变成一条可打开的公开 URL。默认跑完发布并验链。

**范围内：** 本地 Markdown 文件、目录树、Obsidian 库。  
**范围外：** 纯 HTML（转 `static-html-publish`）、Notion/Confluence。点名的未列框架按第 2 步映射表落到一条已有路径。

## 闭环约定（每条路径都适用）

agent 的 shell 没有 TTY，等键盘的命令会卡死。守住四条：

1. **登录不阻塞**：`jotbird login` / `gh auth login -w` 后台跑 + 轮询凭证（写法在 [references/INSTALLS.md](references/INSTALLS.md)）。浏览器那一下必须用户点；agent 轮询，不挂起等进程。
2. **`npx` 一律 `npx -y`**。
3. **URL 从 stdout 截**：发布命令 stdout 进变量、stderr 进文件；用 `command grep` 取最后一条 `https://`（很多环境里 `grep` 是 `rg -n`，`-o` 会留下 `1:` 前缀，验链变成 000）。stderr 里的 `⚠` / `Failed` 必须读完再交付。
4. **验链后才算完**：`curl -sI -o /dev/null -w '%{http_code}' -L --max-time 20 "$URL"` 得到 `200`。Pages 轮询到 200，否则报 latest build。

## 工作流

只要选型、先不发布 → 做完 1–2 就停：主选 + 一句形态→路径，再问要不要现在发布。

### 1. 摸清源

对着用户指出的路径实际看：

| 信号 | 怎么确认 |
| --- | --- |
| 量级 | 几个 `.md`，还是一棵目录树？ |
| 源头 | 已有 `git remote`？有 `.obsidian/` 或大量 `[[wikilink]]`？ |
| 结构 | 有没有 `![…](相对路径)` / `![[图]]` / 子目录附件？ |
| 意图 | 只要一个分享链接，还是要侧栏站点？有没有点名搜索？ |

同时跑：

```bash
test -s "$HOME/.config/jotbird/credentials" && echo jotbird:ok || echo jotbird:missing
command -v gh >/dev/null && gh auth status >/dev/null 2>&1 && echo gh:ok || echo gh:missing
git remote get-url origin 2>/dev/null
```

JotBird CLI **只读** `~/.config/jotbird/credentials`，不读 `JOTBIRD_API_KEY`。用户已有 `jb_...` 密钥时先写入该文件再探测；否则读 [references/INSTALLS.md](references/INSTALLS.md) 走后台 `jotbird login`。`gh` 只在选定 Gist / 仓库视图 / Pages 时才是硬门槛；`gh auth status` 报 token invalid 也算 missing。

源里有图时按下表选路（图不会自动跟着 md 走）：

| 路径 | 相对图跟着走 | 裂图时改走 |
| --- | --- | --- |
| **JotBird** | `![alt](path)` 的 png/jpeg/gif/webp（≤10MB） | `![[wikilink]]` / `<img>` → 先改成 `![alt](path)`；**SVG 改不成**。不是 vault 不要为了救图改走 Quartz，改 Docsify 或仓库视图 |
| **Gist** | 不跟 | 有相对图 → JotBird 或仓库视图 |
| **仓库视图** | 和 `.md` 一起进仓的相对路径 | 本机绝对路径先改相对 |
| **Docsify** | 图文件和 `.md` 一起部署；`relativePath: true` | 只传 md → 把附件一并纳入 |
| **MkDocs** | 图在 `docs_dir` 内 | 图在外面 → 移入或改 `docs_dir` |
| **Quartz** | copy 进库的 `![]` 与 `![[image]]` | 图不在被 copy 的库里 → 先放进库 |

**完成标准：** 源根路径、文件量级、是否 vault、图引用形态、是否已有 GitHub remote、JotBird / `gh` 凭证是否可用，全部已知。

### 2. 选定一条路径

只点名**一个主选**。用户点名工具时先查映射，再按形态表第一行能对上的走：

| 用户点名 | 主选 |
| --- | --- |
| JotBird / 单页 / 甩链接 | **JotBird** |
| Gist / 挂到我 GitHub（一篇或几篇） | **Gist**（有相对图则改 JotBird 或仓库视图） |
| 只要渲染页 / blob URL | **仓库视图** |
| Docsify / Wiki / 侧栏笔记站 | **Docsify** |
| MkDocs / 搜索 / YAML 导航 | **MkDocs** |
| Quartz / Obsidian | **Quartz** |
| HackMD / 在线 pad | **JotBird** |
| Hugo / Jekyll / Docusaurus | 要侧栏且正文保持 `.md` → **Docsify**；点名搜索或构建导航 → **MkDocs** |
| GitHub Pages（未点名框架） | 目录树 → **Docsify**；点名搜索 → **MkDocs** |

| 形态 | 路径 | 对源文件 |
| --- | --- | --- |
| 一篇或几篇、一次性单页 | **JotBird** | 不改 |
| 一篇或几篇、图是 `![[ ]]` / `<img>` / SVG | **改写后 JotBird** 或 **Docsify** / **仓库视图** | 能改成 `![alt](path)` 的 png/jpeg/gif/webp 就改写再发；SVG / 改不干净 → Docsify 或仓库视图。**不是库就不上 Quartz** |
| 一篇或几篇、要挂在自己的 GitHub 上 | **Gist** | 不改（有相对图则改上一行） |
| 已在（或即将推进）GitHub 仓库，只要渲染页 | **仓库视图** | 不改 |
| 笔记目录树，要侧栏，`.md` 保持原样 | **Docsify** | 只加壳文件 |
| 项目文档，点名了搜索 / YAML 导航 | **MkDocs** | 加 `mkdocs.yml` |
| Obsidian 库（`.obsidian/` 或大量页面 wikilink / callout） | **Quartz** | 原文不动，复制进站点工程 |

Quartz 只吃「库」。一篇散笔记上的 `![[图]]`、孤立 `[[wikilink]]` 或单个 callout 不够开整站工程——那是 JotBird 能渲染的语法，或裂图时改写/换 Docsify。

用户只说「把这个 md 放到网上」时：单文件 → JotBird；图是 `![[ ]]` / `<img>` / SVG 且不是 vault → 先改写或改 Docsify / 仓库视图；点名 Gist / 「挂到我 GitHub」→ Gist；目录树 → Docsify；已有 GitHub remote 且不要站点 → 仓库视图。

**完成标准：** 已选定主选，并用一句话说明形态 → 路径。只要选型则在此停。

### 3. 加载对应配方

**只**读一行。本地预览可以做；`jotbird publish` / `gh gist create` / `git push` / `gh repo create` / Pages 设定留到第 4 步确认之后。

| 路径 | 读 |
| --- | --- |
| JotBird | [references/jotbird.md](references/jotbird.md) |
| Gist | [references/gist.md](references/gist.md) |
| 仓库视图 | [references/repo-view.md](references/repo-view.md) |
| Docsify | [references/docsify.md](references/docsify.md) |
| MkDocs | [references/mkdocs.md](references/mkdocs.md) |
| Quartz | [references/quartz.md](references/quartz.md) |

站点三条（Docsify / MkDocs / Quartz）部署与验链共用 [references/github-pages.md](references/github-pages.md)。用户点名 Cloudflare / Vercel / Netlify / Surge 时，构建完成后再转 `static-html-publish`。

缺命令或依赖时读 [references/INSTALLS.md](references/INSTALLS.md)。

**完成标准：** 已读且仅读主选配方；站点三条则本地探针已过，单页路径则发布命令已备好。尚未对外发布。

### 4. 发布门槛（任何 push / gist / deploy 前）

发布是对外动作：JotBird 页、公开仓库、Gist、Pages 全网可见且可能被缓存。

1. **亮清单** — 将上传的文件、目标（JotBird / 账号与仓库/Gist 名）、预期 URL。
2. **查敏感** — `.env`、密钥、私密笔记、含个人信息的日记。命中即停下，由用户定夺。
3. **说可见性** — JotBird / Secret Gist 默认「不公开列出，凭 URL 就能看」；公开仓库可被索引。JotBird 免费档约 90 天。
4. **拿确认** — 用户明确同意后才执行。把 `git init && gh repo create --public --push` 拆开，确认后再跑。

未经确认的发布 = 失败，哪怕命令成功。

### 5. 交付

1. **可打开的 URL**（已 `curl` 验过，或写明还在 Pages 构建中及如何查）。
2. **对源文件做了什么**（未改 / 加了哪些壳 / 复制到了哪里）。
3. **怎么撤**（`jotbird remove <slug>`、删 Gist、关 Pages、删仓库）——一行即可。

**完成标准：** 公开 URL 已可访问，或卡在门槛/登录时已停下并说明缺什么（登录类要把一次性验证码 / 待打开的 URL 原样给用户，并说明 agent 正在轮询）。用户不必再调研下一步命令。
