#!/bin/bash
# logger.sh - verification-pipeline 自带日志库
# 不依赖 dev-flow，保持 skill 独立可运行
#
# 设计：
# - 所有日志输出到 stderr，不污染 stdout 的 JSON/数据输出
# - 支持 NO_COLOR 环境变量禁用颜色（CI 友好）

if [ -n "${VP_LOGGER_LOADED:-}" ]; then
  return 0
fi
VP_LOGGER_LOADED=1

# 颜色定义（NO_COLOR 时清空）
if [ -n "${NO_COLOR:-}" ] || [ ! -t 2 ]; then
  VP_C_RESET=""
  VP_C_RED=""
  VP_C_GREEN=""
  VP_C_YELLOW=""
  VP_C_BLUE=""
  VP_C_GRAY=""
else
  VP_C_RESET="\033[0m"
  VP_C_RED="\033[31m"
  VP_C_GREEN="\033[32m"
  VP_C_YELLOW="\033[33m"
  VP_C_BLUE="\033[34m"
  VP_C_GRAY="\033[90m"
fi

log_info() {
  printf "${VP_C_BLUE}ℹ${VP_C_RESET}  %s\n" "$*" >&2
}

log_pass() {
  printf "${VP_C_GREEN}✅${VP_C_RESET} %s\n" "$*" >&2
}

log_fail() {
  printf "${VP_C_RED}❌${VP_C_RESET} %s\n" "$*" >&2
}

log_warn() {
  printf "${VP_C_YELLOW}⚠${VP_C_RESET}  %s\n" "$*" >&2
}

log_error() {
  printf "${VP_C_RED}❌${VP_C_RESET} %s\n" "$*" >&2
}

log_debug() {
  [ -n "${VP_DEBUG:-}" ] && printf "${VP_C_GRAY}🐛 %s${VP_C_RESET}\n" "$*" >&2
  return 0
}

log_kv() {
  printf "${VP_C_GRAY}  %-32s${VP_C_RESET} %s\n" "$1" "$2" >&2
}

log_section() {
  printf "\n${VP_C_BLUE}═══ %s ═══${VP_C_RESET}\n" "$*" >&2
}
