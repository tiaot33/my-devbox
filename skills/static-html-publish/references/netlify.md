# Netlify — 发布配方

官方：[Pricing](https://www.netlify.com/pricing/) · [Credit 计划](https://docs.netlify.com/manage/accounts-and-billing/billing/billing-for-credit-based-plans/credit-based-pricing-plans/) · [Credits 如何计费](https://docs.netlify.com/manage/accounts-and-billing/billing/billing-for-credit-based-plans/how-credits-work/)

上次核实：2026-07。

## 何时读本文件

SKILL 选型表指向 Netlify 时：连接 Git 的静态站、以后要加表单/函数、能接受 Free 上的 **credit** 计量。项目数较宽裕（credit 计划 **500** 个）。若目标只是免费不限量静态流量 + 路径库，优先 Cloudflare Pages。

## 状态探测（发布前）

- 不要单独预检登录/link 状态——直接跑真实命令（`netlify deploy`），报鉴权错时再让用户 `netlify login`，报 "No site linked" 时再 `netlify link` / `netlify init`。
- 已 link 的目录有 `.netlify/state.json`。**`.netlify` 必须进 `.gitignore`**。
- 有 git remote 且站点已连 Git → 优先 push 触发（A）；无 Git / 原型 → CLI 手发（B）。

## 发布模型（先选一条）

| 模型 | 入口 |
| --- | --- |
| Git 原生（主路径） | UI 或 `netlify init` 连仓库，push 触发（见 A） |
| 一次性 / 原型 | `netlify deploy --dir=.`（draft 预览 URL，见 B） |
| 路径库 | 同一 site 反复 `netlify deploy --dir=site --prod`（见 B + 路径库节） |

## A. Git 持续部署（主路径）

1. 登录 [app.netlify.com](https://app.netlify.com) → **Add new site** → **Import an existing project**（或 CLI `netlify init`）。
2. 连接 GitHub/GitLab/Bitbucket → 选仓库。
3. 纯 HTML 构建设置：Build command 留空；Publish directory = 含 `index.html` 的文件夹（`.`、`public`、`site`）。
4. 部署。生产 URL：`https://<site-name>.netlify.app`。
5. 之后：push 生产分支 → 生产部署；PR → Deploy Preview；其他分支 → branch deploy（默认关，需在设置里开）。

注意 `netlify.toml` 里的构建设置**覆盖** UI 设置——两边都配时以文件为准。

## B. CLI 手发（无 Git / 原型 / 外部 CI）

```bash
npm i -g netlify-cli       # 或 npx netlify
netlify login              # 浏览器 OAuth；CI 见下
netlify deploy --dir=.            # draft：预览 URL
netlify deploy --prod --dir=.     # 生产
```

- 执行前先过 SKILL 的「发布门槛」：draft 与生产 URL 均按链接公开（详见下文 Preview URL 条目）。
- 未 link 的文件夹上首次 `deploy` 会提示创建并 link 新站点（写 `.netlify/state.json`，记得 gitignore）。
- **与 Git CD 的竞态**：站点已连 Git 时，手发的 `--prod` 会被下一次 push **覆盖**。要保住手发版本，在 UI 的 Deploys 里 lock 住已发布部署（Stop auto publishing）。
- **CI 环境**：需同时设 `NETLIFY_AUTH_TOKEN`（User settings → Applications → Personal access tokens）**和** `NETLIFY_SITE_ID`（站点配置里的 Project ID）——只有 token 不知道发往哪个站点，CI 里没有 `.netlify/state.json`。
- **Preview URL 按链接公开**：draft / Deploy Preview / permalink 谁拿到链接谁就能看，别当机密内容存放处；要限制访问去开站点保护（密码 / Team SSO）。

## 路径库

一个 Netlify 站点，多条路径：

```text
site/d/<id>/index.html
```

整树重新 `netlify deploy --dir=site --prod`。500 的项目上限虽比 CF 的 100 宽裕，仍优先路径库，不烧项目槽位。

## 自定义域名（可选）

Site → Domain management → Add domain → 按指示配 DNS。免费 SSL。

## 本形态会踩到的限制

| 行为 | 影响 |
| --- | --- |
| 生产部署消耗 credits | 大型库高频全量重部署会更快耗尽 Free credits |
| 带宽消耗 credits | 下载流量大可能当月暂停 Free team |
| Free 硬上限 | credits 归零后，项目暂停至下周期或升级计划 |
| Secrets 扫描 | 构建成功后若产物里扫到密钥值会**判部署失败**；真泄露要撤密钥，合法值用 `SECRETS_SCAN_OMIT_KEYS` 精确豁免 |

具体 credit 单价（每次部署、每 GB）会变——读当前定价表，不要编数字。若「每天多次重部署不断变大的 HTML 树」，先估算 credits，或优先 **Cloudflare Pages**（静态请求免费不限量）。

## 失败纪律

`netlify` 命令失败时：报告确切错误 + CLI 打印的 deploy log URL + 受影响站点，然后**停**。不要改用 `netlify api` / curl REST API / 读磁盘上的 token 硬推。构建失败的部署不会发布——线上仍是上一版，没有东西可「回滚」，修好重发即可。

## 不要

- 把旧版「100 GB / 300 构建分钟」当成当前 Free 事实——credit 计划已取代那套表述。
- 纯一次性浏览器拖拽场景加载本文件；那种场景用 Vercel Drop 或 CF 上传。
- 在已连 Git 的站点上默默手发 `--prod` 然后被下次 push 冲掉还不告诉用户。

## 延伸（可选，默认零依赖）

需要表单/函数/访问控制时，官方 `netlify/context-and-tools` 技能族（`netlify-deploy`、`netlify-forms`、`netlify-functions` 等）可按需另装。本配方自包含。
