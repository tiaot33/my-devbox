# GitHub Pages — 发布配方

官方：[About Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/about-github-pages) · [限制](https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits) · [HTTPS](https://docs.github.com/en/pages/getting-started-with-github-pages/securing-your-github-pages-site-with-https) · [自定义域名](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site)

上次核实：2026-07。

## 何时读本文件

SKILL 选型表指向 GitHub Pages 时：HTML（或静态构建产物）已在 GitHub 仓库，做文档/项目站，不想再开托管账号。不适合商业交易或 SaaS 主用途（见 GitHub Pages 使用限制）。

## 状态探测（发布前）

```bash
command -v gh && gh auth status     # gh CLI 可用且已登录?
git remote get-url origin 2>/dev/null   # 已有关联 GitHub 仓库?
```

- 仓库已存在 → UI 开 Pages（A）或 Actions（B）。
- 从零开始 + 有 `gh` → 一条命令链建仓库 + 开 Pages（C）。

## 两种站点与 base path（先搞清）

| 类型 | URL | 上限 |
| --- | --- | --- |
| 用户/组织站 | `https://<owner>.github.io/` | 每用户或组织**一个**（仓库名必须是 `<owner>.github.io`） |
| 项目站 | `https://<owner>.github.io/<repo>/` | **每个仓库一个** |

**项目站挂在 `/<repo>/` 子路径下**：HTML 里的绝对路径（`/assets/...`、`/d/...`）会指向域根而 404。站内一律用相对链接——这与路径库纪律一致。要根路径就用用户/组织站或自定义域名。

## A. 从分支发布（纯静态最简单）

1. 静态文件放进某分支（`main` 或 `gh-pages`）的根目录或 `/docs`。
2. 仓库 → **Settings** → **Pages** → Source：**Deploy from a branch** → 选分支 + 文件夹。
3. 保存，等绿勾（1–2 分钟）。打开 `https://<owner>.github.io/<repo>/`。

纯 HTML 不需要 Jekyll；若有 `_` 开头的文件/目录要被原样服务，在发布根加空文件 `.nojekyll`。

## B. GitHub Actions（CI 生成 HTML / 要部署历史）

1. Settings → Pages → Source：**GitHub Actions**。
2. 提交 `.github/workflows/deploy-pages.yml`（官方静态站最小模板）：

```yaml
name: Deploy to GitHub Pages
on:
  push:
    branches: [main]
  workflow_dispatch:
permissions:
  contents: read
  pages: write
  id-token: write
concurrency:
  group: pages
  cancel-in-progress: false
jobs:
  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/configure-pages@v5
      - uses: actions/upload-pages-artifact@v3
        with:
          path: ./site        # 含 index.html 的目录
      - id: deployment
        uses: actions/deploy-pages@v4
```

3. push 后 Actions 跑完即更新；部署 URL 在 job 输出里。

## C. gh CLI 一把梭（从零到上线）

**高风险，先过 SKILL 的「发布门槛」**：`git add .` 会把当前目录**所有**文件收进提交，`--public` 让仓库全网可见——免费 Pages 没有私有选项。先 `git status` 亮清单、查敏感文件，用户明确确认后再执行。

```bash
# 未登录则停，把下一行交给用户：gh auth login
git init && git add . && git commit -m "Initial commit"
gh repo create <repo-name> --public --source=. --push

OWNER=$(gh api user --jq '.login')
# source 必须是对象。-f source='{"branch":...}' 会把 JSON 当字符串发出去，API 422。
gh api repos/$OWNER/<repo-name>/pages -X POST --input - <<'EOF'
{"build_type":"legacy","source":{"branch":"main","path":"/"}}
EOF

# 把 live URL 写回仓库 About 栏（可选但好用）
gh api --method PATCH repos/$OWNER/<repo-name> \
  --field homepage="https://$OWNER.github.io/<repo-name>/"
```

- 预期 URL：`https://<owner>.github.io/<repo>/`，1–2 分钟生效；之后每次 push 自动重建。
- 查状态：`gh api repos/$OWNER/<repo>/pages/builds/latest`。
- 免费 Pages 要求**公开**仓库（私有仓库 Pages 需付费 GitHub 计划）；API 开通失败就回 A 的 UI 手动开。

## 路径库

与其他平台同思路：一个仓库，多条路径 `d/<id>/index.html`。**不要**每生成一个 AI HTML 就新建仓库——除非用户明确要各自独立的项目 URL。单仓库整树推送，文档天然挂在 `/<repo>/d/<id>/` 下。

## 自定义域名（可选）

Settings → Pages → Custom domain → 按文档配 DNS（A/ALIAS/CNAME）。DNS 验证通过后开 **Enforce HTTPS**。配了自定义域名后 base path 问题消失（站回到域根）。

## 本形态会踩到的限制

| 限制 | 实际影响 |
| --- | --- |
| 每仓库 1 个站 | monorepo 库没问题；「每个碎 HTML 一个仓库」很糟 |
| 软上限：站 ≤ 1 GB、约 100 GB/月带宽、非 Actions 约 10 次构建/小时、部署超时 10 分钟 | 大流量或高频重建要另上 CDN/主机 |
| 允许用途 | 不能作为主要商业交易 / SaaS 托管 |

## 不要

- 把结账流程或商业 SaaS 落地页的主站推荐成 Pages。
- 承诺硬性无限带宽。
- 项目站里写绝对路径资源引用（base path 会咬人）。
- 未经用户确认就 `git add .` + `gh repo create --public --push`——整个目录被公开，事后删除也难收回。
- 用 `-f source='{"branch":"main","path":"/"}'` 开 Pages——`source` 会变成字符串，API 拒收。

## 延伸（可选，默认零依赖）

GitHub 无官方 Pages skill；社区可参考 `julianobarbosa` 的 github-pages skill（QuickStart / 自定义域名 / Jekyll / 排障分 workflow）。本配方自包含。
