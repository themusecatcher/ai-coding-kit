#!/usr/bin/env bash
# ============================================================================
#  test-check-state.sh — check-state.sh 端到端单测
#  ----------------------------------------------------------------------------
#  覆盖（B-1 落盘 + 复用既有 fixtures）：
#    PASS（exit=0）:
#      - fixtures/state-deprecated.md  （B-1 新增正例：confidence=deprecated → state=deprecated）
#      - fixtures/_overview.md         （复用：confidence=verified → state=clean）
#    FAIL（exit=1）:
#      - fixtures/state-bad-confidence.md （B-1 新增反例：confidence=foobar 不在映射表）
#      - fixtures/no-fm.md             （复用：无 frontmatter）
#  ----------------------------------------------------------------------------
#  断言策略：仅断言 exit code（pass=0, fail=1）；不约束 stdout 文本格式
#  与 test-check-frontmatter.sh 风格保持一致。
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINT="$SKILL_ROOT/scripts/lints/check-state.sh"
FIX="$SCRIPT_DIR/fixtures"

PASS=0
FAIL=0
FAILED_CASES=()

# ----------------------------------------------------------------------------
# 工具
# ----------------------------------------------------------------------------
run_lint() {
  set +e
  OUT=$(bash "$LINT" "$@" 2>&1)
  RC=$?
  set -e
}

assert_pass() {
  local name="$1"; shift
  run_lint "$@"
  if [ "$RC" -eq 0 ]; then
    PASS=$((PASS + 1))
    printf '  ✓ %s (exit=0)\n' "$name"
  else
    FAIL=$((FAIL + 1))
    FAILED_CASES+=("$name (expected exit=0, got $RC)")
    printf '  ✗ %s (expected exit=0, got %d)\n' "$name" "$RC"
    printf '%s\n' "$OUT" | sed "s/^/      /"
  fi
}

assert_fail() {
  local name="$1"; shift
  run_lint "$@"
  if [ "$RC" -ne 0 ]; then
    PASS=$((PASS + 1))
    printf '  ✓ %s (exit=%d)\n' "$name" "$RC"
  else
    FAIL=$((FAIL + 1))
    FAILED_CASES+=("$name (expected non-zero exit, got 0)")
    printf '  ✗ %s (expected non-zero exit, got 0)\n' "$name"
    printf '%s\n' "$OUT" | sed "s/^/      /"
  fi
}

# ----------------------------------------------------------------------------
# 前置：确认依赖 + fixtures 都在
# ----------------------------------------------------------------------------
echo "[test-check-state]"

if [ ! -x "$LINT" ] && [ ! -r "$LINT" ]; then
  echo "  ✗ check-state.sh not found: $LINT" >&2
  exit 1
fi
for f in \
  "$FIX/state-deprecated.md" \
  "$FIX/_overview.md" \
  "$FIX/state-bad-confidence.md" \
  "$FIX/no-fm.md"; do
  if [ ! -r "$f" ]; then
    echo "  ✗ fixture missing: $f" >&2
    exit 1
  fi
done

# ----------------------------------------------------------------------------
# 用例
# ----------------------------------------------------------------------------

# --- PASS 用例（2 个） ---
assert_pass "fixtures/state-deprecated.md     (deprecated → state=deprecated)" "$FIX/state-deprecated.md"
assert_pass "fixtures/_overview.md            (verified → state=clean)"        "$FIX/_overview.md"

# --- FAIL 用例（2 个） ---
assert_fail "fixtures/state-bad-confidence.md (confidence not in mapping)"     "$FIX/state-bad-confidence.md"
assert_fail "fixtures/no-fm.md                (no frontmatter)"                "$FIX/no-fm.md"

# ----------------------------------------------------------------------------
# 汇总
# ----------------------------------------------------------------------------
echo
echo "[test-check-state] PASS=$PASS  FAIL=$FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "[test-check-state] failed cases:"
  for c in "${FAILED_CASES[@]}"; do
    echo "  - $c"
  done
  exit 1
fi
exit 0
