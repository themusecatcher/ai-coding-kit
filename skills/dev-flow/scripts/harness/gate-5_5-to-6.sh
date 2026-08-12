#!/bin/bash
# ============================================================
# gate-5-to-6.sh - 重量门禁：编码(5) → 验证(6)
#
# 检查编码完成后的质量基线：
#   P0-1: ESLint 无新增错误（支持 auto-fix 恢复）
#   P0-2: TypeScript 编译无错误
#   P0-3: 无未暂存的变更（Git 干净）
#   P1-1: 无调试代码残留
#
# 返回: 0=全部通过, 1=P0失败, 2=仅P1失败
# ============================================================

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_FLOW_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$DEV_FLOW_ROOT/scripts/lib/common.sh"
source "$DEV_FLOW_ROOT/scripts/lib/logger.sh"
source "$DEV_FLOW_ROOT/scripts/recovery/recovery-engine.sh"

FLOW_NAME="${1:-}"
STEP_JSON="${2:-}"
MODIFIED_FILES="${3:-}"

p0_total=0; p0_fails=0
p1_total=0; p1_fails=0

# ======== P0 检查 ========

# P0-1: ESLint 无新增错误
p0_total=$((p0_total + 1))
log_step "P0-1: ESLint"
if command -v npx &>/dev/null && [ -f "package.json" ]; then
  eslint_target="${MODIFIED_FILES:-src/}"
  eslint_errors=$(npx eslint $eslint_target --quiet 2>&1 | grep -c "error" || echo "0")
  if [ "$eslint_errors" -gt 0 ]; then
    # 尝试 auto-fix 恢复
    log_warn "P0-1: ESLint 发现 $eslint_errors 处错误，尝试 auto-fix..."
    if try_recover "eslint" "auto_fix" "npx eslint $eslint_target --fix --quiet" 2; then
      # Recheck
      eslint_errors_after=$(npx eslint $eslint_target --quiet 2>&1 | grep -c "error" || echo "0")
      if [ "$eslint_errors_after" -eq 0 ]; then
        log_pass "P0-1: ESLint（auto-fix 后通过）"
      else
        log_fail "P0-1: ESLint 仍有 $eslint_errors_after 处错误（auto-fix 无法修复）"
        p0_fails=$((p0_fails + 1))
      fi
    else
      log_fail "P0-1: ESLint 恢复失败"
      p0_fails=$((p0_fails + 1))
    fi
  else
    log_pass "P0-1: ESLint 通过"
  fi
else
  log_skip "P0-1: ESLint 跳过（无 npx 或 package.json）"
fi

# P0-2: TypeScript 编译
p0_total=$((p0_total + 1))
log_step "P0-2: TypeScript"
if [ -f "tsconfig.json" ] && command -v npx &>/dev/null; then
  ts_errors=$(npx tsc --noEmit 2>&1 | grep -c "error TS" || echo "0")
  if [ "$ts_errors" -gt 0 ]; then
    log_fail "P0-2: TypeScript 有 $ts_errors 个编译错误"
    p0_fails=$((p0_fails + 1))
  else
    log_pass "P0-2: TypeScript 通过"
  fi
else
  log_skip "P0-2: TypeScript 跳过（无 tsconfig.json 或 npx）"
fi

# P0-3: Git 状态（无未暂存变更）
p0_total=$((p0_total + 1))
log_step "P0-3: Git 状态"
if git rev-parse --git-dir &>/dev/null; then
  unstaged=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
  if [ "$unstaged" -gt 0 ]; then
    log_fail "P0-3: 有 $unstaged 个文件有未暂存变更"
    p0_fails=$((p0_fails + 1))
  else
    log_pass "P0-3: Git 状态干净"
  fi
else
  log_skip "P0-3: 非 Git 仓库（跳过）"
fi

# ======== P1 检查 ========

# P1-1: 无调试代码残留
p1_total=$((p1_total + 1))
log_step "P1-1: 调试代码检查"
if [ -n "$MODIFIED_FILES" ]; then
  debug_hits=$(grep -rn "console\.\|debugger" $MODIFIED_FILES 2>/dev/null \
    | grep -v "// eslint-disable" \
    | grep -v "console.error\|console.warn" \
    | wc -l | tr -d ' ')
  if [ "$debug_hits" -gt 0 ]; then
    log_warn "P1-1: 发现 $debug_hits 处调试代码（console.log/debugger）"
    p1_fails=$((p1_fails + 1))
  else
    log_pass "P1-1: 无调试代码"
  fi
else
  log_skip "P1-1: 无指定修改文件（跳过）"
fi

# ======== 汇总 ========
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  门禁 step-5 → step-6"
echo "  P0: $((p0_total - p0_fails))/$p0_total 通过"
echo "  P1: $((p1_total - p1_fails))/$p1_total 通过"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $p0_fails -gt 0 ]; then
  exit 1
elif [ $p1_fails -gt 0 ]; then
  exit 2
else
  exit 0
fi
