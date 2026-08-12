#!/bin/bash
# step5-precheck.sh - 编码前置硬卡点（步骤 5 加载前强制校验）
# 实现 steps/step-router.md §「编码前置硬卡点」的 5 项校验
#
# 用法:
#   bash step5-precheck.sh <flow-name>
#
# 返回码:
#   0  5 项全部通过
#   1  任一项失败（禁止加载 step-5）
#   2  参数错误

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_FLOW_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$DEV_FLOW_ROOT/scripts/lib/common.sh"
source "$DEV_FLOW_ROOT/scripts/lib/logger.sh"
source "$DEV_FLOW_ROOT/scripts/lib/audit.sh"

FLOW_NAME="${1:-}"
WC_DIR="$(df_workcontext_path)"
ACTIVE_FLOWS="$(df_active_flows_dir)"

if [ -z "$FLOW_NAME" ]; then
  log_error "用法: $0 <flow-name>"
  exit 2
fi

log_info "编码前置硬卡点校验：flow=$FLOW_NAME"

# ========================================
# 读取 mode（决定走标准校验还是 micro-fix 专项校验）
# ========================================
FLOW_FILE="$ACTIVE_FLOWS/${FLOW_NAME}.flow"
if [ ! -f "$FLOW_FILE" ]; then
  log_fail "🔴 项 2 失败：.flow 锁文件不存在 - $FLOW_FILE"
  df_audit_redcard "step5_precheck" reason="flow_missing" flow="$FLOW_NAME"
  exit 1
fi

MODE=$(df_get_flow_mode "$FLOW_FILE")
CURRENT_STEP=$(df_get_flow_current_step "$FLOW_FILE")
log_kv "mode" "$MODE"
log_kv "current_step" "${CURRENT_STEP:-(未设置)}"

failures=0

# ========================================
# 项 1：工作上下文文件存在（标准 + micro-fix 共用）
# ========================================
check_1_workcontext_exists() {
  local wc_file="$WC_DIR/${FLOW_NAME}.md"
  if [ -f "$wc_file" ]; then
    log_pass "项 1：工作上下文文件存在 - $wc_file"
    return 0
  fi
  log_fail "🔴 项 1 失败：工作上下文文件不存在 - $wc_file"
  echo "    处理建议：回退到阶段 0 创建工作上下文" >&2
  return 1
}

# ========================================
# 项 2（标准）：.flow 步骤 ≥ 4.5
# ========================================
check_2_standard_step_at_least_4_5() {
  if [ -z "$CURRENT_STEP" ]; then
    log_fail "🔴 项 2 失败：.flow 中 current_step 未设置"
    return 1
  fi
  # 浮点比较 current_step ≥ 4.5
  if awk -v s="$CURRENT_STEP" 'BEGIN{exit !(s+0 >= 4.5)}'; then
    log_pass "项 2：.flow current_step=$CURRENT_STEP ≥ 4.5"
    return 0
  fi
  log_fail "🔴 项 2 失败：current_step=$CURRENT_STEP < 4.5"
  echo "    处理建议：回退到最后完成的步骤" >&2
  return 1
}

# ========================================
# 项 3（标准）：步骤 4 user_decision 非空
# ========================================
check_3_standard_user_decision() {
  local step4_json="$ACTIVE_FLOWS/${FLOW_NAME}.step-4.validated.json"
  if [ ! -f "$step4_json" ]; then
    # 步骤 4 元信息缺失也算违规
    log_fail "🔴 项 3 失败：缺少 step-4.validated.json - $step4_json"
    echo "    处理建议：回退到步骤 4 等待用户决策" >&2
    return 1
  fi
  # 简单字符串检查（json 文件可能是 ad-hoc 格式）
  if grep -qE '"user_decision"\s*:\s*"[^"]+' "$step4_json" 2>/dev/null; then
    log_pass "项 3：step-4 user_decision 非空"
    return 0
  fi
  # validate-output.sh 创建的 .json 文件可能不直接含 user_decision，
  # 此时检查工作上下文 .md 中是否有 user_decision 字段
  local wc_file="$WC_DIR/${FLOW_NAME}.md"
  if [ -f "$wc_file" ] && grep -qE '^[[:space:]]*user_decision:[[:space:]]+(execute_|modify|change_plan|pause|cancel)' "$wc_file" 2>/dev/null; then
    log_pass "项 3：工作上下文中 user_decision 已记录"
    return 0
  fi
  log_warn "项 3：未找到 user_decision 显式字段（如已确认请检查工作上下文）"
  return 0  # 软失败：不阻塞，但产生警告
}

# ========================================
# 项 4（标准）：步骤 2/4 有 ask_followup_question 交互记录
# ========================================
# 此项无法用脚本严格校验（对话历史不持久化），仅做存在性提示
check_4_standard_interaction_recorded() {
  log_info "项 4：交互记录校验（提示性，无法严格机械校验）"
  log_info "      请人工确认步骤 2/4 已通过 ask_followup_question 让用户确认"
  return 0
}

# ========================================
# 项 2（micro-fix）：阶段 0 极简确认已完成
# ========================================
check_2_microfix_intake_confirmed() {
  # 通过工作上下文 ## 元数据 > intake_confirmed 字段判断
  local wc_file="$WC_DIR/${FLOW_NAME}.md"
  if [ ! -f "$wc_file" ]; then
    log_fail "🔴 项 2 失败：工作上下文不存在"
    return 1
  fi
  if grep -qE '^[[:space:]]*intake_confirmed:[[:space:]]*true' "$wc_file" 2>/dev/null; then
    log_pass "项 2 (micro-fix)：阶段 0 极简确认已完成"
    return 0
  fi
  log_warn "项 2 (micro-fix)：未找到 intake_confirmed: true 字段（提示性）"
  return 0
}

# ========================================
# 项 3（micro-fix）：4.5 主干分支检测通过 (branch_safe: true)
# ========================================
check_3_microfix_branch_safe() {
  local wc_file="$WC_DIR/${FLOW_NAME}.md"
  local step4_5_json="$ACTIVE_FLOWS/${FLOW_NAME}.step-4_5.validated.json"
  
  if [ -f "$step4_5_json" ] && grep -qE '"branch_safe"\s*:\s*true' "$step4_5_json" 2>/dev/null; then
    log_pass "项 3 (micro-fix)：4.5 branch_safe=true"
    return 0
  fi
  if [ -f "$wc_file" ] && grep -qE '^[[:space:]]*branch_safe:[[:space:]]*true' "$wc_file" 2>/dev/null; then
    log_pass "项 3 (micro-fix)：工作上下文 branch_safe=true"
    return 0
  fi
  log_fail "🔴 项 3 (micro-fix) 失败：未找到 branch_safe=true（4.5 主干分支检测未通过）"
  echo "    处理建议：回退到 4.5 重新检测分支" >&2
  return 1
}

# ========================================
# 项 4（micro-fix）：未命中降级条件
# ========================================
check_4_microfix_no_downgrade() {
  log_info "项 4 (micro-fix)：降级条件检测（>15行/≥2文件/主干分支/需决策思考）"
  log_info "      此项由 mode-matrix 在阶段 0 评估，运行时仅提示"
  return 0
}

# ========================================
# 项 5（v2 新增）：产物链完整性验证（复用 physical-checkpoint.sh）
# Pipeline Harness 思想：缺少前序产物 → 不可能合法到达步骤 5
# ========================================
check_5_artifact_chain() {
  local pc_script="$DEV_FLOW_ROOT/scripts/precheck/physical-checkpoint.sh"
  
  if [ ! -f "$pc_script" ]; then
    log_warn "项 5：physical-checkpoint.sh 不存在，跳过产物链验证"
    return 0
  fi
  
  # physical-checkpoint.sh 已按 mode 自动选择所需检查点
  # 只需确认"到达步骤 5 前的所有必需检查点"都已存在
  log_info "项 5：调用 physical-checkpoint.sh 验证前序产物链"
  
  # 获取当前模式步骤 5 之前应有的检查点
  local result
  result=$(bash "$pc_script" "$FLOW_NAME" "step-5" 2>&1)
  local exit_code=$?
  
  if [ $exit_code -eq 0 ]; then
    log_pass "项 5：产物链完整性验证通过"
    return 0
  fi
  
  log_fail "🔴 项 5 失败：前序产物链不完整"
  echo "$result" | grep -E "^(🔴|  )" >&2
  echo "    处理建议：回退到缺失的步骤重新执行" >&2
  return 1
}

# ========================================
# 主流程：根据 mode 选择校验集
# ========================================
echo ""
log_section "项 1：工作上下文存在性校验"
check_1_workcontext_exists || failures=$((failures + 1))

echo ""
case "$MODE" in
  micro-fix)
    log_section "micro-fix 专项校验（项 2/3/4）"
    check_2_microfix_intake_confirmed || failures=$((failures + 1))
    check_3_microfix_branch_safe      || failures=$((failures + 1))
    check_4_microfix_no_downgrade     || failures=$((failures + 1))
    ;;
  *)
    log_section "标准/其他模式校验（项 2/3/4）"
    check_2_standard_step_at_least_4_5 || failures=$((failures + 1))
    check_3_standard_user_decision     || failures=$((failures + 1))
    check_4_standard_interaction_recorded || failures=$((failures + 1))
    ;;
esac

echo ""
log_section "项 5：产物链完整性校验（v2）"
check_5_artifact_chain || failures=$((failures + 1))

# ========================================
# 汇总
# ========================================
echo ""
if [ $failures -gt 0 ]; then
  log_fail "🔴 编码前置硬卡点未通过：$failures 项失败"
  echo "    禁止加载 step-5-execute.md，必须按提示回退到对应步骤" >&2
  df_audit_redcard "step5_precheck_failed" flow="$FLOW_NAME" mode="$MODE" failures="$failures"
  exit 1
fi

log_pass "✅ 编码前置硬卡点全部通过：可加载 step-5"
df_audit_gate_pass "step5_precheck" flow="$FLOW_NAME" mode="$MODE"
exit 0
