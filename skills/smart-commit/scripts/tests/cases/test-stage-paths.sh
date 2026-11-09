#!/bin/bash
# test-stage-paths.sh - stage-paths.sh 的测试用例
#
# 覆盖：
# - 非 git 仓库 → exit 1
# - 无参数 → exit 1
# - 禁止 `.` / `-A` 等危险入参 → exit 2
# - 不在改动清单中的路径 → exit 2
# - dry-run 不改动暂存区 → exit 0
# - 精确暂存：只暂存指定文件，其余保持未暂存
# - 入参支持目录：展开为该目录下全部改动文件
# - 暂存区已含本批外文件 → exit 5（批次边界污染）
# - 从子目录调用时自动切到仓库根

_setup_repo() {
  local dir="$1"
  rm -rf "$dir"
  mkdir -p "$dir"
  (cd "$dir" && git init -q 2>/dev/null && \
    git config user.email "test@example.com" && \
    git config user.name "Test" && \
    printf 'a\n' > a.txt && \
    printf 'b\n' > b.txt && \
    git add -A && \
    git commit -q -m "init" 2>/dev/null) || return 1
}

run_tests() {
  local script="$SC_ROOT/scripts/stage-paths.sh"
  local TMP_BASE="/tmp/sc-stage-test-$$"

  # ---------- 1. 非 git 仓库 ----------
  local non_git="$TMP_BASE/not-a-repo"
  mkdir -p "$non_git"
  (cd "$non_git" && bash "$script" a.txt >/dev/null 2>&1)
  assert_exit_code "$?" "1" "非 git 仓库 → exit 1"
  rm -rf "$non_git"

  # ---------- 2~6. 在临时仓库中验证 ----------
  local repo="$TMP_BASE/repo"
  if _setup_repo "$repo"; then
    (cd "$repo" && printf 'a2\n' >> a.txt && printf 'b2\n' >> b.txt && printf 'c\n' > c.txt)

    # 2. 无参数
    (cd "$repo" && bash "$script" >/dev/null 2>&1)
    assert_exit_code "$?" "1" "无参数 → exit 1"

    # 3. 禁止 `.`
    (cd "$repo" && bash "$script" . >/dev/null 2>&1)
    assert_exit_code "$?" "2" "禁止 '.' → exit 2"

    # 4. 禁止 -A
    (cd "$repo" && bash "$script" -A >/dev/null 2>&1)
    assert_exit_code "$?" "2" "禁止 '-A' → exit 2"

    # 5. 路径不在改动清单
    (cd "$repo" && bash "$script" nope.txt >/dev/null 2>&1)
    assert_exit_code "$?" "2" "不存在的路径 → exit 2"

    # 6. dry-run 不改暂存区
    (cd "$repo" && bash "$script" --dry-run a.txt c.txt >/dev/null 2>&1)
    assert_exit_code "$?" "0" "dry-run → exit 0"
    local staged_count
    staged_count=$(cd "$repo" && git diff --cached --name-only | wc -l | tr -d ' ')
    assert_eq "$staged_count" "0" "dry-run 未改动暂存区"

    # 7. 精确暂存：只暂存 a.txt 与 c.txt
    local out
    out=$(cd "$repo" && bash "$script" a.txt c.txt 2>/dev/null)
    assert_exit_code "$?" "0" "精确暂存 → exit 0"
    assert_contains "$out" "a.txt" "输出含 a.txt"
    assert_contains "$out" "c.txt" "输出含 c.txt"

    local staged
    staged=$(cd "$repo" && git diff --cached --name-only | sort | tr '\n' ' ')
    assert_eq "$staged" "a.txt c.txt " "暂存区恰好只含本批文件"

    local unstaged
    unstaged=$(cd "$repo" && git diff --name-only)
    assert_contains "$unstaged" "b.txt" "未指定文件保持未暂存"

    # 8. 目录入参：展开为该目录下全部改动文件
    (cd "$repo" && git restore --staged . >/dev/null 2>&1 && mkdir -p sub && \
      printf 'd\n' > sub/d.txt && printf 'e\n' > sub/e.txt)
    local dir_out dir_staged
    dir_out=$(cd "$repo" && bash "$script" sub 2>/dev/null)
    assert_exit_code "$?" "0" "目录入参 → exit 0"
    assert_contains "$dir_out" "sub/d.txt" "目录展开含 sub/d.txt"
    dir_staged=$(cd "$repo" && git diff --cached --name-only | sort | tr '\n' ' ')
    assert_eq "$dir_staged" "sub/d.txt sub/e.txt " "目录入参只暂存该目录文件"

    # 9. 暂存区已含本批之外的文件 → exit 5（批次边界污染）
    (cd "$repo" && git restore --staged . >/dev/null 2>&1 && git add b.txt)
    local contam_err
    contam_err=$(cd "$repo" && bash "$script" a.txt 2>&1 1>/dev/null)
    assert_exit_code "$?" "5" "暂存区含本批外文件 → exit 5"
    assert_contains "$contam_err" "批次边界被污染" "提示批次边界污染"
    assert_contains "$contam_err" "b.txt" "指出污染的具名文件"

    # 10. 暂存区内容全部属于本批 → 放行
    (cd "$repo" && git restore --staged . >/dev/null 2>&1 && git add a.txt)
    (cd "$repo" && bash "$script" a.txt >/dev/null 2>&1)
    assert_exit_code "$?" "0" "暂存区内容属于本批 → 放行"

    # 11. 从子目录调用：自动切到仓库根，路径按仓库根解析
    (cd "$repo" && git restore --staged . >/dev/null 2>&1)
    local sub_err
    sub_err=$(cd "$repo/sub" && bash "$script" sub/d.txt 2>&1 1>/dev/null)
    assert_contains "$sub_err" "已切换到仓库根" "子目录调用 → 提示切到仓库根"
    local sub_staged
    sub_staged=$(cd "$repo" && git diff --cached --name-only | sort | tr '\n' ' ')
    assert_eq "$sub_staged" "sub/d.txt " "子目录调用暂存结果正确"
  fi
  rm -rf "$repo"

  rm -rf "$TMP_BASE"
}
