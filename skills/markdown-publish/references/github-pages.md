# GitHub Pages（本 skill 的默认主机）

站点三条路径共用。官方：[About Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/about-github-pages) · [Limits](https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits)

免费 Pages **要求公开仓库**。项目站 URL 是 `https://<owner>.github.io/<repo>/`，资源必须用相对路径（Docsify 用 hash，不受影响；MkDocs 靠 `site_url`；Quartz 靠 `baseUrl`）。

```bash
command -v gh && gh auth status
git remote get-url origin
OWNER=$(gh repo view --json owner -q .owner.login)   # 仓库属主，可能是 org，不要用 gh api user
REPO=$(gh repo view --json name -q .name)
BRANCH=$(git branch --show-current)
```

还没有 GitHub 仓库时，过门槛后再：

```bash
gh repo create <repo-name> --public --source=. --remote=origin --push
```

## 设定发布源（三条路径共用的函数）

GitHub REST 要的是嵌套对象 `source: {branch, path}`。`gh api -f source='{"branch":…}'` 会把整段当**字符串**发出去，服务端 422 —— 必须用 `key[subkey]=value`。已开通时 POST 会 409，所以先 GET 判断走 PUT 还是 POST：

```bash
set_pages_source() {   # 用法: set_pages_source <branch> </ 或 /docs>
  local branch="$1" path="$2" method=POST
  gh api "repos/$OWNER/$REPO/pages" >/dev/null 2>&1 && method=PUT
  gh api "repos/$OWNER/$REPO/pages" -X "$method" \
    -f build_type=legacy \
    -f "source[branch]=$branch" \
    -f "source[path]=$path"
  echo "pages source: $branch $path ($method)"
}
```

PUT 成功返回空（204），POST 返回 JSON；两者都不报错就算设好。`path` 只允许 `/` 或 `/docs`。

## A. 分支 + 目录（Docsify）

静态文件已在 `main`（或当前分支）的 `/docs` 或仓库根。

```bash
# 先提交壳 + 内容并 push
git add -- <清单>
git commit -m "<why>"
git push -u origin HEAD

set_pages_source "$BRANCH" /docs    # 壳在仓库根则改 /
```

`_` 开头的文件必须有 `.nojekyll`（Docsify 配方已写）。

## B. MkDocs 已跑 `gh-deploy`

`mkdocs gh-deploy` 会推 `gh-pages` 分支，但**不会**替你把 Pages 源指过去：

```bash
set_pages_source gh-pages /
```

## C. 把构建目录推到 `gh-pages`（Quartz `public/`）

只推产物，不把整个 Node 工程的 `node_modules` 送上 Pages：

```bash
ORIGIN=$(git remote get-url origin)
STAGE=$(mktemp -d)
cp -R public/. "$STAGE/"
touch "$STAGE/.nojekyll"
git -C "$STAGE" init
git -C "$STAGE" checkout -b gh-pages
git -C "$STAGE" add .
git -C "$STAGE" commit -m "deploy pages"
git -C "$STAGE" remote add origin "$ORIGIN"
git -C "$STAGE" push -f origin gh-pages
rm -rf "$STAGE"

set_pages_source gh-pages /
```

`-f` 推 `gh-pages` 只在该分支专用于站点时用；先告诉用户。

## 验链

```bash
URL=$(gh api "repos/$OWNER/$REPO/pages" --jq .html_url)   # 通常 https://$OWNER.github.io/$REPO/
for i in 1 2 3 4 5 6 7 8 9; do
  code=$(curl -sI -o /dev/null -w '%{http_code}' -L --max-time 20 "$URL")
  echo "try $i: $code"
  [ "$code" = 200 ] && break
  sleep 20
done
[ "$code" = 200 ] || gh api "repos/$OWNER/$REPO/pages/builds/latest" --jq '{status,error}'
```

首次开通一般 1–3 分钟；`status: built` 但仍 404 再等一轮 CDN。完成标准：`200` 并把 URL 交给用户。9 次仍失败：报告 latest build 的 `status/error`，不要假装已上线。

可选：把 URL 写进仓库 About：

```bash
gh api --method PATCH "repos/$OWNER/$REPO" --field homepage="$URL"
```

## 会踩到的限制

| 限制 | 影响 |
| --- | --- |
| 免费档要公开仓库 | 私有仓库 Pages 需付费计划；本 skill 默认 `--public` |
| 每仓库一个站 | 不要为每篇笔记新建仓库 |
| 软上限 | 站约 1 GB、带宽约 100 GB/月；不要承诺无限 |

用户要 Cloudflare / Vercel / Netlify / Surge：构建目录就绪后转 `static-html-publish`，不要在这里再写一套主机菜单。
