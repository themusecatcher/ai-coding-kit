#!/usr/bin/env bash
# ============================================================================
#  test-check-frontmatter.sh — check-frontmatter.sh 端到端单测
#  ----------------------------------------------------------------------------
#  覆盖（§7.7 已落盘 fixtures）：
#    PASS（exit=0）:
#      - fixtures/_index.md           （正例：完整 _index）
#      - fixtures/_overview.md        （正例：完整 _overview）
#      - fixtures/data-model.md       （正例：合法 topic）
#    FAIL（exit=1）:
#      - fixtures/extras/_index.md    （负例：缺 base_branch / created）
#      - fixtures/extras/bad-topic.md （负例：topic 不在 enum）
#      - fixtures/no-fm.md            （负例：无 frontmatter）
#  ----------------------------------------------------------------------------
#  断言策略：仅断言 exit code（pass=0, fail=1）；不约束 stdout 文本格式
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINT="$SKILL_ROOT/scripts/lints/check-frontmatter.sh"
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
echo "[test-check-frontmatter]"

if [ ! -x "$LINT" ] && [ ! -r "$LINT" ]; then
  echo "  ✗ check-frontmatter.sh not found: $LINT" >&2
  exit 1
fi
for f in \
  "$FIX/_index.md" \
  "$FIX/_overview.md" \
  "$FIX/data-model.md" \
  "$FIX/extras/_index.md" \
  "$FIX/extras/bad-topic.md" \
  "$FIX/no-fm.md"; do
  if [ ! -r "$f" ]; then
    echo "  ✗ fixture missing: $f" >&2
    exit 1
  fi
done

# ----------------------------------------------------------------------------
# 用例
# ----------------------------------------------------------------------------

# --- PASS 用例（3 个）---
assert_pass "fixtures/_index.md           (valid index)"     "$FIX/_index.md"
assert_pass "fixtures/_overview.md        (valid overview)"  "$FIX/_overview.md"
assert_pass "fixtures/data-model.md       (valid topic)"     "$FIX/data-model.md"

# --- FAIL 用例（3 个）---
assert_fail "fixtures/extras/_index.md    (missing required)" "$FIX/extras/_index.md"
assert_fail "fixtures/extras/bad-topic.md (topic not in enum)" "$FIX/extras/bad-topic.md"
assert_fail "fixtures/no-fm.md            (no frontmatter)"   "$FIX/no-fm.md"

# ----------------------------------------------------------------------------
# 汇总
# ----------------------------------------------------------------------------
echo
echo "[test-check-frontmatter] PASS=$PASS  FAIL=$FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "[test-check-frontmatter] failed cases:"
  for c in "${FAILED_CASES[@]}"; do
    echo "  - $c"
  done
  exit 1
fi
exit 0
