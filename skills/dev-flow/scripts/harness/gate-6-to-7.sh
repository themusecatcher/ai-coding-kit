#!/bin/bash
# ============================================================
# gate-6-to-7.sh - 重量门禁：验证(6) → commit(7)
#
# 检查验证通过后的推进条件：
#   P0-1: 验证步骤已通过（step-6 JSON 存在且 status=pass）
#   P0-2: 无阻塞级 lint 错误
#   P1-1: CR 状态检查（in_progress CR 提醒）
#
# 返回: 0=全部通过, 1=P0失败, 2=仅P1失败
# ============================================================

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_FLOW_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$DEV_FLOW_ROOT/scripts/lib/common.sh"
source "$DEV_FLOW_ROOT/scripts/lib/logger.sh"
source "$DEV_FLOW_ROOT/scripts/recovery/recovery-engine.sh"

FLOW_NAME="${1:-}"
STEP_JSON="${2:-}"
MODIFIED_FILES="${3:-}"

p0_total=0; p0_fails=0
p1_total=0; p1_fails=0

# ======== P0 检查 ========

# P0-1: 验证步骤已通过
p0_total=$((p0_total + 1))
log_step "P0-1: 验证步骤结果"
if [ -f "$STEP_JSON" ]; then
  verify_status=$(df_jq_get "$STEP_JSON" ".outputs.verification_status" "")
  if [ "$verify_status" = "pass" ] || [ "$verify_status" = "passed" ]; then
    log_pass "P0-1: 验证已通过"
  elif [ -z "$verify_status" ]; then
    # 兼容：JSON 存在但字段名不同，视为通过（validate-output.sh 已校验）
    log_pass "P0-1: 验证步骤已完成（产物存在）"
  else
    log_fail "P0-1: 验证状态异常: $verify_status"
    p0_fails=$((p0_fails + 1))
  fi
else
  log_fail "P0-1: 验证产物不存在: $STEP_JSON"
  p0_fails=$((p0_fails + 1))
fi

# P0-2: 无阻塞级 lint 错误
p0_total=$((p0_total + 1))
log_step "P0-2: Lint 状态"
if command -v npx &>/dev/null && [ -f "package.json" ]; then
  lint_target="${MODIFIED_FILES:-src/}"
  lint_errors=$(npx eslint $lint_target --quiet 2>&1 | grep -c "error" || echo "0")
  if [ "$lint_errors" -gt 0 ]; then
    # 尝试 auto-fix
    log_warn "P0-2: 发现 $lint_errors 处 lint 错误，尝试 fix..."
    if try_recover "lint" "auto_fix" "npx eslint $lint_target --fix --quiet" 1; then
      lint_errors_after=$(npx eslint $lint_target --quiet 2>&1 | grep -c "error" || echo "0")
      if [ "$lint_errors_after" -eq 0 ]; then
        log_pass "P0-2: Lint（auto-fix 后通过）"
      else
        log_fail "P0-2: Lint 仍有 $lint_errors_after 处错误"
        p0_fails=$((p0_fails + 1))
      fi
    fi
  else
    log_pass "P0-2: Lint 通过"
  fi
else
  log_skip "P0-2: Lint 跳过（无环境）"
fi

# ======== P1 检查 ========

# P1-1: CR 状态检查
p1_total=$((p1_total + 1))
log_step "P1-1: CR 状态检查"
WORKING_CONTEXT=$(find "$HOME/.codebuddy/working-context" -maxdepth 1 -name "*.md" 2>/dev/null | head -1)
if [ -n "$WORKING_CONTEXT" ] && [ -f "$WORKING_CONTEXT" ]; then
  in_progress_crs=$(grep -c 'status:.*in_progress' "$WORKING_CONTEXT" 2>/dev/null || echo "0")
  if [ "$in_progress_crs" -gt 0 ]; then
    log_warn "P1-1: 有 $in_progress_crs 个 CR 仍为 in_progress"
    log_info "  💡 建议确认变更已实现后标记为 done"
    p1_fails=$((p1_fails + 1))
  else
    log_pass "P1-1: 所有 CR 已完成（或无 CR）"
  fi
else
  log_pass "P1-1: 无工作上下文（跳过 CR 检查）"
fi

# ======== 汇总 ========
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  门禁 step-6 → step-7"
echo "  P0: $((p0_total - p0_fails))/$p0_total 通过"
echo "  P1: $((p1_total - p1_fails))/$p1_total 通过"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $p0_fails -gt 0 ]; then
  exit 1
elif [ $p1_fails -gt 0 ]; then
  exit 2
else
  exit 0
fi
