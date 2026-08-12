#!/bin/bash
# ============================================================
# gate-7-to-8.sh - 中量门禁：commit(7) → L3审查(8)
#
# 检查 commit 完成后的推进条件：
#   P0-1: commit 已完成（最近 commit 在 10 分钟内）
#   P0-2: commit body 含 CR 汇总（如有 CR）
#   P1-1: devlog 存在
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

# P0-1: commit 已完成
p0_total=$((p0_total + 1))
log_step "P0-1: commit 存在"
if git rev-parse --git-dir &>/dev/null; then
  last_commit_time=$(git log -1 --format='%ct' 2>/dev/null || echo "0")
  now=$(date +%s)
  diff=$((now - last_commit_time))
  # 10 分钟内的 commit 视为本次
  if [ $diff -lt 600 ]; then
    last_msg=$(git log -1 --format='%s' 2>/dev/null)
    log_pass "P0-1: 最近 commit: $last_msg"
  else
    log_fail "P0-1: 最近 commit 超过 10 分钟前（可能未提交）"
    p0_fails=$((p0_fails + 1))
  fi
else
  log_skip "P0-1: 非 Git 仓库（跳过）"
fi

# P0-2: commit body 含 CR 汇总（如有 CR）
WORKING_CONTEXT=$(find "$HOME/.codebuddy/working-context" -maxdepth 1 -name "*.md" 2>/dev/null | head -1)
if [ -n "$WORKING_CONTEXT" ] && grep -q "change_requests:" "$WORKING_CONTEXT" 2>/dev/null; then
  cr_count=$(grep -c 'id:.*CR-' "$WORKING_CONTEXT" 2>/dev/null || echo "0")
  if [ "$cr_count" -gt 0 ]; then
    p0_total=$((p0_total + 1))
    log_step "P0-2: commit body 含 CR 汇总"
    last_commit_body=$(git log -1 --format='%b' 2>/dev/null)
    if echo "$last_commit_body" | grep -qi "change request\|CR-"; then
      log_pass "P0-2: commit body 包含 CR 汇总"
    else
      log_fail "P0-2: commit body 未包含 CR 汇总（有 $cr_count 个 CR 需记录）"
      log_info "  💡 恢复方式: git commit --amend 追加 CR 摘要到 body"
      p0_fails=$((p0_fails + 1))
    fi
  fi
fi

# ======== P1 检查 ========

# P1-1: devlog 存在
p1_total=$((p1_total + 1))
log_step "P1-1: devlog 存在"
DEVLOG_DIR="$HOME/.codebuddy/dev-logs"
if [ -d "$DEVLOG_DIR" ]; then
  # 检查最近 10 分钟内的 devlog
  recent_devlog=$(find "$DEVLOG_DIR" -name "*.md" -mmin -10 2>/dev/null | head -1)
  if [ -n "$recent_devlog" ]; then
    log_pass "P1-1: devlog 存在: $(basename "$recent_devlog")"
  else
    log_warn "P1-1: 未发现最近 10 分钟内的 devlog"
    p1_fails=$((p1_fails + 1))
  fi
else
  log_skip "P1-1: devlog 目录不存在（跳过）"
fi

# ======== 汇总 ========
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  门禁 step-7 → step-8"
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
