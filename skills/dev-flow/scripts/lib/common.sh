#!/bin/bash
# common.sh - dev-flow 脚本公共函数库
# 提供：跨平台日期、路径解析、JSON 读取、工作上下文路径解析等
# 用法：source "$(dirname "$0")/../lib/common.sh"

set -o pipefail 2>/dev/null || true

# ========================================
# 路径常量
# ========================================
df_skill_root() {
  # 返回 ~/.codebuddy/skills/dev-flow（脚本所在 skill 根目录）
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[1]:-$0}")" && pwd)"
  # 向上回溯，找到含 SKILL.md 的目录
  while [ "$script_dir" != "/" ] && [ ! -f "$script_dir/SKILL.md" ]; do
    script_dir="$(dirname "$script_dir")"
  done
  [ -f "$script_dir/SKILL.md" ] && echo "$script_dir" || echo "$HOME/.codebuddy/skills/dev-flow"
}

df_workcontext_path() {
  echo "$HOME/.codebuddy/working-context"
}

df_active_flows_dir() {
  echo "$(df_workcontext_path)/.active-flows"
}

df_backup_root() {
  echo "$HOME/.codebuddy/.backup"
}

# ========================================
# 跨平台日期函数（macOS BSD date / Linux GNU date）
# ========================================
df_iso_now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

df_iso_local() {
  date +"%Y-%m-%dT%H:%M:%S%z"
}

df_unix_now() {
  date +%s
}

df_date_diff_seconds() {
  # 计算两个 ISO 时间戳的秒差（仅支持 UTC ISO 格式）
  local t1="$1" t2="$2"
  local s1 s2
  if [ "$(uname)" = "Darwin" ]; then
    s1=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$t1" +%s 2>/dev/null)
    s2=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$t2" +%s 2>/dev/null)
  else
    s1=$(date -d "$t1" +%s 2>/dev/null)
    s2=$(date -d "$t2" +%s 2>/dev/null)
  fi
  [ -z "$s1" ] || [ -z "$s2" ] && { echo 0; return 1; }
  echo $((s2 - s1))
}

# ========================================
# 路径处理
# ========================================
df_normalize_path() {
  # 展开 ~ 和环境变量
  local p="$1"
  eval echo "$p"
}

df_relative_to() {
  # 计算 $1 相对 $2 的相对路径（macOS 没有 realpath --relative-to）
  local target="$1" base="$2"
  python3 -c "import os.path; print(os.path.relpath('$target', '$base'))" 2>/dev/null \
    || echo "$target"
}

# ========================================
# JSON 读取（带降级）
# ========================================
df_jq_get() {
  # 用法: df_jq_get <file> <jq-path> [default]
  local file="$1" path="$2" default="${3:-}"
  if ! command -v jq >/dev/null 2>&1; then
    echo "$default"
    return 1
  fi
  local result
  result=$(jq -r "$path // empty" "$file" 2>/dev/null)
  if [ -z "$result" ] || [ "$result" = "null" ]; then
    echo "$default"
  else
    echo "$result"
  fi
}

df_jq_validate() {
  # 校验 JSON 文件格式合法性
  local file="$1"
  command -v jq >/dev/null 2>&1 || return 0  # jq 不存在时不阻塞
  jq empty "$file" 2>/dev/null
}

# ========================================
# .flow 锁文件读取（兼容 YAML / TOML 风格）
# ========================================
df_get_flow_field() {
  # 用法: df_get_flow_field <flow-file> <field-name>
  # 兼容三种格式：
  #   field: value         (YAML 简单格式)
  #   field: "value"       (YAML 带引号)
  #   field = "value"      (TOML 风格)
  local flow_file="$1" field="$2"
  [ ! -f "$flow_file" ] && return 1
  # 单一正则匹配三种格式
  grep -E "^${field}[[:space:]]*[:=]" "$flow_file" 2>/dev/null \
    | head -1 \
    | sed -E "s/^${field}[[:space:]]*[:=][[:space:]]*//;s/^['\"]//;s/['\"]$//"
}

df_get_flow_mode() {
  local flow_file="$1"
  local mode
  mode=$(df_get_flow_field "$flow_file" "mode")
  echo "${mode:-standard}"
}

df_get_flow_current_step() {
  local flow_file="$1"
  local step
  # 优先 current_step，回退到别名 step
  step=$(df_get_flow_field "$flow_file" "current_step")
  if [ -z "$step" ]; then
    step=$(df_get_flow_field "$flow_file" "step")
  fi
  echo "$step"
}

# ========================================
# 步骤 ID 规范化
# ========================================
df_normalize_step_id() {
  # 4.5 → 4_5；7-micro-fix → 7_micro_fix
  echo "$1" | tr '.-' '__'
}

df_step_id_lt() {
  # 比较步骤 ID：$1 < $2 ？返回 0 表示 yes
  # 简单字典序对小数版本不准；用浮点比较
  local a="$1" b="$2"
  awk -v a="$a" -v b="$b" 'BEGIN{exit !(a+0 < b+0)}'
}

# ========================================
# 文件操作辅助
# ========================================
df_ensure_executable() {
  local script="$1"
  [ -f "$script" ] && [ ! -x "$script" ] && chmod +x "$script"
}

df_atomic_write() {
  # 原子写入：先写 .tmp，再 mv
  local target="$1"
  local tmp="${target}.tmp.$$"
  cat > "$tmp"
  mv -f "$tmp" "$target"
}

# ========================================
# 工具可用性探测
# ========================================
df_has_jq()   { command -v jq   >/dev/null 2>&1; }
df_has_yq()   { command -v yq   >/dev/null 2>&1; }
df_has_ajv()  { command -v ajv  >/dev/null 2>&1; }
df_has_bats() { command -v bats >/dev/null 2>&1; }

df_check_required_tools() {
  local missing=()
  df_has_jq || missing+=("jq")
  if [ ${#missing[@]} -gt 0 ]; then
    echo "⚠️  缺少推荐工具：${missing[*]}" >&2
    echo "   macOS: brew install ${missing[*]}" >&2
    return 1
  fi
  return 0
}

# ========================================
# YAML 字段读取（纯 bash + grep + sed 实现，无外部依赖）
# ========================================
# 仅支持简单嵌套结构：top:\n  sub:\n    key: "value"
# 限制：不支持数组（YAML list）、不支持多行字符串、不支持锚点
# 适用：dev-flow 配置文件 gates.yaml 的简单嵌套字段
#
# 用法:
#   df_get_yaml_value <yaml-file> <dotted.path>
# 例:
#   df_get_yaml_value config/gates.yaml "state_machine.step_sequences.standard"
# 返回:
#   字段值（去除引号和行内注释，stdout 单行输出）；找不到时输出空字符串，rc=1
df_get_yaml_value() {
  local file="$1" path="$2"
  [ ! -f "$file" ] && return 1
  [ -z "$path" ] && return 1
  
  # 把 path 拆为段（用 . 分隔）
  local IFS='.'
  local -a parts=($path)
  unset IFS
  local depth=${#parts[@]}
  [ $depth -eq 0 ] && return 1
  
  # 计算每一层期望的缩进空格数：第 0 层 0 空格、第 1 层 2 空格、第 N 层 N*2 空格
  # 策略：用 awk 一行匹配，传入完整 path 数组
  local awk_parts=""
  local i
  for ((i = 0; i < depth; i++)); do
    awk_parts="${awk_parts}${parts[i]}|"
  done
  
  awk -v target_path="$path" '
    function trim(s) {
      sub(/^[ \t]+/, "", s)
      sub(/[ \t]+$/, "", s)
      return s
    }
    function strip_inline_comment(v) {
      # 处理双引号包裹值
      if (v ~ /^"/) {
        # 找闭合双引号位置
        rest = substr(v, 2)
        if (match(rest, /"/) > 0) {
          v = substr(rest, 1, RSTART - 1)
        } else {
          # 引号没闭合，保守剥离
          sub(/^"/, "", v)
          sub(/"$/, "", v)
        }
      } else {
        # 无引号 → 行内 # 之前都是 value（# 前必须有空白）
        sub(/[ \t]+#.*$/, "", v)
        # 简单去除前后引号（兼容意外带引号情况）
        sub(/^['"'"']/, "", v)
        sub(/['"'"']$/, "", v)
      }
      return v
    }
    BEGIN {
      n = split(target_path, parts, ".")
      # path_match[i] = 1 表示第 i 层已匹配到正确 key
      for (i = 0; i < n; i++) path_match[i] = 0
    }
    {
      # 跳过空行/注释行
      if ($0 ~ /^[ \t]*$/) next
      if ($0 ~ /^[ \t]*#/) next
      
      # 计算缩进层级（每 2 空格 = 1 层）
      match($0, /^ */)
      indent = RLENGTH
      level = int(indent / 2)
      
      # 边界：超出 path 深度的行直接跳过
      if (level >= n) next
      
      # 提取 key
      line = trim($0)
      if (match(line, /^[a-zA-Z_][a-zA-Z0-9_-]*[ \t]*:/) == 0) next
      key_with_colon = substr(line, 1, RLENGTH)
      key = key_with_colon
      sub(/[ \t]*:$/, "", key)
      
      # value 部分
      value = substr(line, RLENGTH + 1)
      value = trim(value)
      
      # 当前层的期望 key
      expected_key = parts[level + 1]
      
      if (key == expected_key) {
        path_match[level] = 1
        # 清空更深层级的 match 状态（防止旧状态残留）
        for (i = level + 1; i < n; i++) path_match[i] = 0
        
        # 如果到达最深层 + 有 value
        if (level == n - 1 && length(value) > 0) {
          # 检查所有上层是否都已 match（防止跨分支误命中）
          all_matched = 1
          for (i = 0; i < n; i++) {
            if (path_match[i] != 1) { all_matched = 0; break }
          }
          if (all_matched) {
            value = strip_inline_comment(value)
            print value
            found = 1
            exit 0
          }
        }
      } else {
        # 当前层 key 不匹配，且小于等于已 match 的最深层 → 说明走出了目标分支
        if (path_match[level] == 1) {
          # 之前在此层 match 过，现在又来了个不同 key → 重置此层及更深层
          for (i = level; i < n; i++) path_match[i] = 0
        }
      }
    }
    END {
      if (!found) exit 1
    }
  ' "$file"
}

# df_get_yaml_list：读取 YAML 中的字符串字段并按空格分割为列表
# 适用于 step_sequences 这种 inline 字符串列表
# 用法:
#   df_get_yaml_list <yaml-file> <dotted.path>
# 例:
#   df_get_yaml_list config/gates.yaml "state_machine.step_sequences.standard"
# 返回:
#   空格分隔的元素列表；找不到时输出空字符串，rc=1
df_get_yaml_list() {
  local file="$1" path="$2"
  local value
  value=$(df_get_yaml_value "$file" "$path") || return 1
  echo "$value"
}

# 标记本库已加载，避免重复 source
__DF_COMMON_LOADED=1
