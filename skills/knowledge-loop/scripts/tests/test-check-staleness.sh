#!/usr/bin/env bash
# ============================================================================
#  test-check-staleness.sh — check-staleness.sh 端到端单测
#  ----------------------------------------------------------------------------
#  覆盖（4 用例，与决策"语义 a2"一致：仅断言 exit code 行为，不断言数值）：
#    FAIL（exit ≠ 0）:
#      1. 空参                           （usage 错误 → exit 1）
#      2. fixtures/ 整体目录             （含 state-deprecated + state-stale → exit 1）
#    PASS（exit = 0）:
#      3. 单文件 _overview.md           （confidence=verified → state=clean → 无腐烂）
#      4. 临时目录 + 1 个全 fresh md    （动态构造，全 verified → exit 0）
#  ----------------------------------------------------------------------------
#  与 test-check-state.sh / test-check-health.sh 风格保持一致；
#  临时目录用 mktemp -d，结束 trap 清理。
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINT="$SKILL_ROOT/scripts/lints/check-staleness.sh"
FIX="$SCRIPT_DIR/fixtures"

PASS=0
FAIL=0
FAILED_CASES=()

# 临时目录（用例 4）— 进程结束清理
TMPDIR_FRESH=$(mktemp -d 2>/dev/null || mktemp -d -t 'check-staleness-test')
trap 'rm -rf "$TMPDIR_FRESH"' EXIT

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
# 前置：依赖 + fixtures
# ----------------------------------------------------------------------------
echo "[test-check-staleness]"

if [ ! -r "$LINT" ]; then
  echo "  ✗ check-staleness.sh not found: $LINT" >&2
  exit 1
fi
for f in \
  "$FIX/_overview.md" \
  "$FIX/state-stale.md" \
  "$FIX/state-deprecated.md"; do
  if [ ! -r "$f" ]; then
    echo "  ✗ fixture missing: $f" >&2
    exit 1
  fi
done

# 构造用例 4 输入：1 个 confidence=verified 的 md，确保全 fresh
cat > "$TMPDIR_FRESH/fresh.md" <<'EOF'
---
module: health-test
topic: api
confidence: verified
created: 2026-05-16
---
# fresh

confidence=verified → state=clean → 无腐烂条目，exit=0。
EOF

# ----------------------------------------------------------------------------
# 用例
# ----------------------------------------------------------------------------

# 1) 空参 — usage 错误
assert_fail "empty args                       (usage error)"

# 2) fixtures/ 整库 — 含 state-deprecated + state-stale，应有腐烂
assert_fail "fixtures/                        (has stale entries)" "$FIX"

# 3) 单文件 _overview.md — verified → 无腐烂
assert_pass "fixtures/_overview.md            (verified → no stale)" "$FIX/_overview.md"

# 4) 临时目录 — 全 fresh
assert_pass "tmpdir with 1 fresh md           (all fresh)" "$TMPDIR_FRESH"

# ----------------------------------------------------------------------------
# 汇总
# ----------------------------------------------------------------------------
echo
echo "[test-check-staleness] PASS=$PASS  FAIL=$FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "[test-check-staleness] failed cases:"
  for c in "${FAILED_CASES[@]}"; do
    echo "  - $c"
  done
  exit 1
fi
exit 0
