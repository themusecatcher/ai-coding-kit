#!/bin/bash
# gate-9-to-10.sh - 轻量门禁：反思(9) → 归档(10)
# 仅校验 step-9 JSON 关键字段
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
for field in learnings_recorded reflection_summary; do
  value=$(df_jq_get "$STEP_JSON" ".outputs.$field" "")
  if [ -z "$value" ]; then
    log_fail "缺少必需字段: outputs.$field"
    fail=1
  fi
done

if [ $fail -eq 0 ]; then
  log_pass "gate-9-to-10 通过"
  exit 0
else
  exit 1
fi
