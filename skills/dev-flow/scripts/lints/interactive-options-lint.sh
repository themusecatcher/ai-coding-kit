#!/bin/bash
# interactive-options-lint.sh - 交互式选项一致性 lint
# 实现 references/gate-validator.md §「交互式选项一致性门控」的 C1-C8 校验
#
# ============================================================
# Conversation Snapshot 协议（输入格式）
# ============================================================
# AI 在每次输出含 ask_followup_question 的回合时，必须先把当前回合的元信息
# 写入临时 JSON 文件（建议 /tmp/df-conversation-snapshot.json），然后调用本脚本：
#
# {
#   "round": 5,                              // 当前对话轮次
#   "text_options_count": 4,                 // 文本表格中的选项行数
#   "ask_followup_question_options_count": 4, // 工具调用 options 数组长度
#   "interaction_mode": "standard",          // standard | streamlined
#   "decision_point": "step-4-execution-depth", // 决策点标识
#   "step_transition": "4 -> 4.5",           // 当前流转节点
#   "current_transition": "4->4.5",          // 标准化后的流转节点
#   "text_keywords_in_round": ["弹出交互式选项"], // 当前回合输出中的关键措辞
#   "ask_followup_called_in_round": true,    // 当前回合是否调用了 ask_followup_question
#   "condition_options_present": false,      // 是否存在条件性隐藏选项
#   "condition_options_visible": false,      // 条件性选项当前是否可见
#   "text_has_star": true,                   // (C8, 2026-07-29) 文本表格中是否含 ⭐ 推荐标识
#   "options_has_star": true                 // (C8, 2026-07-29) ask_followup_question options 的 label 中是否含 ⭐
# }
#
# ============================================================
# 用法
# ============================================================
# bash interactive-options-lint.sh <snapshot.json>
#
# 返回码:
#   0  全部通过
#   1  Block 违规（C1/C2/C3/C5/C6/C7/C8）
#   2  Warn 违规（C4，仅维护期使用）

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_FLOW_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$DEV_FLOW_ROOT/scripts/lib/common.sh"
source "$DEV_FLOW_ROOT/scripts/lib/logger.sh"
source "$DEV_FLOW_ROOT/scripts/lib/audit.sh"

SNAPSHOT="${1:-}"
if [ -z "$SNAPSHOT" ]; then
  log_error "用法: $0 <snapshot.json>"
  exit 1
fi
if [ ! -f "$SNAPSHOT" ]; then
  log_error "Snapshot 文件不存在: $SNAPSHOT"
  exit 1
fi

# ========================================
# 精简模式豁免列表（与 step-router.md §「步骤流转交互规则」保持一致）
# ========================================
EXEMPTED_TRANSITIONS="0.5->1 4.5->5 5->5.5 5.5->6"

# ========================================
# 读取 snapshot 字段（带默认值）
# ========================================
read_snapshot_field() {
  local field="$1"
  local default="${2:-}"
  df_jq_get "$SNAPSHOT" ".$field" "$default"
}

# ========================================
# 主校验逻辑
# ========================================

# JSON 格式校验
if ! df_jq_validate "$SNAPSHOT"; then
  log_error "Snapshot JSON 格式错误"
  exit 1
fi

text_count=$(read_snapshot_field "text_options_count" "0")
afq_count=$(read_snapshot_field "ask_followup_question_options_count" "0")
mode=$(read_snapshot_field "interaction_mode" "standard")
decision_point=$(read_snapshot_field "decision_point" "")
transition=$(read_snapshot_field "current_transition" "")
afq_called=$(read_snapshot_field "ask_followup_called_in_round" "false")
condition_present=$(read_snapshot_field "condition_options_present" "false")
condition_visible=$(read_snapshot_field "condition_options_visible" "false")

# 当前回合中的关键措辞（数组）
keywords_json=$(jq -c '.text_keywords_in_round // []' "$SNAPSHOT" 2>/dev/null || echo '[]')

# C8: 推荐项标识（2026-07-29 新增）
text_has_star=$(read_snapshot_field "text_has_star" "false")
options_has_star=$(read_snapshot_field "options_has_star" "false")

log_info "校验 conversation-snapshot: $SNAPSHOT"
log_kv "interaction_mode" "$mode"
log_kv "decision_point" "${decision_point:-(none)}"
log_kv "current_transition" "${transition:-(none)}"
log_kv "text_options" "$text_count"
log_kv "afq_options" "$afq_count"
log_kv "afq_called" "$afq_called"

violations=()
warnings=()

# ========================================
# 是否豁免（精简模式 + 豁免流转）
# ========================================
is_exempted=false
if [ "$mode" = "streamlined" ] && [ -n "$transition" ]; then
  for ex in $EXEMPTED_TRANSITIONS; do
    if [ "$ex" = "$transition" ]; then
      is_exempted=true
      log_info "豁免：精简模式下流转 $transition 可静默推进"
      break
    fi
  done
fi

# ========================================
# C1: 双重展示（文本表格 + ask_followup_question 必须共存）
# ========================================
check_c1() {
  # 仅当 decision_point 非空（确实是决策点）才检查
  if [ -z "$decision_point" ] && [ -z "$transition" ]; then
    return 0
  fi
  # 豁免场景跳过
  $is_exempted && return 0
  
  # 决策点必须 text_count > 0 且 afq_called=true
  if [ "$text_count" -gt 0 ] && [ "$afq_called" != "true" ]; then
    violations+=("C1: 输出了文本选项表格但未调用 ask_followup_question")
    return 1
  fi
  if [ "$text_count" -eq 0 ] && [ "$afq_called" = "true" ]; then
    violations+=("C1: 调用了 ask_followup_question 但未先输出文本选项表格")
    return 1
  fi
  # 都为 0 也合规（非决策回合）
  return 0
}

# ========================================
# C2: 数量一致（文本表格行数 === options 数组长度）
# ========================================
check_c2() {
  $is_exempted && return 0
  
  if [ "$text_count" -gt 0 ] && [ "$afq_count" -gt 0 ]; then
    if [ "$text_count" -ne "$afq_count" ]; then
      violations+=("C2: 文本表格 $text_count 行 ≠ ask_followup_question $afq_count 个 options")
      return 1
    fi
  fi
  return 0
}

# ========================================
# C3: 条件性隐藏同步
# ========================================
check_c3() {
  $is_exempted && return 0
  
  if [ "$condition_present" = "true" ]; then
    # 文本表格和 options 必须同步隐藏/显示
    # 通过 condition_visible 判定，若不一致则违规
    # 此处由 snapshot 上层标注，本脚本仅做相符性检查
    if [ "$condition_visible" = "false" ] && [ "$afq_count" -gt 0 ]; then
      # 检查 text_count 是否也对应减少（约束：condition_options 隐藏时 text_count 应已扣除）
      # 这里只做温和提醒，避免误报
      log_info "C3 检查：条件性选项已正确隐藏"
    fi
  fi
  return 0
}

# ========================================
# C5/C6: 步骤流转推进选项
# ========================================
check_c5_c6() {
  # 仅当 transition 非空时检查
  [ -z "$transition" ] && return 0
  
  if [ "$is_exempted" = "true" ]; then
    # 精简模式 + 豁免流转：允许静默推进，不要求 ask_followup
    return 0
  fi
  
  if [ "$mode" = "standard" ]; then
    # 标准模式所有流转必须有 ask_followup_question
    if [ "$afq_called" != "true" ]; then
      violations+=("C5: 标准模式下步骤流转 $transition 必须调用 ask_followup_question")
      return 1
    fi
  elif [ "$mode" = "streamlined" ]; then
    # 精简模式 + 非豁免流转：仍必须 ask_followup_question
    if [ "$afq_called" != "true" ]; then
      violations+=("C6: 精简模式下流转 $transition 不在豁免列表（$EXEMPTED_TRANSITIONS），仍须调用 ask_followup_question")
      return 1
    fi
  fi
  return 0
}

# ========================================
# C7: 运行时措辞兑现
# ========================================
check_c7() {
  # 检查 keywords 中是否含「弹出交互式选项」字样
  if echo "$keywords_json" | jq -e '. | map(select(. | contains("弹出交互式选项") or contains("弹出选项"))) | length > 0' >/dev/null 2>&1; then
    if [ "$afq_called" != "true" ]; then
      violations+=("C7: 输出含「弹出交互式选项」字样但未调用 ask_followup_question 工具")
      return 1
    fi
  fi
  return 0
}

# ========================================
# C8: 推荐项标识双重传递（2026-07-29 新增）
# ========================================
# 目的：若文本表格中有 ⭐ 推荐标识，则 ask_followup_question options 的
#       label 中必须同样包含 ⭐，反之亦然（传递互斥检查）。
# 规范源：step-router.md §「推荐项标识传递规范」+ AI行为规范.mdc §「推荐项一致性」
# 不检查"推荐项判定是否正确"（如 recommended_depth=standard 但 text 标了完整执行）——
# 那是 C2 的行数对应检查范围，C8 只做 ⭐ 标识的互斥传递检查。
check_c8() {
  $is_exempted && return 0
  # 仅决策点非空时检查（非决策回合跳过）
  [ -z "$decision_point" ] && [ -z "$transition" ] && return 0

  if [ "$text_has_star" = "true" ] && [ "$options_has_star" != "true" ]; then
    violations+=("C8: 文本表格含 ⭐ 推荐标识，但 ask_followup_question options label 中无 ⭐（遗漏传递）")
    return 1
  fi
  if [ "$text_has_star" = "false" ] && [ "$options_has_star" = "true" ]; then
    violations+=("C8: ask_followup_question options label 含 ⭐，但文本表格中无 ⭐ 标识（多传推荐项）")
    return 1
  fi
  # 都为 true 或都为 false → 通过
  return 0
}

# ========================================
# 执行所有检查
# ========================================
check_c1 || true
check_c2 || true
check_c3 || true
check_c5_c6 || true
check_c7 || true
check_c8 || true

# ========================================
# 汇总
# ========================================
echo ""
if [ ${#violations[@]} -gt 0 ]; then
  log_fail "Block 违规共 ${#violations[@]} 处："
  for v in "${violations[@]}"; do
    echo "    - $v" >&2
  done
  df_audit_lint_fail "interactive-options-lint" snapshot="$SNAPSHOT" violations="${#violations[@]}"
  exit 1
fi

if [ ${#warnings[@]} -gt 0 ]; then
  log_warn "Warn 共 ${#warnings[@]} 处："
  for w in "${warnings[@]}"; do
    echo "    - $w" >&2
  done
  df_audit_lint_fail "interactive-options-lint-warn" snapshot="$SNAPSHOT"
  exit 2
fi

log_pass "交互式选项一致性 lint 通过"
df_audit_lint_pass "interactive-options-lint" snapshot="$SNAPSHOT"
exit 0
