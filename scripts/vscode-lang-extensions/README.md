# 项目扩展组选择器

需要 Python 3，无第三方依赖。

```bash
# 远程执行（在项目目录里）
python3 -B <(wget -qO- https://raw.githubusercontent.com/tiaot33/my-devbox/main/scripts/vscode-lang-extensions/select-extensions.py)

# 本地脚本
python3 -B select-extensions.py
python3 -B select-extensions.py /path/to/project
```

macOS/Linux：方向键移动，空格切换，回车保存，Esc 或 q 取消。
Windows 无 curses 时使用编号菜单。`[x]` 表示主动选择，`[+]` 表示依赖自动包含。
例如选择 Jupyter 会包含 Python；取消 Jupyter 后，未主动选择的 Python 也会移除。

- `select-extensions.py` 顶部的 `GROUPS`：内置分组定义，直接修改这里即可；不再需要外部配置文件或 `--config` 参数。
- 项目 `.vscode/extensions.json`：生成的扩展推荐列表。
- 项目 `.vscode/extension-groups.json`：主动选择和工具生成项记录，再次运行会恢复选择。

首次运行将已有推荐视为手动添加，后续只移除工具生成的推荐。其他字段保留；JSONC 注释会在保存时移除。
若选择与 `unwantedRecommendations` 冲突，停止写入并提示处理。两个项目文件一起提交 Git，就能在另一台电脑恢复选择。

工具只修改推荐列表，不安装扩展、不修改扩展启停或语言设置。在 VS Code 中搜索 `@recommended` 后操作“启用/禁用（工作区）”。
