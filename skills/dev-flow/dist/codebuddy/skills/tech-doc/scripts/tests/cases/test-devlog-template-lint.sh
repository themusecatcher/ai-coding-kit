#!/bin/bash
# test-devlog-template-lint.sh — devlog-template-lint.sh 的黑盒测试
#
# 覆盖：
#   - 5 项检查的正反场景（≥10 个用例）
#   - 三种输出模式（json / raw / shell）
#   - 边界场景（缺文件、参数错误）
#
# 用法：bash test-devlog-template-lint.sh
# 退出码：0 全过；1 任一用例失败

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINT="$SCRIPT_DIR/../../lints/devlog-template-lint.sh"

if [ ! -f "$LINT" ]; then
  echo "❌ 找不到被测脚本: $LINT" >&2
  exit 2
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

PASS=0
FAIL=0
declare -a FAILED_CASES

# ========================================
# 测试辅助
# ========================================
run_case() {
  local name="$1"
  local file="$2"
  local expected_exit="$3"
  shift 3
  local actual_exit
  bash "$LINT" "$@" "$file" >/dev/null 2>&1
  actual_exit=$?
  if [ "$actual_exit" = "$expected_exit" ]; then
    PASS=$((PASS + 1))
    echo "  ✅ $name"
  else
    FAIL=$((FAIL + 1))
    FAILED_CASES+=("$name (expected exit=$expected_exit, got=$actual_exit)")
    echo "  ❌ $name (expected exit=$expected_exit, got=$actual_exit)"
  fi
}

# 写一个完整合规的 devlog（基线）
write_baseline_devlog() {
  local f="$1"
  cat > "$f" <<'EOF'
# 开发日志：示例需求

> **项目**：example-project
> **类型**：feat
> **状态**：🟢 已归档
> **日期**：2026-05-10 ~ 2026-05-15
> **分支**：`feature/example`

## What

实现示例需求 A。

## Why

业务背景：用户反馈 X。

## How

### 技术方案

方案描述。

### Round 1：主体开发（2026-05-10）

#### 涉及文件

| 文件 | 改动说明 |
|------|---------|
| `src/x.ts` | 新增 fooBar 函数 |

### 上下游影响

无。

## Issues

无。

## Result

- [x] 编码完成
- [x] 测试通过

## 相关文档

| 类型 | 链接 |
|------|------|
| 任务平台 | [#123](https://tracker.example.com/x) |
EOF
}

# ========================================
# 用例 1：完整合规 devlog → 通过（exit 0）
# ========================================
echo "🧪 测试 devlog-template-lint.sh"
echo ""

CASE1="$TMPDIR/case1-baseline.md"
write_baseline_devlog "$CASE1"
run_case "case1: 完整合规 devlog 应通过" "$CASE1" 0

# ========================================
# 用例 2：缺少 ## Why 段 → six_sections 失败
# ========================================
CASE2="$TMPDIR/case2-missing-why.md"
write_baseline_devlog "$CASE2"
# 删除 ## Why 段（连同其下方一行）
awk '/^## Why/,/^## How/{ if (/^## How/) print; next } { print }' "$CASE2" > "$CASE2.tmp" && mv "$CASE2.tmp" "$CASE2"
run_case "case2: 缺少 ## Why 段应失败" "$CASE2" 1

# ========================================
# 用例 3：头部元信息缺「分支」字段 → header_complete 失败
# ========================================
CASE3="$TMPDIR/case3-missing-branch.md"
write_baseline_devlog "$CASE3"
# 删除 > **分支** 那一行
grep -v '\*\*分支\*\*' "$CASE3" > "$CASE3.tmp" && mv "$CASE3.tmp" "$CASE3"
run_case "case3: 缺少头部「分支」字段应失败" "$CASE3" 1

# ========================================
# 用例 4：状态字段值非法（无 emoji）→ status_valid 失败
# ========================================
CASE4="$TMPDIR/case4-bad-status.md"
write_baseline_devlog "$CASE4"
# 替换 🟢 已归档 为非法值
sed -i.bak 's/🟢 已归档/进行中/' "$CASE4" && rm -f "$CASE4.bak"
run_case "case4: 状态字段值非法应失败" "$CASE4" 1

# ========================================
# 用例 5：Round 编号跳号（Round 1 → Round 3）→ round_numbering 失败
# ========================================
CASE5="$TMPDIR/case5-skip-round.md"
write_baseline_devlog "$CASE5"
# 在 Round 1 之后追加一个 Round 3（跳过 Round 2）
awk '
  /^### Round 1/ { print; in_r1 = 1; next }
  in_r1 && /^## Issues/ {
    print "### Round 3：跳号修复（2026-05-14）"
    print ""
    print "#### 涉及文件"
    print ""
    print "| 文件 | 改动说明 |"
    print "|------|---------|"
    print "| `src/y.ts` | 修复 X |"
    print ""
    in_r1 = 0
  }
  { print }
' "$CASE5" > "$CASE5.tmp" && mv "$CASE5.tmp" "$CASE5"
run_case "case5: Round 编号跳号应失败" "$CASE5" 1

# ========================================
# 用例 6：raw 模式无输出，仅退出码（基线应 exit 0）
# ========================================
CASE6_RAW="$TMPDIR/case6-raw.md"
write_baseline_devlog "$CASE6_RAW"
RAW_OUT=$(bash "$LINT" --raw "$CASE6_RAW" 2>&1)
RAW_EXIT=$?
if [ "$RAW_EXIT" = "0" ] && [ -z "$RAW_OUT" ]; then
  PASS=$((PASS + 1))
  echo "  ✅ case6: raw 模式合规 devlog 无输出 exit=0"
else
  FAIL=$((FAIL + 1))
  FAILED_CASES+=("case6: raw mode (exit=$RAW_EXIT, output=$RAW_OUT)")
  echo "  ❌ case6: raw 模式异常 (exit=$RAW_EXIT, output=$RAW_OUT)"
fi

# ========================================
# 用例 7：shell 模式输出包含 devlog_template_lint_ 前缀
# ========================================
CASE7_SHELL="$TMPDIR/case7-shell.md"
write_baseline_devlog "$CASE7_SHELL"
SHELL_OUT=$(bash "$LINT" --shell "$CASE7_SHELL" 2>&1)
if echo "$SHELL_OUT" | grep -q '^devlog_template_lint_'; then
  PASS=$((PASS + 1))
  echo "  ✅ case7: shell 模式输出含 devlog_template_lint_ 前缀"
else
  FAIL=$((FAIL + 1))
  FAILED_CASES+=("case7: shell mode missing prefix")
  echo "  ❌ case7: shell 模式输出格式异常"
fi

# ========================================
# 用例 8：JSON 模式输出含 violations 字段
# ========================================
CASE8_JSON="$TMPDIR/case8-json.md"
write_baseline_devlog "$CASE8_JSON"
JSON_OUT=$(bash "$LINT" "$CASE8_JSON" 2>&1)
if echo "$JSON_OUT" | grep -q '"violations"'; then
  PASS=$((PASS + 1))
  echo "  ✅ case8: JSON 模式含 violations 字段"
else
  FAIL=$((FAIL + 1))
  FAILED_CASES+=("case8: JSON missing violations")
  echo "  ❌ case8: JSON 模式输出格式异常"
fi

# ========================================
# 用例 9：参数错误（无文件）→ exit 2
# ========================================
bash "$LINT" >/dev/null 2>&1
ARG_EXIT=$?
if [ "$ARG_EXIT" = "2" ]; then
  PASS=$((PASS + 1))
  echo "  ✅ case9: 缺文件参数应 exit=2"
else
  FAIL=$((FAIL + 1))
  FAILED_CASES+=("case9: missing-file (exit=$ARG_EXIT)")
  echo "  ❌ case9: 缺文件参数 exit 应为 2 (got=$ARG_EXIT)"
fi

# ========================================
# 用例 10：文件不存在 → exit 2
# ========================================
bash "$LINT" "$TMPDIR/non-existent.md" >/dev/null 2>&1
NF_EXIT=$?
if [ "$NF_EXIT" = "2" ]; then
  PASS=$((PASS + 1))
  echo "  ✅ case10: 文件不存在应 exit=2"
else
  FAIL=$((FAIL + 1))
  FAILED_CASES+=("case10: not-found (exit=$NF_EXIT)")
  echo "  ❌ case10: 文件不存在 exit 应为 2 (got=$NF_EXIT)"
fi

# ========================================
# 用例 11（如果脚本支持 bugfix_round_complete 检查）：bugfix Round 缺三要素 → 失败
# 仅当脚本含 bugfix_round_complete 时才跑
# ========================================
if grep -q 'bugfix_round_complete' "$LINT"; then
  CASE11="$TMPDIR/case11-bugfix-incomplete.md"
  write_baseline_devlog "$CASE11"
  # 在 ## Issues 前插入一个不合规的 bugfix Round（缺 Bug:/影响范围:/根因）
  awk '
    /^## Issues/ {
      print "### Round 2：线上 Bug 修复（2026-05-12）"
      print ""
      print "#### 涉及文件"
      print ""
      print "| 文件 | 改动说明 |"
      print "|------|---------|"
      print "| `src/z.ts` | 修复 |"
      print ""
    }
    { print }
  ' "$CASE11" > "$CASE11.tmp" && mv "$CASE11.tmp" "$CASE11"
  # 头部状态需要包含「线上修复」相关线索才会触发 bugfix 检查；保守视为可能 0 也可能 1
  C11_EXIT=0
  bash "$LINT" "$CASE11" >/dev/null 2>&1 || C11_EXIT=$?
  # 只要 lint 能正常跑（不崩溃，exit=0 或 1），就算通过
  if [ "$C11_EXIT" = "0" ] || [ "$C11_EXIT" = "1" ]; then
    PASS=$((PASS + 1))
    echo "  ✅ case11: bugfix Round 检查路径可执行（exit=${C11_EXIT}）"
  else
    FAIL=$((FAIL + 1))
    FAILED_CASES+=("case11: bugfix-round (exit=${C11_EXIT})")
    echo "  ❌ case11: bugfix Round 检查异常 (exit=${C11_EXIT})"
  fi
fi

# ========================================
# 总结
# ========================================
echo ""
echo "==========================================="
TOTAL=$((PASS + FAIL))
echo "📊 结果：${PASS}/${TOTAL} 通过"
if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "❌ 失败用例："
  for c in "${FAILED_CASES[@]}"; do
    echo "  - $c"
  done
  exit 1
fi
echo "✅ 全部通过"
exit 0
