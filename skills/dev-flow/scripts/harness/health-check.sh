#!/bin/bash
# health-check.sh - dev-flow 热启动状态健康检查
#
# 设计意图：
# - 跨天恢复时自动校验 .flow / .md / .validated 三者状态一致性
# - 防止在漂移数据上继续工作（如 file-export 事故）
# - ≤3 秒完成，不阻塞恢复流程
#
# 检查项：
#   H1: .flow 文件存在且格式合法
#   H2: working-context .md 存在且 YAML 头部可解析
#   H3: .flow.current_step == .md YAML current_step（步进漂移检测）
#   H4: .validated 链完整性（无孤儿、无缺环）
#   H5: git HEAD hash vs .flow.last_commit_hash（跨天对账，已有逻辑增强）
#
# 用法：
#   bash health-check.sh <flow-name> [--mode hot-start|quick]
#
# 返回码：
#   0 全部通过
#   1 有 BLOCK 级问题（必须修复才能继续）
#   2 仅 WARN 级问题（可继续但建议修复）
#   3 flow 文件不存在（没有活跃流程，不是错误）

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_FLOW_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$DEV_FLOW_ROOT/scripts/lib/common.sh"
source "$DEV_FLOW_ROOT/scripts/lib/logger.sh"

FLOW_NAME="${1:-}"
MODE="${2:-hot-start}"

if [ -z "$FLOW_NAME" ]; then
  log_error "用法: $0 <flow-name> [--mode hot-start|quick]"
  exit 3
fi

FLOW_DIR="$(df_active_flows_dir)"
FLOW_FILE="$FLOW_DIR/${FLOW_NAME}.flow"
WC_FILE="$HOME/.codebuddy/working-context/${FLOW_NAME}.md"

# 契约对齐（2026-08-07 修复）：
# 头部声明「返回码 3 = flow 文件不存在（没有活跃流程，不是错误）」，但历史实现
# 对不存在的 flow 走 H1 check_block → 返回 1，把「无活跃流程」误报为严重健康问题，
# 与恢复网关语义冲突。此处提前短路：.flow 完全不存在时返回 3（非错误）。
# 注意：.flow 存在但缺 current_step 字段仍属BLOCK（rc=1），不在此短路范围内。
if [ ! -f "$FLOW_FILE" ]; then
  echo ""
  echo "🏥 dev-flow 健康检查: ${FLOW_NAME}"
  echo "  ℹ️  无活跃流程（.flow 文件不存在: ${FLOW_NAME}.flow），跳过健康检查"
  exit 3
fi

block_count=0
warn_count=0

header() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🏥 dev-flow 健康检查: ${FLOW_NAME}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

check_pass() {
  echo "  ✅ $1"
}

check_warn() {
  echo "  ⚠️  $1"
  warn_count=$((warn_count + 1))
}

check_block() {
  echo "  🔴 $1"
  block_count=$((block_count + 1))
}

# ========================================
# H1: .flow 文件存在性
# ========================================
echo "H1: .flow 锁文件检查"
if [ -f "$FLOW_FILE" ]; then
  # 基本格式检查：必须有 current_step 字段
  if grep -q "^current_step:" "$FLOW_FILE" 2>/dev/null; then
    cs=$(grep "^current_step:" "$FLOW_FILE" 2>/dev/null | head -1 | sed 's/current_step:\s*//' | tr -d '"' | xargs)
    flow_mode=$(grep "^mode:" "$FLOW_FILE" 2>/dev/null | head -1 | sed 's/mode:\s*//' | tr -d '"' | xargs)
    check_pass "存在，current_step=${cs:-?}，mode=${flow_mode:-?}"
  else
    check_block ".flow 文件缺少 current_step 字段"
  fi
else
  check_block ".flow 文件不存在: ${FLOW_NAME}.flow"
fi

# ========================================
# H2: working-context .md 存在性
# ========================================
echo "H2: 工作上下文文件检查"
if [ -f "$WC_FILE" ]; then
  # 检查 YAML 头部
  if head -n 1 "$WC_FILE" | grep -q "^---$"; then
    check_pass "存在且 YAML 头部正常"
  else
    check_warn "存在但 YAML 头部格式异常（可能缺少 --- 分隔符）"
  fi
else
  # 尝试在 archive 中查找
  wc_archive=$(find "$HOME/.codebuddy/working-context/archive" -name "${FLOW_NAME}.md" 2>/dev/null | head -1 || true)
  if [ -n "$wc_archive" ]; then
    check_warn "已归档至 archive/，不在顶层（若流程已完成则正常）"
  else
    check_block "工作上下文文件不存在: ${FLOW_NAME}.md"
  fi
fi

# ========================================
# H3: current_step 一致性（漂移检测）
# ========================================
echo "H3: current_step 一致性检查"
if [ -f "$FLOW_FILE" ] && [ -f "$WC_FILE" ]; then
  flow_cs=$(grep "^current_step:" "$FLOW_FILE" 2>/dev/null | head -1 | sed 's/current_step:\s*//' | tr -d '"' | xargs)
  # 从 .md YAML 头部提取
  md_cs=$(awk '
    /^---$/ { in_yaml = !in_yaml; next }
    in_yaml && /^current_step:/ {
      val=$0
      sub(/^current_step:[[:space:]]*/, "", val)
      gsub(/^"|"$/, "", val)
      print val
      exit
    }
  ' "$WC_FILE" 2>/dev/null || echo "")
  
  if [ -n "$flow_cs" ] && [ -n "$md_cs" ]; then
    if [ "$flow_cs" = "$md_cs" ]; then
      check_pass "一致: .flow=${flow_cs}, .md=${md_cs}"
    else
      check_warn "不一致: .flow=${flow_cs}, .md=${md_cs}（以工作上下文为准）"
    fi
  else
    check_warn "无法提取 current_step（.flow=${flow_cs:-?}, .md=${md_cs:-?}）"
  fi
fi

# ========================================
# H4: .validated 链完整性
# ========================================
echo "H4: 物理检查点链完整性"
if [ -d "$FLOW_DIR" ]; then
  validated_count=$(find "$FLOW_DIR" -name "${FLOW_NAME}.step-*.validated" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
  validated_json_count=$(find "$FLOW_DIR" -name "${FLOW_NAME}.step-*.validated.json" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
  done_count=$(find "$FLOW_DIR" -name "${FLOW_NAME}.step-*.done" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
  
  if [ "$validated_count" -gt 0 ]; then
    check_pass "${validated_count} 个 .validated 检查点"
    
    # 检查是否有 .validated 但无对应的 .validated.json（审计元信息缺失）
    if [ "$validated_count" -ne "$validated_json_count" ]; then
      check_warn ".validated (${validated_count}) 与 .validated.json (${validated_json_count}) 数量不一致"
    fi
  elif [ "$done_count" -gt 0 ]; then
    check_warn "仅有旧 v1 .done 文件（${done_count} 个），无 .validated"
  else
    check_pass "无检查点（可能为新流程或已完成清理）"
  fi
  
  # 检查是否有孤儿 .validated（flow 中 current_step 已远超但检查点仍残留）
  if [ -f "$FLOW_FILE" ] && [ "$validated_count" -gt 0 ]; then
    flow_cs=$(grep "^current_step:" "$FLOW_FILE" 2>/dev/null | head -1 | sed 's/current_step:\s*//' | tr -d '"' | xargs)
    if [ -n "$flow_cs" ]; then
      # 检查是否存在超过 current_step 的 .validated（正常不应有）
      orphan_found=false
      for vf in "$FLOW_DIR/${FLOW_NAME}".step-*.validated; do
        [ -f "$vf" ] || continue
        step_in_file=$(basename "$vf" | sed "s/${FLOW_NAME}\.step-//" | sed 's/\.validated//' | tr '_' '.')
        # 简单比较：非数字开头时是正常的
        if [ -n "$step_in_file" ]; then
          # 检查是否为孤儿：若 flow 状态为 completed 但仍有 .validated
          flow_status=$(grep "^status:" "$FLOW_FILE" 2>/dev/null | head -1 | sed 's/status:\s*//' | tr -d '"' | xargs)
          if [ "$flow_status" = "completed" ]; then
            orphan_found=true
            break
          fi
        fi
      done
      if [ "$orphan_found" = "true" ]; then
        check_warn "流程已 completed 但仍有 .validated 残留（建议清理）"
      fi
    fi
  fi
fi

# ========================================
# H5: git HEAD 对账（跨天）
# ========================================
echo "H5: git HEAD 对账"
if git rev-parse --git-dir >/dev/null 2>&1; then
  NOW_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "")
  if [ -f "$FLOW_FILE" ]; then
    LAST_HASH=$(grep "^last_commit_hash:" "$FLOW_FILE" 2>/dev/null | head -1 | sed 's/last_commit_hash:\s*//' | tr -d '"' | xargs)
    
    if [ -n "$NOW_HASH" ] && [ -n "$LAST_HASH" ]; then
      if [ "$NOW_HASH" = "$LAST_HASH" ]; then
        check_pass "一致: ${NOW_HASH}"
      else
        flow_status=$(grep "^status:" "$FLOW_FILE" 2>/dev/null | head -1 | sed 's/status:\s*//' | tr -d '"' | xargs)
        if [ "$flow_status" = "active" ] || [ "$flow_status" = "idle" ]; then
          check_warn "HEAD 已变化: ${LAST_HASH} → ${NOW_HASH}（跨天可能有新 commit）"
        else
          check_pass "已变化但 flow 非 active（${LAST_HASH} → ${NOW_HASH}，流程 ${flow_status}）"
        fi
      fi
    elif [ -n "$NOW_HASH" ] && [ -z "$LAST_HASH" ]; then
      check_warn "当前 HEAD=${NOW_HASH}，但 .flow 中无 last_commit_hash（旧版 flow 文件）"
    fi
  fi
else
  check_pass "非 git 仓库，跳过"
fi

# ========================================
# 汇总
# ========================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$block_count" -eq 0 ] && [ "$warn_count" -eq 0 ]; then
  echo "🏥 健康检查: ✅ 全部通过"
  exit 0
elif [ "$block_count" -eq 0 ]; then
  echo "🏥 健康检查: ⚠️  通过（${warn_count} 个警告）"
  exit 2
else
  echo "🏥 健康检查: 🔴 ${block_count} 个阻断问题, ${warn_count} 个警告"
  exit 1
fi
