#!/bin/bash
# test-git-diff-summary.sh - git-diff-summary.sh 的测试用例
#
# 覆盖：
# - 非 git 仓库 → exit 1，stderr 含错误信息
# - 空仓库（无任何 diff）→ exit 0，stderr 含 mode=empty
# - staged diff 优先于工作区 diff
# - 工作区 diff fallback（无 staged 时）
# - full diff 模式（行数 ≤ 阈值）
# - stat 模式（行数 > 阈值，注入低阈值复现）
# - 输出包含 file list / diff stat / 主 diff 段落标题
# - --staged-only：无暂存时不回退工作区（mode=empty / source=staged）
# - --staged-only：有暂存时正常输出
# - untracked-only：无 tracked 改动但有未跟踪文件时列出文件

# 准备临时 git 仓库的辅助函数
_setup_temp_repo() {
  local dir="$1"
  rm -rf "$dir"
  mkdir -p "$dir"
  (cd "$dir" && git init -q 2>/dev/null && \
    git config user.email "test@example.com" && \
    git config user.name "Test" && \
    echo "init" > README.md && \
    git add README.md && \
    git commit -q -m "init" 2>/dev/null) || return 1
}

run_tests() {
  local script="$SC_ROOT/scripts/git-diff-summary.sh"
  local TMP_BASE="/tmp/sc-test-$$"

  # ---------- 1. 非 git 仓库 → exit 1 ----------
  local non_git="$TMP_BASE/not-a-repo"
  mkdir -p "$non_git"
  local err
  err=$(cd "$non_git" && bash "$script" 2>&1 1>/dev/null)
  assert_exit_code "$?" "1" "非 git 仓库 → exit 1"
  assert_contains "$err" "不是 git 仓库" "非 git 仓库 stderr 含错误信息"
  rm -rf "$non_git"

  # ---------- 2. 空 git 仓库（无 diff）→ exit 0 + mode=empty ----------
  local empty_repo="$TMP_BASE/empty-repo"
  if _setup_temp_repo "$empty_repo"; then
    err=$(cd "$empty_repo" && bash "$script" 2>&1 1>/dev/null)
    assert_exit_code "$?" "0" "无 diff 时 → exit 0"
    assert_contains "$err" '"mode":"empty"' "无 diff 时 stderr mode=empty"
  fi
  rm -rf "$empty_repo"

  # ---------- 3. 工作区改动 → mode=full + source=working-tree ----------
  local wt_repo="$TMP_BASE/wt-repo"
  if _setup_temp_repo "$wt_repo"; then
    (cd "$wt_repo" && echo "modified" >> README.md)
    local stdout stderr
    stdout=$(cd "$wt_repo" && bash "$script" 2>/dev/null)
    stderr=$(cd "$wt_repo" && bash "$script" 2>&1 1>/dev/null)
    assert_contains "$stderr" '"source":"working-tree"' "工作区改动 source=working-tree"
    assert_contains "$stderr" '"mode":"full"' "小改动 mode=full"
    assert_contains "$stdout" "===== file list" "stdout 含 file list 标题"
    assert_contains "$stdout" "===== diff stat" "stdout 含 diff stat 标题"
    assert_contains "$stdout" "===== full diff" "stdout 含 full diff 标题"
    assert_contains "$stdout" "README.md" "diff 输出含改动文件名"
  fi
  rm -rf "$wt_repo"

  # ---------- 4. staged 优先于工作区 ----------
  local staged_repo="$TMP_BASE/staged-repo"
  if _setup_temp_repo "$staged_repo"; then
    # staged 改动
    (cd "$staged_repo" && echo "staged change" >> README.md && git add README.md)
    # 同时还加一个工作区改动（不同文件）
    (cd "$staged_repo" && echo "wt change" > new.txt)
    local stderr
    stderr=$(cd "$staged_repo" && bash "$script" 2>&1 1>/dev/null)
    assert_contains "$stderr" '"source":"staged"' "有 staged 时 source=staged 优先"
  fi
  rm -rf "$staged_repo"

  # ---------- 5. 大 diff 自动降级到 stat 模式 ----------
  # 关键：必须改动**已追踪文件**或先 git add，否则 `git diff` 看不到新文件。
  # 这里追加 250 行到已追踪的 README.md，触发 >200 行阈值。
  local big_repo="$TMP_BASE/big-repo"
  if _setup_temp_repo "$big_repo"; then
    # 追加 250 行到已追踪的 README.md
    for i in $(seq 1 250); do
      echo "line $i content" >> "$big_repo/README.md"
    done
    local stderr
    stderr=$(cd "$big_repo" && bash "$script" 2>&1 1>/dev/null)
    assert_contains "$stderr" '"mode":"stat"' "超阈值 → mode=stat 自动降级"
  fi
  rm -rf "$big_repo"

  # ---------- 6. --staged-only：无暂存时不回退工作区 ----------
  local so_repo="$TMP_BASE/staged-only"
  if _setup_temp_repo "$so_repo"; then
    (cd "$so_repo" && echo "only working tree" >> README.md)
    local so_out so_err
    so_out=$(cd "$so_repo" && bash "$script" --staged-only 2>/dev/null)
    so_err=$(cd "$so_repo" && bash "$script" --staged-only 2>&1 1>/dev/null)
    assert_contains "$so_err" '"mode":"empty"' "--staged-only 无暂存 → mode=empty"
    assert_contains "$so_err" '"source":"staged"' "--staged-only 固定 source=staged"
    local wt_leak
    wt_leak=$(printf '%s' "$so_out" | grep -c "full diff" || true)
    assert_eq "$wt_leak" "0" "--staged-only 不输出工作区 diff"

    # ---------- 7. --staged-only：有暂存时正常输出 ----------
    (cd "$so_repo" && git add README.md)
    so_out=$(cd "$so_repo" && bash "$script" --staged-only 2>/dev/null)
    assert_contains "$so_out" "===== full diff" "--staged-only 有暂存 → 输出 full diff"
    assert_contains "$so_out" "README.md" "--staged-only 输出含改动文件"
  fi
  rm -rf "$so_repo"

  # ---------- 8. untracked-only：只有未跟踪文件 ----------
  local ut_repo="$TMP_BASE/untracked"
  if _setup_temp_repo "$ut_repo"; then
    (cd "$ut_repo" && echo "brand new" > brand-new.txt)
    local ut_out ut_err
    ut_out=$(cd "$ut_repo" && bash "$script" 2>/dev/null)
    ut_err=$(cd "$ut_repo" && bash "$script" 2>&1 1>/dev/null)
    assert_contains "$ut_err" '"mode":"untracked-only"' "只有 untracked → mode=untracked-only"
    assert_contains "$ut_err" '"untracked_count":1' "untracked_count 为 1"
    assert_contains "$ut_out" "brand-new.txt" "列出未跟踪文件"
  fi
  rm -rf "$ut_repo"

  # 清理 base 目录
  rm -rf "$TMP_BASE"
}
