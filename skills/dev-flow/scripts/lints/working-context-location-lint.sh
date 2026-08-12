#!/usr/bin/env bash
# working-context-location-lint.sh — 工作上下文位置/状态完整性 lint
#
# 规范反向引用：
#   - gates.yaml §lints.working-context-location-lint
#   - rules/AI行为规范.mdc §「验证行为规范 > 编辑工具假性成功兜底」
#   - skills/dev-flow/references/working-context.md §九「目录结构禁令」（权威源）
#   - skills/dev-flow/references/active-flows.md §锁文件维护规则
#
# 设计哲学：
#   「确定性用代码，模糊性用 LLM」
#   工作上下文 .md 应该在哪、状态应该是什么、流程结束后应该清理哪些残留 = 物理事实 → 用脚本强制
#
# 设计动机（2026-06-02 事故根因）：
#   有人/Agent 在 `status: completed` 后手动 `mv ~/.codebuddy/working-context/<slug>.md archive/`，
#   但 dev-flow 规范从未支持自动归档 .md。所有 lint 假设 .md 在顶层。
#   误归档发生后所有现有 lint 静默通过（`-f` 检查跳过），事故只能靠 dashboard 显示 ARCHIVED 角标暴露。
#
# 用法：
#   bash working-context-location-lint.sh <flow-name>           # 单需求模式
#   bash working-context-location-lint.sh --all                 # 全量扫描模式（doctor 体检用）
#   bash working-context-location-lint.sh --help
#
# 检查项（4 项）：
#   L1 [block]  位置完整性：<flow-name>.md 必须在顶层 working-context/，不在 archive/
#   L2 [warn]   状态一致性：.md 头部 status 应与 .flow 文件 status 一致（仅 .flow 存在时）
#   L3 [block]  残留检测：流程结束后（.flow 已删 + step-N.validated 存在），.active-flows/<slug>.* 不应有残留
#   L4 [block]  archive 检测：archive/ 子目录不应存在 .md 文件（dev-flow 不归档 .md，仅 --all 模式触发）
#
# 退出码：
#   0 = 全部通过
#   1 = 至少一项 block 失败
#   2 = 仅 warn（不阻塞，建议修复）
#   3 = 参数错误
#
set -u

# ========== 参数解析 ==========
FLOW_NAME=""
SCAN_ALL=0

show_help() {
  sed -n '2,42p' "$0"
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    --all)
      SCAN_ALL=1
      ;;
    -h|--help)
      show_help
      ;;
    -*)
      echo "❌ 未知参数: $1" >&2
      exit 3
      ;;
    *)
      FLOW_NAME="$1"
      ;;
  esac
  shift
done

if [ "$SCAN_ALL" -eq 0 ] && [ -z "$FLOW_NAME" ]; then
  echo "❌ 必须传入 <flow-name> 或 --all" >&2
  echo "   用法: bash $0 <flow-name>     # 校验单个流程" >&2
  echo "         bash $0 --all           # 全量扫描" >&2
  exit 3
fi

WC_DIR="${HOME}/.codebuddy/working-context"
ARCHIVE_DIR="${WC_DIR}/archive"
ACTIVE_DIR="${WC_DIR}/.active-flows"

ERRORS=0
WARNS=0

# ========== L1：位置完整性（block） ==========
check_l1_location() {
  local flow="$1"
  local wc_top="${WC_DIR}/${flow}.md"

  if [ -f "$wc_top" ]; then
    return 0  # 顶层存在即通过
  fi

  # 顶层不存在 → 检查是否在 archive 子目录
  if [ -d "$ARCHIVE_DIR" ]; then
    local archived_path
    archived_path=$(find "$ARCHIVE_DIR" -type f -name "${flow}.md" 2>/dev/null | head -1)
    if [ -n "$archived_path" ]; then
      echo "❌ [L1] 位置完整性失败: ${flow}.md 被错误移动到 archive/"
      echo "   期望: $wc_top"
      echo "   实际: $archived_path"
      echo "   ⚠️  dev-flow 不存在自动归档机制（skills/dev-flow/references/working-context.md §九「目录结构禁令」）"
      echo "   修复: mv \"$archived_path\" \"$wc_top\""
      ERRORS=$((ERRORS + 1))
      return 1
    fi
  fi

  # 顶层和 archive 都没有：可能是新流程未创建 .md，给 warn 而非 error
  # （--all 模式下不报，单 flow 模式下警告）
  if [ "$SCAN_ALL" -eq 0 ]; then
    echo "⚠️  [L1] 工作上下文 .md 不存在: $wc_top"
    WARNS=$((WARNS + 1))
  fi
  return 2
}

# ========== L2：状态一致性（warn） ==========
# 仅当顶层 .md 存在 + .flow 存在时才校验
check_l2_status_consistency() {
  local flow="$1"
  local wc_top="${WC_DIR}/${flow}.md"
  local flow_file="${ACTIVE_DIR}/${flow}.flow"

  [ -f "$wc_top" ] || return 0
  [ -f "$flow_file" ] || return 0

  # 提取 .md 头部 status（YAML 头部 frontmatter 范围内首个顶级 status: 字段）
  local md_status
  md_status=$(awk '
    BEGIN { in_fm=0; depth=0 }
    /^---[[:space:]]*$/ { if (in_fm==0) { in_fm=1; next } else { exit } }
    in_fm==1 && /^status:/ { val=$0; sub(/^status:[[:space:]]*/, "", val); gsub(/^"|"$|^'\''|'\''$/, "", val); print val; exit }
  ' "$wc_top" 2>/dev/null | head -1)

  # 提取 .flow status（YAML 顶级 status: 字段）
  local flow_status
  flow_status=$(awk '
    /^status:/ { val=$0; sub(/^status:[[:space:]]*/, "", val); gsub(/^"|"$|^'\''|'\''$/, "", val); print val; exit }
  ' "$flow_file" 2>/dev/null | head -1)

  [ -z "$md_status" ] && return 0
  [ -z "$flow_status" ] && return 0

  # status 取值范围不同：.md 用 in_progress/completed/...，.flow 用 active/idle/completed/blocked-...
  # 仅检测明显矛盾：.flow=completed 但 .md=in_progress
  if [ "$flow_status" = "completed" ] && [ "$md_status" = "in_progress" ]; then
    echo "⚠️  [L2] 状态一致性: .flow 已 completed 但 .md 仍 in_progress"
    echo "   ${flow_file}: status=$flow_status"
    echo "   ${wc_top}: status=$md_status"
    echo "   修复: 将 .md 头部 status 改为 completed（流程已完成应同步状态）"
    WARNS=$((WARNS + 1))
    return 2
  fi
  return 0
}

# ========== L3：残留检测（block） ==========
# 触发条件：.flow 已删（流程已结束）但 .active-flows/<slug>.* 仍有残留 → 违反 active-flows.md L97
check_l3_leftover() {
  local flow="$1"
  local flow_file="${ACTIVE_DIR}/${flow}.flow"

  # .flow 仍存在 → 流程未结束，残留是合法的
  [ ! -f "$flow_file" ] || return 0

  # .flow 不存在 → 检查 .active-flows/<flow>.* 残留
  [ -d "$ACTIVE_DIR" ] || return 0

  # 寻找该 flow 的 .validated / .validated.json / .done 等残留
  local leftovers=()
  while IFS= read -r f; do
    [ -n "$f" ] && leftovers+=("$f")
  done < <(find "$ACTIVE_DIR" -maxdepth 1 -type f \( -name "${flow}.step-*.validated*" -o -name "${flow}.step-*.done" \) 2>/dev/null)

  # 寻找该 flow 的 .breaker/ 熔断目录残留（2026-07-17 补充：post-step.sh §7 已清理它，
  # 但 L3 lint 历史上漏检了目录类型，导致 .breaker/ 孤儿无人发现）
  if [ -d "$ACTIVE_DIR/${flow}.breaker" ]; then
    leftovers+=("$ACTIVE_DIR/${flow}.breaker/")
  fi

  # 注：不做"短名 fuzzy 匹配"。历史上有 `sdk-brand-rename.step-7_standard.validated` 这种
  # 不带日期前缀的命名，但 fuzzy 容易把两个独立流程的残留误算到一起，宁可漏报不可误报。
  # 这类不规范命名的残留，由 --all 全量扫描结合 L4 孤儿检测 / 用户手动清理。

  if [ "${#leftovers[@]}" -gt 0 ]; then
    echo "❌ [L3] 残留检测失败: 流程已结束（.flow 已删）但 .active-flows/ 仍有残留"
    for f in "${leftovers[@]}"; do
      echo "   残留: $f"
    done
    echo "   规范: skills/dev-flow/references/active-flows.md §锁文件维护规则"
    echo "   修复: rm -f ${leftovers[*]}"
    ERRORS=$((ERRORS + 1))
    return 1
  fi
  return 0
}

# ========== L4：archive/ 中的 .md 文件（block，全量模式） ==========
# 说明：dev-flow 不存在自动归档机制（详见 references/working-context.md §九「目录结构禁令」），
# archive/ 子目录里出现 .md 文件本身就是违规，无论是否对应活跃需求都应 block。
# 这与单流程模式下的 L1 检查互补：L1 只能检查"已知 flow_name 的文件位置"，
# L4 兜底捕获"未知 flow_name 但物理存在于 archive 的 .md"（如孤儿、误命名、历史残留）。
check_l4_archived_md() {
  [ -d "$ARCHIVE_DIR" ] || return 0

  local orphans=()
  while IFS= read -r f; do
    [ -n "$f" ] && orphans+=("$f")
  done < <(find "$ARCHIVE_DIR" -type f -name "*.md" 2>/dev/null)

  if [ "${#orphans[@]}" -gt 0 ]; then
    echo "❌ [L4] archive/ 子目录存在 .md 文件（${#orphans[@]} 个）"
    echo "   ⚠️  dev-flow 不存在自动归档机制，archive/ 不应存在任何 .md"
    for f in "${orphans[@]}"; do
      echo "   违规: $f"
    done
    echo "   修复: 将 .md 文件 mv 回顶层 working-context/，或确认无用后删除"
    ERRORS=$((ERRORS + 1))
    return 1
  fi
  return 0
}

# ========== 主流程 ==========

if [ "$SCAN_ALL" -eq 1 ]; then
  echo "🔍 工作上下文位置完整性体检（全量扫描模式）"
  echo "   扫描目录: $WC_DIR"
  echo ""

  # 全量扫描：遍历顶层所有 .md（除 README）+ archive 中孤儿 + .active-flows 残留
  for md in "$WC_DIR"/*.md; do
    [ -f "$md" ] || continue
    name=$(basename "$md" .md)
    [ "$(echo "$name" | tr '[:upper:]' '[:lower:]')" = "readme" ] && continue
    check_l2_status_consistency "$name"
    check_l3_leftover "$name"
  done

  # archive/ 中的 .md 是违规（dev-flow 不归档 .md），block 级
  check_l4_archived_md

  # 全量模式补：扫描所有 .flow 中提到的 flow_name 是否在顶层有 .md
  if [ -d "$ACTIVE_DIR" ]; then
    for flow_file in "$ACTIVE_DIR"/*.flow; do
      [ -f "$flow_file" ] || continue
      flow_name=$(basename "$flow_file" .flow)
      check_l1_location "$flow_name"
    done
  fi
else
  # 单流程模式：跑 L1 + L2 + L3（L4 全局级，单流程不跑）
  check_l1_location "$FLOW_NAME"
  check_l2_status_consistency "$FLOW_NAME"
  check_l3_leftover "$FLOW_NAME"
fi

# ========== 汇总 ==========
echo ""
if [ "$ERRORS" -gt 0 ]; then
  echo "❌ 失败: $ERRORS 项 block 错误，$WARNS 项 warn 警告"
  exit 1
elif [ "$WARNS" -gt 0 ]; then
  echo "⚠️  通过（含警告）: 0 项 block 错误，$WARNS 项 warn 警告"
  exit 2
else
  echo "✅ 全部通过"
  exit 0
fi
