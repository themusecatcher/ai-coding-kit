#!/bin/bash
# test-circuit-breaker.sh - 测试 3 次熔断计数器
# 由 test-runner.sh source 后调用 run_tests

run_tests() {
  local CB="$VP_ROOT/scripts/state/circuit-breaker.sh"
  # 隔离测试用 state 目录
  local TMP_STATE
  TMP_STATE="$(mktemp -d -t vp-test-cb.XXXXXX)"
  export VP_STATE_DIR="$TMP_STATE"

  # 1. 初始 get 应该是 0
  local n
  n="$(bash "$CB" --get test_stage)"
  assert_eq "$n" "0" "初始 get == 0"

  # 2. inc 一次，结果 1
  n="$(bash "$CB" --inc test_stage 2>/dev/null)"
  assert_eq "$n" "1" "inc 1 次 → 1"

  # 3. inc 两次再 get
  bash "$CB" --inc test_stage >/dev/null 2>&1
  n="$(bash "$CB" --get test_stage)"
  assert_eq "$n" "2" "inc 第 2 次 → get 返回 2"

  # 4. inc 第 3 次应该熔断（exit code 1）
  bash "$CB" --inc test_stage >/dev/null 2>&1
  local rc=$?
  assert_exit_code "$rc" "1" "inc 到 3 次触发熔断"

  # 5. check 已熔断
  bash "$CB" --check test_stage >/dev/null 2>&1
  rc=$?
  assert_exit_code "$rc" "1" "check 已熔断 → exit 1"

  # 6. reset 后 check 通过
  bash "$CB" --reset test_stage >/dev/null 2>&1
  bash "$CB" --check test_stage >/dev/null 2>&1
  rc=$?
  assert_exit_code "$rc" "0" "reset 后 check → exit 0"

  # 7. 非法 stage 名拒绝
  bash "$CB" --inc 'bad name with space' >/dev/null 2>&1
  rc=$?
  assert_exit_code "$rc" "2" "非法 stage 名退出 2"

  # 8. clear-all
  bash "$CB" --inc s1 >/dev/null 2>&1
  bash "$CB" --inc s2 >/dev/null 2>&1
  bash "$CB" --clear-all >/dev/null 2>&1
  n="$(bash "$CB" --get s1)"
  assert_eq "$n" "0" "clear-all 后 s1 → 0"
  n="$(bash "$CB" --get s2)"
  assert_eq "$n" "0" "clear-all 后 s2 → 0"

  rm -rf "$TMP_STATE"
  unset VP_STATE_DIR
}
