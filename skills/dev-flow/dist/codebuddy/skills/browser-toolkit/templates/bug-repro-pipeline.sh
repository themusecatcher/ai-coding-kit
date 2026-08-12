#!/usr/bin/env bash
# bug-repro-pipeline.sh — Bug 复现三步流水线
#
# 工作流 1：DevTools MCP（定位）→ agent-browser（复现）→ Playwright（固化）
#
# 用法：
#   ./bug-repro-pipeline.sh <URL> <BUG_DESCRIPTION>

set -e

URL="${1:?需要提供 URL 参数}"
DESC="${2:-unnamed-bug}"
SLUG="$(echo "$DESC" | tr -c "a-zA-Z0-9" "-" | tr -s "-" | /usr/bin/cut -c1-40)"

OUTDIR="./bug-repro/$(date +%Y%m%d-%H%M)-$SLUG"
/bin/mkdir -p "$OUTDIR"

echo "═══════════════════════════════════════"
echo "  Bug 复现流水线 / 产物目录：$OUTDIR"
echo "═══════════════════════════════════════"

echo ""
echo "📍 Step 1 — Chrome DevTools MCP 定位（手动执行）"
echo "   1. 运行 ./debug-live-page.sh 启动调试 Chrome"
echo "   2. 让 AI 通过 MCP 调用："
echo "      - navigate_page $URL"
echo "      - list_console_messages  → 存到 $OUTDIR/console.json"
echo "      - list_network_requests  → 存到 $OUTDIR/network.json"
echo "      - performance_start_trace / _stop_trace → $OUTDIR/trace.json"
echo ""

echo "🤖 Step 2 — agent-browser 稳定复现"
agent-browser --session bug-repro open "$URL" 2>/dev/null || true
agent-browser --session bug-repro screenshot --annotate "$OUTDIR/repro.png" 2>/dev/null || true
agent-browser --session bug-repro snapshot -i --json > "$OUTDIR/snapshot.json" 2>/dev/null || true
echo "  产物：$OUTDIR/repro.png, snapshot.json"
echo "  交互式：agent-browser --session bug-repro snapshot -i 继续复现步骤"

echo ""
echo "🧪 Step 3 — Playwright 固化为回归测试（建议委托 e2e-testing skill）"
echo "  - 将 agent-browser 命令序列翻译为 *.spec.ts"
echo "  - 加 expect() 断言" 
echo "  - 加入 CI 矩阵"
echo ""
echo "✅ 流水线模板已执行。产物位于：$OUTDIR"
