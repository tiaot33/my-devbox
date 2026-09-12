# 安装（探测失败才读）

`gh` 只给 Gist / 仓库视图 / GitHub Pages 用。JotBird 要 Node + 一次登录。站点路径另外需要 Python（MkDocs）或 Node 22+（Quartz）。

## JotBird

需要 Node 18+。不要全局乱装。CLI（`src/config.js`）**只读** `~/.config/jotbird/credentials`，不认 `JOTBIRD_API_KEY`。

**已有 `jb_...` 密钥**（环境变量、用户口述、其他机器拷来）→ 直接落盘，不必 login：

```bash
mkdir -p "$HOME/.config/jotbird"
( umask 077; printf '%s\n' "$JOTBIRD_API_KEY" > "$HOME/.config/jotbird/credentials" )
npx -y jotbird list >/dev/null && echo jotbird:ok    # 401 说明密钥不对
```

**没有密钥** → 后台跑 login，agent 轮询文件出现，不要前台挂着等：

```bash
CRED="$HOME/.config/jotbird/credentials"
LOG=$(mktemp)
( npx -y jotbird login </dev/null >"$LOG" 2>&1 & )
sleep 3; cat "$LOG"        # 见 "Opening browser to log in..." 说明浏览器已弹；只有弹失败时才会打印 URL，届时把它给用户
for i in $(seq 1 60); do test -s "$CRED" && break; sleep 5; done
test -s "$CRED" && echo jotbird:ok || { echo "login 未完成"; cat "$LOG"; }
```

原理：`login` 起一个 `127.0.0.1` 回调服务并打开 `https://www.jotbird.com/account/api-key?callback=...`，用户在浏览器登录/授权后密钥自动回写（0600），5 分钟超时。stdin 给 `/dev/null` 是为了跳过「粘贴 token」的 readline，不影响回调。没有账号就先在 [jotbird.com](https://www.jotbird.com) 免费注册。

## GitHub CLI

```bash
command -v gh || brew install gh
gh auth status
```

未登录 / token invalid → **非交互 device flow**，后台跑，把一次性码交给用户，agent 轮询：

```bash
LOG=$(mktemp)
( gh auth login -h github.com -p https -w --skip-ssh-key </dev/null >"$LOG" 2>&1 & )
sleep 3; cat "$LOG"
# 输出形如：
#   ! First copy your one-time code: XXXX-XXXX
#   Open this URL to continue in your web browser: https://github.com/login/device
# 把这两行原样给用户；stdin 非 TTY 时 gh 不会等回车，只等浏览器授权（约 15 分钟超时）
for i in $(seq 1 90); do gh auth status >/dev/null 2>&1 && break; sleep 10; done
gh auth status
```

只是 token 过期想保留原账号：把 `gh auth login ...` 换成 `gh auth refresh -h github.com`，其余相同。不要改走「让用户去网页建 PAT 再粘贴」来绕过；用户自己主动给 token 时才用 `gh auth login --with-token < file`。

## MkDocs

```bash
python3 -m venv .venv
# gitignore 里应有 .venv
. .venv/bin/activate
pip install mkdocs-material
mkdocs --version
```

不要全局乱装。`.venv` 不要提交。

## Quartz

需要 Node **≥ 22** 与 npm ≥ 10.9：

```bash
node -v
# 不够就用 nvm / 官方安装包，不要降级 Quartz 配方
```

Quartz 工程本身用 `git clone` + `npm i`，见 [quartz.md](quartz.md)。

## Docsify

不装 `docsify-cli`。壳文件手写，本地预览用：

```bash
python3 -m http.server 3000 --directory <docs根>
```
