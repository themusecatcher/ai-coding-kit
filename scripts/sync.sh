#!/bin/bash
# ==============================================================================
# sync.sh - 从 ~/.codebuddy 同步 skills/agents/rules 到 ai-coding-kit Git 仓库
#
# 用法（推荐在仓库根目录通过 npm scripts 调用）:
#   npm run sync                   # 同步全部（skills + agents + rules）
#   npm run sync:skills            # 仅同步 skills
#   npm run sync:agents            # 仅同步 agents
#   npm run sync:rules             # 仅同步 rules
#
# 也可直接调用:
#   bash scripts/sync.sh [目录名...]
# ==============================================================================

set -e

# ---- 配置 ----
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_DIR="$HOME/.codebuddy"

# 可同步的目录列表
ALL_DIRS=("skills" "agents" "rules")

# 所有目录通用排除（保护 Git 仓库中独有的文件）
# 注意：/README.md 只排除同步根目录下的 README.md，不影响子目录中的 README.md
# 这样当源端删除某个 skill/agent 时，rsync --delete 能正确清理整个子目录
COMMON_EXCLUDES=(
  "--exclude=/README.md"
  "--exclude=.git"
)

# skills 目录额外排除的内容
# 排除策略：
#   - 运行时/缓存数据（.clawhub）
#   - 私有 skill（`_` 前缀）— 不随仓库公开
#   - 仓库独有文件/目录（plugin.json, .codebuddy-plugin, _platform-integrations.yaml）— ~/.codebuddy 中不存在，需保护不被 --delete 删除
SKILLS_EXCLUDES=(
  "--exclude=.clawhub"
  "--exclude=_private"
  "--exclude=plugin.json"
  "--exclude=.codebuddy-plugin"
  "--exclude=_platform-integrations.yaml"
)

# ---- 颜色 ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ---- 函数 ----
info()  { echo -e "${BLUE}ℹ${NC}  $1"; }
ok()    { echo -e "${GREEN}✅${NC} $1"; }
warn()  { echo -e "${YELLOW}⚠${NC}  $1"; }
error() { echo -e "${RED}❌${NC} $1"; }

usage() {
  echo "用法: $0 [目录名...]"
  echo ""
  echo "  不带参数    同步全部 (skills, agents, rules)"
  echo "  skills     仅同步 skills"
  echo "  agents     仅同步 agents"
  echo "  rules      仅同步 rules"
  echo ""
  echo "示例:"
  echo "  $0                  # 同步全部"
  echo "  $0 skills           # 仅同步 skills"
  echo "  $0 skills rules     # 同步 skills 和 rules"
}

sync_dir() {
  local dir="$1"
  local src="$SOURCE_DIR/$dir"
  local dst="$REPO_DIR/$dir"

  if [ ! -d "$src" ]; then
    warn "源目录不存在，跳过: $src"
    return
  fi

  info "同步 $dir ..."

  # 构建 rsync 参数：通用排除 + 目录专属排除
  local rsync_args=(-av --delete "${COMMON_EXCLUDES[@]}")

  # skills 目录需要额外排除运行时数据
  if [ "$dir" = "skills" ]; then
    rsync_args+=("${SKILLS_EXCLUDES[@]}")
  fi

  rsync "${rsync_args[@]}" "$src/" "$dst/"

  ok "$dir 同步完成"
}

# ---- 变动分析 ----

# 按 item 级别分析变更类型
# 核心逻辑：一个 item 下所有文件都是新增（??）→ add；所有文件都是删除（D）→ remove；其余 → update
# 用法: classify_items_by_dir <dir>
# 输出: 单行，格式为 "added|updated|removed"，各部分内的 item 名称用空格分隔
classify_items_by_dir() {
  local dir="$1"
  local dir_changes
  dir_changes=$(git status --porcelain -- "$dir/" 2>/dev/null)
  [ -z "$dir_changes" ] && return
  echo "$dir_changes" | awk '
{
  status = substr($0, 1, 2)
  filepath = substr($0, 4)
  gsub(/^"/, "", filepath)
  gsub(/"$/, "", filepath)
  n = split(filepath, parts, "/")
  if (n >= 2) { item = parts[2] } else { item = filepath }
  if (status == "??") { type = "A" }
  else if (status ~ /D/) { type = "D" }
  else { type = "M" }
  if (!(item in types)) {
    types[item] = type
    order[++count] = item
  } else if (index(types[item], type) == 0) {
    types[item] = types[item] type
  }
}
END {
  added = ""; updated = ""; removed = ""
  for (i = 1; i <= count; i++) {
    item = order[i]
    t = types[item]
    if (t == "A") { added = (added == "" ? item : added " " item) }
    else if (t == "D") { removed = (removed == "" ? item : removed " " item) }
    else { updated = (updated == "" ? item : updated " " item) }
  }
  printf "%s|%s|%s\n", added, updated, removed
}'
}

# ---- 主逻辑 ----

# 帮助参数
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  exit 0
fi

# 确定要同步的目录
if [ $# -eq 0 ]; then
  SYNC_DIRS=("${ALL_DIRS[@]}")
else
  SYNC_DIRS=()
  for arg in "$@"; do
    # 验证参数是否合法
    valid=false
    for d in "${ALL_DIRS[@]}"; do
      if [ "$arg" = "$d" ]; then
        valid=true
        break
      fi
    done
    if [ "$valid" = true ]; then
      SYNC_DIRS+=("$arg")
    else
      error "无效的目录名: $arg（仅支持: ${ALL_DIRS[*]}）"
      exit 1
    fi
  done
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  ${BLUE}🔄 CodeBuddy 配置同步工具${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
info "源: $SOURCE_DIR"
info "目标: $REPO_DIR"
info "同步目录: ${SYNC_DIRS[*]}"
echo ""

# 执行同步
for dir in "${SYNC_DIRS[@]}"; do
  sync_dir "$dir"
  echo ""
done

# 显示 Git 变更
cd "$REPO_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  ${BLUE}📋 Git 变更概览${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

CHANGES=$(git status --porcelain)
if [ -z "$CHANGES" ]; then
  ok "没有变更，已是最新状态 ✨"
  echo ""
  exit 0
fi

# 统计变更
ADDED=$(echo "$CHANGES" | grep -c '^\?' || true)
MODIFIED=$(echo "$CHANGES" | grep -c '^ M\|^M' || true)
DELETED=$(echo "$CHANGES" | grep -c '^ D\|^D' || true)

echo -e "  新增: ${GREEN}${ADDED}${NC} 个文件"
echo -e "  修改: ${YELLOW}${MODIFIED}${NC} 个文件"
echo -e "  删除: ${RED}${DELETED}${NC} 个文件"
echo ""

# 显示按目录分组的详细变更（使用 item 级别分类）
for dir in "${SYNC_DIRS[@]}"; do
  classification=$(classify_items_by_dir "$dir")
  [ -z "$classification" ] && continue

  echo -e "  ${BLUE}📁 ${dir}/${NC}"

  IFS='|' read -r added_line updated_line removed_line <<< "$classification"

  for item in $added_line; do
    echo -e "    ${GREEN}+ ${item}${NC}  (new)"
  done
  for item in $updated_line; do
    echo -e "    ${YELLOW}~ ${item}${NC}"
  done
  for item in $removed_line; do
    echo -e "    ${RED}- ${item}${NC}"
  done

  echo ""
done

# 显示完整文件变更列表
echo -e "  ${BLUE}📄 文件变更明细:${NC}"
git status --short
echo ""

# 生成智能 commit message（扁平化逻辑，避免嵌套子 shell 挂起问题）
_ALL_ADDED=()
_ALL_UPDATED=()
_ALL_REMOVED=()
_CHANGED_DIRS=()

for dir in "${SYNC_DIRS[@]}"; do
  classification=$(classify_items_by_dir "$dir")
  [ -z "$classification" ] && continue
  _CHANGED_DIRS+=("$dir")
  IFS='|' read -r _added_line _updated_line _removed_line <<< "$classification"
  for item in $_added_line; do _ALL_ADDED+=("$item"); done
  for item in $_updated_line; do _ALL_UPDATED+=("$item"); done
  for item in $_removed_line; do _ALL_REMOVED+=("$item"); done
done

# ---- 内容变动分析函数 ----

# 分析单个 item 的具体文件变更内容，生成简明描述
# 用法: describe_item_changes <dir> <item> <change_type>
# change_type: add | update | remove
describe_item_changes() {
  local dir="$1" item="$2" change_type="$3"
  local item_path="$dir/$item"

  case "$change_type" in
    add)
      # 新增：列出包含的主要文件
      local files
      files=$(git status --porcelain -- "$item_path/" 2>/dev/null | awk '{print substr($0,4)}' | sed "s|^$dir/$item/||")
      local file_count
      file_count=$(echo "$files" | grep -c . || true)
      if [ "$file_count" -le 3 ]; then
        echo "new ${item} ($(echo "$files" | tr '\n' ', ' | sed 's/,$//'))"
      else
        local main_file
        main_file=$(echo "$files" | head -1)
        echo "new ${item} (${file_count} files: ${main_file}, ...)"
      fi
      ;;
    remove)
      echo "remove ${item}"
      ;;
    update)
      # 更新：先 git add 获取 staged diff，再分析内容变动
      # 注意：此时还未 git add，需要对比 working tree
      local diff_output changed_files
      changed_files=$(git status --porcelain -- "$item_path/" 2>/dev/null | awk '{print substr($0,4)}')
      local desc_parts=()

      while IFS= read -r filepath; do
        [ -z "$filepath" ] && continue
        # 去除可能的引号
        filepath="${filepath#\"}"
        filepath="${filepath%\"}"
        local basename_f
        basename_f=$(basename "$filepath")
        local status_code
        status_code=$(git status --porcelain -- "$filepath" 2>/dev/null | head -1 | cut -c1-2)

        if [[ "$status_code" == "??" ]]; then
          desc_parts+=("add ${basename_f}")
        elif [[ "$status_code" =~ D ]]; then
          desc_parts+=("remove ${basename_f}")
        else
          # 分析 diff 内容
          local diff_stat
          diff_stat=$(git diff --stat -- "$filepath" 2>/dev/null | tail -1)
          local insertions deletions
          insertions=$(echo "$diff_stat" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
          deletions=$(echo "$diff_stat" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo "0")

          if [ "$insertions" != "0" ] || [ "$deletions" != "0" ]; then
            desc_parts+=("${basename_f} (+${insertions}/-${deletions})")
          else
            desc_parts+=("modify ${basename_f}")
          fi
        fi
      done <<< "$changed_files"

      # 组装描述
      local desc_count=${#desc_parts[@]}
      if [ "$desc_count" -eq 0 ]; then
        echo "update ${item}"
      elif [ "$desc_count" -le 4 ]; then
        local joined
        joined=$(printf '%s' "${desc_parts[0]}")
        for ((k = 1; k < desc_count; k++)); do joined+=", ${desc_parts[$k]}"; done
        echo "${item}: ${joined}"
      else
        local joined
        joined=$(printf '%s' "${desc_parts[0]}")
        for ((k = 1; k < 3; k++)); do joined+=", ${desc_parts[$k]}"; done
        echo "${item}: ${joined}, ... (+$((desc_count - 3)) more)"
      fi
      ;;
  esac
}

if [ ${#_CHANGED_DIRS[@]} -eq 0 ]; then
  COMMIT_HEADER="chore: sync ${SYNC_DIRS[*]} from .codebuddy"
  COMMIT_BODY=""
else
  # 构建 header 描述片段（简洁摘要）
  _parts=()
  for _g in add update remove; do
    case "$_g" in
      add)    _items=("${_ALL_ADDED[@]}") ;;
      update) _items=("${_ALL_UPDATED[@]}") ;;
      remove) _items=("${_ALL_REMOVED[@]}") ;;
    esac
    _count=${#_items[@]}
    [ "$_count" -eq 0 ] && continue
    if [ "$_count" -le 3 ]; then
      _joined=$(printf '%s' "${_items[0]}")
      for ((j = 1; j < _count; j++)); do _joined+=", ${_items[$j]}"; done
      _parts+=("${_g} ${_joined}")
    else
      _parts+=("${_g} ${_items[0]}, ${_items[1]} etc ${_count} items")
    fi
  done

  # 确定 commit type
  _commit_type="chore"
  if [ ${#_ALL_ADDED[@]} -gt 0 ] && [ ${#_ALL_UPDATED[@]} -eq 0 ] && [ ${#_ALL_REMOVED[@]} -eq 0 ]; then
    _commit_type="feat"
  fi

  # 确定 scope
  if [ ${#_CHANGED_DIRS[@]} -eq 1 ]; then _scope="${_CHANGED_DIRS[0]}"
  else _scope="sync"; fi

  # 组装 header（第一行，保持简洁）
  _header_body=$(printf '%s' "${_parts[0]}")
  for ((i = 1; i < ${#_parts[@]}; i++)); do _header_body+="; ${_parts[$i]}"; done
  COMMIT_HEADER="${_commit_type}(${_scope}): ${_header_body}"

  # 构建 body（详细内容变动描述）
  _body_lines=()

  for dir in "${SYNC_DIRS[@]}"; do
    classification=$(classify_items_by_dir "$dir")
    [ -z "$classification" ] && continue

    IFS='|' read -r _a _u _r <<< "$classification"

    # 处理每种变更类型的 item
    for item in $_a; do
      _body_lines+=("- $(describe_item_changes "$dir" "$item" "add")")
    done
    for item in $_u; do
      _body_lines+=("- $(describe_item_changes "$dir" "$item" "update")")
    done
    for item in $_r; do
      _body_lines+=("- $(describe_item_changes "$dir" "$item" "remove")")
    done
  done

  # body 行数上限，超出截断
  _MAX_BODY_LINES=15
  _total_body=${#_body_lines[@]}

  if [ "$_total_body" -gt 0 ]; then
    COMMIT_BODY=""
    if [ "$_total_body" -le "$_MAX_BODY_LINES" ]; then
      for line in "${_body_lines[@]}"; do
        COMMIT_BODY+="${line}"$'\n'
      done
    else
      # 只保留前 N-1 行 + 省略提示
      _show=$((_MAX_BODY_LINES - 1))
      for ((i = 0; i < _show; i++)); do
        COMMIT_BODY+="${_body_lines[$i]}"$'\n'
      done
      _remaining=$((_total_body - _show))
      COMMIT_BODY+="- ... and ${_remaining} more items"$'\n'
    fi
    # 移除末尾换行
    COMMIT_BODY="${COMMIT_BODY%$'\n'}"
  else
    COMMIT_BODY=""
  fi
fi

# 询问是否提交
read -p "是否提交并推送到远程？(y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo ""
  echo -e "  ${BLUE}💡 建议的 commit message:${NC}"
  echo -e "  ${GREEN}${COMMIT_HEADER}${NC}"
  if [ -n "$COMMIT_BODY" ]; then
    echo ""
    echo -e "  ${BLUE}📝 详细变更:${NC}"
    while IFS= read -r _bline; do
      echo -e "  ${YELLOW}${_bline}${NC}"
    done <<< "$COMMIT_BODY"
  fi
  echo ""
  read -p "输入 commit message（回车使用上述建议）: " CUSTOM_MSG

  git add -A

  if [ -n "$CUSTOM_MSG" ]; then
    git commit -m "$CUSTOM_MSG"
  elif [ -n "$COMMIT_BODY" ]; then
    git commit -m "$COMMIT_HEADER" -m "$COMMIT_BODY"
  else
    git commit -m "$COMMIT_HEADER"
  fi

  echo ""
  read -p "确认推送到远程？(y/n) " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    git push
    echo ""
    ok "推送完成 🚀"
  else
    ok "已提交到本地，未推送（可稍后手动 git push）"
  fi
else
  warn "已取消提交。变更已同步到本地仓库目录，可稍后手动提交。"
fi

echo ""
