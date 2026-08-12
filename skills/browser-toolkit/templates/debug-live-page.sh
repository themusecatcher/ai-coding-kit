#!/usr/bin/env bash
# debug-live-page.sh — 调试真实 Chrome 页面（Chrome DevTools MCP 前置脚本）
#
# 用途：
#   当用户想让 AI 分析/调试其当前浏览器里某个页面时，先运行此脚本
#   启动带远程调试端口的 Chrome，然后 AI 通过 DevTools MCP 连上去
#
# 用法：
#   ./debug-live-page.sh [profile-dir]
#   默认 profile-dir=/tmp/cdp-debug-profile（安全隔离，避免污染真实账号）

set -e

PROFILE_DIR="${1:-/tmp/cdp-debug-profile}"
PORT="${PORT:-9222}"

CHROME_MAC="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
CHROME_LINUX="$(command -v google-chrome || command -v chromium || true)"

if [[ "$(uname)" == "Darwin" ]]; then
  CHROME="$CHROME_MAC"
else
  CHROME="$CHROME_LINUX"
fi

if [[ -z "$CHROME" || ! -e "$CHROME" ]]; then
  echo "❌ 未找到 Chrome 可执行文件" >&2
  exit 1
fi

# 端口占用检测
if lsof -Pi :"$PORT" -sTCP:LISTEN -t >/dev/null 2>&1; then
  echo "⚠️  端口 $PORT 已被占用，请先杀掉进程：lsof -i:$PORT" >&2
  exit 1
fi

echo "🚀 启动 Chrome with remote-debugging-port=$PORT"
echo "📂 Profile: $PROFILE_DIR（隔离模式，不影响你主 Chrome）"
echo ""
echo "然后让 AI 调用 Chrome DevTools MCP 工具即可连接："
echo "  list_pages / select_page / performance_start_trace 等"
echo ""
# 后台启动 Chrome，stdout/stderr 重定向到日志文件，避免脚本阻塞
LOG_FILE="/tmp/cdp-chrome-$PORT.log"
"$CHROME" \
  --remote-debugging-port="$PORT" \
  --user-data-dir="$PROFILE_DIR" \
  --no-first-run \
  --no-default-browser-check \
  >"$LOG_FILE" 2>&1 &

CHROME_PID=$!
sleep 2

# 验证是否成功起监听
if ! lsof -Pi :"$PORT" -sTCP:LISTEN -t >/dev/null 2>&1; then
  echo "❌ Chrome 启动后端口 $PORT 未监听，查看日志：$LOG_FILE" >&2
  exit 1
fi

echo "✅ Chrome 已在后台启动（PID=$CHROME_PID）"
echo "   关闭时：kill $CHROME_PID  或  pkill -f 'remote-debugging-port=$PORT'"
echo "   日志：$LOG_FILE"
