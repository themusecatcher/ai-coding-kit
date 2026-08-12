#!/bin/bash
# doc-sync-lint.sh — 文档同步物理事实校验（drift / sync 通用）
#
# 用途：验证 AI 是否完成了文档同步操作，不依赖 AI 的完成声明。
# 模式：
#   --mode drift  : 校验 drift 完成后 CR 是否登记
#   --mode sync   : 校验 sync 完成后 devlog/plan.md/CR 是否写入（兼容原 micro-fix-doc-sync-lint.sh）
#
# 调用方式：
#   bash doc-sync-lint.sh --mode drift <flow-name>
#   bash doc-sync-lint.sh --mode sync <flow-name>
#   bash doc-sync-lint.sh <flow-name>            — 默认 sync 模式（兼容旧 micro-fix 调用）
#   bash doc-sync-lint.sh <flow-name> --warn     — 软告警模式（不阻断）
#
# 退出码：0=通过, 1=阻断

set -euo pipefail

MODE="sync"
FLOW_NAME=""
WARN_MODE=false

# 解析参数
args=("$@")
i=0
while [ $i -lt ${#args[@]} ]; do
  arg="${args[$i]}"
  case "$arg" in
    --mode)
      i=$((i + 1))
      if [ $i -lt ${#args[@]} ]; then
        MODE="${args[$i]}"
      fi
      ;;
    --warn)
      WARN_MODE=true
      ;;
    *)
      if [ -z "$FLOW_NAME" ]; then
        FLOW_NAME="$arg"
      fi
      ;;
  esac
  i=$((i + 1))
done

if [ -z "$FLOW_NAME" ]; then
  echo "[lint] doc-sync-lint: 缺少 flow-name 参数" >&2
  exit 1
fi

WC_FILE="$HOME/.codebuddy/working-context/${FLOW_NAME}.md"

# ========================================
# mode=drift: CR 登记校验
# ========================================
if [ "$MODE" = "drift" ]; then
  if [ ! -f "$WC_FILE" ]; then
    echo "[lint] doc-sync-lint (drift): 工作上下文 $WC_FILE 不存在" >&2
    exit 1
  fi

  PASS=true
  ISSUES=""
  TODAY=$(date +%Y-%m-%d)

  # 检查 1: change_requests 中最新 CR 的 detected_time 为今天
  CR_START=$(grep -n '^change_requests:' "$WC_FILE" 2>/dev/null | head -1 | cut -d: -f1)
  if [ -z "$CR_START" ]; then
    ISSUES="${ISSUES}  - 工作上下文中无 change_requests 数组（CR 未登记）\n"
    PASS=false
  else
    CR_END=$(awk "NR>$CR_START && /^[a-z]/ {print NR; exit}" "$WC_FILE" 2>/dev/null)
    if [ -n "$CR_END" ]; then
      CR_BLOCK=$(sed -n "${CR_START},${CR_END}p" "$WC_FILE")
    else
      CR_BLOCK=$(sed -n "${CR_START},\$p" "$WC_FILE")
    fi

    # 提取每个 CR 的 id 和 detected_time
    LATEST_TIME=""
    CR_COUNT=0
    CURRENT_ID=""
    while IFS= read -r line; do
      case "$line" in
        *"- id:"*)
          CURRENT_ID=$(echo "$line" | sed 's/.*"\([^"]*\)".*/\1/')
          ;;
        *"detected_time:"*)
          CR_TIME=$(echo "$line" | sed 's/.*"\([^"]*\)".*/\1/' | cut -d'T' -f1)
          CR_COUNT=$((CR_COUNT + 1))
          if [ -z "$LATEST_TIME" ] || [ "$CR_TIME" \> "$LATEST_TIME" ]; then
            LATEST_TIME="$CR_TIME"
          fi
          ;;
      esac
    done <<< "$CR_BLOCK"

    if [ "$CR_COUNT" -eq 0 ]; then
      ISSUES="${ISSUES}  - change_requests 数组中无 CR 条目（drift 未登记 CR）\n"
      PASS=false
    elif [ "$LATEST_TIME" != "$TODAY" ]; then
      ISSUES="${ISSUES}  - 最新 CR 的 detected_time ($LATEST_TIME) 不是今天 ($TODAY)\n"
      PASS=false
    fi
  fi

  # 检查 2: ## 约束与决策 含今天日期的 [需求漂移] 行
  if ! grep -q "$TODAY" "$WC_FILE" 2>/dev/null || ! grep -q "\[需求漂移\]" "$WC_FILE" 2>/dev/null; then
    ISSUES="${ISSUES}  - ## 约束与决策 中未找到今天 ($TODAY) 的 [需求漂移] 行\n"
    PASS=false
  fi

  if [ "$PASS" = true ]; then
    echo "[lint] doc-sync-lint (drift): ✅ 通过"
    exit 0
  else
    echo "[lint] doc-sync-lint (drift): 🔴 阻断" >&2
    printf '%b' "$ISSUES" >&2
    echo "修复：回退到 drift-handling.md §步骤 3.5 重新登记 CR" >&2
    exit 1
  fi
fi

# ========================================
# mode=sync: 文档写入校验（原 micro-fix-doc-sync-lint 逻辑 + 扩展）
# ========================================
if [ "$MODE" = "sync" ]; then
  if [ ! -f "$WC_FILE" ]; then
    echo "[lint] doc-sync-lint (sync): 工作上下文 $WC_FILE 不存在，跳过" >&2
    exit 0
  fi

  PASS=true
  ISSUES=""

  # ---- 检查 1：devlog 文件是否存在并有写入 ----
  ARTIFACTS_DIR=$(grep -A1 '^artifacts:' "$WC_FILE" | grep 'dir:' | head -1 | sed 's/.*dir: *"//' | sed 's/".*//' | sed "s|^~|$HOME|")

  if [ -n "$ARTIFACTS_DIR" ] && [ -d "$ARTIFACTS_DIR" ]; then
    DEVLOG="$ARTIFACTS_DIR/devlog.md"
    if [ -f "$DEVLOG" ]; then
      TODAY=$(date +%Y-%m-%d)
      # macOS/BSD stat 和 GNU stat 语法不同
      if stat -f %Sm -t %Y-%m-%d "$DEVLOG" 2>/dev/null | grep -q "$TODAY"; then
        : # pass
      elif stat -c %y "$DEVLOG" 2>/dev/null | grep -q "$TODAY"; then
        : # pass (GNU stat)
      else
        ISSUES="${ISSUES}  - devlog.md ($DEVLOG) 最后修改日期不是今天 ($TODAY)\n"
        PASS=false
      fi
    else
      ISSUES="${ISSUES}  - devlog.md ($DEVLOG) 不存在\n"
      PASS=false
    fi
  fi

  # ---- 检查 2：plan.md 中是否有未同步的 CR ----
  CR_START=$(grep -n '^change_requests:' "$WC_FILE" 2>/dev/null | head -1 | cut -d: -f1)
  if [ -n "$CR_START" ]; then
    CR_END=$(awk "NR>$CR_START && /^[a-z]/ {print NR; exit}" "$WC_FILE" 2>/dev/null)
    if [ -n "$CR_END" ]; then
      CR_IDS=$(sed -n "${CR_START},${CR_END}p" "$WC_FILE" 2>/dev/null | awk 'BEGIN{id=""} /- *id:/{sub(/[^"]*"/,""); sub(/".*/,""); id=$0} /status: *"done"/{print id; id=""}' 2>/dev/null || true)
    else
      CR_IDS=""
    fi
  else
    CR_IDS=""
  fi

  if [ -n "$ARTIFACTS_DIR" ] && [ -f "$ARTIFACTS_DIR/plan.md" ]; then
    for CR_ID in $CR_IDS; do
      if ! grep -q "$CR_ID" "$ARTIFACTS_DIR/plan.md" 2>/dev/null; then
        ISSUES="${ISSUES}  - plan.md ($ARTIFACTS_DIR/plan.md) 缺少 $CR_ID 的记录\n"
        PASS=false
      fi
    done
  fi

  # ---- 检查 3：in_progress CR 数 ≤ plan.md 中 CR 行数（新增） ----
  if [ -n "$CR_START" ]; then
    if [ -n "$CR_END" ]; then
      IN_PROGRESS_COUNT=$(sed -n "${CR_START},${CR_END}p" "$WC_FILE" 2>/dev/null | grep -c 'status: *"in_progress"' 2>/dev/null || echo "0")
    else
      IN_PROGRESS_COUNT=$(sed -n "${CR_START},\$p" "$WC_FILE" 2>/dev/null | grep -c 'status: *"in_progress"' 2>/dev/null || echo "0")
    fi
    if [ -n "$ARTIFACTS_DIR" ] && [ -f "$ARTIFACTS_DIR/plan.md" ]; then
      PLAN_CR_COUNT=$(grep -c 'CR-' "$ARTIFACTS_DIR/plan.md" 2>/dev/null || echo "0")
    else
      PLAN_CR_COUNT=0
    fi

    if [ "$IN_PROGRESS_COUNT" -gt "$PLAN_CR_COUNT" ] 2>/dev/null; then
      ISSUES="${ISSUES}  - 工作上下文中 in_progress CR 数 ($IN_PROGRESS_COUNT) > plan.md 中 CR 行数 ($PLAN_CR_COUNT)\n"
      PASS=false
    fi
  fi

  # ---- 检查 4：knowledge 漂移检测 — 相关文件 mtime 为今天 ----
  KNOWLEDGE_DIR="$HOME/.codebuddy/knowledge"
  if [ -d "$KNOWLEDGE_DIR" ]; then
    TODAY=$(date +%Y-%m-%d)
    # 按工作上下文关键字反查 knowledge 文件（不依赖项目目录命名风格）
    K_FILES=$(grep -rl "enroll-limit\|max_enroll_count\|signup-setting\|放开报名" "$KNOWLEDGE_DIR/" 2>/dev/null | head -20 || true)
    K_UPDATED=false
    for KF in $K_FILES; do
      if [ -f "$KF" ]; then
        if stat -f %Sm -t %Y-%m-%d "$KF" 2>/dev/null | grep -q "$TODAY"; then
          K_UPDATED=true
          break
        elif stat -c %y "$KF" 2>/dev/null | grep -q "$TODAY"; then
          K_UPDATED=true
          break
        fi
      fi
    done
    if [ "$K_UPDATED" = false ]; then
      ISSUES="${ISSUES}  - knowledge 目录中无今天 ($TODAY) 更新的条目（H.3 漂移检测可能未执行）\n"
      PASS=false
    fi
  fi

  # ---- 检查 5：文档平台 同步 — last_synced_at 为今天 ----
  SYNCED_AT=$(grep 'last_synced_at:' "$WC_FILE" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)".*/\1/' | cut -d'T' -f1 || true)
  TODAY=$(date +%Y-%m-%d)
  if [ -z "$SYNCED_AT" ] || [ "$SYNCED_AT" != "$TODAY" ]; then
    ISSUES="${ISSUES}  - 文档平台 last_synced_at ($SYNCED_AT) 不是今天 ($TODAY)（H.3+ 对账可能未执行）\n"
    PASS=false
  fi

  # ---- 检查 6：artifacts 路径完整性 — 所有非 null 路径存在 ----
  if [ -n "$ARTIFACTS_DIR" ]; then
    # plan.md
    PLAN_PATH=$(grep 'plan:' "$WC_FILE" 2>/dev/null | head -1 | sed 's/.*plan: *//' | sed 's/^"//' | sed 's/"$//' | sed "s|^~|$HOME|")
    if [ -n "$PLAN_PATH" ] && [ ! -f "$PLAN_PATH" ]; then
      ISSUES="${ISSUES}  - artifacts.plan ($PLAN_PATH) 不存在\n"
      PASS=false
    fi
    # devlog (null 时跳过；值可能带引号或不带引号)
    DEVLOG_PATH=$(grep 'devlog:' "$WC_FILE" 2>/dev/null | head -1 | sed 's/.*devlog: *//' | sed 's/^"//' | sed 's/"$//' | sed "s|^~|$HOME|")
    if [ -n "$DEVLOG_PATH" ] && [ "$DEVLOG_PATH" != "null" ] && [ ! -f "$DEVLOG_PATH" ]; then
      ISSUES="${ISSUES}  - artifacts.devlog ($DEVLOG_PATH) 不存在\n"
      PASS=false
    fi
    # report.yaml
    REPORT_PATH="$ARTIFACTS_DIR/report.yaml"
    if [ ! -f "$REPORT_PATH" ]; then
      ISSUES="${ISSUES}  - artifacts/report.yaml ($REPORT_PATH) 不存在\n"
      PASS=false
    fi
  fi

  # ---- 检查 7：度量采集 — report.yaml complete_date 为今天（仅流程已完成时） ----
  FLOW_STATUS=$(grep '^status:' "$WC_FILE" 2>/dev/null | head -1 | sed 's/status: *"//' | sed 's/".*//' || true)
  if [ "$FLOW_STATUS" = "completed" ] || [ "$FLOW_STATUS" = "done" ]; then
    REPORT_CD=$(grep 'complete_date:' "$REPORT_PATH" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)".*/\1/' || true)
    TODAY=$(date +%Y-%m-%d)
    if [ -z "$REPORT_CD" ] || [ "$REPORT_CD" != "$TODAY" ]; then
      ISSUES="${ISSUES}  - report.yaml complete_date ($REPORT_CD) 不是今天 ($TODAY)（I 度量采集可能未执行）\n"
      PASS=false
    fi
  fi

  # ---- 输出 ----
  if [ "$PASS" = true ]; then
    echo "[lint] doc-sync-lint (sync): ✅ 通过"
    exit 0
  fi

  if [ "$WARN_MODE" = true ]; then
    echo "[lint] doc-sync-lint (sync): ⚠️ 告警（soft mode）" >&2
    printf '%b' "$ISSUES" >&2
    exit 0
  else
    echo "[lint] doc-sync-lint (sync): 🔴 阻断" >&2
    printf '%b' "$ISSUES" >&2
    echo "修复：执行对应文档同步操作后重试" >&2
    exit 1
  fi
fi

# 不应该到这里
echo "[lint] doc-sync-lint: 未知模式 $MODE" >&2
exit 1
