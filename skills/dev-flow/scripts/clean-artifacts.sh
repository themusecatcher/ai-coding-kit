#!/bin/bash
# ============================================================
# clean-artifacts.sh - 清理 dev-flow 产物归档
#
# 用法:
#   bash clean-artifacts.sh              # 清理 14 天前已完成的流程产物
#   bash clean-artifacts.sh --all        # 清理全部产物
#   bash clean-artifacts.sh --list       # 列出当前归档
#   bash clean-artifacts.sh --days 7     # 自定义过期天数
#
# 存储位置: ~/.codebuddy/dev-flow-artifacts/{flow-name}/
# ============================================================

set -u

ARTIFACT_ROOT="$HOME/.codebuddy/dev-flow-artifacts"
TTL_DAYS=14
ACTION="clean"

# 参数解析
while [ $# -gt 0 ]; do
  case "$1" in
    --all)   ACTION="clean_all" ;;
    --list)  ACTION="list" ;;
    --days)  TTL_DAYS="$2"; shift ;;
    --help|-h)
      echo "用法: bash clean-artifacts.sh [--all | --list | --days N]"
      echo ""
      echo "选项:"
      echo "  (无参数)     清理 ${TTL_DAYS} 天前的产物"
      echo "  --all       清理全部产物"
      echo "  --list      列出当前归档"
      echo "  --days N    自定义过期天数（默认 14）"
      exit 0
      ;;
    *) echo "❌ 未知参数: $1"; exit 1 ;;
  esac
  shift
done

# ==================== 列出归档 ====================

do_list() {
  if [ ! -d "$ARTIFACT_ROOT" ]; then
    echo "📁 无产物归档目录"
    return
  fi

  local count=0
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  📦 dev-flow 产物归档"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  for dir in "$ARTIFACT_ROOT"/*/; do
    [ -d "$dir" ] || continue
    count=$((count + 1))
    local flow_name
    flow_name=$(basename "$dir")
    local file_count
    file_count=$(find "$dir" -name "*.json" | wc -l | tr -d ' ')
    local last_modified
    last_modified=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$dir" 2>/dev/null || stat -c "%y" "$dir" 2>/dev/null | cut -d. -f1)
    echo "  📂 $flow_name"
    echo "     文件: ${file_count} 个 JSON | 最后修改: $last_modified"
    # 列出步骤文件
    find "$dir" -name "step-*.json" -exec basename {} \; 2>/dev/null | sort | sed 's/^/     ├── /'
    echo ""
  done

  if [ $count -eq 0 ]; then
    echo "  (空)"
  fi

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  共 $count 个流程归档"
  local total_size
  total_size=$(du -sh "$ARTIFACT_ROOT" 2>/dev/null | cut -f1)
  echo "  磁盘占用: ${total_size:-0}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

# ==================== 清理过期 ====================

do_clean() {
  if [ ! -d "$ARTIFACT_ROOT" ]; then
    echo "✅ 无产物需清理"
    return
  fi

  local cleaned=0
  local kept=0

  # 查找超过 TTL 天数的目录
  while IFS= read -r dir; do
    [ -d "$dir" ] || continue
    local flow_name
    flow_name=$(basename "$dir")
    rm -rf "$dir"
    echo "🗑  已清理: $flow_name"
    cleaned=$((cleaned + 1))
  done < <(find "$ARTIFACT_ROOT" -maxdepth 1 -type d -not -path "$ARTIFACT_ROOT" -mtime +$TTL_DAYS 2>/dev/null)

  # 统计保留的
  kept=$(find "$ARTIFACT_ROOT" -maxdepth 1 -type d -not -path "$ARTIFACT_ROOT" 2>/dev/null | wc -l | tr -d ' ')

  echo ""
  echo "✅ 清理完成: 移除 $cleaned 个，保留 $kept 个（TTL=${TTL_DAYS}天）"
}

# ==================== 清理全部 ====================

do_clean_all() {
  if [ ! -d "$ARTIFACT_ROOT" ]; then
    echo "✅ 无产物需清理"
    return
  fi

  local count
  count=$(find "$ARTIFACT_ROOT" -maxdepth 1 -type d -not -path "$ARTIFACT_ROOT" 2>/dev/null | wc -l | tr -d ' ')

  rm -rf "$ARTIFACT_ROOT"
  echo "✅ 已清理全部产物（共 $count 个流程归档）"
}

# ==================== 主逻辑 ====================

case "$ACTION" in
  list)      do_list ;;
  clean)     do_clean ;;
  clean_all) do_clean_all ;;
esac
