#!/bin/bash
# test-repo-preflight.sh - repo-preflight.sh 的测试用例
#
# 覆盖：
# - 非 git 仓库 → exit 1
# - 干净仓库 → changed_files=0
# - untracked / deleted / renamed 全部纳入清单（git diff 的天然盲区）
# - 敏感文件标记（.env.local）
# - mixed-stage（同一文件同时有暂存与未暂存改动）→ blocked
# - merge 中间态 → blocked=merge

_setup_repo() {
  local dir="$1"
  rm -rf "$dir"
  mkdir -p "$dir"
  (cd "$dir" && git init -q 2>/dev/null && \
    git config user.email "test@example.com" && \
    git config user.name "Test" && \
    printf 'a\n' > a.txt && \
    printf 'b\n' > b.txt && \
    printf 'k\n' > keep.txt && \
    git add -A && \
    git commit -q -m "init" 2>/dev/null) || return 1
}

run_tests() {
  local script="$SC_ROOT/scripts/repo-preflight.sh"
  local TMP_BASE="/tmp/sc-preflight-test-$$"

  # ---------- 1. 非 git 仓库 ----------
  local non_git="$TMP_BASE/not-a-repo"
  mkdir -p "$non_git"
  local err
  err=$(cd "$non_git" && bash "$script" 2>&1 1>/dev/null)
  assert_exit_code "$?" "1" "非 git 仓库 → exit 1"
  assert_contains "$err" "不是 git 仓库" "非 git 仓库 stderr 含错误信息"
  rm -rf "$non_git"

  # ---------- 2. 干净仓库 ----------
  local clean="$TMP_BASE/clean"
  if _setup_repo "$clean"; then
    err=$(cd "$clean" && bash "$script" 2>&1 1>/dev/null)
    assert_exit_code "$?" "0" "干净仓库 → exit 0"
    assert_contains "$err" '"changed_files":0' "干净仓库 changed_files=0"
    assert_contains "$err" '"blocked":"none"' "干净仓库 blocked=none"
    assert_contains "$err" '"batch_enabled":"true"' "batch_enabled 默认 true"
    assert_contains "$err" '"min_files":5' "min_files 从配置读出"
    assert_contains "$err" '"volume_trigger":false' "空仓库 volume_trigger=false"
  fi
  rm -rf "$clean"

  # ---------- 3. 全量清单：untracked / deleted / renamed / sensitive ----------
  local full="$TMP_BASE/full"
  if _setup_repo "$full"; then
    (cd "$full" && \
      printf 'a2\n' >> a.txt && \
      printf 'new\n' > new.txt && \
      rm b.txt && \
      printf 'SECRET=1\n' > .env.local && \
      git mv keep.txt renamed.txt)
    local stdout
    stdout=$(cd "$full" && bash "$script" 2>/dev/null)
    assert_contains "$stdout" "new.txt" "untracked 文件进入清单"
    assert_contains "$stdout" "b.txt" "deleted 文件进入清单"
    assert_contains "$stdout" "renamed.txt" "rename 新路径进入清单"
    assert_contains "$stdout" "sensitive" "存在敏感文件标记段"
    assert_contains "$stdout" ".env.local" "敏感文件被标记"
    err=$(cd "$full" && bash "$script" 2>&1 1>/dev/null)
    assert_contains "$err" '"untracked":2' "untracked 计数正确（new.txt + .env.local）"
    assert_contains "$err" '"deleted":1' "deleted 计数正确"
    assert_contains "$err" '"renamed":1' "renamed 计数正确"
  fi
  rm -rf "$full"

  # ---------- 4. mixed-stage（同文件既暂存又改动） ----------
  local mixed="$TMP_BASE/mixed"
  if _setup_repo "$mixed"; then
    (cd "$mixed" && printf 'staged\n' >> a.txt && git add a.txt && printf 'unstaged\n' >> a.txt)
    err=$(cd "$mixed" && bash "$script" 2>&1 1>/dev/null)
    assert_contains "$err" '"mixed_files":1' "mixed-stage 文件被统计"
    assert_contains "$err" '"blocked":"mixed-stage"' "mixed-stage → blocked"
  fi
  rm -rf "$mixed"

  # ---------- 5. merge 中间态 ----------
  local merging="$TMP_BASE/merging"
  if _setup_repo "$merging"; then
    touch "$merging/.git/MERGE_HEAD"
    err=$(cd "$merging" && bash "$script" 2>&1 1>/dev/null)
    assert_contains "$err" '"op":"merge"' "merge 态被识别"
    assert_contains "$err" '"blocked":"merge"' "merge 态 → blocked"
  fi
  rm -rf "$merging"

  rm -rf "$TMP_BASE"
}
