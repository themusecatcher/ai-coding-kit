#!/usr/bin/env bash
# ============================================================================
#  test-state.sh — state.sh 单元测试
#  ----------------------------------------------------------------------------
#  覆盖（与 §7.4 计划一致）：
#    - 5 个状态全覆盖：dirty / clean / synced / stale / deprecated
#    - stdin 输入路径
#    - 错误信息分层：confidence 缺失 / 未知 confidence / JSON 不合法
#  ----------------------------------------------------------------------------
#  断言策略：正向用例断言 stdout + exit；错误用例仅断言 exit != 0
#    （state.sh 错误路径 stderr 是友好中文，但断 exit 已足够保证契约）
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_SH="$SKILL_ROOT/scripts/lib/state.sh"

PASS=0
FAIL=0
FAILED_CASES=()

# ----------------------------------------------------------------------------
# 工具
# ----------------------------------------------------------------------------
# 运行 state.sh（参数模式），全局变量 OUT / RC
run_state_args() {
  set +e
  OUT=$(bash "$STATE_SH" "$@" 2>/dev/null)
  RC=$?
  set -e
}

# 运行 state.sh（stdin 模式），$1 = stdin 内容，剩余为参数
run_state_stdin() {
  local stdin_content="$1"; shift
  set +e
  OUT=$(printf '%s' "$stdin_content" | bash "$STATE_SH" "$@" 2>/dev/null)
  RC=$?
  set -e
}

assert_state() {
  local name="$1"; local expect="$2"
  if [ "$RC" -eq 0 ] && [ "$OUT" = "$expect" ]; then
    PASS=$((PASS + 1))
    printf '  ✓ %s\n' "$name"
  else
    FAIL=$((FAIL + 1))
    FAILED_CASES+=("$name (expect=$expect got_stdout='$OUT' exit=$RC)")
    printf '  ✗ %s (expect=%s got_stdout=%q exit=%d)\n' "$name" "$expect" "$OUT" "$RC"
  fi
}

assert_fail() {
  local name="$1"
  if [ "$RC" -ne 0 ]; then
    PASS=$((PASS + 1))
    printf '  ✓ %s (exit=%d)\n' "$name" "$RC"
  else
    FAIL=$((FAIL + 1))
    FAILED_CASES+=("$name (expected non-zero exit, got 0; stdout='$OUT')")
    printf '  ✗ %s (expected non-zero exit, got 0)\n' "$name"
  fi
}

# ----------------------------------------------------------------------------
# 用例
# ----------------------------------------------------------------------------
echo "[test-state]"

# --- 5 状态全覆盖 ---
run_state_args --json '{"confidence":"draft"}'
assert_state "draft → dirty" "dirty"

run_state_args --json '{"confidence":"verified"}'
assert_state "verified (no synced flag) → clean" "clean"

run_state_args --json '{"confidence":"verified"}' --synced-flag true
assert_state "verified + synced-flag=true → synced" "synced"

run_state_args --json '{"confidence":"stale"}'
assert_state "stale → stale" "stale"

run_state_args --json '{"confidence":"deprecated"}'
assert_state "deprecated (终态优先) → deprecated" "deprecated"

# --- drift_count 强制升级（confidence=verified 但 drift>=3） ---
run_state_args --json '{"confidence":"verified","stability":{"drift_count":3}}'
assert_state "verified + drift_count=3 → stale (强制升级)" "stale"

# --- stdin 输入路径 ---
run_state_stdin '{"confidence":"pending"}'
assert_state "stdin pending → dirty" "dirty"

# --- 错误信息分层 ---
run_state_args --json '{}'
assert_fail "missing .confidence"

run_state_args --json '{"confidence":"foobar"}'
assert_fail "unknown confidence value"

run_state_args --json 'not-json'
assert_fail "invalid JSON"

# ----------------------------------------------------------------------------
# 汇总
# ----------------------------------------------------------------------------
echo
echo "[test-state] PASS=$PASS  FAIL=$FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "[test-state] failed cases:"
  for c in "${FAILED_CASES[@]}"; do
    echo "  - $c"
  done
  exit 1
fi
exit 0
