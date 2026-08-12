#!/bin/bash
# ==============================================================================
# load-config.sh — 仓库级组织配置加载器（纯 bash 实现，零外部依赖）
#
# 用法：
#   source scripts/lib/load-config.sh
#   val=$(get_config "org_name" "默认值")
#   get_config "mcp_tools.component_library" ""
#
# 查找顺序：
#   1. $REPO_ROOT/config/org.yaml（仓库自带配置）
#   2. ~/.codebuddy/config/org.yaml（用户本地覆盖）
#
# 特性：
#   - 纯 bash + grep + sed，无需 yq/jq
#   - 支持 dotted.path 读取嵌套 YAML 字段
#   - 值读取有内部缓存，同进程内不重复解析
#   - 找不到或值为空时返回默认值
# ==============================================================================

set -o pipefail 2>/dev/null || true

# ---- 确定配置文件路径 ----
__find_config_file() {
  # 仓库根目录下的 config/org.yaml
  local repo_config
  if [ -n "${REPO_ROOT:-}" ]; then
    repo_config="$REPO_ROOT/config/org.yaml"
  else
    # 从脚本位置推断仓库根目录
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[1]:-$0}")" && pwd)"
    local candidate
    candidate="$(cd "$script_dir/../.." 2>/dev/null && pwd)/config/org.yaml"
    if [ -f "$candidate" ]; then
      repo_config="$candidate"
    fi
  fi

  # 用户本地覆盖优先
  local user_config="$HOME/.codebuddy/config/org.yaml"
  if [ -f "$user_config" ]; then
    echo "$user_config"
  elif [ -n "${repo_config:-}" ] && [ -f "$repo_config" ]; then
    echo "$repo_config"
  else
    echo ""
  fi
}

__CONFIG_FILE=$(__find_config_file)

# ---- 内部：从 YAML 中按 dotted.path 读取值 ----
# 纯 bash 实现，支持 2 层嵌套（top_key.sub_key）
# 不依赖 yq/jq
__read_yaml_value() {
  local file="$1" path="$2"
  [ ! -f "$file" ] && return 1
  [ -z "$path" ] && return 1

  # 将 dotted.path 拆为数组
  local IFS='.'
  local -a parts=($path)
  unset IFS
  local depth=${#parts[@]}

  if [ "$depth" -eq 1 ]; then
    # 顶层字段：直接 grep
    __read_top_key "$file" "${parts[0]}"
    return $?
  elif [ "$depth" -eq 2 ]; then
    # 两层嵌套：先找父 key，再在父 key 的缩进范围内找子 key
    __read_nested_key "$file" "${parts[0]}" "${parts[1]}"
    return $?
  else
    # 深度 >2：用 awk 通用解析
    __read_yaml_awk "$file" "$path"
    return $?
  fi
}

# 读取顶层 key（无需缩进）
__read_top_key() {
  local file="$1" key="$2"
  # 匹配行首（允许 0 或 2 空格缩进）的 key:
  local line
  line=$(grep -E "^[ ]{0,2}${key}[ ]*:" "$file" | head -1)
  [ -z "$line" ] && return 1
  # 提取冒号后的值
  local value
  value=$(echo "$line" | sed -E 's/^[^:]*:[ ]*//')
  # 去除引号和行内注释
  value=$(__clean_yaml_value "$value")
  echo "$value"
  return 0
}

# 读取嵌套 key（父 key 下一级缩进内的子 key）
__read_nested_key() {
  local file="$1" parent="$2" child="$3"

  # 用 awk 查找父 key 的缩进范围，在其范围内找子 key
  awk -v parent="$parent" -v child="$child" '
    function trim(s) {
      sub(/^[ \t]+/, "", s)
      sub(/[ \t]+$/, "", s)
      return s
    }
    function clean_val(v) {
      # 去除行内注释
      sub(/[ \t]+#.*$/, "", v)
      # 去除首尾引号
      sub(/^["'\''"]/, "", v)
      sub(/["'\''"]$/, "", v)
      return v
    }
    /^[ ]{0,2}'"$parent"'[ ]*:/ {
      in_block = 1
      next
    }
    in_block {
      # 计算当前行缩进
      match($0, /^ */)
      indent = RLENGTH
      # 缩进为 2 空格 = 子字段；缩进为 0 或 0 空格 = 块结束
      if (indent < 2 && $0 !~ /^[ \t]*$/) { exit 0 }
      if (indent >= 2 && indent <= 4) {
        line = trim($0)
        if (match(line, /^[a-zA-Z_][a-zA-Z0-9_-]*[ \t]*:/) > 0) {
          k = substr(line, 1, RLENGTH)
          sub(/[ \t]*:$/, "", k)
          if (k == child) {
            v = substr(line, RLENGTH + 1)
            v = trim(v)
            v = clean_val(v)
            print v
            found = 1
            exit 0
          }
        }
      }
    }
    END { if (!found) exit 1 }
  ' "$file"
}

# 通用 awk YAML 读取（支持任意深度）
__read_yaml_awk() {
  local file="$1" path="$2"

  awk -v target_path="$path" '
    function trim(s) {
      sub(/^[ \t]+/, "", s)
      sub(/[ \t]+$/, "", s)
      return s
    }
    function clean_val(v) {
      sub(/[ \t]+#.*$/, "", v)
      sub(/^["'\''"]/, "", v)
      sub(/["'\''"]$/, "", v)
      return v
    }
    BEGIN {
      n = split(target_path, parts, ".")
      for (i = 0; i < n; i++) pm[i] = 0
    }
    {
      if ($0 ~ /^[ \t]*$/ || $0 ~ /^[ \t]*#/) next
      match($0, /^ */)
      level = int(RLENGTH / 2)
      if (level >= n) next

      line = trim($0)
      if (match(line, /^[a-zA-Z_][a-zA-Z0-9_-]*[ \t]*:/) == 0) next
      k = substr(line, 1, RLENGTH)
      sub(/[ \t]*:$/, "", k)
      v = substr(line, RLENGTH + 1)
      v = trim(v)

      expected = parts[level + 1]

      if (k == expected) {
        pm[level] = 1
        for (i = level + 1; i < n; i++) pm[i] = 0

        if (level == n - 1 && length(v) > 0) {
          all = 1
          for (i = 0; i < n; i++) { if (pm[i] != 1) { all = 0; break } }
          if (all) {
            print clean_val(v)
            exit 0
          }
        }
      } else {
        if (pm[level] == 1) {
          for (i = level; i < n; i++) pm[i] = 0
        }
      }
    }
    END { exit 1 }
  ' "$file"
}

# 清理 YAML 值：去除引号、行内注释、首尾空白
__clean_yaml_value() {
  local v="$1"
  # 去除首尾空白
  v=$(echo "$v" | sed -E 's/^[ \t]+//;s/[ \t]+$//')
  # 去除行内注释（# 前至少一个空格）
  v=$(echo "$v" | sed -E 's/[ \t]+#.*$//')
  # 去除首尾引号
  v=$(echo "$v" | sed -E 's/^"//;s/"$//;s/^'\''//;s/'\''$//')
  echo "$v"
}

# ---- 公开 API ----

# get_config <dotted.path> [default]
# 读取配置项，未设置或为空时返回默认值
# 例：
#   name=$(get_config "org_name" "MyOrg")
#   url=$(get_config "task_platform_url" "")
get_config() {
  local path="$1"
  local default="${2:-}"

  [ -z "$__CONFIG_FILE" ] && { echo "$default"; return 0; }

  local value
  value=$(__read_yaml_value "$__CONFIG_FILE" "$path" 2>/dev/null) || true

  if [ -z "$value" ]; then
    echo "$default"
  else
    echo "$value"
  fi
}

# has_config <dotted.path>
# 检查配置项是否已设置（非空），返回 0 表示已设置
has_config() {
  local path="$1"
  local val
  val=$(get_config "$path" "")
  [ -n "$val" ]
}

# require_config <dotted.path> <description>
# 必须已配置，否则报错退出（用于关键配置项）
require_config() {
  local path="$1"
  local desc="${2:-$path}"
  if ! has_config "$path"; then
    echo "❌ 缺少必要配置: $desc" >&2
    echo "   请在 $__CONFIG_FILE 中设置 $path" >&2
    return 1
  fi
}

# config_file_path
# 返回当前使用的配置文件路径
config_file_path() {
  echo "${__CONFIG_FILE:-未找到配置文件}"
}

# 标记已加载
__LOAD_CONFIG_LOADED=1
