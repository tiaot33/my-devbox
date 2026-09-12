# JotBird

单页 Markdown：渲染层比 Gist 全（callout、Mermaid、KaTeX、脚注、`[TOC]`）。免费档链接 **90 天**、默认 Unlisted（凭 URL 能看、不进搜索）。

官方：[CLI](https://www.jotbird.com/cli) · [API](https://www.jotbird.com/docs/api) · [Help / 语法](https://www.jotbird.com/help)

适用：一篇或几篇合成**一页**。  
不适用：要侧栏的目录树 → Docsify。要挂在自己 GitHub 上 → Gist。

网页可以匿名发（30 天），但 agent 闭环不了那个按钮。这里只走 CLI。

## 探测

```bash
test -s "$HOME/.config/jotbird/credentials" && echo jotbird:ok || echo jotbird:missing
```

CLI 只读这个文件，**不读 `JOTBIRD_API_KEY`**。missing → [INSTALLS.md](INSTALLS.md)：有密钥就落盘，没密钥就后台 `login` + 轮询。不要改走网页粘贴。

## 发布

过 SKILL「发布门槛」后再跑。门槛里写明：Unlisted、90 天、凭 URL 即可见。

**就地发布原文件**，不要把内容拼进 `/tmp` 再发——CLI 按该文件所在目录解析相对图（`src/images.js`）。`cd` 到文件所在目录再发：`.jotbird` 文件名→slug 映射写在 **cwd**，跟文件放一起下次才更新得到同一 URL。

```bash
FILE=/绝对路径/note.md
ERR=$(mktemp)
OUT=$(cd "$(dirname "$FILE")" && npx -y jotbird publish "$(basename "$FILE")" 2>"$ERR")
echo "$OUT"; cat "$ERR"
URL=$(printf '%s\n' "$OUT" | command grep -o 'https://share.jotbird.com/[^ ]*' | tail -1)
[ -n "$URL" ] || { echo "没拿到 URL"; exit 1; }
command grep -E 'Skipping|Failed to upload|failed' "$ERR" && echo "有图没上去，交付时要说" 
```

stdout 形如 `✨ Published → https://share.jotbird.com/<slug>`（更新时是 `✓ Updated → …`），后面可能跟一行 `Expires <日期>`。几篇都有图：各发各的，不要合成一页。几篇都无图才允许拼成一页。

不要给新文档加 `--slug`：slug 只用来更新**已有**页；乱传会被忽略并另开随机 slug。免费档限 10 篇在线、10 次/小时，`Publish failed` 带 429 就是撞了。

图片（CLI 源码，不是 README）：只匹配 `![alt](path)`；上传 png/jpeg/gif/webp、单张 ≤10MB，发布稿改成托管 URL，**原文不动**。`https://` 外链不改。`![[wikilink]]`、`<img src>`、**SVG**（服务端拒收，README 写支持是错的）会原样留下本地路径，线上裂图。上传失败只打警告，发布仍继续——所以上面必须 grep stderr。REST API 不传图。

## 验链

```bash
curl -sI -o /dev/null -w '%{http_code}\n' -L --max-time 20 "$URL"
# 有图时再抽一张验：页面源码里不该残留本地路径
curl -sL --max-time 20 "$URL.md" | command grep -n '](\./\|](\.\./\|](/Users/' && echo "仍有本地图路径"
```

完成标准：HTTP 200、`$URL.md` 里没有本地图路径，把 URL 交给用户。

## 撤

```bash
npx -y jotbird remove <slug>
```

`<slug>` 来自 URL 最后一段，或 `npx -y jotbird list`；在原目录里也可直接传文件名（走 `.jotbird` 映射）。不可恢复。
