# Quartz

把 **Obsidian 库**编成静态站。原文库不动，**copy** 进独立的 Quartz 工程。

没有 `.obsidian/`、也不是一棵带大量页面 wikilink 的库，就不要走这条。散篇上的 `![[图]]` / 单个 callout 回 SKILL 第 2 步：改写或 Docsify / 仓库视图。

官方：[Installation](https://quartz.jzhao.xyz/getting-started/installation) · [create](https://quartz.jzhao.xyz/cli/create) · [build](https://quartz.jzhao.xyz/cli/build) · [Hosting](https://quartz.jzhao.xyz/hosting)

需要 Node ≥ 22、npm ≥ 10.9。当前是 Quartz **v5**（默认分支 `v5`，配置文件 `quartz.config.yaml`，插件走 `npx quartz plugin install`）；网上大量 v4 教程写的 `quartz.config.ts` / 分支 `v4` 已过时。交互式 `npx quartz create` **不要裸跑**（会等键盘）；四个 flag 都给全就不会提问。

## 探测

```bash
node -v          # 必须 ≥ 22
command -v gh && gh auth status
git remote get-url origin 2>/dev/null
ls -d <库根>/.obsidian 2>/dev/null
```

Node 不够或未登录 → [INSTALLS.md](INSTALLS.md)，停下。

## 建工程（在库外面）

不要在 vault 里 clone。旁挂一个目录，例如 `<库的父目录>/quartz-site`：

```bash
git clone https://github.com/jackyzha0/quartz.git quartz-site   # 不要 --depth 1，Quartz 用 git 历史算日期
cd quartz-site
npm i
```

先定仓库名与 Pages 地址，再 create（`baseUrl` **不要** `https://`，项目站必须带 `/<repo>`；`obsidian` 模板自动用 `shortest` 链接解析，不会再问）：

```bash
npx quartz create \
  --template obsidian \
  --strategy copy \
  --source /绝对路径/到/vault \
  --baseUrl <owner>.github.io/<repo>
npx quartz plugin install --from-config
grep -n baseUrl quartz.config.yaml      # 核对写进去了
```

`--strategy copy`：不碰原库，连附件目录一起拷进 `content/`。未经用户明确要求不要用 `symlink`。图要在被 copy 的库里：`![](相对路径)` 与 `![[image.png]]` 都靠默认 Assets 插件发出去。外链图可以。`create` 顺手会加一个 `upstream` remote 指向官方仓库（升级用），`origin` 仍指向 jackyzha0/quartz，上线前要换。

## 本地预览

```bash
npx quartz build
test -s public/index.html && ls public | head
# 抽一篇：content/<某篇>.md 应对应 public/<某篇>.html
( npx quartz build --serve >/tmp/quartz.log 2>&1 & echo $! > /tmp/quartz.pid )
sleep 8
curl -sI -o /dev/null -w '%{http_code}\n' http://localhost:8080/    # 200
kill "$(cat /tmp/quartz.pid)"
```

`--serve` 是前台进程，后台起、探完就杀。完成标准：`public/index.html` 存在，本地首页 200，随便一篇笔记有对应 `.html`。再谈上线。

## 上线

Quartz 工程本身要进 GitHub。`origin` 目前指向 jackyzha0/quartz，`gh repo create --source=.` 遇到已有 `origin` 会拒绝，先摘掉：

```bash
git remote remove origin
gh repo create <repo> --public --source=. --remote=origin --push   # 推的是当前分支 v5
```

先过「发布门槛」：清单是 **quartz-site 工程**（含 `content/` 副本），不是整个原库的隐藏文件。工程自带的 `.gitignore` 已排除 `public/`、`.obsidian`、`.quartz/`、`private/`，`.gitignore` 已忽略的不要强行 add；但要看一眼 `content/` 里有没有原库的私密笔记跟着 copy 进来了。

然后读 [github-pages.md](github-pages.md)：定义 `set_pages_source`，跑 **C. 把构建目录推到 gh-pages**（目录 `public/`）。Quartz 输出的是 `file.html` 而不是 `file/index.html`，Pages 不做尾斜杠重定向，验链时用不带尾斜杠的笔记 URL。

预期 URL：`https://<owner>.github.io/<repo>/`

用户想要「push 即部署」时改走官方 Actions：把 [Hosting](https://quartz.jzhao.xyz/hosting) 里的 `deploy.yml` 写进 `.github/workflows/`，然后 `gh api "repos/$OWNER/$REPO/pages" -X POST -f build_type=workflow`（已存在则 `-X PUT`），再 `npx quartz sync --no-pull`。这条会消耗 Actions 分钟数，默认不走。

更新站点：在原库改笔记 → 再 `npx quartz create ... --strategy copy` 会覆盖 `content/`，或直接把变更文件拷进 `content/` → `npx quartz build` → 再跑一次 C。

## 限制（只在相关时说）

- wikilink / callout 只在 Quartz 里有完整意义，不是可移植 GFM。
- 官方 Publish（`publish.obsidian.md`）是付费应用内操作，本 skill 不驱动 Obsidian UI。
