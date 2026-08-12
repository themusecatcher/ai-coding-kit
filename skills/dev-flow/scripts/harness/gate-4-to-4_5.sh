#!/bin/bash
# gate-4-to-4_5.sh - 轻量门禁：方案决策(4) → 环境检查(4.5)
# 校验 step-4 JSON 的核心决策字段
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_FLOW_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$DEV_FLOW_ROOT/scripts/lib/common.sh"
source "$DEV_FLOW_ROOT/scripts/lib/logger.sh"

FLOW_NAME="${1:-}"; STEP_JSON="${2:-}"; MODIFIED_FILES="${3:-}"

if [ ! -f "$STEP_JSON" ]; then
  log_fail "前步产物不存在: $STEP_JSON"
  exit 1
fi

# 校验关键字段（决策结果）
fail=0
for field in execution_depth plan_summary; do
  value=$(df_jq_get "$STEP_JSON" ".outputs.$field" "")
  if [ -z "$value" ]; then
    log_fail "缺少必需字段: outputs.$field"
    fail=1
  fi
done

# 校验 AI 推荐深度（确保环节 1 评估卡片已输出）
rec_depth=$(df_jq_get "$STEP_JSON" ".outputs.assessment.recommended_depth" "")
if [ -z "$rec_depth" ]; then
  log_fail "缺少必需字段: outputs.assessment.recommended_depth（环节 1 评估卡片未输出）"
  fail=1
elif [ "$rec_depth" != "standard" ] && [ "$rec_depth" != "full" ]; then
  log_fail "无效值: outputs.assessment.recommended_depth=$rec_depth（期望 standard 或 full）"
  fail=1
fi

if [ $fail -eq 0 ]; then
  log_pass "gate-4-to-4.5 通过"
  exit 0
else
  exit 1
fi
