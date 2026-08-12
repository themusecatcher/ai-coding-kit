#!/bin/bash
# logger.sh - dev-flow 脚本统一日志库（5 级 + 彩色输出）
# 用法：source "$(dirname "$0")/../lib/logger.sh"
#
# 5 级：INFO / WARN / ERROR / PASS / FAIL
# 环境变量：DF_NO_COLOR=1 关闭颜色，DF_LOG_LEVEL=debug|info|warn|error 控制输出阈值

# ========================================
# 颜色定义（自动检测 TTY）
# ========================================
if [ -t 1 ] && [ -z "${DF_NO_COLOR:-}" ]; then
  __DF_C_RESET="\033[0m"
  __DF_C_RED="\033[31m"
  __DF_C_GREEN="\033[32m"
  __DF_C_YELLOW="\033[33m"
  __DF_C_BLUE="\033[34m"
  __DF_C_MAGENTA="\033[35m"
  __DF_C_CYAN="\033[36m"
  __DF_C_BOLD="\033[1m"
  __DF_C_DIM="\033[2m"
else
  __DF_C_RESET=""; __DF_C_RED=""; __DF_C_GREEN=""; __DF_C_YELLOW="";
  __DF_C_BLUE=""; __DF_C_MAGENTA=""; __DF_C_CYAN=""; __DF_C_BOLD=""; __DF_C_DIM="";
fi

# ========================================
# 日志级别（默认 info）
# ========================================
__df_log_level_num() {
  case "${1:-info}" in
    debug) echo 0 ;;
    info)  echo 1 ;;
    warn)  echo 2 ;;
    error) echo 3 ;;
    *)     echo 1 ;;
  esac
}

__df_should_log() {
  local msg_level="$1"
  local current_level
  current_level=$(__df_log_level_num "${DF_LOG_LEVEL:-info}")
  local m
  m=$(__df_log_level_num "$msg_level")
  [ "$m" -ge "$current_level" ]
}

# ========================================
# 5 级日志函数
# ========================================
log_debug() {
  __df_should_log debug || return 0
  printf "${__DF_C_DIM}[DEBUG]${__DF_C_RESET} %s\n" "$*" >&2
}

log_info() {
  __df_should_log info || return 0
  printf "${__DF_C_BLUE}[INFO]${__DF_C_RESET}  %s\n" "$*"
}

log_warn() {
  __df_should_log warn || return 0
  printf "${__DF_C_YELLOW}[WARN]${__DF_C_RESET}  %s\n" "$*" >&2
}

log_error() {
  __df_should_log error || return 0
  printf "${__DF_C_RED}[ERROR]${__DF_C_RESET} %s\n" "$*" >&2
}

# ========================================
# 检查类标记
# ========================================
log_pass() {
  printf "${__DF_C_GREEN}[ ✓ ]${__DF_C_RESET}   %s\n" "$*"
}

log_fail() {
  printf "${__DF_C_RED}[ ✗ ]${__DF_C_RESET}   %s\n" "$*" >&2
}

log_skip() {
  printf "${__DF_C_DIM}[ - ]${__DF_C_RESET}   %s\n" "$*"
}

# ========================================
# 段落与高亮
# ========================================
log_section() {
  printf "\n${__DF_C_BOLD}${__DF_C_CYAN}=== %s ===${__DF_C_RESET}\n" "$*"
}

log_step() {
  printf "${__DF_C_MAGENTA}▶${__DF_C_RESET} ${__DF_C_BOLD}%s${__DF_C_RESET}\n" "$*"
}

log_kv() {
  # log_kv <key> <value>
  printf "  ${__DF_C_DIM}%-20s${__DF_C_RESET} %s\n" "$1:" "$2"
}

# ========================================
# 摘要表格输出
# ========================================
log_summary_box() {
  # 用法：log_summary_box <标题> <pass_count> <fail_count> <warn_count>
  local title="$1" pass="$2" fail="$3" warn="$4"
  printf "\n┌─────────────────────────────────────────────┐\n"
  printf "│ %-43s │\n" "$title"
  printf "├─────────────────────────────────────────────┤\n"
  printf "│  ✓ Pass: %-3s   ✗ Fail: %-3s   ⚠ Warn: %-3s    │\n" "$pass" "$fail" "$warn"
  printf "└─────────────────────────────────────────────┘\n"
}

__DF_LOGGER_LOADED=1
