#!/bin/bash
# token-estimate.sh - dev-flow Token/模型消耗估算
#
# 设计意图：
#   IDE 不暴露原始 token 计数 API，通过 heuristic 估算：
#   - 每个步骤平均 token = 步骤基础值 + 子 agent 调用加成
#   - 模型信息从 .flow.last_model 读取
#   - 子 agent 模型从 agents/ 定义文件读取
#
# 用法：
#   bash token-estimate.sh <flow-name>
#   输出：单行 JSON，供 post-step.sh 追加到完成标记
#
#   也可单独使用子命令：
#   bash token-estimate.sh --model <flow-name>
#   bash token-estimate.sh --step-estimate <step-id>

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_FLOW_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$DEV_FLOW_ROOT/scripts/lib/common.sh"

ACTION="${1:-}"
ARG2="${2:-}"

# 步骤基础 token 估算表（无子 agent 时的基础值）
step_baseline() {
  case "$1" in
    0)    echo 3000 ;;   # 需求理解
    1)    echo 5000 ;;   # 研究定位（含知识检索）
    2)    echo 2500 ;;   # 确认范围
    3)    echo 3000 ;;   # 制定方案
    4)    echo 4000 ;;   # 决策（含 doc_platform 探测）
    4.5|4_5) echo 1500 ;; # 环境检查
    5)    echo 6000 ;;   # 编码执行
    5.5|5_5) echo 3000 ;; # 编码后置（不含子 agent）
    6)    echo 4000 ;;   # 质量验证（不含子 agent）
    7|7-standard|7_standard) echo 5000 ;;  # L2+commit+devlog（不含子 agent）
    8)    echo 4000 ;;   # L3 审查（不含子 agent）
    9)    echo 2000 ;;   # 反思
    10)   echo 2000 ;;   # 归档
    *)    echo 2000 ;;
  esac
}

# 子 agent 调用加成
subagent_bonus() {
  case "$1" in
    5.5|5_5)  echo 5000 ;;    # 2号+5号 L1 审查
    7|7-standard|7_standard) echo 8000 ;;  # 2号+5号+6号 L2 审查
    6)        echo 2000 ;;    # 1号 V7 调用方追踪
    8)        echo 8000 ;;    # 2号+5号+6号 L3 审查
    *)        echo 0 ;;
  esac
}

# 提取模型信息
get_model() {
  local flow_file="$HOME/.codebuddy/working-context/.active-flows/${1}.flow"
  if [ -f "$flow_file" ]; then
    grep "^last_model:" "$flow_file" 2>/dev/null | head -1 | sed 's/last_model:\s*//' | tr -d '"' | xargs
  else
    echo "unknown"
  fi
}

# 提取子 agent 模型
get_agent_models() {
  local agents_dir="$HOME/.codebuddy/agents"
  local result=""
  if [ -d "$agents_dir" ]; then
    for af in "$agents_dir"/*.md; do
      [ -f "$af" ] || continue
      local name model
      name=$(head -n 10 "$af" | grep "^name:" | head -1 | sed 's/name:\s*//' | tr -d '"' | xargs)
      model=$(head -n 10 "$af" | grep "^model:" | head -1 | sed 's/model:\s*//' | tr -d '"' | xargs)
      if [ -n "$name" ] && [ -n "$model" ]; then
        result="${result:+${result},}\"${name}\":\"${model}\""
      fi
    done
  fi
  echo "{$result}"
}

# 估算全流程 token
estimate_flow() {
  local flow_name="$1"
  local artifacts_dir="$HOME/.codebuddy/dev-flow-artifacts/${flow_name}"
  local total=0
  local steps_json=""
  local comma=""
  local model
  
  model=$(get_model "$flow_name")
  
  if [ -d "$artifacts_dir" ]; then
    for json_file in "$artifacts_dir"/step-*.json; do
      [ -f "$json_file" ] || continue
      local sid sname
      sname=$(basename "$json_file" .json)
      sid=$(echo "$sname" | sed 's/^step-//' | tr '_' '.')
      
      local base bonus step_total
      base=$(step_baseline "$sid")
      bonus=$(subagent_bonus "$sid")
      step_total=$((base + bonus))
      
      steps_json="${steps_json}${comma}{\"step\":\"${sid}\",\"est_tokens\":${step_total}}"
      comma=","
      total=$((total + step_total))
    done
  fi
  
  local agent_models
  agent_models=$(get_agent_models)
  
  echo "{\"total_est_tokens\":${total},\"model\":\"${model}\",\"agent_models\":${agent_models},\"steps\":[${steps_json}]}"
}

case "$ACTION" in
  --model)
    get_model "$ARG2"
    ;;
  --step-estimate)
    local base bonus
    base=$(step_baseline "$ARG2")
    bonus=$(subagent_bonus "$ARG2")
    echo $((base + bonus))
    ;;
  *)
    if [ -n "$ACTION" ]; then
      estimate_flow "$ACTION"
    else
      echo '{"error":"missing flow-name"}'
      exit 2
    fi
    ;;
esac
