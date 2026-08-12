#!/bin/bash
# run-all.sh — tech-doc Skill 单元测试一键入口
#
# 设计哲学：「确定性事实用代码」——一键串跑所有 lint 单测，CI/本地均可用。
# 自动发现 scripts/tests/cases/ 下所有 test-*.sh，按文件名排序依次执行。
#
# 用法：
#   bash run-all.sh            # 全部跑，逐子套件输出
#   bash run-all.sh --quiet    # 仅输出每个子套件的最终汇总行 + 总汇总
#   bash run-all.sh --filter <关键字>   # 仅跑匹配关键字的子套件
#
# 退出码：
#   0  全部子套件 PASS
#   1  任一子套件 FAIL
#   2  参数/环境错误

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CASES_DIR="$SCRIPT_DIR/cases"

QUIET=0
FILTER=""

while [ $# -gt 0 ]; do
  case "$1" in
    --quiet)  QUIET=1; shift ;;
    --filter) FILTER="${2:-}"; shift 2 ;;
    -h|--help)
      sed -n '2,15p' "$0"
      exit 0
      ;;
    *)
      echo "❌ 未知参数: $1" >&2
      exit 2
      ;;
  esac
done

if [ ! -d "$CASES_DIR" ]; then
  echo "❌ 找不到测试用例目录: $CASES_DIR" >&2
  exit 2
fi

# 收集测试脚本（按文件名排序）
TESTS=()
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if [ -n "$FILTER" ] && ! echo "$(basename "$f")" | grep -q "$FILTER"; then
    continue
  fi
  TESTS+=("$f")
done < <(find "$CASES_DIR" -maxdepth 1 -type f -name 'test-*.sh' | sort)

if [ "${#TESTS[@]}" -eq 0 ]; then
  echo "❌ 未发现任何测试脚本（cases/test-*.sh）" >&2
  exit 2
fi

# 计数器
TOTAL_SUITES=0
PASS_SUITES=0
FAIL_SUITES=0
FAIL_SUITE_NAMES=()

echo "=========================================="
echo " tech-doc Skill 测试套件汇总"
echo " 用例目录: $CASES_DIR"
echo " 子套件数: ${#TESTS[@]}"
[ -n "$FILTER" ] && echo " 过滤关键字: $FILTER"
echo "=========================================="

for t in "${TESTS[@]}"; do
  TOTAL_SUITES=$((TOTAL_SUITES + 1))
  name=$(basename "$t" .sh)
  echo
  echo "▶ [$TOTAL_SUITES/${#TESTS[@]}] $name"
  if [ "$QUIET" -eq 1 ]; then
    out=$(bash "$t" 2>&1)
    rc=$?
    summary=$(echo "$out" | grep -E '^[[:space:]]*结果：' | tail -n1)
    [ -n "$summary" ] && echo "   $summary"
  else
    bash "$t"
    rc=$?
  fi
  if [ "$rc" -eq 0 ]; then
    PASS_SUITES=$((PASS_SUITES + 1))
    echo "   ✅ $name 通过"
  else
    FAIL_SUITES=$((FAIL_SUITES + 1))
    FAIL_SUITE_NAMES+=("$name (exit=$rc)")
    echo "   ❌ $name 失败 (exit=$rc)"
  fi
done

echo
echo "=========================================="
echo " 总汇总：套件 PASS=$PASS_SUITES / 总数=$TOTAL_SUITES   FAIL=$FAIL_SUITES"
echo "=========================================="

if [ "$FAIL_SUITES" -gt 0 ]; then
  echo "失败子套件："
  for n in "${FAIL_SUITE_NAMES[@]}"; do
    echo "  - $n"
  done
  exit 1
fi
exit 0
