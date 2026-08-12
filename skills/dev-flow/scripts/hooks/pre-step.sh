#!/bin/bash
# pre-step.sh - 步骤加载前统一钩子调度
# 在 read_file("steps/step-N-xxx.md") 之前调用，自动执行该步骤所需的所有前置校验
#
# 用法:
#   bash pre-step.sh <flow-name> <target-step-id>
#
# 行为:
#   1. 调用 physical-checkpoint.sh 校验白名单
#   2. 若 target=5，调用 step5-precheck.sh 校验编码前置硬卡点
#   3. 其他步骤后续可扩展
#
# 返回码:
#   0 全部通过；1 任一前置校验失败；2 参数错误

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_FLOW_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$DEV_FLOW_ROOT/scripts/lib/common.sh"
source "$DEV_FLOW_ROOT/scripts/lib/logger.sh"
source "$DEV_FLOW_ROOT/scripts/lib/audit.sh"

FLOW_NAME="${1:-}"
TARGET_STEP="${2:-}"

if [ -z "$FLOW_NAME" ] || [ -z "$TARGET_STEP" ]; then
  log_error "用法: $0 <flow-name> <target-step-id>"
  exit 2
fi

log_section "🔒 PreStepLoad Hook (target=step-$TARGET_STEP)"
df_audit "hook.pre_step.start" "pre-step hook started" flow="$FLOW_NAME" target="$TARGET_STEP"

failures=0

# ========================================
# 1. 物理检查点白名单校验（所有步骤）
# ========================================
log_step "1. 物理检查点白名单"
if ! bash "$DEV_FLOW_ROOT/scripts/precheck/physical-checkpoint.sh" "$FLOW_NAME" "$TARGET_STEP"; then
  failures=$((failures + 1))
fi

# ========================================
# 2. 步骤 5 编码前置硬卡点
# ========================================
if [ "$TARGET_STEP" = "5" ]; then
  echo ""
  log_step "2. 编码前置硬卡点（仅 step-5）"
  if ! bash "$DEV_FLOW_ROOT/scripts/precheck/step5-precheck.sh" "$FLOW_NAME"; then
    failures=$((failures + 1))
  fi

  # 标记步骤 5 开始时间戳（供 working-context-freshness-lint 校验）
  log_step "2b. 标记步骤 5 开始时间戳"
  bash "$DEV_FLOW_ROOT/scripts/lints/mark-step5-start.sh" "$FLOW_NAME"
fi

# ========================================
# 汇总
# ========================================
echo ""
if [ $failures -gt 0 ]; then
  log_fail "❌ pre-step hook 失败：$failures 项前置校验未通过"
  log_error "禁止加载 step-$TARGET_STEP；按上方提示回退"
  df_audit "hook.pre_step.fail" "pre-step hook failed" flow="$FLOW_NAME" target="$TARGET_STEP" failures="$failures"
  exit 1
fi

log_pass "✅ pre-step hook 全部通过：可加载 step-$TARGET_STEP"
df_audit "hook.pre_step.pass" "pre-step hook passed" flow="$FLOW_NAME" target="$TARGET_STEP"
exit 0
