#!/bin/bash
# ============================================================
# harness-engine.sh - 步骤间门禁统一调度引擎
#
# 用法: harness-engine.sh <flow-name> <from-step> <to-step> [modified-files]
# 返回: 0=通过, 1=P0失败(阻塞), 2=P1警告(不阻塞)
#
# 三层执行架构中的 Layer 3：
#   Layer 1: validate-output.sh（Schema 格式校验）
#   Layer 2: 产物归档（cp JSON → artifacts/）
#   Layer 3: harness-engine.sh（本脚本，质量门禁）
# ============================================================

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_FLOW_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$DEV_FLOW_ROOT/scripts/lib/common.sh"
source "$DEV_FLOW_ROOT/scripts/lib/logger.sh"
source "$DEV_FLOW_ROOT/scripts/lib/audit.sh"

FLOW_NAME="${1:-}"
FROM_STEP="${2:-}"
TO_STEP="${3:-}"
MODIFIED_FILES="${4:-}"

if [ -z "$FLOW_NAME" ] || [ -z "$FROM_STEP" ] || [ -z "$TO_STEP" ]; then
  log_error "用法: harness-engine.sh <flow-name> <from-step> <to-step> [modified-files]"
  exit 1
fi

# 规范化步骤名（与文件命名一致）
FROM_SLUG=$(echo "$FROM_STEP" | tr '.' '_' | tr '-' '_')
TO_SLUG=$(echo "$TO_STEP" | tr '.' '_' | tr '-' '_')

GATE_SCRIPT="$SCRIPT_DIR/gate-${FROM_SLUG}-to-${TO_SLUG}.sh"

# 无门禁脚本 → 直接放行
if [ ! -f "$GATE_SCRIPT" ]; then
  log_info "无门禁: step-$FROM_STEP -> step-$TO_STEP (直接放行)"
  exit 0
fi

log_section "🚧 质量门禁: step-$FROM_STEP → step-$TO_STEP"

# 获取前步产物 JSON
ARTIFACT_DIR="$HOME/.codebuddy/dev-flow-artifacts/$FLOW_NAME"
STEP_JSON="$ARTIFACT_DIR/step-$(echo "$FROM_STEP" | tr '.' '_').json"

# 确保门禁脚本可执行
df_ensure_executable "$GATE_SCRIPT"

# 执行门禁脚本
gate_rc=0
bash "$GATE_SCRIPT" "$FLOW_NAME" "$STEP_JSON" "$MODIFIED_FILES" || gate_rc=$?

case $gate_rc in
  0)
    log_pass "质量门禁通过: step-$FROM_STEP → step-$TO_STEP"
    df_audit "harness.pass" "gate passed" from="$FROM_STEP" to="$TO_STEP" flow="$FLOW_NAME"
    ;;
  1)
    log_fail "P0 门禁失败，禁止推进到 step-$TO_STEP"
    df_audit "harness.fail.p0" "gate P0 failed" from="$FROM_STEP" to="$TO_STEP" flow="$FLOW_NAME"
    ;;
  2)
    log_warn "P1 门禁警告 (不阻塞推进到 step-$TO_STEP)"
    df_audit "harness.warn.p1" "gate P1 warning" from="$FROM_STEP" to="$TO_STEP" flow="$FLOW_NAME"
    ;;
  *)
    log_warn "门禁返回未知码 $gate_rc (视为 P1 警告)"
    gate_rc=2
    ;;
esac

exit $gate_rc
