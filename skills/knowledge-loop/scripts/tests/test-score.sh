#!/usr/bin/env bash
# ============================================================================
#  test-score.sh — score.sh 单元测试
#  ----------------------------------------------------------------------------
#  契约边界（与 references/refactor-plan.md §7.6 决策 A 对齐）：
#    - 正向用例：断言 stdout 整数 + exit 0
#    - 错误用例：仅断言 exit != 0，不断言 stderr 文本
#    （score.sh 在 bash 3.2 + set -u 下数值校验路径 stderr 不友好；详见 §7.6）
#
#  覆盖：
#    - 6 个数值用例（公式 / clamp 上下限 / 各 level 边界）
#    - 3 个错误用例（unknown level / 缺参 / 未知参数）
#  ----------------------------------------------------------------------------
#  退出码：0 = 全部通过；1 = 至少一个用例失败
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCORE_SH="$SKILL_ROOT/scripts/lib/score.sh"

PASS=0
FAIL=0
FAILED_CASES=()

# ----------------------------------------------------------------------------
# 工具：运行 score.sh 并捕获 stdout / exit code（不让被测失败影响本脚本）
# ----------------------------------------------------------------------------
run_score() {
  # 用法：run_score <args...>
  # 输出：stdout 行（被测 stdout），全局变量 RC 保存 exit code
  set +e
  OUT=$(bash "$SCORE_SH" "$@" 2>/dev/null)
  RC=$?
  set -e
}

# 正向：断言 stdout 等于期望值，且 exit == 0
assert_score() {
  local name="$1"; shift
  local expect="$1"; shift
  run_score "$@"
  if [ "$RC" -eq 0 ] && [ "$OUT" = "$expect" ]; then
    PASS=$((PASS + 1))
    printf '  ✓ %s\n' "$name"
  else
    FAIL=$((FAIL + 1))
    FAILED_CASES+=("$name (expect=$expect got_stdout='$OUT' exit=$RC)")
    printf '  ✗ %s (expect=%s got_stdout=%q exit=%d)\n' "$name" "$expect" "$OUT" "$RC"
  fi
}

# 错误：仅断言 exit != 0（不约束 stderr / stdout）
assert_fail() {
  local name="$1"; shift
  run_score "$@"
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
echo "[test-score]"

# --- 数值用例（公式：base + (drift==0 ? bonus.no_drift : -penalty*drift) + (days>=stable ? bonus.merged_stable : 0); clamp [0,100]） ---
# verified=95, no_drift=+5, merged_stable=+3, penalty=5/drift, days_stable=30
assert_score "verified  drift=0  days=0  → 95+5=100"               "100" --level verified     --drift 0  --days_merged 0
assert_score "verified  drift=0  days=30 → 95+5+3=103 → clamp 100" "100" --level verified     --drift 0  --days_merged 30
assert_score "pending   drift=2  days=0  → 70-10=60"               "60"  --level pending      --drift 2  --days_merged 0
assert_score "draft     drift=20 days=0  → 50-100=-50 → clamp 0"   "0"   --level draft        --drift 20 --days_merged 0
assert_score "deprecated drift=0 days=0  → 0+5=5"                  "5"   --level deprecated   --drift 0  --days_merged 0
assert_score "auto-stale drift=1 days=30 → 35-5+3=33"              "33"  --level auto-stale   --drift 1  --days_merged 30

# --- 错误用例（仅断言 exit != 0；不进入 §7.6 已知遗留路径，即不传负数 / 非数字 drift / days_merged） ---
assert_fail "unknown level"        --level INVALID  --drift 0 --days_merged 0
assert_fail "missing --days_merged" --level verified --drift 0
assert_fail "unknown arg --foo"    --foo bar --level verified --drift 0 --days_merged 0

# ----------------------------------------------------------------------------
# 汇总
# ----------------------------------------------------------------------------
echo
echo "[test-score] PASS=$PASS  FAIL=$FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "[test-score] failed cases:"
  for c in "${FAILED_CASES[@]}"; do
    echo "  - $c"
  done
  exit 1
fi
exit 0
