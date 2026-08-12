#!/bin/bash
# find-context-by-branch.sh - 反查工作上下文文件（按分支名）
#
# 单一权威源：references/working-context.md §「反查工具（A 方案）」
#
# 三层匹配优先级：
#   L1 YAML 字段精确匹配（branch / branch_dev / branch_workspace）—— 最可靠
#   L2 文件名「需求简述」段 = 分支功能段（命名对齐规则保证）
#   L3 功能段 kebab-case 模糊匹配（容错）
#
# 用法：
#   bash find-context-by-branch.sh                          # 反查当前分支
#   bash find-context-by-branch.sh "feature/xxx"            # 反查指定分支
#   bash find-context-by-branch.sh --json                   # JSON 输出（当前分支）
#   bash find-context-by-branch.sh --json "feature/xxx"     # JSON 输出（指定分支）
#   bash find-context-by-branch.sh --help                   # 显示帮助
#
# 退出码：
#   0  找到 1 个匹配
#   1  找到多个匹配（需用户决策）
#   2  未找到匹配
#   3  参数错误 / git 仓库异常

set -u

WORKING_CONTEXT_DIR="${HOME}/.codebuddy/working-context"

# ========================================
# 解析参数
# ========================================

OUTPUT_MODE="text"
TARGET_BRANCH=""

while [ $# -gt 0 ]; do
  case "$1" in
    --json)  OUTPUT_MODE="json"; shift ;;
    --help|-h)
      sed -n '2,18p' "$0"
      exit 0
      ;;
    --*)
      echo "❌ 未知参数: $1" >&2
      exit 3
      ;;
    *)
      TARGET_BRANCH="$1"
      shift
      ;;
  esac
done

# ========================================
# 获取目标分支
# ========================================

if [ -z "$TARGET_BRANCH" ]; then
  TARGET_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  if [ -z "$TARGET_BRANCH" ] || [ "$TARGET_BRANCH" = "HEAD" ]; then
    if [ "$OUTPUT_MODE" = "json" ]; then
      echo '{"error": "not_in_git_repo_or_detached_head", "match_count": 0, "matches": []}'
    else
      echo "❌ 当前不在 git 仓库中或处于 detached HEAD 状态" >&2
      echo "   请显式传入分支名: $0 \"feature/xxx\"" >&2
    fi
    exit 3
  fi
fi

# ========================================
# 提取分支「功能段」（去前缀+去开发者后缀）
# 例如：
#   feature/article-list-filter              → article-list-filter
#   feature_dev/article-list-filter/yourname  → article-list-filter
#   bugfix/login-loop                      → login-loop
#   master                                 → master
# ========================================

extract_feature_segment() {
  local branch="$1"
  # feature_dev/<功能>/<开发者>：取中间段
  if [[ "$branch" =~ ^feature_dev/([^/]+)/[^/]+$ ]]; then
    echo "${BASH_REMATCH[1]}"
    return
  fi
  # 标准前缀：取最后一段
  if [[ "$branch" =~ ^(feature|bugfix|hotfix|test|i18n|private|sub-master|dev)/(.+)$ ]]; then
    echo "${BASH_REMATCH[2]}"
    return
  fi
  # 无前缀：原样返回
  echo "$branch"
}

FEATURE_SEGMENT=$(extract_feature_segment "$TARGET_BRANCH")

# ========================================
# 检查工作上下文目录存在性
# ========================================

if [ ! -d "$WORKING_CONTEXT_DIR" ]; then
  if [ "$OUTPUT_MODE" = "json" ]; then
    echo '{"error": "working_context_dir_not_found", "match_count": 0, "matches": []}'
  else
    echo "❌ 工作上下文目录不存在: $WORKING_CONTEXT_DIR" >&2
  fi
  exit 2
fi

# ========================================
# 三层匹配
# ========================================

declare -a L1_MATCHES=()  # YAML 字段精确
declare -a L2_MATCHES=()  # 文件名功能段精确
declare -a L3_MATCHES=()  # 功能段模糊

for file in "$WORKING_CONTEXT_DIR"/*.md; do
  [ -f "$file" ] || continue
  filename=$(basename "$file")

  # ----- L1：YAML 字段精确匹配 -----
  # 从 Front Matter 提取 branch / branch_dev / branch_workspace
  yaml_branch=$(awk '/^---$/{c++; next} c==1 && /^branch:/{print; exit}' "$file" 2>/dev/null \
    | sed -E 's/^branch:[[:space:]]*"?([^"#]*)"?.*$/\1/' | xargs)
  yaml_branch_dev=$(awk '/^---$/{c++; next} c==1 && /^branch_dev:/{print; exit}' "$file" 2>/dev/null \
    | sed -E 's/^branch_dev:[[:space:]]*"?([^"#]*)"?.*$/\1/' | xargs)
  yaml_branch_workspace=$(awk '/^---$/{c++; next} c==1 && /^branch_workspace:/{print; exit}' "$file" 2>/dev/null \
    | sed -E 's/^branch_workspace:[[:space:]]*"?([^"#]*)"?.*$/\1/' | xargs)

  if [ -n "$yaml_branch" ] && [ "$yaml_branch" = "$TARGET_BRANCH" ]; then
    L1_MATCHES+=("$filename|yaml.branch")
    continue
  fi
  if [ -n "$yaml_branch_dev" ] && [ "$yaml_branch_dev" = "$TARGET_BRANCH" ]; then
    L1_MATCHES+=("$filename|yaml.branch_dev")
    continue
  fi
  if [ -n "$yaml_branch_workspace" ] && [ "$yaml_branch_workspace" = "$TARGET_BRANCH" ]; then
    L1_MATCHES+=("$filename|yaml.branch_workspace")
    continue
  fi

  # ----- L2：文件名「需求简述」段精确匹配 -----
  # 文件名格式：YYYYMMDD_<需求简述>_<项目缩写>.md
  if [[ "$filename" =~ ^[0-9]{8}_(.+)_[^_]+\.md$ ]]; then
    file_brief="${BASH_REMATCH[1]}"
    if [ "$file_brief" = "$FEATURE_SEGMENT" ]; then
      L2_MATCHES+=("$filename|filename.brief_exact")
      continue
    fi
    # ----- L3：模糊匹配（功能段是文件简述的子串，或反之） -----
    if [ -n "$FEATURE_SEGMENT" ] && [ "$FEATURE_SEGMENT" != "master" ]; then
      if [[ "$file_brief" == *"$FEATURE_SEGMENT"* ]] || [[ "$FEATURE_SEGMENT" == *"$file_brief"* ]]; then
        L3_MATCHES+=("$filename|filename.brief_fuzzy")
      fi
    fi
  fi
done

# ========================================
# 决定最终匹配（按优先级）
# ========================================

declare -a FINAL_MATCHES=()
MATCH_LAYER=""

if [ ${#L1_MATCHES[@]} -gt 0 ]; then
  FINAL_MATCHES=("${L1_MATCHES[@]}")
  MATCH_LAYER="L1_yaml_exact"
elif [ ${#L2_MATCHES[@]} -gt 0 ]; then
  FINAL_MATCHES=("${L2_MATCHES[@]}")
  MATCH_LAYER="L2_filename_exact"
elif [ ${#L3_MATCHES[@]} -gt 0 ]; then
  FINAL_MATCHES=("${L3_MATCHES[@]}")
  MATCH_LAYER="L3_filename_fuzzy"
fi

MATCH_COUNT=${#FINAL_MATCHES[@]}

# ========================================
# 输出
# ========================================

if [ "$OUTPUT_MODE" = "json" ]; then
  printf '{"target_branch": "%s", "feature_segment": "%s", "match_layer": "%s", "match_count": %d, "matches": [' \
    "$TARGET_BRANCH" "$FEATURE_SEGMENT" "$MATCH_LAYER" "$MATCH_COUNT"
  first=1
  for entry in "${FINAL_MATCHES[@]}"; do
    fname="${entry%|*}"
    mreason="${entry#*|}"
    [ $first -eq 1 ] && first=0 || printf ','
    printf '{"file": "%s", "path": "%s/%s", "match_reason": "%s"}' \
      "$fname" "$WORKING_CONTEXT_DIR" "$fname" "$mreason"
  done
  printf ']}\n'
else
  echo "🔍 反查工作上下文（按分支名）"
  echo "   目标分支：$TARGET_BRANCH"
  echo "   功能段：$FEATURE_SEGMENT"
  echo ""
  if [ "$MATCH_COUNT" -eq 0 ]; then
    echo "❌ 未找到匹配的工作上下文文件"
    echo ""
    echo "建议："
    echo "  1. 确认当前分支是否正确"
    echo "  2. 检查工作上下文目录：ls -la $WORKING_CONTEXT_DIR"
    echo "  3. 若该需求尚未创建工作上下文，触发 dev-flow 会自动创建"
  elif [ "$MATCH_COUNT" -eq 1 ]; then
    echo "✅ 找到 1 个匹配（匹配层级：${MATCH_LAYER}）"
    echo ""
    fname="${FINAL_MATCHES[0]%|*}"
    mreason="${FINAL_MATCHES[0]#*|}"
    echo "   文件：$fname"
    echo "   路径：$WORKING_CONTEXT_DIR/$fname"
    echo "   匹配原因：$mreason"
  else
    echo "⚠️  找到 ${MATCH_COUNT} 个匹配（匹配层级：${MATCH_LAYER}）—— 需进一步确认"
    echo ""
    i=1
    for entry in "${FINAL_MATCHES[@]}"; do
      fname="${entry%|*}"
      mreason="${entry#*|}"
      echo "   [$i] $fname  ($mreason)"
      i=$((i+1))
    done
    echo ""
    echo "建议：打开各文件比对 任务平台 ID/项目路径，选择最匹配的；或建议用户清理冗余文件。"
  fi
fi

# ========================================
# 退出码
# ========================================

if [ "$MATCH_COUNT" -eq 0 ]; then
  exit 2
elif [ "$MATCH_COUNT" -eq 1 ]; then
  exit 0
else
  exit 1
fi
