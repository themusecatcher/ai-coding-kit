#!/usr/bin/env bash
# ============================================================================
#  test-check-health.sh — check-health.sh 端到端单测
#  ----------------------------------------------------------------------------
#  覆盖（4 用例，与决策 C-4=A 一致：仅断言 exit code 行为，不断言数值）：
#    FAIL（exit ≠ 0）:
#      1. 空参                        （usage 错误 → exit 1）
#      2. 不存在的目录路径             （not a directory → exit 1）
#    PASS（exit = 0）:
#      3. fixtures/ 整体目录          （历史绿区，health ≈ 95，healthy → exit 0）
#    FAIL（exit ≠ 0）:
#      4. 临时目录 + 1 个无日期 md    （freshness=0 → 综合分跌到 warn 区 → exit 1）
#  ----------------------------------------------------------------------------
#  与 test-check-state.sh 风格保持一致；临时目录用 mktemp -d，结束 trap 清理。
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINT="$SKILL_ROOT/scripts/lints/check-health.sh"
FIX="$SCRIPT_DIR/fixtures"

PASS=0
FAIL=0
FAILED_CASES=()

# 临时目录（用例 4）— 进程结束清理
TMPDIR_HEALTH=$(mktemp -d 2>/dev/null || mktemp -d -t 'check-health-test')
trap 'rm -rf "$TMPDIR_HEALTH"' EXIT

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
echo "[test-check-health]"

if [ ! -r "$LINT" ]; then
  echo "  ✗ check-health.sh not found: $LINT" >&2
  exit 1
fi
if [ ! -d "$FIX" ]; then
  echo "  ✗ fixtures dir missing: $FIX" >&2
  exit 1
fi

# 构造用例 4 的输入：1 个无 last_verified/created 的 md，使 freshness=0
cat > "$TMPDIR_HEALTH/stale.md" <<'EOF'
---
module: health-test
topic: stale-no-date
confidence: pending
---
# stale (no date)

freshness 应被算作 0；用例 4 期望整库综合分跌出 healthy 区。
EOF

# ----------------------------------------------------------------------------
# 用例
# ----------------------------------------------------------------------------

# 1) 空参 — usage 错误
assert_fail "empty args                       (usage error)"

# 2) 不存在目录
assert_fail "non-existent dir                 (not a directory)" "/tmp/__no_such_dir_health_$$"

# 3) fixtures/ 整库 — 历史绿区
assert_pass "fixtures/                        (healthy, health>=80)" "$FIX"

# 4) 临时目录（只含一个无日期的 md）— freshness=0 → 综合分跌出 healthy
assert_fail "tmpdir with 1 dateless md        (freshness=0, not healthy)" "$TMPDIR_HEALTH"

# ----------------------------------------------------------------------------
# 汇总
# ----------------------------------------------------------------------------
echo
echo "[test-check-health] PASS=$PASS  FAIL=$FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "[test-check-health] failed cases:"
  for c in "${FAILED_CASES[@]}"; do
    echo "  - $c"
  done
  exit 1
fi
exit 0
