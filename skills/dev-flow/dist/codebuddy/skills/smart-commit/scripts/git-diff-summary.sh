#!/usr/bin/env bash
# git-diff-summary.sh - 智能选择 git diff 输出体量
# 行为：
#   - 默认查 staged diff
#   - 若行数超过 full_diff_max_lines 阈值（默认 200，从 YAML 读取）→ 自动降级为 --stat
#   - 若 staged 为空，自动 fallback 到工作区 diff
# 输出：
#   先输出元信息（mode、line_count）写到 stderr，便于上层 LLM 感知
#   diff 内容写到 stdout
# 退出码：0 = 成功；1 = 不是 git 仓库
#
# 设计哲学：体量判断是确定性规则（行数与阈值比较），不应让 LLM 心算。

set -euo pipefail

# 校验当前在 git 仓库
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "ERROR: 当前目录不是 git 仓库" >&2
  exit 1
fi

# ---------- 读取阈值（从 YAML） ----------
CONFIG_FILE="$(dirname "$0")/../config/action-map.yaml"
THRESHOLD=200  # fallback 默认值（与 YAML 保持一致）

if [ -f "$CONFIG_FILE" ]; then
  PARSED=$(awk '
    /^diff_threshold:/ { in_block=1; next }
    in_block && /^[a-zA-Z]/ { in_block=0 }
    in_block && /full_diff_max_lines:/ { print $2; exit }
  ' "$CONFIG_FILE")
  if [ -n "$PARSED" ] && [[ "$PARSED" =~ ^[0-9]+$ ]]; then
    THRESHOLD="$PARSED"
  fi
fi

# ---------- 决定查询源（staged 优先，工作区兜底） ----------
STAGED_FILES=$(git diff --staged --name-only | wc -l | tr -d ' ')

if [ "$STAGED_FILES" -gt 0 ]; then
  SOURCE="staged"
  DIFF_CMD="git diff --staged"
  STAT_CMD="git diff --staged --stat"
  NAMES_CMD="git diff --staged --name-only"
else
  WT_FILES=$(git diff --name-only | wc -l | tr -d ' ')
  if [ "$WT_FILES" -eq 0 ]; then
    echo "INFO: 既无暂存改动也无工作区改动" >&2
    echo "{\"mode\":\"empty\",\"line_count\":0,\"source\":\"none\"}" >&2
    exit 0
  fi
  SOURCE="working-tree"
  DIFF_CMD="git diff"
  STAT_CMD="git diff --stat"
  NAMES_CMD="git diff --name-only"
fi

# ---------- 探测 full diff 行数 ----------
LINE_COUNT=$($DIFF_CMD | wc -l | tr -d ' ')

# ---------- 决定输出模式 ----------
if [ "$LINE_COUNT" -le "$THRESHOLD" ]; then
  MODE="full"
else
  MODE="stat"
fi

# ---------- 输出元信息到 stderr（不污染 stdout 主输出） ----------
echo "{\"mode\":\"$MODE\",\"line_count\":$LINE_COUNT,\"threshold\":$THRESHOLD,\"source\":\"$SOURCE\"}" >&2

# ---------- 输出主 diff ----------
echo "===== file list ($SOURCE) ====="
$NAMES_CMD
echo ""
echo "===== diff stat ====="
$STAT_CMD
echo ""

if [ "$MODE" = "full" ]; then
  echo "===== full diff ====="
  $DIFF_CMD
else
  echo "===== full diff omitted (line_count=$LINE_COUNT > threshold=$THRESHOLD) ====="
  echo "Tip: 上层 LLM 可对关键文件单独执行 'git diff $([ "$SOURCE" = "staged" ] && echo "--staged ")-- <file>' 获取详情"
fi
