#!/usr/bin/env bash
# devlog-integrity-lint.sh — dev-logs/ 目录完整性 lint
#
# 规范反向引用：
#   - 本脚本是 P1（步骤 7 §K）的实现 → references/gate-validator.md §「dev-logs 物理事实兜底（P0/P1 闭环）」 §P1
#   - 步骤接入点 → steps/step-7-commit.md §K「dev-logs 完整性自检（收尾兜底，物理事实）」
#   - 与 P0 互补 → scripts/validate-output.sh step4 分支「物理事实兜底」（点级 vs 面级）
#
# 用法：
#   bash devlog-integrity-lint.sh                  # 扫描 ~/.codebuddy/dev-logs/，输出报告
#   bash devlog-integrity-lint.sh --strict         # 任意 ERROR 退出码 1（用于 CI / pre-commit）
#   bash devlog-integrity-lint.sh --quiet          # 仅输出 ERROR / WARN，不输出 OK 行
#
# 判定规则：
#   目录创建时间 ≥ V3_THRESHOLD（dev-flow v3 上线日，2026-05-12）：
#     - 缺 plan.md  → ERROR（v3 之后步骤 4 必须落盘 plan.md）
#     - 缺 devlog.md → ERROR（v3 之后步骤 7 H 阶段必须落盘 devlog.md，除非流程未走完）
#   目录创建时间 < V3_THRESHOLD：
#     - 缺 plan.md / devlog.md → WARN（v3 前历史产物，建议补建但不阻断）
#   特殊场景：流程未走完（status != completed）允许 devlog.md 缺失（按生命周期合理）
set -euo pipefail

DEV_LOGS_DIR="${HOME}/.codebuddy/dev-logs"
V3_THRESHOLD="2026-05-12"

STRICT=0
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --strict) STRICT=1 ;;
    --quiet) QUIET=1 ;;
    -h|--help)
      sed -n '2,15p' "$0"
      exit 0
      ;;
  esac
done

if [ ! -d "$DEV_LOGS_DIR" ]; then
  echo "⚠️  dev-logs 目录不存在: $DEV_LOGS_DIR"
  exit 0
fi

ERRORS=()
WARNS=()
OK_COUNT=0
TOTAL=0

# 把 V3 上线日转 epoch（macOS 用 -j -f 解析）
V3_EPOCH=$(date -j -f "%Y-%m-%d" "$V3_THRESHOLD" "+%s" 2>/dev/null || echo "0")

for d in "$DEV_LOGS_DIR"/20260*/; do
  [ -d "$d" ] || continue
  TOTAL=$((TOTAL + 1))
  bn=$(basename "$d")

  # 解析目录创建时间（macOS：stat -f %B = birth time）
  birth=$(stat -f "%B" "$d" 2>/dev/null || echo "0")
  is_legacy=0
  if [ "$V3_EPOCH" != "0" ] && [ "$birth" -lt "$V3_EPOCH" ]; then
    is_legacy=1
  fi
  legacy_tag=""
  [ "$is_legacy" -eq 1 ] && legacy_tag=" (v3 前历史产物)"

  has_plan=0; [ -f "$d/plan.md" ] && has_plan=1
  has_devlog=0; [ -f "$d/devlog.md" ] && has_devlog=1

  # plan.md 检查
  if [ "$has_plan" -eq 0 ]; then
    if [ "$is_legacy" -eq 1 ]; then
      WARNS+=("$bn: 缺 plan.md${legacy_tag}（建议从 working-context 抽取方案补建）")
    else
      ERRORS+=("$bn: 缺 plan.md（v3 之后步骤 4 必须落盘 plan.md，违反 plan_saved_to_disk 门控）")
    fi
  fi

  # devlog.md 检查
  if [ "$has_devlog" -eq 0 ]; then
    if [ "$is_legacy" -eq 1 ]; then
      WARNS+=("$bn: 缺 devlog.md${legacy_tag}")
    elif [ "$has_plan" -eq 1 ]; then
      # v3 后产物 + plan.md 已生成 + devlog.md 缺失 → 推断流程仍在进行（步骤 7 H 阶段尚未跑完）
      WARNS+=("$bn: 缺 devlog.md（推断流程进行中，等步骤 7 H 阶段生成；若已收尾请补建）")
    else
      # plan.md 与 devlog.md 双缺 → 严重违规
      ERRORS+=("$bn: 缺 devlog.md（v3 之后步骤 7 H 阶段必须落盘 devlog.md，违反 devlog_generated 门控）")
    fi
  fi

  # 双件齐全 + 无问题
  if [ "$has_plan" -eq 1 ] && [ "$has_devlog" -eq 1 ]; then
    OK_COUNT=$((OK_COUNT + 1))
    [ "$QUIET" -eq 0 ] && echo "  ✅ $bn"
  fi
done

# ==========================================
# P3: 孤儿目录检测（devlog 目录 vs working-context 关联性）
# ==========================================
# 设计动机：
#   2026-07-06 发现 3 个 devlog 目录没有对应 working-context YAML：
#   它们是已有需求的后续轮次（如 Round 7/8）或跨项目阶段（Phase 2），
#   但 gen-dashboard.py 原逻辑将其计为独立需求导致覆盖率虚低。
#   本检查在 v3 后创建的完整 devlog 目录中检测缺少 working-context 的情况。
#
# 检测逻辑：
#   对每个 v3 后创建的 devlog 目录（≥ V3_THRESHOLD），提取日期前缀 (YYYYMMDD)，
#   在 working-context/ 下查找是否有同日期前缀的 .md 文件。
#   若找不到 → 疑似孤儿目录（可能为已有需求的后续轮次）。
WC_DIR="${HOME}/.codebuddy/working-context"
ORPHAN_COUNT=0

for d in "$DEV_LOGS_DIR"/20260*/; do
  [ -d "$d" ] || continue
  bn=$(basename "$d")

  # 提取日期前缀
  date_prefix=$(echo "$bn" | grep -oE '^[0-9]{8}' || echo "")
  [ -z "$date_prefix" ] && continue

  # 跳过 legacy（v3 前历史产物不检测）
  birth=$(stat -f "%B" "$d" 2>/dev/null || echo "0")
  if [ "$V3_EPOCH" != "0" ] && [ "$birth" -lt "$V3_EPOCH" ]; then
    continue
  fi

  # 必须有 devlog.md 或 plan.md 才算有效目录
  [ -f "$d/devlog.md" ] || [ -f "$d/plan.md" ] || continue

  # 在 working-context 中查找同日期前缀的文件
  wc_found=0
  if [ -d "$WC_DIR" ]; then
    for wc in "$WC_DIR"/*.md; do
      [ -f "$wc" ] || continue
      wc_name=$(basename "$wc" .md)
      if echo "$wc_name" | grep -q "^${date_prefix}_"; then
        wc_found=1
        break
      fi
    done
  fi

  if [ "$wc_found" -eq 0 ]; then
    WARNS+=("$bn: 疑似孤儿目录（无同日期 working-context YAML，可能为已有需求的后续轮次/跨项目阶段目录）")
    ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
  fi
done

# 孤儿目录汇总
if [ "$ORPHAN_COUNT" -gt 0 ]; then
  echo ""
  [ "$QUIET" -eq 0 ] && echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  [ "$QUIET" -eq 0 ] && echo "🕵️  孤儿目录检测（working-context 关联性）"
  [ "$QUIET" -eq 0 ] && echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
  [ "$QUIET" -eq 0 ] && echo "  ✅ 所有 devlog 目录均有对应的 working-context YAML"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 dev-logs 完整性扫描报告"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  扫描目录: $DEV_LOGS_DIR"
  echo "  v3 阈值: ${V3_THRESHOLD}（之前为历史产物，缺失降级为 WARN）"
echo "  共扫描 $TOTAL 个需求目录，✅ 双件齐全 $OK_COUNT 个"
echo ""

if [ ${#ERRORS[@]} -gt 0 ]; then
  echo "🔴 错误（${#ERRORS[@]} 项，违反门控）"
  for e in "${ERRORS[@]}"; do echo "  ❌ $e"; done
  echo ""
fi

if [ ${#WARNS[@]} -gt 0 ]; then
  echo "🟡 警告（${#WARNS[@]} 项，建议处理）"
  for w in "${WARNS[@]}"; do echo "  ⚠️  $w"; done
  echo ""
fi

if [ ${#ERRORS[@]} -eq 0 ] && [ ${#WARNS[@]} -eq 0 ]; then
  echo "🎉 全部完整，无任何问题"
fi

# strict 模式：任意 ERROR 退出码 1（CI 友好）
if [ "$STRICT" -eq 1 ] && [ ${#ERRORS[@]} -gt 0 ]; then
  exit 1
fi

exit 0
