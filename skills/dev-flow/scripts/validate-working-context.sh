#!/bin/bash
# validate-working-context.sh
# 工作上下文文件命名和结构完整性校验
# 用法: bash validate-working-context.sh <文件路径>
# 返回码: 0=通过, 1=失败

set -eo pipefail

FILE="${1:-}"
if [ -z "$FILE" ]; then
  echo "❌ 用法: bash $0 <工作上下文文件路径>"
  exit 1
fi

if [ ! -f "$FILE" ]; then
  echo "❌ 文件不存在: $FILE"
  exit 1
fi

BASENAME=$(basename "$FILE")
ERRORS=()
WARNINGS=()

# ========== 1. 文件名格式校验 ==========

# 1a. 整体格式: YYYYMMDD_英文简述_项目缩写.md
# 项目缩写段允许短横线（与§1d 白名单一致：my-project / my-lib 等均含 -）。
# 修复（2026-08-07）：原正则项目段为 [a-zA-Z][a-zA-Z0-9]*（不含 -），与白名单
# 全部含连字符的项目名互相矛盾 → 任何合规文件都无法同时通过 1a 与 1d。
if ! echo "$BASENAME" | grep -qE '^[0-9]{8}_[a-zA-Z0-9][a-zA-Z0-9-]*_[a-zA-Z][a-zA-Z0-9-]*\.md$'; then
  ERRORS+=("[命名] 文件名格式不匹配 {YYYYMMDD}_{英文简述}_{项目缩写}.md，实际: $BASENAME")
fi

# 1b. 简述部分不能含中文（兼容 macOS grep 无 -P 的情况）
BRIEF=$(echo "$BASENAME" | sed 's/^[0-9]*_//' | sed 's/_[^_]*\.md$//')
if python3 -c "import sys; sys.exit(0 if any('\u4e00' <= c <= '\u9fff' for c in '$BRIEF') else 1)" 2>/dev/null; then
  ERRORS+=("[命名] 需求简述含中文: '$BRIEF'，必须使用英文短横线")
fi

# 1c. 日期部分校验
DATE_PART=$(echo "$BASENAME" | grep -oE '^[0-9]{8}' || echo "")
if [ -n "$DATE_PART" ]; then
  MONTH=${DATE_PART:4:2}
  DAY=${DATE_PART:6:2}
  if [ "$MONTH" -lt 1 ] 2>/dev/null || [ "$MONTH" -gt 12 ] 2>/dev/null || [ "$DAY" -lt 1 ] 2>/dev/null || [ "$DAY" -gt 31 ] 2>/dev/null; then
    ERRORS+=("[命名] 日期无效: $DATE_PART")
  fi
fi

# 1d. 项目缩写白名单校验
PROJECT_SUFFIX=$(echo "$BASENAME" | sed 's/\.md$//' | awk -F_ '{print $NF}')
KNOWN_PROJECTS="my-project my-lib my-components my-app my-service"
FOUND=0
for p in $KNOWN_PROJECTS; do
  if [ "$PROJECT_SUFFIX" = "$p" ]; then
    FOUND=1
    break
  fi
done
if [ "$FOUND" -eq 0 ]; then
  ERRORS+=("[命名] 项目缩写 '$PROJECT_SUFFIX' 不在映射表中（已知: $KNOWN_PROJECTS）")
fi

# ========== 2. YAML Front Matter 校验 ==========

# 2a. 必须有 YAML 头
if ! head -1 "$FILE" | grep -q '^---'; then
  ERRORS+=("[YAML] 缺少 YAML Front Matter（首行必须是 ---）")
fi

# 2b. YAML 闭合标签
YAML_CLOSE=$(awk 'NR>1 && /^---/{print NR; exit}' "$FILE")
if [ -z "$YAML_CLOSE" ]; then
  ERRORS+=("[YAML] YAML Front Matter 未闭合（缺少第二个 ---）")
fi

# 2c. 必填字段检查
for FIELD in "mode:" "current_step:" "status:" "project:"; do
  if ! grep -q "^${FIELD}" "$FILE"; then
    ERRORS+=("[YAML] 缺少必填字段: $FIELD")
  fi
done

# 2d. steps 映射检查
if ! grep -q "^steps:" "$FILE"; then
  ERRORS+=("[YAML] 缺少 steps 字段（步骤状态映射）")
fi

# 2e. 跨项目场景必须有 cross_project
if grep -q "cross_project" "$FILE"; then
  # 提取完整 cross_project 块（到下一个顶级 key 为止），不用行数窗口，避免块变长（如 projects_detail）后漏检
  CP_BLOCK=$(awk '/^cross_project:/{flag=1;next} /^[a-zA-Z_]+:/{flag=0} flag' "$FILE")
  for CP_FIELD in "enabled:" "fix_project:" "status:"; do
    if ! echo "$CP_BLOCK" | grep -q "$CP_FIELD"; then
      ERRORS+=("[YAML] cross_project 缺少子字段: $CP_FIELD")
    fi
  done
  # origin_project / source_project 二选一必填（依赖型用 origin_project，修复型用 source_project）
  if ! echo "$CP_BLOCK" | grep -qE "(origin_project|source_project):"; then
    ERRORS+=("[YAML] cross_project 缺少子字段: origin_project 或 source_project（二选一）")
  fi
fi

# ========== 3. Markdown 正文必填区块校验 ==========

# 3a. ## 需求 区块
if ! grep -q '^## 需求' "$FILE"; then
  ERRORS+=("[正文] 缺少 ## 需求 区块")
else
  # 需求区块内的必填子字段
  if ! grep -q '\*\*任务平台\*\*' "$FILE"; then
    ERRORS+=("[正文] ## 需求 区块缺少 任务平台 字段")
  fi
  if ! grep -q '\*\*标题\*\*' "$FILE"; then
    ERRORS+=("[正文] ## 需求 区块缺少标题字段")
  fi
  if ! grep -q '\*\*摘要\*\*' "$FILE"; then
    ERRORS+=("[正文] ## 需求 区块缺少摘要字段")
  fi
  # 任务平台 必含完整 URL（"无"类豁免标记除外）
  if grep -q '\*\*任务平台\*\*' "$FILE" && ! grep '\*\*任务平台\*\*' "$FILE" | grep -qE 'tracker\.example\.com|无（|无。|无$'; then
    WARNINGS+=("[正文] 任务平台 字段未包含完整可点击 URL（或未显式标记为"无"）")
  fi
fi

# 3b. ## 约束与决策 区块
if ! grep -q '^## 约束与决策' "$FILE"; then
  WARNINGS+=("[正文] 缺少 ## 约束与决策 区块")
fi

# 3c. ## 进度 区块
if ! grep -q '^## 进度' "$FILE" && ! grep -q '^### 恢复指令' "$FILE"; then
  WARNINGS+=("[正文] 缺少 ## 进度 或 ### 恢复指令 区块")
fi

# 3d. 头部时间戳格式
if ! grep -q '^> 更新：[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}' "$FILE"; then
  WARNINGS+=("[正文] 头部时间戳格式不规范（应为 > 更新：YYYY-MM-DD HH:mm | ...）")
fi

# ========== 4. .flow 文件一致性检查 ==========

FLOW_DIR="$HOME/.codebuddy/working-context/.active-flows"
FLOW_NAME=$(echo "$BASENAME" | sed 's/\.md$/.flow/')
FLOW_PATH="$FLOW_DIR/$FLOW_NAME"

if [ -f "$FLOW_PATH" ]; then
  # 检查 .flow 必填字段
  for FLOW_FIELD in "brief" "status" "phase" "match_keywords"; do
    if ! grep -q "^${FLOW_FIELD}" "$FLOW_PATH"; then
      WARNINGS+=("[.flow] 缺少字段: $FLOW_FIELD")
    fi
  done
  # 检查 recovery 三段式（同时兼容 TOML 的 [recovery] 与 YAML 的 recovery:）
  if ! grep -qE '^\[recovery\]|^recovery:' "$FLOW_PATH"; then
    WARNINGS+=("[.flow] 缺少 [recovery] / recovery: 区块（三段式恢复信息）")
  else
    for REC_FIELD in "yesterday" "next_action" "pending"; do
      if ! grep -qE "^${REC_FIELD}|^  ${REC_FIELD}" "$FLOW_PATH"; then
        WARNINGS+=("[.flow] recovery 缺少字段: $REC_FIELD")
      fi
    done
  fi
else
  # 已 completed / superseded 的流程不要求有 .flow（生命周期要求收尾后删除）
  if grep -qE '^status: (completed|superseded)' "$FILE"; then
    : # silenced：正常状态，.flow 已应被删除
  else
    WARNINGS+=("[.flow] 对应 .flow 文件不存在: $FLOW_NAME")
  fi
fi

# ========== 输出结果 ==========

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 工作上下文校验报告: $BASENAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  📅 日期: ${DATE_PART:-N/A}"
echo "  📝 简述: ${BRIEF:-N/A}"
echo "  📦 项目缩写: ${PROJECT_SUFFIX:-N/A}"
echo ""

if [ ${#ERRORS[@]} -gt 0 ]; then
  echo "🔴 错误（${#ERRORS[@]} 项，必须修正）："
  for err in "${ERRORS[@]}"; do
    echo "  ❌ $err"
  done
  echo ""
fi

if [ ${#WARNINGS[@]} -gt 0 ]; then
  echo "🟡 警告（${#WARNINGS[@]} 项，建议修正）："
  for warn in "${WARNINGS[@]}"; do
    echo "  ⚠️ $warn"
  done
  echo ""
fi

if [ ${#ERRORS[@]} -eq 0 ] && [ ${#WARNINGS[@]} -eq 0 ]; then
  echo "✅ 全部通过，无错误无警告"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ ${#ERRORS[@]} -gt 0 ]; then
  echo "❌ 校验失败（${#ERRORS[@]} 项错误），请修正后重新运行"
  exit 1
else
  if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo "✅ 校验通过（有 ${#WARNINGS[@]} 项警告）"
  else
    echo "✅ 校验通过"
  fi
  exit 0
fi
