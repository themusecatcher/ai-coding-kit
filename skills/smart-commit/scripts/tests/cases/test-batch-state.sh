#!/bin/bash
# test-batch-state.sh - batch-state.sh 的测试用例
#
# 覆盖：
# - 非 git 仓库 → exit 2
# - 无状态时 status → exit 1
# - init / status / next / clear 全流程
# - 状态目录可用 SC_STATE_DIR 隔离（测试不污染用户 HOME）

_setup_repo() {
  local dir="$1"
  rm -rf "$dir"
  mkdir -p "$dir"
  (cd "$dir" && git init -q 2>/dev/null && \
    git config user.email "test@example.com" && \
    git config user.name "Test" && \
    printf 'a\n' > a.txt && \
    git add -A && \
    git commit -q -m "init" 2>/dev/null) || return 1
}

run_tests() {
  local script="$SC_ROOT/scripts/batch-state.sh"
  local TMP_BASE="/tmp/sc-batch-state-test-$$"
  local SAVED_STATE_DIR="${SC_STATE_DIR:-}"
  export SC_STATE_DIR="$TMP_BASE/state"

  # ---------- 1. 非 git 仓库 ----------
  local non_git="$TMP_BASE/not-a-repo"
  mkdir -p "$non_git"
  (cd "$non_git" && bash "$script" status >/dev/null 2>&1)
  assert_exit_code "$?" "2" "非 git 仓库 → exit 2"
  rm -rf "$non_git"

  # ---------- 2~6. 在临时仓库中验证 ----------
  local repo="$TMP_BASE/repo"
  if _setup_repo "$repo"; then
    # 2. 无状态
    (cd "$repo" && bash "$script" status >/dev/null 2>&1)
    assert_exit_code "$?" "1" "无状态时 status → exit 1"

    # 3. init
    (cd "$repo" && bash "$script" init 3 >/dev/null 2>&1)
    assert_exit_code "$?" "0" "init → exit 0"
    local state_file
    state_file=$(ls "$SC_STATE_DIR"/*.state 2>/dev/null | head -1)
    assert_contains "$state_file" ".state" "状态文件已创建"

    # 4. status 首态
    local st
    st=$(cd "$repo" && bash "$script" status 2>/dev/null)
    assert_contains "$st" '"current":1' "初始 current=1"
    assert_contains "$st" '"total":3' "total=3"

    # 5. next 推进
    local hash
    hash=$(cd "$repo" && git rev-parse HEAD)
    (cd "$repo" && bash "$script" next --hash "$hash" --header "chore: 批次一" >/dev/null 2>&1)
    assert_exit_code "$?" "0" "next → exit 0"
    st=$(cd "$repo" && bash "$script" status 2>/dev/null)
    assert_contains "$st" '"current":2' "next 后 current=2"
    assert_contains "$st" "chore: 批次一" "已提交批次被记录"

    # 6. 最后一批 → COMPLETED
    local out
    out=$(cd "$repo" && bash "$script" next 2>/dev/null && bash "$script" next 2>/dev/null)
    assert_contains "$out" "COMPLETED" "最后一批 → COMPLETED"

    # 7. clear
    (cd "$repo" && bash "$script" clear >/dev/null 2>&1)
    assert_exit_code "$?" "0" "clear → exit 0"
    local remaining
    remaining=$(ls "$SC_STATE_DIR"/*.state 2>/dev/null | wc -l | tr -d ' ')
    assert_eq "$remaining" "0" "clear 后状态文件被删除"
  fi
  rm -rf "$repo"

  if [ -n "$SAVED_STATE_DIR" ]; then
    export SC_STATE_DIR="$SAVED_STATE_DIR"
  else
    unset SC_STATE_DIR
  fi
  rm -rf "$TMP_BASE"
}
