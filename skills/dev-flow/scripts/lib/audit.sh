#!/bin/bash
# audit.sh - dev-flow 脚本操作审计追踪库
# 把所有 lint/precheck/hook 的关键操作写入 ~/.codebuddy/.audit/dev-flow.log
# 便于事后追溯"为什么这个步骤被红牌""哪个脚本判定的"
#
# 用法：source "$(dirname "$0")/../lib/audit.sh"
#       df_audit "<event-type>" "<message>" [extra_kv...]

# 加载依赖
__SCRIPT_DIR_AUDIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${__DF_COMMON_LOADED:-}" ] && source "$__SCRIPT_DIR_AUDIT/common.sh"

# ========================================
# 审计日志路径
# ========================================
DF_AUDIT_DIR="${DF_AUDIT_DIR:-$HOME/.codebuddy/.audit}"
DF_AUDIT_LOG="${DF_AUDIT_LOG:-$DF_AUDIT_DIR/dev-flow.log}"
DF_AUDIT_LOG_MAX_SIZE_KB="${DF_AUDIT_LOG_MAX_SIZE_KB:-1024}"  # 1MB 自动滚动

# ========================================
# 内部：确保目录存在 + 滚动
# ========================================
__df_audit_ensure_dir() {
  [ -d "$DF_AUDIT_DIR" ] || mkdir -p "$DF_AUDIT_DIR" 2>/dev/null
}

__df_audit_rotate_if_needed() {
  [ ! -f "$DF_AUDIT_LOG" ] && return 0
  local size_kb
  if [ "$(uname)" = "Darwin" ]; then
    size_kb=$(stat -f %z "$DF_AUDIT_LOG" 2>/dev/null || echo 0)
  else
    size_kb=$(stat -c %s "$DF_AUDIT_LOG" 2>/dev/null || echo 0)
  fi
  size_kb=$((size_kb / 1024))
  if [ "$size_kb" -gt "$DF_AUDIT_LOG_MAX_SIZE_KB" ]; then
    mv -f "$DF_AUDIT_LOG" "${DF_AUDIT_LOG}.1" 2>/dev/null
  fi
}

# ========================================
# 主审计函数（JSON Lines 格式）
# ========================================
df_audit() {
  # 用法: df_audit <event-type> <message> [key=value ...]
  # 示例: df_audit "lint.path" "violation" file=step-1.md rule=R1
  local event="${1:-unknown}"
  local message="${2:-}"
  shift 2 || true
  
  __df_audit_ensure_dir
  __df_audit_rotate_if_needed
  
  # 收集额外 KV（包括 caller 信息）
  local caller_script="${BASH_SOURCE[1]:-unknown}"
  local caller_line="${BASH_LINENO[0]:-0}"
  local pid="$$"
  local timestamp
  timestamp=$(df_iso_now)
  
  # 拼装 JSON Lines（手工拼装，不依赖 jq）
  local extras=""
  for kv in "$@"; do
    local k="${kv%%=*}"
    local v="${kv#*=}"
    # 转义双引号
    v="${v//\"/\\\"}"
    extras+=",\"$k\":\"$v\""
  done
  
  # 转义 message 中的双引号
  message="${message//\"/\\\"}"
  caller_script="${caller_script##*/}"
  
  printf '{"ts":"%s","event":"%s","msg":"%s","caller":"%s:%s","pid":%s%s}\n' \
    "$timestamp" "$event" "$message" "$caller_script" "$caller_line" "$pid" "$extras" \
    >> "$DF_AUDIT_LOG" 2>/dev/null
}

# ========================================
# 便捷封装
# ========================================
df_audit_lint_pass() { df_audit "lint.pass" "$1" "${@:2}"; }
df_audit_lint_fail() { df_audit "lint.fail" "$1" "${@:2}"; }
df_audit_gate_pass() { df_audit "gate.pass" "$1" "${@:2}"; }
df_audit_gate_fail() { df_audit "gate.fail" "$1" "${@:2}"; }
df_audit_redcard()   { df_audit "redcard"   "$1" "${@:2}"; }

# ========================================
# 查询辅助（调试用）
# ========================================
df_audit_tail() {
  # 显示最近 N 条审计记录（默认 20）
  local n="${1:-20}"
  [ -f "$DF_AUDIT_LOG" ] || { echo "审计日志为空"; return 0; }
  if command -v jq >/dev/null 2>&1; then
    tail -n "$n" "$DF_AUDIT_LOG" | jq -c .
  else
    tail -n "$n" "$DF_AUDIT_LOG"
  fi
}

df_audit_grep() {
  # 按 event 类型过滤
  local pattern="$1"
  [ -f "$DF_AUDIT_LOG" ] || return 0
  grep -E "\"event\":\"$pattern\"" "$DF_AUDIT_LOG"
}

df_audit_clear() {
  # 清空审计日志（仅调试场景）
  : > "$DF_AUDIT_LOG"
}

__DF_AUDIT_LOADED=1
