#!/usr/bin/env bash
# git-diff-summary.sh - 智能选择 git diff 输出体量
# 行为：
#   - 默认查 staged diff
#   - 若行数超过 full_diff_max_lines 阈值（默认 200，从 YAML 读取）→ 自动降级为 --stat
#   - 若 staged 为空，自动 fallback 到工作区 diff
#   - --staged-only：只读暂存区，不回退工作区（分批提交批次内生成 message 用）
#   - 无 diff 但存在未跟踪文件时，输出 mode=untracked-only 并列出文件
#     （git diff 看不到新文件，这是"新建文件被漏掉"的根因）
# 输出：
#   先输出元信息（mode、line_count、untracked_count）写到 stderr，便于上层 LLM 感知
#   diff 内容写到 stdout
# 退出码：0 = 成功；1 = 不是 git 仓库；2 = 未知参数
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

# ---------- 参数解析 ----------
# --staged-only：分批提交模式使用。只读暂存区，绝不 fallback 到工作区，
#                保证生成 message 的 diff 与「本批实际要提交的内容」严格一致。
STAGED_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --staged-only) STAGED_ONLY=1 ;;
    -h|--help)
      echo "用法: git-diff-summary.sh [--staged-only]" >&2
      echo "  --staged-only  只分析暂存区（分批提交时使用，不回退到工作区）" >&2
      exit 0
      ;;
    *) echo "ERROR: 未知参数 $arg" >&2; exit 2 ;;
  esac
done

# ---------- 未跟踪文件（git diff 的天然盲区） ----------
UNTRACKED_CMD="git ls-files --others --exclude-standard"
UNTRACKED_COUNT=$($UNTRACKED_CMD | wc -l | tr -d ' ')

# ---------- 决定查询源（staged 优先，工作区兜底） ----------
STAGED_FILES=$(git diff --staged --name-only | wc -l | tr -d ' ')

if [ "$STAGED_FILES" -gt 0 ]; then
  SOURCE="staged"
  DIFF_CMD="git diff --staged"
  STAT_CMD="git diff --staged --stat"
  NAMES_CMD="git diff --staged --name-only"
else
  if [ "$STAGED_ONLY" -eq 1 ]; then
    if [ "$UNTRACKED_COUNT" -gt 0 ]; then
      echo "INFO: 暂存区为空，存在 $UNTRACKED_COUNT 个未跟踪文件（分批模式需先按批 add）" >&2
      echo "{\"mode\":\"untracked-only\",\"line_count\":0,\"source\":\"staged\",\"untracked_count\":$UNTRACKED_COUNT}" >&2
      echo "===== untracked (not staged) ====="
      $UNTRACKED_CMD
      exit 0
    fi
    echo "INFO: 暂存区为空（--staged-only 模式不回退到工作区）" >&2
    echo "{\"mode\":\"empty\",\"line_count\":0,\"source\":\"staged\",\"untracked_count\":0}" >&2
    exit 0
  fi

  WT_FILES=$(git diff --name-only | wc -l | tr -d ' ')
  if [ "$WT_FILES" -eq 0 ]; then
    if [ "$UNTRACKED_COUNT" -gt 0 ]; then
      echo "INFO: 无已跟踪改动，但存在 $UNTRACKED_COUNT 个未跟踪文件" >&2
      echo "{\"mode\":\"untracked-only\",\"line_count\":0,\"source\":\"none\",\"untracked_count\":$UNTRACKED_COUNT}" >&2
      echo "===== untracked (not tracked yet) ====="
      $UNTRACKED_CMD
      echo ""
      echo "提示: git diff 看不到未跟踪文件，需先 git add 才能生成完整 message"
      exit 0
    fi
    echo "INFO: 既无暂存改动也无工作区改动" >&2
    echo "{\"mode\":\"empty\",\"line_count\":0,\"source\":\"none\",\"untracked_count\":0}" >&2
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
echo "{\"mode\":\"$MODE\",\"line_count\":$LINE_COUNT,\"threshold\":$THRESHOLD,\"source\":\"$SOURCE\",\"untracked_count\":$UNTRACKED_COUNT}" >&2

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
