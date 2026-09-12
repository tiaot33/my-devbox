# 仓库视图

把 `.md` 推进 GitHub，用平台自己的渲染页。不建站点、不加框架。

官方：[About READMEs](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes) · [GFM](https://github.github.com/gfm/)

适用：文件已在或即将进入一个 Git 仓库，用户只要「打开就能看」。  
不适用：要侧栏 / 搜索 → Docsify 或 MkDocs。

## 探测

```bash
command -v gh && gh auth status
git rev-parse --show-toplevel 2>/dev/null
git remote get-url origin 2>/dev/null
git branch --show-current
```

未登录 → [INSTALLS.md](INSTALLS.md)，停下。

## 已有 GitHub remote

1. 确认要发布的 `.md` 已在工作区（相对链接、图片按仓库路径放好）。
2. 过「发布门槛」（亮 `git status`，查敏感）。
3. 提交并推送：

```bash
git add -- <只加清单里的文件>
git commit -m "<why>"
git push -u origin HEAD
```

不要 `git add .`，除非清单就是整棵工作区且用户确认过。

4. 让 `gh` 拼 URL（不要手拼 owner/repo；ssh 形式的 remote 也能解析）：

```bash
BRANCH=$(git branch --show-current)
URL=$(gh browse -n -b "$BRANCH" <相对仓库根的路径>.md)
echo "$URL"    # https://github.com/<owner>/<repo>/blob/<branch>/<path>.md
```

要 owner/repo 本身时用 `gh repo view --json nameWithOwner -q .nameWithOwner`。README 在 `.github/`、仓库根或 `docs/` 会自动当仓库首页，可给 `gh repo view --json url -q .url`。

## 还没有仓库

过门槛后：

```bash
git init    # 已是 git 仓库则跳过
git add -- <清单>
git commit -m "<why>"
gh repo create <repo-name> --public --source=. --remote=origin --push
URL=$(gh browse -n <相对仓库根的路径>.md)
```

`gh repo create --source=.` 在已有 `origin` 时会报错；先 `git remote get-url origin` 看一眼，有就走上一节。免费 GitHub Pages 不是这条路径的一部分；这里只需要公开仓库。私有仓库渲染页仅协作者能看——用户要私有时改 `--private`，并说明「不是公开分享」。

## 验链

```bash
curl -sI -o /dev/null -w '%{http_code}\n' -L --max-time 20 "$URL"
```

刚建的仓库偶尔前几秒 404，重试一次再下结论。

完成标准：200，把 blob URL 交给用户。README 也可给仓库根 URL。

## 限制（只在相关时说）

- 方言是 GFM；原始 HTML 会被清洗。
- README > 500 KiB 截断。
- 相对图片：官方要求图和 `.md` 一起在仓库里，用相对路径（`./`、`../` 或仓库根 `/`）；GitHub 按当前分支重写。本机绝对路径裂图。外链图可以。
