#!/bin/bash
# gate-5-to-5_5.sh - 轻量门禁：编码(5) → 编码后置钩子(5.5)
# 校验 step-5 JSON 已完成
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
for field in files_modified coding_completed; do
  value=$(df_jq_get "$STEP_JSON" ".outputs.$field" "")
  if [ -z "$value" ]; then
    log_fail "缺少必需字段: outputs.$field"
    fail=1
  fi
done

if [ $fail -eq 0 ]; then
  log_pass "gate-5-to-5.5 通过"
  exit 0
else
  exit 1
fi
