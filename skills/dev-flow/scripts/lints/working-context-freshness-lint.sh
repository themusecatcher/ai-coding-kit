#!/usr/bin/env bash
# working-context-freshness-lint.sh — 工作上下文更新新鲜度 lint
#
# 规范反向引用：
#   - gates.yaml §lints.working-context-freshness-lint
#   - references/iteration-fix.md §「工作上下文更新规则（迭代修复场景）」
#   - steps/step-5.5-post-coding.md §5.5b 文档同步
#   - rules/AI行为规范.mdc §「验证行为规范 > 编辑工具假性成功兜底」
#
# 设计哲学：
#   「确定性用代码，模糊性用 LLM」
#   工作上下文是否更新 = 确定性事实（文件 mtime 可检测）→ 用脚本强制
#
# 用法：
#   bash working-context-freshness-lint.sh <flow-name> [--timestamp <epoch>]
#   bash working-context-freshness-lint.sh <flow-name> --check-only
#   bash working-context-freshness-lint.sh --help
#
# 参数：
#   <flow-name>        工作上下文文件名（不含 .md 后缀），如 20260514_user-login-form_myProject
#   --timestamp <epoch> 步骤 5 开始的 epoch 时间戳（可选，不传则用 .step5-start 标记文件）
#   --check-only       仅检查不阻断（退出码 0/2，不返回 1）
#
# 退出码：
#   0 = pass（工作上下文已在编码后更新）
#   1 = block（工作上下文未更新，应阻断后续步骤）
#   2 = skip（无法判定——文件不存在/参数缺失/标记文件缺失，不阻断但发出警告）
#
# 判定逻辑：
#   1. 定位工作上下文文件：~/.codebuddy/working-context/{flow-name}.md
#   2. 获取基准时间戳：
#      a. --timestamp 参数优先
#      b. 否则读取 /tmp/.dev-flow-step5-start-{flow-name} 标记文件内容
#      c. 均无则 exit 2（skip）
#   3. 获取工作上下文 mtime
#   4. mtime > baseline → pass；mtime <= baseline → block
#
set -euo pipefail

# ========== 参数解析 ==========
FLOW_NAME=""
BASELINE_TS=""
CHECK_ONLY=0

show_help() {
  sed -n '2,36p' "$0"
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    --timestamp)
      shift
      BASELINE_TS="$1"
      ;;
    --check-only)
      CHECK_ONLY=1
      ;;
    -h|--help)
      show_help
      ;;
    *)
      if [ -z "$FLOW_NAME" ]; then
        FLOW_NAME="$1"
      else
        echo "❌ 未知参数: $1"
        exit 2
      fi
      ;;
  esac
  shift
done

if [ -z "$FLOW_NAME" ]; then
  echo "❌ 缺少必需参数 <flow-name>"
  echo "   用法: bash working-context-freshness-lint.sh <flow-name> [--timestamp <epoch>]"
  exit 2
fi

# ========== 定位工作上下文文件 ==========
WC_DIR="${HOME}/.codebuddy/working-context"
WC_FILE="${WC_DIR}/${FLOW_NAME}.md"

if [ ! -f "$WC_FILE" ]; then
  # 反沉默失败：先在 archive/ 子目录里兜底搜索，文件被异常移动时直接报错
  # 出处：rules/AI行为规范.mdc §「验证行为规范 > 编辑工具假性成功兜底」
  # 设计原因：dev-flow 不存在自动归档机制（详见 skills/dev-flow/references/working-context.md §九「目录结构禁令」），
  #   .md 文件出现在 archive/ 子目录通常意味着被错误的 `mv` 操作移动，必须主动报错而非沉默跳过。
  if [ -d "${WC_DIR}/archive" ]; then
    ARCHIVED_PATH=$(find "${WC_DIR}/archive" -type f -name "${FLOW_NAME}.md" 2>/dev/null | head -1)
    if [ -n "$ARCHIVED_PATH" ]; then
      echo "❌ 工作上下文文件被错误移动到 archive/ 子目录"
      echo "   期望位置: ${WC_FILE}"
      echo "   实际位置: ${ARCHIVED_PATH}"
      echo ""
      echo "   ⚠️  dev-flow 不存在自动归档机制（详见 skills/dev-flow/references/working-context.md §九「目录结构禁令」）"
      echo "   修复: mv \"${ARCHIVED_PATH}\" \"${WC_FILE}\""
      exit 1
    fi
  fi

  echo "⚠️  工作上下文文件不存在: ${WC_FILE}"
  echo "   无法执行新鲜度检查，跳过（不阻断）"
  exit 2
fi

# ========== 获取基准时间戳 ==========
STEP5_MARKER="/tmp/.dev-flow-step5-start-${FLOW_NAME}"

if [ -z "$BASELINE_TS" ]; then
  if [ -f "$STEP5_MARKER" ]; then
    BASELINE_TS=$(cat "$STEP5_MARKER" 2>/dev/null | tr -d '[:space:]')
  fi
fi

if [ -z "$BASELINE_TS" ]; then
  echo "⚠️  无法获取步骤 5 开始时间戳"
  echo "   未找到 --timestamp 参数，且标记文件不存在: ${STEP5_MARKER}"
  echo "   提示: 步骤 5 开始时应执行 'date +%s > ${STEP5_MARKER}'"
  echo "   本次跳过（不阻断）"
  exit 2
fi

# 校验时间戳格式（纯数字）
if ! echo "$BASELINE_TS" | grep -qE '^[0-9]+$'; then
  echo "❌ 基准时间戳格式无效: ${BASELINE_TS}（应为 Unix epoch 纯数字）"
  exit 2
fi

# ========== 获取工作上下文 mtime ==========
# macOS stat 格式
WC_MTIME=$(stat -f %m "$WC_FILE" 2>/dev/null)
if [ -z "$WC_MTIME" ]; then
  # Linux stat 格式 fallback
  WC_MTIME=$(stat -c %Y "$WC_FILE" 2>/dev/null)
fi

if [ -z "$WC_MTIME" ]; then
  echo "❌ 无法获取文件 mtime: ${WC_FILE}"
  exit 2
fi

# ========== 判定 ==========
BASELINE_DATE=$(date -r "$BASELINE_TS" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date -d "@$BASELINE_TS" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "unknown")
WC_DATE=$(date -r "$WC_MTIME" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date -d "@$WC_MTIME" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "unknown")

if [ "$WC_MTIME" -gt "$BASELINE_TS" ]; then
  echo "✅ 工作上下文已更新"
  echo "   文件: ${FLOW_NAME}.md"
  echo "   基准时间（步骤5开始）: ${BASELINE_DATE} (${BASELINE_TS})"
  echo "   文件修改时间:          ${WC_DATE} (${WC_MTIME})"
  echo "   差值: +$(( WC_MTIME - BASELINE_TS ))s"
  exit 0
else
  echo "🔴 工作上下文未在编码后更新！"
  echo "   文件: ${FLOW_NAME}.md"
  echo "   基准时间（步骤5开始）: ${BASELINE_DATE} (${BASELINE_TS})"
  echo "   文件修改时间:          ${WC_DATE} (${WC_MTIME})"
  echo "   滞后: -$(( BASELINE_TS - WC_MTIME ))s"
  echo ""
  echo "   步骤 5.5b 要求：每轮编码完成后必须更新工作上下文 ## 进度"
  echo "   请执行工作上下文更新后重新校验。"
  if [ "$CHECK_ONLY" -eq 1 ]; then
    exit 2
  fi
  exit 1
fi
