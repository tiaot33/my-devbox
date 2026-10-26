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
        nameLink: "/",
        loadSidebar: true,
        relativePath: true,
        subMaxLevel: 3,
        homepage: "README.md",
        alias: {
          "/.*/_sidebar.md": "/_sidebar.md"
        }
      };
    </script>
    <script src="https://cdn.jsdelivr.net/npm/docsify@5"></script>
  </body>
</html>
```

要 v4 的老外观就在 core 之后再加一行 `docsify@5/dist/themes/addons/vue.min.css`。要站内搜索加 `docsify@5/dist/plugins/search.min.js` 并在配置里加 `search: 'auto'`。

没有 `README.md` 时：把 `homepage` 改成实际首页文件名（如 `index.md`），或把用户指定的那篇复制为 `README.md`（复制，不改原名文件）。

`.nojekyll`：空文件。GitHub Pages 否则会丢掉 `_sidebar.md`。

`_sidebar.md`：链接一律 `/` 开头的站点根路径。有子目录就按文件夹分组，章节行链到该章第一篇（纯文本章节名会被当成 `章/README`）。取正文第一个 `# 标题` 作显示名：

```bash
python3 - <<'PY'
from pathlib import Path
root = Path(".")

def heading(p: Path) -> str:
    for line in p.read_text(encoding="utf-8", errors="replace").splitlines():
        s = line.strip()
        if s.startswith("# "):
            return s[2:].strip()
    return p.stem

def articles(d: Path):
    return sorted(
        p for p in d.glob("*.md")
        if not p.name.startswith("_") and p.name != "README.md"
    )

lines = ["- [Home](/README.md)"] if (root / "README.md").exists() else []
for p in articles(root):
    lines.append(f"- [{heading(p)}](/{p.name})")
for d in sorted(p for p in root.iterdir() if p.is_dir() and not p.name.startswith(".")):
    files = articles(d)
    if not files:
        continue
    first = files[0].relative_to(root).as_posix()
    lines.append(f"- [{d.name}](/{first})")
    for p in files:
        rel = p.relative_to(root).as_posix()
        lines.append(f"  - [{heading(p)}](/{rel})")
Path("_sidebar.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"wrote {len(lines)} sidebar entries")
PY
```

`relativePath: true` 只解析**正文**里的相对链接/图片。壳链接（侧栏、自己写的首页 TOC）写成 `/章/篇.md`：hash 路由下这是 `#/章/篇`，不是域根 HTTP。图的 `src` 才是真实 HTTP——项目站（`/<repo>/`）用相对路径，图文件和 `.md` 一起进站点根再部署。外链图可以。

## 本地预览

```bash
( python3 -m http.server 3000 --directory . >/dev/null 2>&1 & echo $! > /tmp/docsify.pid )
sleep 1
curl -s http://127.0.0.1:3000/ | grep -c 'docsify@5'      # 壳在
curl -sI -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3000/_sidebar.md   # 200
curl -sI -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3000/README.md     # 200（或你的 homepage）
bad=$(command grep -E '^\s*- \[.*\]\([^)]+\)' _sidebar.md | command grep -vE '\]\(/' || true)
[ -z "$bad" ] || { echo "FAIL: sidebar link not root-absolute"; echo "$bad"; }
```

三条 200、侧栏条目 > 0、侧栏 markdown 链接全是 `/` 开头。有子目录时再点一次路由：从章 A 一篇点到章 B，`location.hash` 是 `#/章B/…`，不能含章 A。有浏览器工具就点；否则用系统 Chrome + `puppeteer-core` 点侧栏文本。扁平目录（所有 `.md` 都在站点根）到 `/` 检查即可，然后 `kill "$(cat /tmp/docsify.pid)"`。再谈上线。

## 上线

过「发布门槛」。部署站点根（含壳 + `.md` + 图片）到 GitHub Pages：源在 `docs/` 就用 Pages 的 `/docs`；壳加在仓库根就用 `/`。

读 [github-pages.md](github-pages.md)：先定义 `set_pages_source`，再跑 **A. 分支 + 目录**，最后验链。

预期 URL：`https://<owner>.github.io/<repo>/`（hash 路由，如 `/#/guide`）。Pages 只返回静态文件，`curl` 200 只证明 `index.html` 在线；再 `curl -sI "${URL}_sidebar.md"` 看 200，证明 `.nojekyll` 生效。轮询到线上 `_sidebar.md` 链接已是 `/` 开头、`index.html` 含 `alias`（CDN 可能先吐旧壳）。有子目录则对线上 URL 再做一次跨章点击，hash 仍不得叠目录。

## 限制（只在相关时说）

- 无预渲染，SEO 弱。用户要预渲染 / 搜索 → 改 MkDocs。
- 不要承诺 Docsify 与 CommonMark 100% 一致。
