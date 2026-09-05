#!/usr/bin/env python3
"""Select extension groups and update a folder's VS Code recommendations."""
import argparse
import json
import os
from pathlib import Path
import re
import sys
import tempfile


# 扩展分组定义：在此修改名称、依赖和扩展列表。
GROUPS = {
    "python": {
        "name": "Python",
        "requires": [],
        "extensions": [
            "ms-python.python",
            "ms-python.vscode-pylance",
            "ms-python.debugpy",
            "ms-python.vscode-python-envs",
            "charliermarsh.ruff",
            "njpwerner.autodocstring",
            "tamasfe.even-better-toml"
        ]
    },
    "jupyter": {
        "name": "Jupyter",
        "requires": [
            "python"
        ],
        "extensions": [
            "ms-toolsai.jupyter",
            "ms-toolsai.jupyter-keymap",
            "ms-toolsai.jupyter-renderers",
            "ms-toolsai.vscode-jupyter-cell-tags",
            "ms-toolsai.vscode-jupyter-slideshow",
            "dvirtz.parquet-viewer"
        ]
    },
    "node": {
        "name": "Node.js",
        "requires": [],
        "extensions": [
            "oxc.oxc-vscode",
            "dbaeumer.vscode-eslint",
            "christian-kohler.npm-intellisense",
            "xabikos.javascriptsnippets",
            "iwanabethatguy.path-alias",
            "orta.vscode-jest",
            "mikestead.dotenv",
            "humao.rest-client"
        ]
    },
    "bun": {
        "name": "Bun",
        "requires": [],
        "extensions": [
            "oven.bun-vscode",
            "oxc.oxc-vscode"
        ]
    },
    "deno": {
        "name": "Deno",
        "requires": [],
        "extensions": [
            "denoland.vscode-deno"
        ]
    },
    "java": {
        "name": "Java",
        "requires": [],
        "extensions": [
            "vscjava.vscode-java-pack",
            "redhat.java",
            "vscjava.vscode-java-debug",
            "vscjava.vscode-java-test",
            "vscjava.vscode-java-dependency",
            "vscjava.vscode-maven",
            "vscjava.vscode-gradle",
            "vscjava.vscode-lombok",
            "vscjava.migrate-java-to-azure"
        ]
    },
    "spring": {
        "name": "Spring",
        "requires": [
            "java"
        ],
        "extensions": [
            "vmware.vscode-boot-dev-pack",
            "vmware.vscode-spring-boot",
            "vscjava.vscode-spring-boot-dashboard",
            "vscjava.vscode-spring-initializr"
        ]
    },
    "go": {
        "name": "Go",
        "requires": [],
        "extensions": [
            "golang.go"
        ]
    },
    "rust": {
        "name": "Rust",
        "requires": [],
        "extensions": [
            "rust-lang.rust-analyzer",
            "vadimcn.vscode-lldb",
            "tamasfe.even-better-toml",
            "serayuzgur.crates",
            "usernamehw.errorlens"
        ]
    }
}

def read_json(path, default=None):
    if not path.exists():
        if default is not None:
            return default
        raise ValueError(f"找不到文件：{path}")
    # JSONC: remove comments/trailing commas without modifying string contents.
    text = re.sub(r'"(?:\\.|[^"\\])*"|//[^\n]*|/\*[\s\S]*?\*/',
                  lambda m: m[0] if m[0].startswith('"') else ' ',
                  path.read_text(encoding='utf-8-sig'))
    text = re.sub(r'"(?:\\.|[^"\\])*"|,\s*(?=[}\]])',
                  lambda m: m[0] if m[0].startswith('"') else '', text)
    data = json.loads(text)
    if not isinstance(data, dict):
        raise ValueError(f"必须是 JSON 对象：{path}")
    return data


def string_list(value):
    return isinstance(value, list) and all(isinstance(x, str) for x in value)


def resolve(groups, selected):
    result, visiting = set(), set()

    def visit(key):
        if key not in groups:
            raise ValueError(f"未知分组：{key}")
        if key in visiting:
            raise ValueError(f"分组依赖存在循环：{key}")
        if key in result:
            return
        visiting.add(key)
        for dependency in groups[key]['requires']:
            visit(dependency)
        visiting.remove(key)
        result.add(key)

    for key in selected:
        visit(key)
    return result


def load_groups():
    groups = GROUPS
    if not isinstance(groups, dict) or not groups:
        raise ValueError('groups 必须是非空对象')
    for key, group in groups.items():
        if (not isinstance(group, dict) or not isinstance(group.get('name'), str)
                or not string_list(group.get('requires'))
                or not string_list(group.get('extensions'))):
            raise ValueError(f"分组格式不正确：{key}")
    resolve(groups, groups)
    return groups


def choose(groups, selected, project):
    selected = set(selected)
    keys = list(groups)
    if not sys.stdin.isatty() or not sys.stdout.isatty():
        raise ValueError('请在交互式终端运行')
    try:
        import curses
    except ImportError:
        # Windows Python does not bundle curses; retain a dependency-free menu.
        while True:
            effective = resolve(groups, selected)
            for i, key in enumerate(keys, 1):
                mark = 'x' if key in selected else '+' if key in effective else ' '
                print(f"{i}. [{mark}] {groups[key]['name']}")
            answer = input('输入编号切换，回车保存，q 取消（+ 为依赖）：').strip()
            if not answer:
                return selected
            if answer.lower() == 'q':
                return None
            if answer.isdigit() and 1 <= int(answer) <= len(keys):
                key = keys[int(answer) - 1]
                selected.symmetric_difference_update({key})

    def menu(screen):
        cursor = 0
        while True:
            screen.erase()
            height, width = screen.getmaxyx()
            effective = resolve(groups, selected)
            lines = [f'项目：{project.name}', '↑↓ 移动 · 空格选择 · 回车保存 · Esc/q 取消',
                     '[x] 主动选择   [+] 依赖自动包含', '']
            visible = max(1, height - 6)
            start = max(0, cursor - visible + 1)
            for key in keys[start:start + visible]:
                mark = 'x' if key in selected else '+' if key in effective else ' '
                deps = ', '.join(groups[d]['name'] for d in groups[key]['requires'])
                lines.append(f"[{mark}] {groups[key]['name']}" + (f'（包含 {deps}）' if deps else ''))
            for row, line in enumerate(lines[:height - 1]):
                try:
                    screen.addnstr(row, 0, line, max(0, width - 1),
                                   curses.A_REVERSE if row == 4 + cursor - start else 0)
                except curses.error:
                    pass
            screen.refresh()
            key = screen.getch()
            if key in (27, ord('q')):
                return None
            if key in (10, 13, curses.KEY_ENTER):
                return selected
            if key in (curses.KEY_UP, ord('k')):
                cursor = (cursor - 1) % len(keys)
            elif key in (curses.KEY_DOWN, ord('j')):
                cursor = (cursor + 1) % len(keys)
            elif key == ord(' '):
                selected.symmetric_difference_update({keys[cursor]})

    return curses.wrapper(menu)


def prepare(groups, selected, recommendations, state):
    effective = resolve(groups, selected)
    wanted = list(dict.fromkeys(ext for key, group in groups.items()
                               if key in effective for ext in group['extensions']))
    old = {x.lower() for x in state.get('managedExtensions', [])}
    manual = [x for x in recommendations.get('recommendations', []) if x.lower() not in old]
    manual_ids = {x.lower() for x in manual}
    additions = [x for x in wanted if x.lower() not in manual_ids]
    conflicts = {x.lower() for x in recommendations.get('unwantedRecommendations', [])}
    if conflicts.intersection(x.lower() for x in wanted):
        raise ValueError('所选扩展与 unwantedRecommendations 冲突，请先修改该列表')
    updated = {**recommendations, 'recommendations': list(dict.fromkeys(manual + additions))}
    saved = {'selectedGroups': [k for k in groups if k in selected],
             'managedExtensions': additions}
    return updated, saved


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp = tempfile.mkstemp(dir=path.parent, prefix='.' + path.name)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as stream:
            json.dump(data, stream, ensure_ascii=False, indent=2)
            stream.write('\n')
        os.replace(temp, path)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('project', nargs='?', type=Path, default=Path.cwd(), help='项目目录（默认当前目录）')
    args = parser.parse_args()
    project = args.project.resolve()
    if not project.is_dir():
        raise ValueError(f'项目目录不存在：{project}')
    groups = load_groups()
    folder = project / '.vscode'
    recommendation_path = folder / 'extensions.json'
    state_path = folder / 'extension-groups.json'
    recommendations = read_json(recommendation_path, {})
    state = read_json(state_path, {})
    for data, fields in [(recommendations, ['recommendations', 'unwantedRecommendations']),
                         (state, ['selectedGroups', 'managedExtensions'])]:
        for field in fields:
            if not string_list(data.get(field, [])):
                raise ValueError(f'{field} 必须是字符串数组')
    unknown = set(state.get('selectedGroups', [])) - groups.keys()
    if unknown:
        raise ValueError(f'已选分组不在当前配置中：{", ".join(sorted(unknown))}')
    selected = choose(groups, state.get('selectedGroups', []), project)
    if selected is None:
        print('已取消，文件未修改。')
        return
    updated, saved = prepare(groups, selected, recommendations, state)
    # Refuse to overwrite concurrent edits made while the picker was open.
    if read_json(recommendation_path, {}) != recommendations or read_json(state_path, {}) != state:
        raise ValueError('选择期间项目配置被其他程序修改，请重新运行')
    write_json(recommendation_path, updated)
    try:
        write_json(state_path, saved)
    except OSError:
        write_json(recommendation_path, recommendations)
        raise
    print('已选择：' + (', '.join(groups[k]['name'] for k in groups if k in selected) or '无'))
    print(f'已生成 {len(updated["recommendations"])} 个推荐：{recommendation_path}')
    print('在 VS Code 扩展面板搜索 @recommended，管理工作区启停。')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError) as error:
        print(f'错误：{error}', file=sys.stderr)
        sys.exit(1)
    except (KeyboardInterrupt, EOFError):
        print('\n已取消。')
