#!/bin/bash
# ============================================================
# recovery-engine.sh - 恢复执行器
# 被门禁脚本 source 后使用
#
# 提供 try_recover 函数：
#   try_recover <check_name> <strategy> <fix_cmd> [max_retry]
#   返回: 0=恢复命令执行成功（调用方需 recheck）, 1=恢复失败
# ============================================================

# try_recover <check_name> <strategy> <fix_cmd> <max_retry>
try_recover() {
  local check_name="$1"
  local strategy="$2"
  local fix_cmd="$3"
  local max_retry="${4:-1}"

  case "$strategy" in
    auto_fix)
      for i in $(seq 1 "$max_retry"); do
        log_info "  🔧 恢复尝试 $i/$max_retry: $fix_cmd"
        eval "$fix_cmd" 2>/dev/null || true
      done
      # 返回 0 让调用方 recheck
      return 0
      ;;
    retry)
      # 直接返回让调用方重新执行检查
      return 0
      ;;
    prompt)
      log_warn "  📝 需要手动处理: $check_name"
      log_warn "  💡 处理后重新执行门禁检查"
      return 1
      ;;
    none)
      log_fail "  ⛔ 不可自动恢复: $check_name"
      return 1
      ;;
    *)
      log_fail "  ⛔ 未知恢复策略: $strategy"
      return 1
      ;;
  esac
}
