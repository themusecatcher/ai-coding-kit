#!/bin/bash
# circuit-breaker.sh - dev-flow 全局熔断器
#
# 设计意图（兑现「确定性用代码」哲学）：
# - 防止 AI 在同一步骤反复失败时无限消耗 token
# - 计数文件由本脚本原子维护，AI 无法"忘记数到第几次"
# - 简化版，专为 dev-flow 步骤间熔断设计
#
# 计数文件位置：~/.codebuddy/working-context/.active-flows/{flow-name}.breaker/
#
# 用法：
#   bash circuit-breaker.sh --inc <flow-name> <step-id>       # 累加，检查是否熔断
#   bash circuit-breaker.sh --reset <flow-name> <step-id>     # 重置为 0
#   bash circuit-breaker.sh --check <flow-name> <step-id>     # 仅检查
#   bash circuit-breaker.sh --clear <flow-name>               # 清理该 flow 的所有计数
#   bash circuit-breaker.sh --list <flow-name>                # 列出所有阶段计数
#
# 返回码：
#   0 操作成功，未达熔断
#   1 已达熔断阈值
#   2 参数错误 / 文件系统错误
#
# 阈值规则（两级）：
#   - 同一步骤连续 3 次失败 → 熔断（T1）
#   - 同一 flow 累计 5 次任意步骤失败 → 熔断（T2）

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_FLOW_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$DEV_FLOW_ROOT/scripts/lib/common.sh"
source "$DEV_FLOW_ROOT/scripts/lib/logger.sh"

# 阈值
STEP_FAILURE_THRESHOLD=3      # T1：同一步骤连续失败
FLOW_FAILURE_THRESHOLD=5       # T2：全流程累计失败

ACTION="${1:-}"
FLOW_NAME="${2:-}"
STEP_ID="${3:-}"

breaker_dir() {
  echo "$(df_active_flows_dir)/${FLOW_NAME}.breaker"
}

count_file() {
  echo "$(breaker_dir)/${1}.count"
}

read_count() {
  local f
  f="$(count_file "$1")"
  if [ -f "$f" ]; then
    local n
    n="$(cat "$f" 2>/dev/null | tr -d ' \n\r')"
    if [ -n "$n" ] && [ "$n" -eq "$n" ] 2>/dev/null; then
      echo "$n"
      return
    fi
  fi
  echo 0
}

write_count() {
  local stage="$1"
  local n="$2"
  local f tmp
  f="$(count_file "$stage")"
  tmp="${f}.tmp.$$"
  mkdir -p "$(breaker_dir)" 2>/dev/null
  printf '%s\n' "$n" > "$tmp"
  mv -f "$tmp" "$f"
}

# 累计总失败次数（所有 .count 文件之和）
total_failures() {
  local dir total f n
  dir="$(breaker_dir)"
  total=0
  if [ -d "$dir" ]; then
    for f in "$dir"/*.count; do
      [ -f "$f" ] || continue
      n="$(cat "$f" 2>/dev/null | tr -d ' \n\r')"
      if [ -n "$n" ] && [ "$n" -eq "$n" ] 2>/dev/null; then
        total=$((total + n))
      fi
    done
  fi
  echo "$total"
}

# ========================================
# 参数校验
# ========================================
if [ -z "$ACTION" ]; then
  log_error "用法: $0 --inc|--reset|--check|--clear|--list <flow-name> [step-id]"
  exit 2
fi

if [ "$ACTION" != "--clear" ] && [ "$ACTION" != "--list" ]; then
  if [ -z "$FLOW_NAME" ] || [ -z "$STEP_ID" ]; then
    log_error "缺少 flow-name 或 step-id 参数"
    exit 2
  fi
else
  if [ -z "$FLOW_NAME" ]; then
    log_error "缺少 flow-name 参数"
    exit 2
  fi
fi

# ========================================
# 执行
# ========================================
case "$ACTION" in
  --inc)
    # T1：同一步骤计数
    cur="$(read_count "$STEP_ID")"
    new=$((cur + 1))
    write_count "$STEP_ID" "$new"
    
    # T2：全流程累计
    total="$(total_failures)"
    
    tripped=false
    trip_reason=""
    
    if [ "$new" -ge "$STEP_FAILURE_THRESHOLD" ]; then
      tripped=true
      trip_reason="T1：步骤 ${STEP_ID} 连续失败 ${new}/${STEP_FAILURE_THRESHOLD} 次"
    fi
    
    if [ "$total" -ge "$FLOW_FAILURE_THRESHOLD" ]; then
      tripped=true
      trip_reason="${trip_reason:+${trip_reason}；}T2：全流程累计失败 ${total}/${FLOW_FAILURE_THRESHOLD} 次"
    fi
    
    if [ "$tripped" = "true" ]; then
      log_fail "🔴 熔断触发: ${trip_reason}"
      echo ""
      echo "  当前步骤: step-${STEP_ID}（失败 ${new} 次）"
      echo "  全流程累计: ${total} 次"
      echo ""
      echo "  处理建议："
      echo "    1. 检查当前步骤是否陷入修复循环"
      echo "    2. 考虑回退步骤重新制定方案（回退步骤 3）"
      echo "    3. 或暂停流程手动介入"
      echo ""
      echo "  解除熔断："
      echo "    bash $0 --reset ${FLOW_NAME} ${STEP_ID}"
      exit 1
    fi
    
    log_warn "⚠️  [${STEP_ID}] 失败计数: ${cur} → ${new}（T1=${STEP_FAILURE_THRESHOLD}, T2=${total}/${FLOW_FAILURE_THRESHOLD}）"
    exit 0
    ;;

  --reset)
    write_count "$STEP_ID" 0
    log_pass "[${STEP_ID}] 失败计数已重置为 0"
    exit 0
    ;;

  --check)
    # 仅检查 T1，T2 也顺带检查
    cur="$(read_count "$STEP_ID")"
    total="$(total_failures)"
    
    tripped=false
    if [ "$cur" -ge "$STEP_FAILURE_THRESHOLD" ]; then
      tripped=true
    fi
    if [ "$total" -ge "$FLOW_FAILURE_THRESHOLD" ]; then
      tripped=true
    fi
    
    if [ "$tripped" = "true" ]; then
      log_fail "[${STEP_ID}] 已熔断（T1=${cur}/${STEP_FAILURE_THRESHOLD}, T2=${total}/${FLOW_FAILURE_THRESHOLD}）"
      exit 1
    fi
    log_info "[${STEP_ID}] 未熔断（T1=${cur}/${STEP_FAILURE_THRESHOLD}, T2=${total}/${FLOW_FAILURE_THRESHOLD}）"
    exit 0
    ;;

  --clear)
    if [ -d "$(breaker_dir)" ]; then
      rm -rf "$(breaker_dir)"
      log_pass "已清空 ${FLOW_NAME} 的所有熔断计数"
    else
      log_info "无熔断计数需要清理"
    fi
    exit 0
    ;;

  --list)
    dir="$(breaker_dir)"
    if [ ! -d "$dir" ]; then
      echo "(no breaker state)"
      exit 0
    fi
    found=0
    for f in "$dir"/*.count; do
      [ -f "$f" ] || continue
      found=1
      stage="$(basename "$f" .count)"
      n="$(read_count "$stage")"
      printf "  %-20s %s/%s\n" "$stage" "$n" "$STEP_FAILURE_THRESHOLD"
    done
    total="$(total_failures)"
    printf "  %-20s %s/%s\n" "(total)" "$total" "$FLOW_FAILURE_THRESHOLD"
    [ "$found" -eq 0 ] && echo "(no breaker state)"
    exit 0
    ;;

  *)
    log_error "未实现的 action: $ACTION"
    exit 2
    ;;
esac
