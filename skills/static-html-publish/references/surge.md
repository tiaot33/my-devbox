# Surge — 发布配方

官方：[surge.sh](https://surge.sh/) · [Plans](https://surge.sh/docs/platform/plans) · [SSL](https://surge.sh/docs/platform/ssl) · [Pricing](https://surge.sh/pricing)

上次核实：2026-07。

## 何时读本文件

SKILL 选型表指向 Surge 时：纯 CLI、大量独立部署、不想被项目数上限卡住。Surge 是「发射管」，不是整洁的长期库——归档场景优先 Cloudflare Pages 路径库。

## 状态探测（发布前，按序）

```bash
which surge                       # 没有则 npm i -g surge（或改用 npx surge）
surge whoami                      # 报错 = 未登录
cat .surge-domain 2>/dev/null     # 本项目上次发布到哪个域名（见「域名记忆」）
```

- `surge login` 是交互式的，**不要替用户跑**。未登录时让用户自己在终端执行一次（30 秒，可同时注册免费账号），登录态持久保存。
- CI / 无人值守：用环境变量 `SURGE_LOGIN`（邮箱）+ `SURGE_TOKEN`（`surge token` 获取）。

## 发布模型（先选一条）

| 模型 | 一条命令 |
| --- | --- |
| 一次性 | `surge ./site <随机名>.surge.sh` |
| 路径库（单域名整树） | `surge ./site mylib.surge.sh`（同域名反复覆盖） |
| Git 原生 | 无 —— Surge 没有 Git 集成；要 push 触发请改走 CF Pages / Netlify / GitHub Pages |

## 部署步骤

1. **确定发布目录**（含 `index.html` 的那层）：

   | 来源 | 输出目录 |
   | --- | --- |
   | 纯 HTML/CSS/JS | 项目根目录 `./` |
   | React (CRA) | `./build` |
   | Vite / Astro | `./dist` |
   | Next.js 静态导出 | `./out` |
   | SvelteKit 静态 | `./build` |
   | Hugo | `./public` |
   | 11ty | `./_site` |

2. **SPA（前端路由）**：复制一份 `200.html`，否则刷新/直达子路径 404：

   ```bash
   cp ./site/index.html ./site/200.html
   ```

3. 发布（先过 SKILL 的「发布门槛」：`*.surge.sh` 公开可访问）：

   ```bash
   surge ./site my-demo.surge.sh
   ```

4. 预期 URL：`https://my-demo.surge.sh`（surge.sh 子域名自带 HTTPS）。

## 域名记忆（重发必做）

首次发布后把域名写进项目，之后重发不再问：

```bash
echo "my-demo.surge.sh" > .surge-domain
grep -qxF '.surge-domain' .gitignore 2>/dev/null || echo '.surge-domain' >> .gitignore
```

重发优先级：用户显式给的域名 > `.surge-domain` > 现场生成（项目名清洗为小写连字符 + `.surge.sh`，太通用则加随机后缀）。用户改了域名就同步更新该文件。

## 常用命令

| 操作 | 命令 |
| --- | --- |
| 发布 / 覆盖更新 | `surge ./dir name.surge.sh` |
| 列出我的部署 | `surge list` |
| 查看某站文件 | `surge files name.surge.sh` |
| 删除某站 | `surge teardown name.surge.sh`（先向用户确认） |
| 回滚上一版 | `surge rollback name.surge.sh` |
| 刷 CDN 缓存 | `surge bust name.surge.sh` |

## 多个独立 URL

```bash
surge ./doc-a random-a.surge.sh
surge ./doc-b random-b.surge.sh
```

Free 不限项目数，这不消耗配额——但命名与清理全靠用户。归档场景下「一个域名 + 路径库」依然更干净。

## 自定义域名（可选）

```bash
surge ./site www.example.com
```

DNS 加 CNAME 指向 `na-west1.surge.sh`（免费档即支持自定义域名）。SSL 见 [SSL 文档](https://surge.sh/docs/platform/ssl)（`surge encrypt`、付费自定义证书）。

## 限制 / 未知项

| 主题 | 说明 |
| --- | --- |
| 项目数 | Free 无限（官方 plans 页） |
| 带宽 GB | Free 宣传「免费使用」；plans 页没有像 CF/Vercel 那样的 GB 表——视为未文档化；不要编数字 |
| 功能 | 密码保护与部分路由需付费计划 |

## 不要

- 替用户执行 `surge login`（交互式，会卡住）；交给用户跑。
- 在没有官方数字时承诺具体免费带宽额度。
- 用户想要可检索归档时，默认「每个 AI 文档一个子域名」（应推荐 CF 上的路径库）。

## 延伸（可选，默认零依赖）

社区 skill `aruntemme/surge-deploy` 与本配方同源（含 preflight 脚本、CI 模板）；本配方已吸收其核心，不依赖安装。
