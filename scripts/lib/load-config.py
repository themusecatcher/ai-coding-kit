#!/usr/bin/env python3
"""
仓库级组织配置加载器（Python 版，纯标准库实现）。

用法：
    from load_config import get_config, has_config, require_config

    name = get_config("org_name", default="MyOrg")
    url  = get_config("task_platform_url", default="")

查找顺序：
    1. {repo_root}/config/org.yaml
    2. ~/.codebuddy/config/org.yaml（用户本地覆盖优先）

特性：
    - 纯标准库，零外部依赖（无需 PyYAML）
    - 支持 dotted.path 读取嵌套字段（如 "mcp_tools.component_library"）
    - 模块级单例缓存，同进程内不重复解析
    - 字符串值默认去除引号和行内注释
"""

import os
import re

__all__ = ["get_config", "has_config", "require_config", "config_file_path"]

# ---- 配置文件定位 ----

def _find_config_file() -> str:
    """按优先级查找 org.yaml 配置文件"""
    user_config = os.path.expanduser("~/.codebuddy/config/org.yaml")
    if os.path.isfile(user_config):
        return user_config

    # 从当前文件位置推断仓库根目录
    repo_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    repo_config = os.path.join(repo_root, "config", "org.yaml")
    if os.path.isfile(repo_config):
        return repo_config

    return ""


_CONFIG_FILE = _find_config_file()
_CONFIG_CACHE = None  # 惰性加载


def _load_yaml() -> dict:
    """解析 YAML 文件为嵌套 dict（仅支持简单结构，无 list/锚点/多行字符串）"""
    global _CONFIG_CACHE
    if _CONFIG_CACHE is not None:
        return _CONFIG_CACHE

    _CONFIG_CACHE = {}
    if not _CONFIG_FILE or not os.path.isfile(_CONFIG_FILE):
        return _CONFIG_CACHE

    with open(_CONFIG_FILE, "r", encoding="utf-8") as f:
        lines = f.readlines()

    # 栈式解析：追踪每层缩进对应的当前 dict
    stack = [(-1, _CONFIG_CACHE)]  # (indent, dict)

    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        # 跳过只含 key 不含 value 的行（如 "-"、"key:" 后无内容）
        if ":" not in stripped:
            continue

        indent = len(line) - len(line.lstrip(" "))

        # 弹栈直到当前缩进小于栈顶
        while stack and indent <= stack[-1][0]:
            stack.pop()

        # 分割 key: value
        colon_idx = stripped.index(":")
        key = stripped[:colon_idx].strip()
        value_str = stripped[colon_idx + 1:].strip()

        # 清理值：去除引号和行内注释
        value_str = _clean_value(value_str)

        parent_dict = stack[-1][1]

        if value_str:
            # 叶子节点：key = value
            parent_dict[key] = value_str
        else:
            # 中间节点：key 下是一个新的 dict
            parent_dict[key] = {}
            stack.append((indent, parent_dict[key]))

    return _CONFIG_CACHE


def _clean_value(v: str) -> str:
    """去除 YAML 值的引号、行内注释和首尾空白"""
    # 去除行内注释（# 前需有空白）
    v = re.sub(r'\s+#.*$', '', v)
    # 去除首尾引号
    v = v.strip()
    if len(v) >= 2:
        if (v.startswith('"') and v.endswith('"')) or \
           (v.startswith("'") and v.endswith("'")):
            v = v[1:-1]
    return v


def get_config(path: str, default: str = "") -> str:
    """
    读取配置项，未设置或为空时返回默认值。

    参数:
        path: dotted.path 格式，如 "org_name"、"mcp_tools.component_library"
        default: 未找到时的默认值

    返回:
        str: 配置值
    """
    data = _load_yaml()
    parts = path.split(".")
    current = data

    for part in parts:
        if not isinstance(current, dict):
            return default
        current = current.get(part)
        if current is None:
            return default

    # 值为空字符串也视为未配置
    if isinstance(current, str) and not current:
        return default
    if isinstance(current, dict):
        return default  # 中间节点，不是叶子值

    return str(current)


def has_config(path: str) -> bool:
    """检查配置项是否已设置（非空），返回 True 表示已设置"""
    val = get_config(path, default="")
    return bool(val)


def require_config(path: str, description: str = "") -> None:
    """
    必须已配置，否则抛出 ValueError（用于关键配置项）。

    抛出:
        ValueError: 配置项未设置
    """
    if not has_config(path):
        desc = description or path
        raise ValueError(
            f"缺少必要配置: {desc}\n"
            f"   请在 {_CONFIG_FILE or 'config/org.yaml'} 中设置 {path}"
        )


def config_file_path() -> str:
    """返回当前使用的配置文件路径"""
    return _CONFIG_FILE or "未找到配置文件"


# 模块加载标记
__LOAD_CONFIG_LOADED = True
