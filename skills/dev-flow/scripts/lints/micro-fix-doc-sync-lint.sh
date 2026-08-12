#!/bin/bash
# micro-fix-doc-sync-lint.sh — 微修复步骤 7 文档同步物理事实校验
#
# 用途：在 post-step.sh 中调用，验证 AI 是否完成了 H.2 devlog + plan.md CR 同步。
# 调用方式：
#   bash micro-fix-doc-sync-lint.sh <flow-name>   — 严格模式（exit 1 阻断）
#   bash micro-fix-doc-sync-lint.sh <flow-name> --warn — 软告警模式（不阻断）
#
# 退出码：0=通过, 1=阻断(严格模式), 2=告警(软模式)

set -euo pipefail
FLOW_NAME="${1:-}"
WARN_MODE=false
if [ "${2:-}" = "--warn" ]; then WARN_MODE=true; fi

if [ -z "$FLOW_NAME" ]; then
  echo "[lint] micro-fix-doc-sync: 缺少 flow-name 参数" >&2
  exit 1
fi

WC_FILE="$HOME/.codebuddy/working-context/${FLOW_NAME}.md"
if [ ! -f "$WC_FILE" ]; then
  echo "[lint] micro-fix-doc-sync: 工作上下文 $WC_FILE 不存在，可能是轻量 micro-fix（无活跃流程），跳过" >&2
  exit 0
fi

PASS=true
ISSUES=""

# ---- 检查 1：devlog 今天是否有写入 ----
ARTIFACTS_DIR=$(grep -A1 '^artifacts:' "$WC_FILE" | grep 'dir:' | head -1 | sed 's/.*dir: *"//' | sed 's/".*//' | sed "s|^~|$HOME|")

if [ -n "$ARTIFACTS_DIR" ] && [ -d "$ARTIFACTS_DIR" ]; then
  DEVLOG="$ARTIFACTS_DIR/devlog.md"
  if [ -f "$DEVLOG" ]; then
    TODAY=$(date +%Y-%m-%d)
    # macOS/BSD stat 和 GNU stat 语法不同
    if stat -f %Sm -t %Y-%m-%d "$DEVLOG" 2>/dev/null | grep -q "$TODAY"; then
      : # pass
    elif stat -c %y "$DEVLOG" 2>/dev/null | grep -q "$TODAY"; then
      : # pass (GNU stat)
    else
      ISSUES="${ISSUES}  - devlog.md ($DEVLOG) 最后修改日期不是今天 ($TODAY)\n"
      PASS=false
    fi
  else
    ISSUES="${ISSUES}  - devlog.md ($DEVLOG) 不存在\n"
    PASS=false
  fi
fi

# ---- 检查 2：plan.md 中是否有未同步的 CR ----
# 从工作上下文 YAML 头部提取 change_requests 中 status="done" 的 CR ID
# 使用行号范围提取（避免 macOS awk 的 locale 导致 range 匹配异常）
CR_START=$(grep -n '^change_requests:' "$WC_FILE" 2>/dev/null | head -1 | cut -d: -f1)
if [ -n "$CR_START" ]; then
  CR_END=$(awk "NR>$CR_START && /^[a-z]/ {print NR; exit}" "$WC_FILE" 2>/dev/null)
  if [ -n "$CR_END" ]; then
    CR_IDS=$(sed -n "${CR_START},${CR_END}p" "$WC_FILE" 2>/dev/null | awk 'BEGIN{id=""} /- *id:/{sub(/[^"]*"/,""); sub(/".*/,""); id=$0} /status: *"done"/{print id; id=""}' 2>/dev/null || true)
  else
    CR_IDS=""
  fi
else
  CR_IDS=""
fi

if [ -n "$ARTIFACTS_DIR" ] && [ -f "$ARTIFACTS_DIR/plan.md" ]; then
  for CR_ID in $CR_IDS; do
    if ! grep -q "$CR_ID" "$ARTIFACTS_DIR/plan.md" 2>/dev/null; then
      ISSUES="${ISSUES}  - plan.md ($ARTIFACTS_DIR/plan.md) 缺少 CR-$CR_ID 的记录\n"
      PASS=false
    fi
  done
fi

# ---- 输出 ----
if [ "$PASS" = true ]; then
  echo "[lint] micro-fix-doc-sync: ✅ 通过"
  exit 0
fi

if [ "$WARN_MODE" = true ]; then
  echo "[lint] micro-fix-doc-sync: ⚠️ 告警（soft mode）" >&2
  printf '%b' "$ISSUES" >&2
  exit 0
else
  echo "[lint] micro-fix-doc-sync: 🔴 阻断" >&2
  printf '%b' "$ISSUES" >&2
  echo "修复：执行 H.2 devlog 追加 + plan.md CR 同步后重试" >&2
  exit 1
fi

