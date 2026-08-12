#!/bin/bash
# common.sh - verification-pipeline 公共工具函数
# 不依赖 dev-flow，保持 skill 独立可运行

if [ -n "${VP_COMMON_LOADED:-}" ]; then
  return 0
fi
VP_COMMON_LOADED=1

# ========================================
# 路径常量
# ========================================
VP_ROOT="${VP_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
VP_SCRIPTS="$VP_ROOT/scripts"
VP_CONFIG="$VP_ROOT/config"
VP_REFERENCES="$VP_ROOT/references"

# 状态文件根目录（3 次熔断计数器）
VP_STATE_DIR="${VP_STATE_DIR:-$HOME/.codebuddy/working-context/.verify-state}"

# ========================================
# JSON 转义（仅转义双引号、反斜杠、换行）
# 用法：vp_json_escape "原文" → 输出转义后内容
# ========================================
vp_json_escape() {
  local s="$1"
  # 1. 反斜杠先转义（避免后续转义被二次处理）
  s="${s//\\/\\\\}"
  # 2. 双引号
  s="${s//\"/\\\"}"
  # 3. 换行/回车/Tab
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  # 4. 其他 ASCII 控制字符（\x00-\x1F 除上面已处理外）
  #    用 tr 删除剩余控制字符 + ANSI ESC \x1B
  s="$(printf '%s' "$s" | LC_ALL=C tr -d '\000-\010\013\014\016-\037')"
  printf '%s' "$s"
}

# ========================================
# 检查命令是否存在
# 用法：vp_has_cmd npm && echo yes
# ========================================
vp_has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

# ========================================
# 简易 YAML 单值读取（仅支持 a.b.c 类点号路径 + 字符串/数字 标量）
# 不依赖 yq/python，纯 awk 实现，足够本 skill 配置的简单结构
# 用法：vp_yaml_get_scalar <yaml-file> <dotted-key>
# ========================================
vp_yaml_get_scalar() {
  local file="$1"
  local key="$2"
  [ ! -f "$file" ] && return 1

  awk -v target="$key" '
    BEGIN {
      n = split(target, parts, ".")
      depth = 0
      delete path
    }
    # 跳过注释行和空行
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    {
      # 计算当前行缩进（2 空格 = 1 层）
      match($0, /^ */)
      indent = RLENGTH
      level = int(indent / 2)

      # 提取 key:value
      line = $0
      sub(/^[[:space:]]+/, "", line)
      if (match(line, /^[a-zA-Z_][a-zA-Z0-9_-]*:/)) {
        k = substr(line, 1, RLENGTH - 1)
        rest = substr(line, RLENGTH + 1)
        sub(/^[[:space:]]+/, "", rest)
        # 去除行末注释
        sub(/[[:space:]]+#.*$/, "", rest)

        path[level] = k

        if (level + 1 == n) {
          # 检查祖先路径是否匹配
          ok = 1
          for (i = 0; i < n; i++) {
            if (path[i] != parts[i + 1]) { ok = 0; break }
          }
          if (ok && rest != "") {
            # 去除引号
            gsub(/^"|"$/, "", rest)
            gsub(/^'\''|'\''$/, "", rest)
            print rest
            exit 0
          }
        }
      }
    }
  ' "$file"
}

# ========================================
# 简易 YAML 列表读取：返回某个键下的列表项（- xxx）
# 仅支持简单的「一行一个 - value」形式
# ========================================
vp_yaml_get_list() {
  local file="$1"
  local key="$2"
  [ ! -f "$file" ] && return 1

  awk -v target="$key" '
    BEGIN {
      n = split(target, parts, ".")
      delete path
      collecting = 0
      collect_indent = -1
    }
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    {
      match($0, /^ */)
      indent = RLENGTH
      level = int(indent / 2)
      line = $0
      sub(/^[[:space:]]+/, "", line)

      if (collecting) {
        if (line ~ /^- /) {
          item = substr(line, 3)
          gsub(/[[:space:]]+#.*$/, "", item)
          gsub(/^"|"$/, "", item)
          gsub(/^'\''|'\''$/, "", item)
          print item
          next
        } else if (indent <= collect_indent) {
          exit 0
        }
      }

      if (match(line, /^[a-zA-Z_][a-zA-Z0-9_-]*:/)) {
        k = substr(line, 1, RLENGTH - 1)
        path[level] = k
        if (level + 1 == n) {
          ok = 1
          for (i = 0; i < n; i++) {
            if (path[i] != parts[i + 1]) { ok = 0; break }
          }
          if (ok) {
            collecting = 1
            collect_indent = indent
          }
        }
      }
    }
  ' "$file"
}

# ========================================
# 时间戳（ISO 8601 风格，本地时间）
# ========================================
vp_now_iso() {
  date "+%Y-%m-%dT%H:%M:%S%z"
}

# ========================================
# 格式化耗时（毫秒 → "1.23s" / "150ms"）
# ========================================
vp_fmt_duration_ms() {
  local ms="${1:-0}"
  if [ "$ms" -ge 1000 ]; then
    awk "BEGIN { printf \"%.2fs\", $ms / 1000 }"
  else
    printf "%dms" "$ms"
  fi
}

# ========================================
# Mac/Linux 兼容的毫秒级时间戳
# ========================================
vp_now_ms() {
  if vp_has_cmd python3; then
    python3 -c 'import time; print(int(time.time() * 1000))'
  elif vp_has_cmd gdate; then
    gdate +%s%3N
  else
    # 退化：秒级 * 1000
    echo "$(($(date +%s) * 1000))"
  fi
}
