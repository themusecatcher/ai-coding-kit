#!/usr/bin/env bash
# mark-step5-start.sh — 标记步骤 5 开始时间戳
#
# 规范反向引用：
#   - 与 working-context-freshness-lint.sh 配合使用
#   - 步骤 5 开始时由 AI 调用，写入基准时间戳
#
# 用法：
#   bash mark-step5-start.sh <flow-name>
#
# 效果：
#   在 /tmp/.dev-flow-step5-start-{flow-name} 写入当前 epoch 时间戳
#
set -euo pipefail

FLOW_NAME="${1:-}"

if [ -z "$FLOW_NAME" ]; then
  echo "❌ 缺少参数 <flow-name>"
  echo "   用法: bash mark-step5-start.sh <flow-name>"
  exit 1
fi

MARKER="/tmp/.dev-flow-step5-start-${FLOW_NAME}"
date +%s > "$MARKER"
echo "✅ 步骤 5 开始时间已标记: $(cat "$MARKER") → ${MARKER}"
