# Cloudflare Pages — 发布配方

官方：[Pages 文档](https://developers.cloudflare.com/pages/) · [直接上传](https://developers.cloudflare.com/pages/get-started/direct-upload/) · [限制](https://developers.cloudflare.com/pages/platform/limits/) · [静态 HTML](https://developers.cloudflare.com/pages/framework-guides/deploy-anything/)

上次核实：2026-07。

## 何时读本文件

SKILL 选型表指向 CF 时：长期静态 HTML、路径库归档、免费不限量静态流量、免费档可商用。反复归档 AI HTML 时的默认主机。

## 状态探测（发布前）

```bash
npx wrangler whoami        # 显示账号 = 已登录；否则提示先 wrangler login
git remote -v              # 有 remote 且要 push 触发 → 走 C（Git 集成）
```

- 要 agent 直接发 → 走 A（Wrangler CLI）。
- 用户只肯用浏览器 → 走 B（控制台上传）。

## 发布模型（先选一条）

| 模型 | 一条命令 / 入口 |
| --- | --- |
| 一次性 | 控制台 **Upload assets** 拖文件夹（见 B） |
| 路径库（归档推荐） | `npx wrangler pages deploy ./site --project-name=<固定项目名>`（见 A） |
| Git 原生 | Workers & Pages → **Connect to Git**（见 C） |

## A. Wrangler CLI（agent 可执行的主路径）

```bash
npm i -g wrangler          # 或全程用 npx wrangler，免去全局安装
wrangler login             # 浏览器授权；CI 改用带 Pages 权限的 API token（CLOUDFLARE_API_TOKEN）

# 路径库 = 整棵树反复部署进同一个 project
wrangler pages deploy ./site --project-name=ai-docs
```

- 执行前先过 SKILL 的「发布门槛」：`*.pages.dev` 公开可访问——亮出部署目录文件清单、查敏感内容、用户确认后再跑。
- 项目不存在时，首次部署会提示创建。
- 预期生产 URL：`https://<project-name>.pages.dev`（每次部署另有部署级预览 URL）。
- 分支预览：加 `--branch=staging`，在同一项目内产生非生产预览。
- 更新文档 = 改完 `./site` 后原样重跑同一命令；不要新建项目。

## B. 控制台上传（浏览器一次性）

1. 登录 [dash.cloudflare.com](https://dash.cloudflare.com)（无账号先免费注册）→ **Workers & Pages** → **Create** → **Pages** → **Upload assets**。
2. 给项目命名（会变成 `*.pages.dev`）。
3. 拖入**整棵** `site/` 树的文件夹或 ZIP（若是库，要带上以往所有文档）。
4. 部署。打开生产环境的 `*.pages.dev` URL。

之后再发：同一项目 → 再次上传完整更新后的树（或改用 A）。

## C. Git 集成

1. Pages → **Connect to Git** → 选仓库。
2. 框架预设：无 / 静态。若 HTML 已构建好，构建命令留空。输出目录 = 含 `index.html` 的文件夹（如 `/` 或 `site`）。
3. 推送到生产分支即可重新部署；其他分支自动出预览。

## 路径库（多文档时必用）

只保留一个 Pages 项目。布局：

```text
site/
  index.html
  d/
    20260719-a1b2/index.html
    20260719-c3d4/index.html
```

公开 URL 示例：`https://ai-docs.pages.dev/d/20260719-a1b2/`

## 自定义域名（可选）

项目 → **Custom domains** → 添加主机名 → 按提示配置 DNS（CNAME 到 Pages）。HTTPS 由 Cloudflare 签发。

## 本形态会踩到的限制

| 限制 | 实际影响 |
| --- | --- |
| 每账号 100 个项目 | 一个库项目（或大约每月/每年一个），不要每个文档一个 |
| 每站 20,000 文件 | 接近上限时按年/月拆项目 |
| 单文件 25 MiB | 避免把超大 base64 图塞进单个 HTML |
| 拖拽每次 1,000 文件 | 大型库用 Wrangler，别用拖拽 |

静态资源请求免费且不限量；Functions/Worker 流量另计费（纯静态场景不涉及）。

## 不要

- 每生成一个 AI HTML 就新建一个 Pages 项目。
- 在 HTML 里依赖绝对 `file://` 或本机路径。
- 给纯静态场景叠加 Pages Functions / Workers —— 超出本 skill 范围，需要时再说。

## 延伸（可选，默认零依赖）

需要 agent 全自动（CI token、Functions、更多平台能力）时，可另装官方 `cloudflare/skills`（wrangler / platform）或 OpenAI curated `cloudflare-deploy`。本配方自包含，不依赖它们。
