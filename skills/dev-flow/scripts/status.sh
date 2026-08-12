#!/bin/bash
# dev-flow 工作上下文状态查看器
#
# 用法:
#   status.sh              # 活跃需求清单（等同 dev:status）
#   status.sh --trace      # 当前需求实时观测（Token/红牌/步骤耗时）
#   status.sh --all        # 含暂停/完成的全部需求
#   status.sh --token      # 仅显示 Token 消耗估算
#
# 数据源：
#   ~/.codebuddy/working-context/.active-flows/*.flow  → 活跃流程
#   ~/.codebuddy/working-context/*.md                  → 工作上下文
#   ~/.codebuddy/working-context/.active-flows/*.validated  → 物理检查点（v2，由 validate-output.sh 创建）
#   ~/.codebuddy/working-context/.active-flows/*.done  → 物理检查点（v1 兼容）

WC_DIR="$HOME/.codebuddy/working-context"
ACTIVE_DIR="$WC_DIR/.active-flows"
MODE="${1:-}"

# ─── 颜色定义 ───────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

# ─── 工具函数 ────────────────────────────────────────────────────────────────
step_emoji() {
  case "$1" in
    0|0.5) echo "🔍" ;; 1) echo "🔬" ;; 2) echo "📋" ;; 3) echo "📐" ;;
    4|4.5) echo "🤔" ;; 5) echo "⚙️ " ;; 5.5) echo "🔎" ;; 6) echo "✅" ;;
    7) echo "📦" ;; 8) echo "🔍" ;; 9) echo "💡" ;; 10) echo "🎉" ;;
    *) echo "📌" ;;
  esac
}

step_name() {
  case "$1" in
    0) echo "需求理解" ;; 0.5) echo "项目画像" ;; 1) echo "研究与定位" ;;
    2) echo "确认范围" ;; 3) echo "制定方案" ;; 4) echo "方案决策" ;;
    4.5) echo "环境检查" ;; 5) echo "执行修改" ;; 5.5) echo "编码后置" ;;
    6) echo "质量验证" ;; 7) echo "清理+Commit" ;; 8) echo "L3审查" ;;
    9) echo "反思学习" ;; 10) echo "归档交付" ;; *) echo "步骤$1" ;;
  esac
}

# ─── 读取 .flow 文件字段 ─────────────────────────────────────────────────────
get_flow_field() {
  local file="$1" field="$2"
  grep "^${field}:" "$file" 2>/dev/null | head -1 | sed "s/^${field}:[[:space:]]*//"
}

# ─── 计算时间差（分钟）──────────────────────────────────────────────────────
minutes_since() {
  local ts="$1"
  if [ -z "$ts" ]; then echo "?"; return; fi
  local now
  now=$(date +%s)
  local then
  then=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$ts" +%s 2>/dev/null || echo "$now")
  echo $(( (now - then) / 60 ))
}

# ─── 主逻辑：活跃需求清单 ────────────────────────────────────────────────────
show_active() {
  echo -e "${BOLD}${CYAN}📍 dev-flow 工作上下文状态${RESET}"
  echo "────────────────────────────────────────"

  if [ ! -d "$ACTIVE_DIR" ] || [ -z "$(ls "$ACTIVE_DIR"/*.flow 2>/dev/null)" ]; then
    echo -e "${GREEN}✅ 无活跃流程${RESET}"
    echo ""
  else
    echo -e "${BOLD}活跃需求：${RESET}"
    for flow_file in "$ACTIVE_DIR"/*.flow; do
      [ -f "$flow_file" ] || continue
      local name brief step mode last_active
      name=$(basename "$flow_file" .flow)
      brief=$(get_flow_field "$flow_file" "brief")
      step=$(get_flow_field "$flow_file" "current_step")
      mode=$(get_flow_field "$flow_file" "mode")
      last_active=$(get_flow_field "$flow_file" "updated_at")
      local mins
      mins=$(minutes_since "$last_active")
      local emoji
      emoji=$(step_emoji "$step")
      local step_n
      step_n=$(step_name "$step")
      echo -e "  ${emoji} ${BOLD}${brief:-$name}${RESET}"
      echo -e "     步骤 ${step}（${step_n}）| 模式: ${mode:-standard} | 最后活跃: ${mins}min 前"
      echo -e "     文件: ${name}.flow"
    done
    echo ""
  fi

  # 最近完成的需求（最近3个）
  if [ -d "$WC_DIR" ]; then
    local completed
    completed=$(ls -t "$WC_DIR"/*.md 2>/dev/null | head -3)
    if [ -n "$completed" ]; then
      echo -e "${BOLD}最近完成：${RESET}"
      while IFS= read -r f; do
        local fname
        fname=$(basename "$f" .md)
        local mtime
        mtime=$(stat -f "%Sm" -t "%m-%d %H:%M" "$f" 2>/dev/null || echo "?")
        echo -e "  ✅ ${fname} (${mtime})"
      done <<< "$completed"
    fi
  fi
}

# ─── --trace 模式：实时观测 ──────────────────────────────────────────────────
show_trace() {
  echo -e "${BOLD}${CYAN}🔭 dev-flow 实时观测（--trace）${RESET}"
  echo "────────────────────────────────────────"

  if [ ! -d "$ACTIVE_DIR" ] || [ -z "$(ls "$ACTIVE_DIR"/*.flow 2>/dev/null)" ]; then
    echo -e "${YELLOW}⚠️  无活跃流程，无法展示 trace${RESET}"
    echo "   请先触发 dev-flow 开始一个需求"
    exit 0
  fi

  # 取最近活跃的 .flow
  local flow_file
  flow_file=$(ls -t "$ACTIVE_DIR"/*.flow 2>/dev/null | head -1)
  local name brief step mode start_time
  name=$(basename "$flow_file" .flow)
  brief=$(get_flow_field "$flow_file" "brief")
  step=$(get_flow_field "$flow_file" "current_step")
  mode=$(get_flow_field "$flow_file" "mode")
  start_time=$(get_flow_field "$flow_file" "created_at")

  echo -e "${BOLD}当前需求：${brief:-$name}${RESET}"
  echo -e "模式: ${mode:-standard} | 当前步骤: $(step_emoji "$step") 步骤${step}（$(step_name "$step")）"
  echo ""

  # 已完成步骤（优先扫描 .validated v2 检查点，兼容扫描 .done v1 检查点）
  local done_steps=()
  # v2：.validated 文件（由 validate-output.sh 创建，含 Schema 校验证据）
  for validated_file in "$ACTIVE_DIR/${name}".step-*.validated; do
    [ -f "$validated_file" ] || continue
    local s
    s=$(basename "$validated_file" .validated | sed "s/${name}.step-//")
    # step_slug 反向规范化：4_5 → 4.5（仅当最后一段是数字时恢复）
    s=$(echo "$s" | sed -E 's/^([0-9]+)_([0-9]+)$/\1.\2/')
    done_steps+=("$s")
  done
  # v1 兼容：.done 文件（若 .validated 不存在但 .done 存在，仍计入已完成）
  for done_file in "$ACTIVE_DIR/${name}".step-*.done; do
    [ -f "$done_file" ] || continue
    local s
    s=$(basename "$done_file" .done | sed "s/${name}.step-//")
    # 去重：已有 .validated 的步骤不重复计入
    local already=false
    for ds in "${done_steps[@]}"; do
      [ "$ds" = "$s" ] && already=true && break
    done
    $already || done_steps+=("$s")
  done

  echo -e "${BOLD}步骤完成情况：${RESET}"
  for s in 0 0.5 1 2 3 4 4.5 5 5.5 6 7; do
    local found=false
    for ds in "${done_steps[@]}"; do
      [ "$ds" = "$s" ] && found=true && break
    done
    if [ "$s" = "$step" ]; then
      echo -e "  🔄 步骤${s}（$(step_name "$s")）← 当前"
    elif $found; then
      echo -e "  ✅ 步骤${s}（$(step_name "$s")）"
    fi
  done
  echo ""

  # Token 消耗估算（基于已加载步骤数）
  local done_count=${#done_steps[@]}
  local base_tokens=8000  # 精简后的 SKILL.md + flow.md + step-router.md
  local per_step=3500
  local total_est=$(( base_tokens + done_count * per_step ))
  local pct=$(( total_est * 100 / 200000 ))
  echo -e "${BOLD}Token 消耗估算：${RESET}"
  echo -e "  启动基线: ~8,000 tokens（精简后）"
  echo -e "  已完成步骤: ${done_count} 步 × ~3,500 = ~$(( done_count * per_step )) tokens"
  echo -e "  累计估算: ~${total_est} tokens（约 ${pct}% / 200k 窗口）"
  echo ""

  # 红牌记录（从 .learnings/ERRORS.md 中查找）
  local errors_file="$HOME/.codebuddy/.learnings/ERRORS.md"
  if [ -f "$errors_file" ]; then
    local red_count
    red_count=$(grep -c "红牌\|red_card\|⚠️ 红牌" "$errors_file" 2>/dev/null || echo 0)
    echo -e "${BOLD}红牌记录（历史）：${RESET}"
    echo -e "  历史红牌触发次数: ${red_count}"
    echo -e "  详情: ~/.codebuddy/.learnings/ERRORS.md"
    echo ""
  fi

  # 已加载的 reference 文件（从 .flow 文件读取）
  local loaded_refs
  loaded_refs=$(get_flow_field "$flow_file" "loaded_refs")
  if [ -n "$loaded_refs" ]; then
    echo -e "${BOLD}已加载 reference：${RESET}"
    echo "  $loaded_refs"
    echo ""
  fi

  echo -e "${BOLD}下一步提示：${RESET}"
  echo -e "  完成步骤 ${step}（$(step_name "$step")）→ 输出完成标记 JSON → 门控验证 → 步骤 $((${step%.*} + 1))"
}

# ─── --token 模式 ────────────────────────────────────────────────────────────
show_token() {
  echo -e "${BOLD}${CYAN}💰 Token 消耗估算${RESET}"
  echo "────────────────────────────────────────"
  echo -e "  精简后启动基线: ~8,000 tokens（SKILL.md + flow.md + step-router.md）"
  echo -e "  原始启动基线:   ~19,000 tokens（P0 优化前）"
  echo -e "  节省:           ~11,000 tokens（-58%）"
  echo ""
  echo -e "  每步骤加载:     ~3,500 tokens"
  echo -e "  完整执行(10步): ~43,000 tokens（估算）"
  echo -e "  200k 窗口使用:  ~21.5%"
}

# ─── 入口 ────────────────────────────────────────────────────────────────────
case "$MODE" in
  --trace|-t)  show_trace ;;
  --token)     show_token ;;
  --all|-a)    show_active ;;  # TODO: 扩展为含暂停/完成
  *)           show_active ;;
esac
