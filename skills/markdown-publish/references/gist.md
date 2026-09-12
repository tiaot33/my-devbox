# Gist

官方：[Creating gists](https://docs.github.com/en/get-started/writing-on-github/editing-and-sharing-content-with-gists/creating-gists)

适用：一篇或几篇独立 `.md`，只要分享链接。  
不适用：相对图片、子目录、要侧栏 → 有图走 JotBird 或仓库视图；目录树走 Docsify。

`gh gist create` 只上传你列出的文本文件。相对 `![x](./a.png)` 在 Gist 预览里不可靠（无目录树）；网页里往 md 粘贴出的是 GitHub CDN URL，CLI 不会做这一步。外链图可以。

## 探测

```bash
command -v gh && gh auth status
```

未登录 → 不要逼用户注册 GitHub。回 SKILL 改走 [jotbird.md](jotbird.md)；只有用户坚持 Gist 时才读 [INSTALLS.md](INSTALLS.md) 并停在登录。

## 发布

默认 **Secret Gist**（Discover 不列出，**任何人凭 URL 都能看**，也不能改回 secret）。用户明确要可搜索再加 `--public`。

过 SKILL「发布门槛」后再跑：

```bash
# 单文件（文件名必须带 .md，否则没有 Preview）；多文件就多列几个 .md（扁平，没有文件夹）
ERR=$(mktemp)
URL=$(gh gist create --desc "<一句话>" /绝对或相对路径/note.md 2>"$ERR")
cat "$ERR"; echo "$URL"
GIST_ID=$(basename "$URL")
```

进度行（`- Creating gist …` / `✓ Created secret gist …`）走 stderr，**stdout 只有一行 URL**，形如 `https://gist.github.com/<user>/<id>`。ID 是最后一段。

要公开列出时加 `--public`。不要加 `-w`（会抢浏览器焦点，且 URL 不再打到 stdout）。

## 验链

```bash
curl -sI -o /dev/null -w '%{http_code}\n' -L --max-time 20 "$URL"
```

完成标准：HTTP 200，把 URL 交给用户。

## 更新 / 撤

```bash
gh gist edit "$GIST_ID" note.md          # 覆盖同名文件
gh gist delete "$GIST_ID" --yes          # 先拿用户确认；无 TTY 时必须带 --yes
```

`<id>` 可从 URL 取，或 `gh gist list`。
