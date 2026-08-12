#!/bin/bash
# ============================================================
# gate-4-to-5.sh - 重量门禁：决策(4) → 编码(5)
#
# 检查编码前置条件：
#   P0-1: 工作上下文存在
#   P0-2: .flow 文件存在
#   P0-3: 用户决策已确认（step-4 JSON 有 execution_depth）
#   P1-1: 不在主干分支（main/master）
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

# 修复：本门禁检查的是「步骤 4 的决策产物」（execution_depth / branch_workspace
# / plan_summary 等字段）。harness-engine.sh 按 FROM_STEP=4.5 拼接传入的是
# step-4_5.json（步骤 4.5 的产物，不含决策字段），导致 P0-3/P1-2 必然失败。
# 此处优先定位 step-4.json（步骤 4 的决策产物），不存在时才回退传入参数。
ARTIFACT_DIR_LOCAL="$HOME/.codebuddy/dev-flow-artifacts/$FLOW_NAME"
if [ -f "$ARTIFACT_DIR_LOCAL/step-4.json" ]; then
  STEP_JSON="$ARTIFACT_DIR_LOCAL/step-4.json"
fi

p0_total=0; p0_fails=0
p1_total=0; p1_fails=0

# ======== P0 检查 ========

# P0-1: 工作上下文存在
p0_total=$((p0_total + 1))
log_step "P0-1: 工作上下文存在"
WC_DIR="$(df_workcontext_path)"
WC_FILE=$(find "$WC_DIR" -maxdepth 1 -name "*.md" 2>/dev/null | head -1)
if [ -n "$WC_FILE" ] && [ -f "$WC_FILE" ]; then
  log_pass "P0-1: 工作上下文存在: $(basename "$WC_FILE")"
else
  log_fail "P0-1: 工作上下文不存在（$WC_DIR 下无 .md 文件）"
  p0_fails=$((p0_fails + 1))
fi

# P0-2: .flow 文件存在
p0_total=$((p0_total + 1))
log_step "P0-2: .flow 文件存在"
FLOW_DIR="$(df_active_flows_dir)"
FLOW_FILE=$(find "$FLOW_DIR" -name "*.flow" 2>/dev/null | head -1)
if [ -n "$FLOW_FILE" ] && [ -f "$FLOW_FILE" ]; then
  log_pass "P0-2: .flow 存在: $(basename "$FLOW_FILE")"
else
  log_fail "P0-2: .flow 文件不存在（$FLOW_DIR 下无 .flow 文件）"
  p0_fails=$((p0_fails + 1))
fi

# P0-3: 用户决策已确认
p0_total=$((p0_total + 1))
log_step "P0-3: 用户决策已确认"
if [ -f "$STEP_JSON" ]; then
  exec_depth=$(df_jq_get "$STEP_JSON" ".outputs.execution_depth" "")
  if [ -n "$exec_depth" ]; then
    log_pass "P0-3: 执行深度已决策: $exec_depth"
  else
    log_fail "P0-3: step-4 JSON 缺少 execution_depth 字段"
    p0_fails=$((p0_fails + 1))
  fi
else
  log_fail "P0-3: 前步产物不存在: $STEP_JSON"
  p0_fails=$((p0_fails + 1))
fi

# ======== P1 检查 ========

# P1-1: 不在主干分支
p1_total=$((p1_total + 1))
log_step "P1-1: 分支检查"
current_branch=$(git branch --show-current 2>/dev/null || echo "")
if [ "$current_branch" = "main" ] || [ "$current_branch" = "master" ]; then
  log_warn "P1-1: 当前在主干分支 ($current_branch)，建议切到开发分支"
  p1_fails=$((p1_fails + 1))
elif [ -z "$current_branch" ]; then
  log_skip "P1-1: 非 Git 仓库或 detached HEAD（跳过）"
else
  log_pass "P1-1: 分支: $current_branch"
fi

# ======== 汇总 ========
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  门禁 step-4 → step-5"
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
