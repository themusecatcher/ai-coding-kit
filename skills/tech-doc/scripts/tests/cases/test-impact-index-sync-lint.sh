#!/bin/bash
# test-impact-index-sync-lint.sh — impact-index-sync-lint.sh 的单元测试（tech-doc Skill 资产）
#
# 设计哲学：「确定性事实用代码」——验证 C3 lint 对 devlog↔impact-index 因果闭环的检测能力。
# 复用 F1/F2 的 BATS-lite 框架（红绿计数 + tmpdir 隔离），不引外部依赖。
#
# 覆盖范围：
#   1. 全合规场景  → exit 0
#   2. check 1 fail（devlog 缺索引条目）
#   3. check 2 fail（索引条目引用的 devlog 文件不存在 / 僵尸条目）
#   4. check 3 fail（索引条目缺 [详情](./xxx/devlog.md) 链接）
#   5. check 4 fail（索引条目缺必填字段：涉及接口）
#   6. check 5 fail（关键字段值为「待补充」）
#   7. 多 check 同时 fail（综合违规）
#   8. --skip-folder 排除指定 devlog 子目录后通过
#   9. --raw 模式仅退出码（无 JSON 输出）
#
# 用法：
#   bash test-impact-index-sync-lint.sh
#
# 退出码：
#   0  全部通过
#   1  任一用例失败

set -u

# ========================================
# 框架（与 F1/F2 一致：红绿计数 + tmpdir）
# ========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINT_SCRIPT="$SCRIPT_DIR/../../lints/impact-index-sync-lint.sh"

if [ ! -f "$LINT_SCRIPT" ]; then
  echo "❌ 找不到被测脚本: $LINT_SCRIPT" >&2
  exit 1
fi

PASS=0
FAIL=0
FAIL_CASES=()

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
    echo "  ✅ $label"
  else
    FAIL=$((FAIL + 1))
    FAIL_CASES+=("$label  (expected=$expected, actual=$actual)")
    echo "  ❌ $label  expected=$expected actual=$actual"
  fi
}

assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -Fq "$needle"; then
    PASS=$((PASS + 1))
    echo "  ✅ $label"
  else
    FAIL=$((FAIL + 1))
    FAIL_CASES+=("$label  (missing: $needle)")
    echo "  ❌ $label  missing=$needle"
  fi
}

assert_not_contains() {
  local label="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -Fq "$needle"; then
    FAIL=$((FAIL + 1))
    FAIL_CASES+=("$label  (unexpected: $needle)")
    echo "  ❌ $label  unexpected=$needle"
  else
    PASS=$((PASS + 1))
    echo "  ✅ $label"
  fi
}

mk_tmp_devlogs() {
  mktemp -d -t iils_test_XXXXXX
}

# 写入一个最小合规 devlog 文件
write_devlog() {
  local dir="$1" folder="$2"
  mkdir -p "$dir/$folder"
  cat > "$dir/$folder/devlog.md" <<'EOF'
# devlog: 测试条目

## 一、背景
（占位）
EOF
}

# 写入一个完整合规的 impact-index 条目（8 个必填字段全填实值）
emit_full_entry() {
  local title="$1" folder="$2"
  cat <<EOF
## $title

- **项目**：tech-doc
- **分支**：master
- **任务平台**：--story=12345
- **涉及文件**：a.md / b.md
- **涉及接口**：/api/foo
- **涉及功能模块**：模块A
- **关键字段/Key**：user_id, tenant_id
- **上下游**：上游 X / 下游 Y
- **devlog**：[详情](./$folder/devlog.md)

EOF
}

run_lint() {
  bash "$LINT_SCRIPT" "$@" 2>&1
}

# ========================================
# 用例 1：全合规 → exit 0
# ========================================
case_1_all_green() {
  echo
  echo "▶ 用例 1：全合规 → exit 0"
  local tmp; tmp=$(mk_tmp_devlogs)

  write_devlog "$tmp" "20260501_fix_a"
  write_devlog "$tmp" "20260502_feat_b"

  {
    emit_full_entry "20260501 修复 A" "20260501_fix_a"
    emit_full_entry "20260502 新增 B" "20260502_feat_b"
  } > "$tmp/impact-index.md"

  local out rc
  out=$(run_lint --dev-logs "$tmp" --index "$tmp/impact-index.md")
  rc=$?

  assert_eq   "case1.exit_code"               "0"     "$rc"
  assert_contains "case1.json_has_lint_block" '"impact_index_sync_lint":' "$out"
  assert_contains "case1.check1_true"  '"devlog_has_index_entry": true'    "$out"
  assert_contains "case1.check2_true"  '"index_entry_devlog_exists": true' "$out"
  assert_contains "case1.check3_true"  '"devlog_link_valid": true'         "$out"
  assert_contains "case1.check4_true"  '"required_fields_present": true'   "$out"
  assert_contains "case1.check5_true"  '"no_critical_pending": true'       "$out"
  assert_contains "case1.violations_empty" '"violations": []'              "$out"

  rm -rf "$tmp"
}

# ========================================
# 用例 2：devlog 缺索引条目 → check 1 fail
# ========================================
case_2_devlog_missing_index() {
  echo
  echo "▶ 用例 2：devlog 物理存在但 impact-index 缺索引条目 → check 1 fail"
  local tmp; tmp=$(mk_tmp_devlogs)

  write_devlog "$tmp" "20260501_fix_a"
  write_devlog "$tmp" "20260502_feat_b"  # 此目录无对应索引条目

  emit_full_entry "20260501 修复 A" "20260501_fix_a" > "$tmp/impact-index.md"

  local out rc
  out=$(run_lint --dev-logs "$tmp" --index "$tmp/impact-index.md")
  rc=$?

  assert_eq   "case2.exit_code"              "1"     "$rc"
  assert_contains "case2.check1_false" '"devlog_has_index_entry": false'   "$out"
  assert_contains "case2.violation_msg" "20260502_feat_b" "$out"

  rm -rf "$tmp"
}

# ========================================
# 用例 3：索引条目引用的 devlog 文件不存在（僵尸条目）→ check 2 fail
# ========================================
case_3_zombie_index_entry() {
  echo
  echo "▶ 用例 3：索引条目引用的 devlog 文件不存在 → check 2 fail"
  local tmp; tmp=$(mk_tmp_devlogs)

  write_devlog "$tmp" "20260501_fix_a"

  {
    emit_full_entry "20260501 修复 A"        "20260501_fix_a"
    emit_full_entry "20260601 已删除条目"     "20260601_deleted_zombie"  # 物理不存在
  } > "$tmp/impact-index.md"

  local out rc
  out=$(run_lint --dev-logs "$tmp" --index "$tmp/impact-index.md")
  rc=$?

  assert_eq   "case3.exit_code"              "1"     "$rc"
  assert_contains "case3.check2_false" '"index_entry_devlog_exists": false' "$out"
  assert_contains "case3.violation_msg" "20260601_deleted_zombie/devlog.md" "$out"

  rm -rf "$tmp"
}

# ========================================
# 用例 4：索引条目缺 [详情](./xxx/devlog.md) 链接 → check 3 fail
# ========================================
case_4_link_missing() {
  echo
  echo "▶ 用例 4：索引条目缺 devlog 链接行 → check 3 fail"
  local tmp; tmp=$(mk_tmp_devlogs)

  write_devlog "$tmp" "20260501_fix_a"

  # 故意去掉 - **devlog**：[详情](...) 这一行
  cat > "$tmp/impact-index.md" <<'EOF'
## 20260501 修复 A

- **项目**：tech-doc
- **分支**：master
- **任务平台**：--story=12345
- **涉及文件**：a.md
- **涉及接口**：/api/foo
- **涉及功能模块**：模块A
- **关键字段/Key**：user_id
- **上下游**：上游 X / 下游 Y

EOF

  local out rc
  out=$(run_lint --dev-logs "$tmp" --index "$tmp/impact-index.md")
  rc=$?

  assert_eq   "case4.exit_code"              "1"     "$rc"
  assert_contains "case4.check3_false" '"devlog_link_valid": false' "$out"

  rm -rf "$tmp"
}

# ========================================
# 用例 5：索引条目缺必填字段「涉及接口」→ check 4 fail
# ========================================
case_5_required_field_missing() {
  echo
  echo "▶ 用例 5：索引条目缺必填字段「涉及接口」→ check 4 fail"
  local tmp; tmp=$(mk_tmp_devlogs)

  write_devlog "$tmp" "20260501_fix_a"

  cat > "$tmp/impact-index.md" <<'EOF'
## 20260501 修复 A

- **项目**：tech-doc
- **分支**：master
- **任务平台**：--story=12345
- **涉及文件**：a.md
- **涉及功能模块**：模块A
- **关键字段/Key**：user_id
- **上下游**：上游 X / 下游 Y
- **devlog**：[详情](./20260501_fix_a/devlog.md)

EOF

  local out rc
  out=$(run_lint --dev-logs "$tmp" --index "$tmp/impact-index.md")
  rc=$?

  assert_eq   "case5.exit_code"              "1"     "$rc"
  assert_contains "case5.check4_false" '"required_fields_present": false' "$out"
  assert_contains "case5.violation_field" "涉及接口" "$out"

  rm -rf "$tmp"
}

# ========================================
# 用例 6：关键字段值为「待补充」→ check 5 fail
# ========================================
case_6_critical_pending() {
  echo
  echo "▶ 用例 6：关键字段「上下游」值为「待补充」→ check 5 fail"
  local tmp; tmp=$(mk_tmp_devlogs)

  write_devlog "$tmp" "20260501_fix_a"

  cat > "$tmp/impact-index.md" <<'EOF'
## 20260501 修复 A

- **项目**：tech-doc
- **分支**：master
- **任务平台**：--story=12345
- **涉及文件**：a.md
- **涉及接口**：/api/foo
- **涉及功能模块**：模块A
- **关键字段/Key**：user_id
- **上下游**：待补充
- **devlog**：[详情](./20260501_fix_a/devlog.md)

EOF

  local out rc
  out=$(run_lint --dev-logs "$tmp" --index "$tmp/impact-index.md")
  rc=$?

  assert_eq   "case6.exit_code"              "1"     "$rc"
  assert_contains "case6.check5_false" '"no_critical_pending": false' "$out"
  assert_contains "case6.violation_msg" "上下游" "$out"

  rm -rf "$tmp"
}

# ========================================
# 用例 7：多 check 同时 fail（缺字段 + 待补充 + 缺链接）
# ========================================
case_7_multi_violations() {
  echo
  echo "▶ 用例 7：单条条目多重违规（缺字段+缺链接+关键字段待补充）"
  local tmp; tmp=$(mk_tmp_devlogs)

  write_devlog "$tmp" "20260501_fix_a"

  # 缺：涉及接口 / devlog 链接；上下游=待补充
  cat > "$tmp/impact-index.md" <<'EOF'
## 20260501 修复 A

- **项目**：tech-doc
- **分支**：master
- **任务平台**：--story=12345
- **涉及文件**：a.md
- **涉及功能模块**：模块A
- **关键字段/Key**：user_id
- **上下游**：待补充

EOF

  local out rc
  out=$(run_lint --dev-logs "$tmp" --index "$tmp/impact-index.md")
  rc=$?

  assert_eq   "case7.exit_code"              "1"     "$rc"
  assert_contains "case7.check3_false" '"devlog_link_valid": false'        "$out"
  assert_contains "case7.check4_false" '"required_fields_present": false'  "$out"
  assert_contains "case7.check5_false" '"no_critical_pending": false'      "$out"

  rm -rf "$tmp"
}

# ========================================
# 用例 8：--skip-folder 排除指定 devlog 子目录后通过
# ========================================
case_8_skip_folder() {
  echo
  echo "▶ 用例 8：--skip-folder 排除「正在编写中」的 devlog 子目录后通过"
  local tmp; tmp=$(mk_tmp_devlogs)

  write_devlog "$tmp" "20260501_fix_a"
  write_devlog "$tmp" "20260601_wip_draft"  # 草稿期，未入索引

  emit_full_entry "20260501 修复 A" "20260501_fix_a" > "$tmp/impact-index.md"

  # 不带 skip：应失败（check 1）
  local out_fail rc_fail
  out_fail=$(run_lint --dev-logs "$tmp" --index "$tmp/impact-index.md")
  rc_fail=$?
  assert_eq   "case8.without_skip.exit_code" "1" "$rc_fail"

  # 带 skip：应通过
  local out_ok rc_ok
  out_ok=$(run_lint --dev-logs "$tmp" --index "$tmp/impact-index.md" --skip-folder "20260601_wip_draft")
  rc_ok=$?
  assert_eq   "case8.with_skip.exit_code"    "0" "$rc_ok"
  assert_contains "case8.with_skip.violations_empty" '"violations": []' "$out_ok"

  rm -rf "$tmp"
}

# ========================================
# 用例 9：--raw 模式仅退出码（无 JSON 输出）
# ========================================
case_9_raw_mode() {
  echo
  echo "▶ 用例 9：--raw 模式仅退出码"
  local tmp; tmp=$(mk_tmp_devlogs)

  write_devlog "$tmp" "20260501_fix_a"
  emit_full_entry "20260501 修复 A" "20260501_fix_a" > "$tmp/impact-index.md"

  # 全绿场景
  local out_ok rc_ok
  out_ok=$(run_lint --raw --dev-logs "$tmp" --index "$tmp/impact-index.md")
  rc_ok=$?
  assert_eq   "case9.green.exit_code"        "0" "$rc_ok"
  assert_not_contains "case9.green.no_json_brace" '{' "$out_ok"

  # 红场景：构造 check 1 fail
  write_devlog "$tmp" "20260606_extra"
  local out_red rc_red
  out_red=$(run_lint --raw --dev-logs "$tmp" --index "$tmp/impact-index.md")
  rc_red=$?
  assert_eq   "case9.red.exit_code"          "1" "$rc_red"

  rm -rf "$tmp"
}

# ========================================
# 主流程
# ========================================
echo "============================================"
echo " test-impact-index-sync-lint.sh"
echo " 被测脚本: $LINT_SCRIPT"
echo "============================================"

case_1_all_green
case_2_devlog_missing_index
case_3_zombie_index_entry
case_4_link_missing
case_5_required_field_missing
case_6_critical_pending
case_7_multi_violations
case_8_skip_folder
case_9_raw_mode

echo
echo "============================================"
echo " 结果：PASS=$PASS  FAIL=$FAIL"
echo "============================================"

if [ "$FAIL" -gt 0 ]; then
  echo "失败用例："
  for c in "${FAIL_CASES[@]}"; do
    echo "  - $c"
  done
  exit 1
fi
exit 0
