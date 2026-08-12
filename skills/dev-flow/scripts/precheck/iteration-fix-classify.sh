#!/usr/bin/env bash
# iteration-fix-classify.sh
#
# 程序化判定迭代修复场景、复杂度、推荐模式、快车道、分支建议。
# 由 dev-flow 主流程在「检测到匹配的已有工作上下文」后调用，输出 JSON 给 AI 解析。
#
# 用法:
#   iteration-fix-classify.sh \
#     --working-context PATH    工作上下文 .md 文件绝对路径 (必填)
#     --feedback "DESC"         用户本轮反馈文本 (必填，可空字符串)
#     [--git-diff-files N]      可选: 当前 git diff 的文件数（用于复杂度修正）
#     [--current-branch BR]     可选: 当前 git 分支
#
# 输出 (stdout): 单行 JSON，schema 见文末注释
# 错误码:
#   0  正常输出 JSON
#   1  参数错误
#   2  工作上下文文件不存在或不可读
#
# 维护: dev-flow phase2 T4 (2026-05-29)

set -euo pipefail

# --- 参数解析 ---
WC_PATH=""
FEEDBACK=""
DIFF_FILES=""
CUR_BRANCH=""
EXPLICIT_TRIGGER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --working-context)  WC_PATH="$2"; shift 2 ;;
    --feedback)         FEEDBACK="$2"; shift 2 ;;
    --git-diff-files)   DIFF_FILES="$2"; shift 2 ;;
    --current-branch)   CUR_BRANCH="$2"; shift 2 ;;
    --explicit-trigger) EXPLICIT_TRIGGER="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,20p' "$0"; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$WC_PATH" ]] && { echo '{"error":"--working-context is required"}' >&2; exit 1; }
[[ ! -r "$WC_PATH" ]] && { echo "{\"error\":\"working-context not readable: $WC_PATH\"}" >&2; exit 2; }

# --- 1. 提取 YAML 头部字段（容错: 行存在则取，不存在为空） ---
yaml_get() {
  # 仅扫描首个 YAML front matter 块（--- 之间）
  local key="$1"
  awk -v k="$key" '
    BEGIN { in_yaml=0; depth=0 }
    /^---[[:space:]]*$/ { depth++; in_yaml=(depth==1); next }
    depth >= 2 { exit }
    in_yaml && $0 ~ "^"k"[[:space:]]*:" {
      sub("^"k"[[:space:]]*:[[:space:]]*", "")
      sub(/[[:space:]]*$/, "")
      gsub(/^"/,""); gsub(/"$/,"")
      print; exit
    }
  ' "$WC_PATH"
}

WC_STATUS=$(yaml_get "status")
WC_ITERATION=$(yaml_get "iteration")
WC_BRANCH=$(yaml_get "branch")
WC_TASK_ID=$(yaml_get "task_id")
WC_TASK_TYPE=$(yaml_get "task_type")    # bug / story
WC_BATCH_MODE=$(yaml_get "batch_mode")
[[ -z "$WC_ITERATION" ]] && WC_ITERATION="1"

# --- 2. 批次切换分流（最优先） ---
if [[ "$WC_BATCH_MODE" == "true" && "$WC_STATUS" == "batch_in_progress" ]]; then
  cat <<EOF
{
  "scenario": "batch-switch",
  "complexity": "n/a",
  "fast_track_enabled": false,
  "recommended_mode": "n/a",
  "round_number": $WC_ITERATION,
  "branch_advice": "保持当前批次分支",
  "estimated_files": 0,
  "rationale": "batch_mode=true && status=batch_in_progress，按批次切换路径处理（参考 iteration-fix.md §批次切换）"
}
EOF
  exit 0
fi

# --- 3. 是否进入迭代修复（status 前提判定） ---
# 显式命令触发（dev:fix --iteration）时跳过 status 白名单判定，仅在 WC_STATUS 完全为空时报错；否则直接进入 §4 场景分类
if [[ "$EXPLICIT_TRIGGER" == "iteration" ]]; then
  if [[ -z "$WC_STATUS" ]]; then
    cat <<EOF
{
  "scenario": "not-iteration",
  "rationale": "explicit-trigger=iteration 但未匹配到工作上下文，AI 应提示用户先创建工作上下文或检查匹配"
}
EOF
    exit 0
  fi
else
  case "$WC_STATUS" in
    completed|delivered|testing) ;;
    *)
      cat <<EOF
{
  "scenario": "not-iteration",
  "complexity": "n/a",
  "fast_track_enabled": false,
  "recommended_mode": "n/a",
  "round_number": ${WC_ITERATION},
  "branch_advice": "continue current flow (not iteration-fix)",
  "estimated_files": 0,
  "rationale": "working-context status=${WC_STATUS} not in {completed,delivered,testing}, skip iteration-fix and continue normal flow"
}
EOF
      exit 0
      ;;
  esac
fi

# --- 4. 场景分类（上线后 bugfix / 提测后迭代修复） ---
SCENARIO="post-test"   # 默认：提测后迭代修复

# 信号 1: 任务平台 类型 + status 组合（最高优先级）
if [[ "$WC_TASK_TYPE" == "bug" && ( "$WC_STATUS" == "completed" || "$WC_STATUS" == "delivered" ) ]]; then
  SCENARIO="post-launch"
fi

# 信号 2: 用户反馈关键词（次优先级）
if echo "$FEEDBACK" | grep -qE "上线后|线上问题|发布后|线上 bug|production|prod 反馈"; then
  SCENARIO="post-launch"
elif echo "$FEEDBACK" | grep -qE "提测反馈|测试提了|QA 反馈|测试反馈|测试问题"; then
  SCENARIO="post-test"
fi

# 信号 3: 当前分支位置（最低优先级，仅在前两个未明确时）
if [[ -n "$CUR_BRANCH" ]]; then
  if echo "$CUR_BRANCH" | grep -qE "^(master|main|release/)"; then
    SCENARIO="post-launch"
  fi
fi

# --- 5. 复杂度判定（关键词强度） ---
COMPLEXITY="medium"  # 默认中等
ESTIMATED_FILES=2

# 简单信号：单点修复关键词
if echo "$FEEDBACK" | grep -qE "只是改|只改|文案|样式|文字|拼写|颜色|对齐|提示语|placeholder|小问题|微调"; then
  COMPLEXITY="simple"
  ESTIMATED_FILES=1
fi

# 重大信号：架构变更关键词
if echo "$FEEDBACK" | grep -qE "新增功能|新功能|架构调整|重构|推翻|否决|重做|重新设计|方案变更|需求变更|新需求"; then
  COMPLEXITY="major"
  ESTIMATED_FILES=5
fi

# git diff 文件数修正（如果提供了）
if [[ -n "$DIFF_FILES" ]] && [[ "$DIFF_FILES" =~ ^[0-9]+$ ]]; then
  ESTIMATED_FILES="$DIFF_FILES"
  if (( DIFF_FILES <= 1 )) && [[ "$COMPLEXITY" != "major" ]]; then
    COMPLEXITY="simple"
  elif (( DIFF_FILES >= 5 )); then
    COMPLEXITY="major"
  fi
fi

# --- 6. 推荐模式 ---
case "$COMPLEXITY" in
  simple|medium) RECOMMENDED_MODE="standard" ;;
  major)         RECOMMENDED_MODE="full" ;;
  *)             RECOMMENDED_MODE="standard" ;;
esac

# --- 7. 快车道判定（仅简单 + 用户表述代码已实施） ---
FAST_TRACK="false"
if [[ "$COMPLEXITY" == "simple" ]] && \
   echo "$FEEDBACK" | grep -qE "已改|已修复|已实施|改好了|搞定了|已 fix"; then
  FAST_TRACK="true"
fi

# --- 8. 分支建议 ---
BRANCH_ADVICE="继续当前分支"
if [[ "$SCENARIO" == "post-launch" ]]; then
  if [[ -n "$CUR_BRANCH" ]] && ! echo "$CUR_BRANCH" | grep -qE "^bugfix/"; then
    BRANCH_ADVICE="建议切到 bugfix/<≤3单词 kebab-case> 分支（最终分支名由步骤 4 §4.1 定稿）"
  else
    BRANCH_ADVICE="保持 bugfix/ 分支"
  fi
fi

# --- 9. 轮次号 ---
ROUND_NUMBER=$(( WC_ITERATION + 1 ))

# --- 10. 理由 ---
RATIONALE="scenario=${SCENARIO}(status=${WC_STATUS}, task_type=${WC_TASK_TYPE:-N/A}); complexity=${COMPLEXITY} (files=${ESTIMATED_FILES}); mode=${RECOMMENDED_MODE}; fast_track=${FAST_TRACK}"

# --- 输出 JSON ---
cat <<EOF
{
  "scenario": "$SCENARIO",
  "complexity": "$COMPLEXITY",
  "fast_track_enabled": $FAST_TRACK,
  "recommended_mode": "$RECOMMENDED_MODE",
  "round_number": $ROUND_NUMBER,
  "branch_advice": "$BRANCH_ADVICE",
  "estimated_files": $ESTIMATED_FILES,
  "rationale": "$RATIONALE"
}
EOF

# === 输出 schema ===
# {
#   "scenario":           "post-test" | "post-launch" | "not-iteration" | "batch-switch",
#   "complexity":         "simple" | "medium" | "major" | "n/a",
#   "fast_track_enabled": bool,
#   "recommended_mode":   "standard" | "full" | "n/a",
#   "round_number":       int,
#   "branch_advice":      string,    // 自然语言建议（不直接定稿分支名）
#   "estimated_files":    int,
#   "rationale":          string     // 1 句话总结判定依据
# }
