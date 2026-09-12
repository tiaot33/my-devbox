# Vercel — 发布配方

官方：[Docs](https://vercel.com/docs) · [Drop](https://vercel.com/docs/drop) · [Limits](https://vercel.com/docs/limits) · [Hobby](https://vercel.com/docs/plans/hobby) · [Pricing](https://vercel.com/pricing) · [配置构建](https://vercel.com/docs/builds/configure-a-build)

上次核实：2026-07。

## 何时读本文件

SKILL 选型表指向 Vercel 时：浏览器一次性（Drop）、已登录 CLI、或内容本就在 Vercel 生态。Hobby 免费档**限个人/非商用**——商用材料先改推 CF Pages。

## 状态探测（发布前）

```bash
git remote get-url origin 2>/dev/null     # 有 git remote?
cat .vercel/project.json 2>/dev/null || cat .vercel/repo.json 2>/dev/null   # 已 link 到 Vercel 项目?
vercel whoami 2>/dev/null                 # CLI 已登录?
```

- 三个都查完再选路径（见下表）。**不要**在未 link 的目录里用 `vercel link` / `vercel ls` / `vercel project inspect` 来探测状态——它们会交互式提示，甚至静默 link 产生副作用；只有 `vercel whoami` 到处安全。
- `.vercel/` 是 link 状态文件，不要提交进 git（加进 `.gitignore`）。

## 发布模型（先选一条）

| 模型 | 入口 |
| --- | --- |
| 一次性（浏览器，零 CLI） | Vercel Drop（见 A） |
| 路径库 / 长期项目 | 已登录 CLI：link 一次，之后 `vercel deploy`（见 B） |
| Git 原生 | Import Git repository，push 触发（见 C） |
| 无鉴权临时预览 | claimable 部署（见 D，扩展用法） |

## A. Vercel Drop（一次性）

1. 登录后打开 [vercel.com/docs/drop](https://vercel.com/docs/drop)（无账号先免费注册）。
2. 拖入单个 HTML、文件夹或 ZIP。
3. 等部署 URL，分享该链接。

每次 drop 创建**新**项目，不能发回已有项目。适合一次性 demo；不适合 Hobby 上的商用材料或不断增长的归档。

## B. CLI（已登录，长期项目主路径）

```bash
npm i -g vercel
vercel login        # 仅首次；也负责免费注册
cd ./site           # 含 index.html 的文件夹
vercel link         # 首次：关联/创建项目，写 .vercel/project.json
vercel deploy -y --no-wait        # 预览（默认）
vercel deploy --prod -y --no-wait # 生产：必须用户明示要 prod 才加
```

- 执行前先过 SKILL 的「发布门槛」：preview 与生产 URL 均公开可访问。
- **默认发 preview**；production 要用户明确说。
- `--no-wait` 立即返回部署 URL；用 `vercel inspect <url>` 查构建状态。
- 纯静态 HTML 首次 link 时：Framework 选 Other，Build command 留空，Output 为含 HTML 的目录。
- 路径库：link 到**同一个**长期项目后反复 `vercel deploy --prod`，文档挂路径下；不要每个文档 link 一个新项目。
- 已 link + 有 git remote 时，更顺手的是直接 push（Vercel 自动构建）。

## C. Git

1. New Project → Import Git repository。
2. Framework Preset：Other（或自动检测）。文件已是静态 HTML 时清空构建命令。
3. 部署。每次 push 有预览；生产分支更新生产环境。

## D. 无鉴权 claimable（扩展用法）

无登录环境（agent 沙箱）也能发：官方 `vercel-labs/agent-skills` 的 `deploy-to-vercel` 提供脚本，返回 previewUrl + claimUrl（用户点 claimUrl 把部署收进自己账号）。本配方默认零依赖，需要时另装；**不要**把 claimable 当归档方案——那是孤儿部署，不是路径库。

## 自定义域名（可选）

Project → Settings → Domains。HTTPS 自动；Hobby 每项目允许多个域名（计划文档：Hobby 每项目 50 个域名）。

## 本形态会踩到的限制

| 限制 | 实际影响 |
| --- | --- |
| Hobby 非商用 | 工作 deck / 客户交付物 → 用 Pro 或其他主机（CF Pages） |
| Hobby 200 项目 | 每次 drop 与每次 CLI/Git 项目都计数；量大时用单项目 + 路径 |
| Drop 从不复用项目 | 更新已分享文档要用 CLI/Git；新 drop = 新 URL |
| 每天 100 次部署（Hobby） | 人手足够；激进自动化会紧 |
| CLI 上传 100 MB（Hobby） | 大资源树可能失败；去掉二进制或改用 Git |

## 不要

- 未核对当前计划条款就把商用材料放在 Hobby 上。
- 把 Drop 推荐成每天几十个 AI 文档的长期仓库。
- 部署后 curl 部署 URL「验活」——直接给用户链接即可（CLI 返回的 URL 即结果）。
- 用 claimable 孤儿部署冒充长期归档。

## 延伸（可选，默认零依赖）

需要 agent 全自动状态机（团队选择、claimable、CI token）时，可另装官方 `vercel-labs/agent-skills` 的 `deploy-to-vercel`。本配方自包含。
