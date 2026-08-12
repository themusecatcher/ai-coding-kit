#!/bin/bash
# gate-3-to-4.sh - 轻量门禁：方案设计(3) → 方案决策(4)
# 仅校验 step-3 JSON 关键字段
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

# 校验关键字段
fail=0
for field in plan_summary implementation_approach; do
  value=$(df_jq_get "$STEP_JSON" ".outputs.$field" "")
  if [ -z "$value" ]; then
    log_fail "缺少必需字段: outputs.$field"
    fail=1
  fi
done

if [ $fail -eq 0 ]; then
  log_pass "gate-3-to-4 通过"
  exit 0
else
  exit 1
fi
