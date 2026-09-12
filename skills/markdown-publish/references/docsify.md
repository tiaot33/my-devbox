# Docsify

无构建：浏览器打开 `index.html` 再 fetch `.md`。正文保持原样，只加壳。

官方：[Quick start](https://docsify.js.org/#/quickstart) · [Deploy](https://docsify.js.org/#/deploy)

对源文件：加 `index.html`、`_sidebar.md`、`.nojekyll`。不要改现有 `.md`，不要用 `:include`。

## 探测

```bash
command -v gh && gh auth status
git remote get-url origin 2>/dev/null
```

未登录且要上线 → [INSTALLS.md](INSTALLS.md)，停下。本地先搭壳可以继续。

## 放壳（不要全局装 docsify-cli）

源是一棵笔记目录时，**就地**加壳，不要整树复制。已有 `docs/` 就以它为站点根。

在站点根写入三个文件。

`index.html`（完整可用，不要留 `//...`；当前主版本是 docsify **5**，主题路径变了，不要再写 `docsify@4/themes/vue.css`）：

```html
<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
    <title>Notes</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/docsify@5/dist/themes/core.min.css" />
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/docsify@5/dist/themes/addons/core-dark.min.css" media="(prefers-color-scheme: dark)" />
  </head>
  <body class="loading">
    <div id="app"></div>
    <script>
      window.$docsify = {
        name: "Notes",
        loadSidebar: true,
        relativePath: true,
        subMaxLevel: 3,
        homepage: "README.md"
      };
    </script>
    <script src="https://cdn.jsdelivr.net/npm/docsify@5"></script>
  </body>
</html>
```

要 v4 的老外观就在 core 之后再加一行 `docsify@5/dist/themes/addons/vue.min.css`。要站内搜索加 `docsify@5/dist/plugins/search.min.js` 并在配置里加 `search: 'auto'`。

没有 `README.md` 时：把 `homepage` 改成实际首页文件名（如 `index.md`），或把用户指定的那篇复制为 `README.md`（复制，不改原名文件）。

`.nojekyll`：空文件。GitHub Pages 否则会丢掉 `_sidebar.md`。

`_sidebar.md`：按站点根生成扁平列表：

```bash
python3 - <<'PY'
from pathlib import Path
root = Path(".")
lines = []
readme = root / "README.md"
if readme.exists():
    lines.append("- [Home](README.md)")
for p in sorted(root.rglob("*.md")):
    if p.name.startswith("_") or p.name == "README.md":
        continue
    rel = p.as_posix()
    lines.append(f"- [{p.stem}]({rel})")
Path("_sidebar.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"wrote {len(lines)} sidebar entries")
PY
```

`relativePath: true` 是硬要求：默认按站点根解析，会把用户原来的相对链接/图片弄断。图文件必须和 `.md` 一起进站点根再部署，不要只推 md。项目站（`/<repo>/`）不要写以 `/` 开头的图路径，会打到域根 404。外链图可以。

## 本地预览

```bash
( python3 -m http.server 3000 --directory . >/dev/null 2>&1 & echo $! > /tmp/docsify.pid )
sleep 1
curl -s http://127.0.0.1:3000/ | grep -c 'docsify@5'      # 壳在
curl -sI -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3000/_sidebar.md   # 200
curl -sI -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3000/README.md     # 200（或你的 homepage）
kill "$(cat /tmp/docsify.pid)"
```

无头环境验不了 JS 渲染，三条 200 + 侧栏条目数 > 0 就算壳没写错；有浏览器工具时再截一张首页。完成标准：三个探针通过。再谈上线。

## 上线

过「发布门槛」。部署站点根（含壳 + `.md` + 图片）到 GitHub Pages：源在 `docs/` 就用 Pages 的 `/docs`；壳加在仓库根就用 `/`。

读 [github-pages.md](github-pages.md)：先定义 `set_pages_source`，再跑 **A. 分支 + 目录**，最后验链。

预期 URL：`https://<owner>.github.io/<repo>/`（hash 路由，如 `/#/guide`）。Pages 只返回静态文件，`curl` 200 只证明 `index.html` 在线；再 `curl -sI "${URL}_sidebar.md"` 看 200，证明 `.nojekyll` 生效、下划线文件没被 Jekyll 吃掉。

## 限制（只在相关时说）

- 无预渲染，SEO 弱。用户要预渲染 / 搜索 → 改 MkDocs。
- 不要承诺 Docsify 与 CommonMark 100% 一致。
