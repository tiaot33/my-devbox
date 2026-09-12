---
name: static-html-publish
description: >
  推荐并引导静态 HTML 发布托管（Cloudflare Pages、Vercel Drop/CLI、
  Surge、GitHub Pages、Netlify）。在用户想把 HTML 放到网上、托管 AI 生成的
  HTML 文档、挑选免费静态主机，或询问哪种平台适合某种发布形态（一次性分享 vs
  路径库 vs 以 Git 为主的文档站）时使用。也匹配中文问法如
  发布/部署 HTML 页面, 把网页放到网上, 免费静态托管。仅国际主机，不含中国大陆专属云。
---

# 静态 HTML 发布

帮助用户选定静态托管，并留下可直接执行的发布配方。

**范围内：** 纯静态 HTML/CSS/JS（单文件或一个目录）。不含中国大陆专属云。  
**范围外：** 全栈应用、以 SSR 框架为主要目标、付费企业采购流程。

## 关键术语

- **发布形态（publish shape）** — 量级、存续时间、工具偏好、是否商用、是否需要扩展能力（表单/函数等）。在点名主机之前先摸清这些。
- **路径库（path library）** — 许多文档挂在**同一个**项目下，用 URL 路径区分（`/d/<id>/`），绝不要「一个 HTML 文件一个项目」。
- **一次性/抛出式（throwaway）** — 短命分享链接；允许反复重传，不要求归档纪律。

## 发布门槛（任何 deploy / push 前必过）

发布是**对外动作**：目标 URL 公开可访问；GitHub 免费 Pages 更要求**公开仓库**——全网可见，且可能被缓存/镜像，事后删除难收回。agent 亲自执行任何部署/推送命令前，依次：

1. **亮清单** — 列出将上传的文件（`find <目录> -type f` 或 `git status`），并说明目标：账号、项目/仓库名、预期公开 URL。
2. **查敏感** — 检查清单中的 `.env`、密钥/Token、`*.pem`/`*.key`、私密文档。命中即停下报告，由用户定夺；不擅自剔除后静默继续。
3. **说可见性** — 明确告知内容将公开及公开范围（公开 URL / 公开仓库）。
4. **拿确认** — 用户明确同意后才执行。禁止把初始化与发布串成一条链静默跑完（最坏案例：`git init && git add . && gh repo create --public --push`）。

未经确认的发布 = 失败，哪怕命令本身成功。

## 工作流

### 1. 摸清发布形态

从用户（以及他们指向的任何文件）确认：

| 信号 | 要搞清楚什么 |
| --- | --- |
| 量级 | 一次性、少量，还是很多（例如每天 10+）？ |
| 存续 | 几小时/几天，还是长期归档？ |
| 工具 | 更想浏览器拖拽、CLI，还是本来就有 Git？ |
| 商用 | 仅个人，还是工作/商用材料？ |
| 结构 | 单个 HTML，还是带相对链接的目录树？ |
| 扩展 | 以后要不要表单、鉴权、边缘函数？ |

若量级高且计划**每个 HTML 一个托管项目**，先纠正为**路径库**，再推荐平台。

**完成标准：** 上表每个信号已知或已明确采用默认值；量级高时已引导用户远离「一文件一项目」。

### 2. 匹配主机

用下表。优先取第一行能对上的；只点名**一个主选**，最多**一个备选**。

| 发布形态 | 主选 | 备选 |
| --- | --- | --- |
| 长期纯静态；在意免费静态流量；接受一个路径库 | **Cloudflare Pages** | Netlify |
| 仅浏览器、一次性（不要 CLI/Git） | **Vercel Drop** | CF Pages 控制台上传 |
| 本地/CLI、大量独立部署、担心项目数量上限 | **Surge** | CF Pages 路径库（若要归档，更推荐这条） |
| 内容已在 GitHub 仓库；文档/项目站 | **GitHub Pages** | CF Pages（Git） |
| 要 Git 预览 + 以后可能表单/函数；能接受额度（credit）计量 | **Netlify** | CF Pages |
| 框架应用碰巧产出静态（不是手写纯 HTML） | **Vercel**（Git/CLI） | Netlify |

**硬约束（先于口味判断）：**

| 约束 | 影响 |
| --- | --- |
| 长期会散落很多文档 | 强制用 CF Pages（或 Netlify）的**路径库**。不要推荐 CF 上「一文件一项目」（账号最多 100 个项目）。 |
| 免费档上的工作/商用 | 优先 **Cloudflare Pages** 或 **Netlify**，少用 Vercel Hobby（Hobby 限个人/非商用）。 |
| 必须只待在 GitHub | **GitHub Pages**；说明软带宽上限，且不宜做商业交易主站。 |
| 要真正无限*项目数*且能接受杂乱 | **Surge**；仍要提醒归档更干净的是路径库。 |

**完成标准：** 已选定主选主机，并用一句话说明*为什么*（绑定发布形态）——不是一排并列菜单。

### 3. 加载平台配方

**只**读匹配到的主机文件：

| 主机 | 何时读 |
| --- | --- |
| Cloudflare Pages | 主选或备选是 CF |
| Vercel | Drop、CLI 或 Git 走 Vercel |
| Surge | CLI 多部署 |
| GitHub Pages | GitHub 原生文档/站点 |
| Netlify | Git + 额度 / 扩展能力 |

指针：

- [references/cloudflare-pages.md](references/cloudflare-pages.md)
- [references/vercel.md](references/vercel.md)
- [references/surge.md](references/surge.md)
- [references/github-pages.md](references/github-pages.md)
- [references/netlify.md](references/netlify.md)

**完成标准：** 已加载所选 reference 文件；除非用户在比较两个点名的选项，否则不要再读其他主机文件。

### 4. 交付答案

按此顺序输出：

1. **主选主机** + 一行理由（发布形态 → 主机）。
2. **发布模型** — 一次性 / 路径库 / Git 原生（写清楚）。
3. **步骤** — 来自 reference：账号、部署命令或界面、预期 URL。
4. **会卡到此形态的限制** — 项目数、文件数、商用、带宽——只写相关的。
5. **备选**（可选）— 主选被挡时的一个替代。

不要罗列所有平台。不要编造价格；数字重要时指向 reference 里的官方链接。

若 agent 亲自执行发布（而非只交付配方）：先过「发布门槛」，拿到确认再跑命令。

**完成标准：** 用户无需再调研就能发布；高量级场景用路径库（或明确写出例外）；任何已执行的发布动作都先经用户明示确认。

## 默认策略

用户只说「把这个 HTML 放到网上」、未说明形态时：

1. 单文件或小目录、临时 → **Vercel Drop** 或 **CF Pages 上传**。
2. 反复产生的 AI HTML 文档 / 归档 → **Cloudflare Pages 路径库**。
3. 已是公开 GitHub 仓库 → **GitHub Pages**。

## 路径库布局（内联 — 所有高量级分支都用）

```text
site/
  index.html                 # 可选首页
  d/
    <yyyyMMdd>-<short-id>/
      index.html
```

URL：`https://<host>/<…>/d/<yyyyMMdd>-<short-id>/`  
把**整棵树**重新部署（或同步）进**同一个**项目。每个文档内部只用相对链接。

同一项目反复发布的一句对照（细节在各 reference）：

| 主机 | 路径库发布命令 |
| --- | --- |
| Cloudflare Pages | `wrangler pages deploy ./site --project-name=<固定名>` |
| Vercel | link 同一项目后 `vercel deploy --prod`，或 push 同一 repo |
| Netlify | link 同一 site 后 `netlify deploy --dir=site --prod` |
| Surge | 单域名整树 `surge ./site mylib.surge.sh`（用 `.surge-domain` 记忆） |
| GitHub Pages | 单 repo 推送整树，文档挂 `d/<id>/` 路径下 |
