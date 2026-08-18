#!/usr/bin/env bash
# ============================================================================
#  run-tests.sh — knowledge-loop Skill 测试套件入口
#  ----------------------------------------------------------------------------
#  作用：依次运行 scripts/tests/ 下所有 test-*.sh，汇总通过/失败计数 + exit code。
#  ----------------------------------------------------------------------------
#  消费方：
#    - 开发者本地手跑：bash scripts/tests/run-tests.sh
#    - 后续 CI（如有）的 sanity gate
#    - SKILL.md「执行链路」章节可作为最末一道验证（Phase 3 范围）
#  ----------------------------------------------------------------------------
#  CLI:
#    run-tests.sh           # 运行全部子测试
#    run-tests.sh --list    # 仅列出已注册的子测试
#    run-tests.sh -h|--help # 用法
#  退出码：
#    0 = 全部子测试通过
#    1 = 至少一个子测试失败
#  ============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 颜色（仅 tty）
if [ -t 1 ]; then
  C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_DIM=$'\033[2m'; C_BOLD=$'\033[1m'; C_RESET=$'\033[0m'
else
  C_RED=""; C_GREEN=""; C_DIM=""; C_BOLD=""; C_RESET=""
fi

# ----------------------------------------------------------------------------
# 已注册子测试清单（按依赖顺序：lib → lints）
# ----------------------------------------------------------------------------
SUITES=(
  "test-score.sh"
  "test-state.sh"
  "test-check-frontmatter.sh"
  "test-check-state.sh"
  "test-check-health.sh"
  "test-check-staleness.sh"
)

usage() {
  cat >&2 <<'USAGE'
usage: run-tests.sh [--list]
  无参数 : 运行全部子测试，最终汇总
  --list : 仅列出已注册的子测试名
USAGE
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  --list)
    printf "%s[knowledge-loop] registered test suites:%s\n" "$C_DIM" "$C_RESET"
    for s in "${SUITES[@]}"; do printf "  - %s\n" "$s"; done
    exit 0
    ;;
  "") : ;;
  *) echo "run-tests.sh: unknown arg: $1" >&2; usage; exit 1 ;;
esac

# ----------------------------------------------------------------------------
# 主循环：依次运行每个子测试，捕获其 exit code 与最终一行汇总
# ----------------------------------------------------------------------------
printf "\n%s%s[knowledge-loop] run-tests%s\n" "$C_BOLD" "$C_DIM" "$C_RESET"
printf "%s============================================%s\n\n" "$C_DIM" "$C_RESET"

TOTAL=${#SUITES[@]}
PASSED=0
FAILED=0
FAILED_SUITES=()
START_TS=$(date +%s)

for s in "${SUITES[@]}"; do
  suite_path="$SCRIPT_DIR/$s"
  if [ ! -r "$suite_path" ]; then
    printf "  %s✗%s %-32s (not found: %s)\n" "$C_RED" "$C_RESET" "$s" "$suite_path"
    FAILED=$((FAILED + 1))
    FAILED_SUITES+=("$s")
    continue
  fi

  # 运行子测试（不让其失败影响本入口）
  set +e
  out=$(bash "$suite_path" 2>&1)
  rc=$?
  set -e

  # 抽末尾汇总行（形如 "[test-foo] PASS=N  FAIL=M"）
  summary_line=$(printf "%s\n" "$out" | grep -E '^\[test-[a-z-]+\] PASS=[0-9]+ +FAIL=[0-9]+' | tail -n 1)
  [ -z "$summary_line" ] && summary_line="(no summary line)"

  if [ "$rc" -eq 0 ]; then
    printf "  %s✓%s %-32s %s\n" "$C_GREEN" "$C_RESET" "$s" "$summary_line"
    PASSED=$((PASSED + 1))
  else
    printf "  %s✗%s %-32s %s (exit=%d)\n" "$C_RED" "$C_RESET" "$s" "$summary_line" "$rc"
    FAILED=$((FAILED + 1))
    FAILED_SUITES+=("$s")
    # 失败时输出子测试完整日志便于诊断
    printf "%s---- %s output ----%s\n" "$C_DIM" "$s" "$C_RESET"
    printf "%s\n" "$out" | sed "s/^/    /"
    printf "%s---- end ----%s\n\n" "$C_DIM" "$C_RESET"
  fi
done

END_TS=$(date +%s)
ELAPSED=$((END_TS - START_TS))

# ----------------------------------------------------------------------------
# 总览
# ----------------------------------------------------------------------------
printf "\n%s============================================%s\n" "$C_DIM" "$C_RESET"
printf "%ssummary%s: %d total, %s%d passed%s, %s%d failed%s  (%ds)\n" \
  "$C_BOLD" "$C_RESET" "$TOTAL" "$C_GREEN" "$PASSED" "$C_RESET" "$C_RED" "$FAILED" "$C_RESET" "$ELAPSED"

if [ "$FAILED" -gt 0 ]; then
  printf "failed suites:\n"
  for s in "${FAILED_SUITES[@]}"; do printf "  - %s\n" "$s"; done
  echo "RESULT: fail"
  exit 1
fi

echo "RESULT: ok"
exit 0
