#!/bin/bash
# test-runner.sh - smart-commit 脚本测试入口
#
# 用法：
#   bash test-runner.sh                # 运行所有测试
#   bash test-runner.sh <case-name>    # 运行指定用例（不带 test- 前缀也可）
#
# 设计：
# - 简易 bash 测试框架（避免引入外部依赖）
# - 每个用例 cases/test-<name>.sh 暴露 run_tests 函数
# - 通过 assert_eq / assert_contains / assert_exit_code 做断言
# - 内联 logger 工具，smart-commit 本身不带 lib 目录，保持脚本独立

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SC_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
export SC_ROOT

# ---------- 内联 logger（避免引入 lib/） ----------
log_section() { printf '\n═══ %s ═══\n' "$1"; }
log_pass()    { printf '\033[32m%s\033[0m\n' "$1"; }
log_fail()    { printf '\033[31m%s\033[0m\n' "$1" >&2; }
log_warn()    { printf '\033[33m%s\033[0m\n' "$1" >&2; }
log_error()   { printf '\033[31m[ERROR] %s\033[0m\n' "$1" >&2; }
log_kv()      { printf '  %-30s %s\n' "$1" "$2"; }

PASS_COUNT=0
FAIL_COUNT=0
FAIL_DETAILS=()

assert_eq() {
  local actual="$1"
  local expected="$2"
  local msg="${3:-}"
  if [ "$actual" = "$expected" ]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    log_pass "  ✓ ${msg:-assert_eq}"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    FAIL_DETAILS+=("${msg:-assert_eq}: expected='$expected' actual='$actual'")
    log_fail "  ✗ ${msg:-assert_eq}: expected='$expected' actual='$actual'"
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local msg="${3:-}"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    PASS_COUNT=$((PASS_COUNT + 1))
    log_pass "  ✓ ${msg:-assert_contains}"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    FAIL_DETAILS+=("${msg:-assert_contains}: '$needle' not found")
    log_fail "  ✗ ${msg:-assert_contains}: '$needle' not in output"
  fi
}

assert_exit_code() {
  local actual="$1"
  local expected="$2"
  local msg="${3:-}"
  if [ "$actual" = "$expected" ]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    log_pass "  ✓ ${msg:-exit code}"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    FAIL_DETAILS+=("${msg:-exit code}: expected=$expected actual=$actual")
    log_fail "  ✗ ${msg:-exit code}: expected=$expected actual=$actual"
  fi
}

run_case() {
  local case_file="$1"
  local case_name
  case_name="$(basename "$case_file" .sh)"
  log_section "Case: $case_name"
  # shellcheck source=/dev/null
  source "$case_file"
  if type run_tests >/dev/null 2>&1; then
    run_tests
    unset -f run_tests
  else
    log_warn "用例 $case_name 缺少 run_tests 函数"
  fi
}

CASES_DIR="$SCRIPT_DIR/cases"
TARGET="${1:-}"

if [ -n "$TARGET" ]; then
  case_file="$CASES_DIR/test-${TARGET}.sh"
  [ ! -f "$case_file" ] && case_file="$CASES_DIR/$TARGET.sh"
  if [ ! -f "$case_file" ]; then
    log_error "用例不存在: $TARGET"
    exit 2
  fi
  run_case "$case_file"
else
  for f in "$CASES_DIR"/test-*.sh; do
    [ -f "$f" ] || continue
    run_case "$f"
  done
fi

log_section "测试汇总"
log_kv "通过" "$PASS_COUNT"
log_kv "失败" "$FAIL_COUNT"

if [ "$FAIL_COUNT" -gt 0 ]; then
  log_fail "失败明细:"
  for d in "${FAIL_DETAILS[@]}"; do
    printf '  - %s\n' "$d" >&2
  done
  exit 1
fi

log_pass "✅ 全部测试通过 ✨"
exit 0
