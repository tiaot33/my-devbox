# MkDocs

构建期把 `.md` 编成静态站，自带搜索。默认主题 Material。

官方：[Getting started](https://www.mkdocs.org/getting-started/) · [Deploy](https://www.mkdocs.org/user-guide/deploying-your-docs/) · [Material](https://squidfunk.github.io/mkdocs-material/)

对源文件：加 `mkdocs.yml` 和 `.venv/`（不提交）。**不要** `mkdocs new` 覆盖已有笔记。页面正文保持普通 Markdown。

## 探测

```bash
command -v gh && gh auth status
git remote get-url origin 2>/dev/null
python3 -c "import sys; print(sys.version)"
```

缺 Python / 未登录 → [INSTALLS.md](INSTALLS.md)。

## 就地配置

在仓库根（或用户指定的项目根）建 venv 并安装：

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install mkdocs-material
for p in .venv site; do grep -qxF "$p" .gitignore 2>/dev/null || echo "$p" >> .gitignore; done
```

已有一棵笔记目录就**指向它**，不要复制：

```yaml
site_name: <站点名>
site_url: https://<owner>.github.io/<repo>/
docs_dir: <笔记目录相对路径>
theme:
  name: material
```

笔记就在仓库根、和代码混在一起时：只把用户点名的 `.md` 与其相对图片放进 `docs/`，写进门槛清单。不要把整个代码树当 `docs_dir`。

省略 `nav:` —— MkDocs 按文件树自动出导航。用户点名了顺序再手写 `nav`。

`site_url` 必须是项目站的最终 URL（含 `/<repo>/`），否则 CSS/搜索在 Pages 子路径下会 404。

## 本地预览

```bash
. .venv/bin/activate
mkdocs build --strict          # 坏链接 / 缺文件在这里就报，别等 Pages 上线才发现
( mkdocs serve >/tmp/mkdocs.log 2>&1 & echo $! > /tmp/mkdocs.pid )
sleep 3
curl -sI -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8000/          # 200
curl -s http://127.0.0.1:8000/search/search_index.json | grep -c '"title"' # > 0，说明搜索索引在
kill "$(cat /tmp/mkdocs.pid)"
```

`mkdocs serve` 是前台进程，必须后台起、探完就杀。完成标准：`build --strict` 无 error、首页 200、搜索索引非空。再谈上线。

## 上线

先把 **源**（`mkdocs.yml`、`docs_dir` 里的文件、`.gitignore`）按仓库视图那样提交并保证 `origin` 指向 GitHub。`mkdocs gh-deploy` 会把**未跟踪文件也打进站点**——门槛清单必须干净。

```bash
. .venv/bin/activate
git status --porcelain          # 必须为空：gh-deploy 会把未跟踪文件也打进站点
mkdocs gh-deploy --force --no-history
```

`gh-deploy` 构建并把 `site/` 推到 `gh-pages` 分支（`--no-history` 只保留一个提交，避免分支无限长大），但**不会**改仓库的 Pages 设置。然后读 [github-pages.md](github-pages.md)：定义 `set_pages_source`，跑 **B**（`gh-pages` + `/`），再验链。`site/` 是构建产物，和 `.venv` 一样写进 `.gitignore`，不要提交。

不要手改 `gh-pages` 上的文件（下次 deploy 会盖掉）。

预期 URL：`https://<owner>.github.io/<repo>/`

## 限制（只在相关时说）

- 解析器是 Python-Markdown，不是 CommonMark。
- 源里的 `.md` 相对链接构建时会改写成 HTML 链接；搬走站点后这些链接仍是可读 Markdown。
- 图片：放在 `docs_dir` 里（官方例 `docs/img/screenshot.png` + `![x](img/screenshot.png)`），构建时原样拷进站点。图在 `docs_dir` 外不会被带上。外链图可以。
