#!/bin/bash
# ==============================================================================
# sync.sh - ai-coding-kit 与 ~/.codebuddy 之间的双向同步
#
#   pull（默认）: ~/.codebuddy  ──▶  ai-coding-kit 仓库
#   push        : ai-coding-kit 仓库  ──▶  ~/.codebuddy
#
# 用法（推荐在仓库根目录通过 npm scripts 调用）:
#   npm run sync                   # pull 同步全部（skills + agents + rules）
#   npm run sync:pull              # 同上，显式声明方向
#   npm run sync:push              # push 同步全部（含护栏：预览 + 删除确认 + 备份）
#   npm run sync:skills            # 仅同步 skills（pull 方向）
#
# 也可直接调用:
#   bash scripts/sync.sh [push|pull] [目录名...] [--dry-run] [--force] [--keep-newer]
#
# ⚠️ push 方向会覆盖 ~/.codebuddy 下同名文件。执行前自动备份到
#    ~/.codebuddy/.sync-backup/<时间戳>/，建议先用 --dry-run 预览。
# ==============================================================================

set -e

# ---- 配置 ----
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RUNTIME_DIR="$HOME/.codebuddy"

# 可同步的目录列表（白名单：只允许这三个子目录，避免误伤 ~/.codebuddy 顶层配置）
ALL_DIRS=("skills" "agents" "rules")

# ---- 方向（pull 默认，向后兼容）----
#   pull: RUNTIME_DIR → REPO_DIR
#   push: REPO_DIR → RUNTIME_DIR
DIRECTION="pull"
DRY_RUN=false
FORCE=false
KEEP_NEWER=false
SYNC_DIRS=()
BACKUP_DIR=""
PREVIEW_DIR=""

# 所有目录通用排除（保护目标端独有文件）
# 注意：/README.md 只排除同步根目录下的 README.md，不影响子目录中的 README.md
# 这样当源端删除某个 skill/agent 时，rsync --delete 能正确清理整个子目录
#
# .dev-flow-managed 是 install.sh v1.3.0 写入的受管标记，其 --status / --uninstall
# 完全依赖它识别副本。若被 --delete 清除，会导致卸载与健康检查失效，
# 故两个方向都必须排除（同时避免 pull 时把该标记拉进仓库）。
COMMON_EXCLUDES=(
  "--exclude=/README.md"
  # 构建产物目录（如 skills/dev-flow/dist 分发包）：运行时无对应目录，
  # 若纳入 pull 方向的 --delete 会清空仓库产物（2026-09-15 事故：190 个跟踪文件被误删）
  "--exclude=dist/"
  "--exclude=.git"
  "--exclude=.dev-flow-managed"
)

# skills 目录额外排除的内容（双向）
# 排除策略：
#   - 运行时/缓存数据（.clawhub）
#   - 私有 skill（`_` 前缀）— 不随仓库公开
#   - 仓库独有文件/目录（plugin.json, .codebuddy-plugin, _platform-integrations.yaml）— 需保护不被 --delete 删除
SKILLS_EXCLUDES=(
  "--exclude=.clawhub"
  "--exclude=_private"
  "--exclude=plugin.json"
  "--exclude=.codebuddy-plugin"
  "--exclude=_platform-integrations.yaml"
)

# push 方向额外排除（仅仓库侧独有的分发产物）
#   - dev-flow/dist 是给未 clone 仓库用户的独立分发包，回灌 ~/.codebuddy 只会冗余膨胀
PUSH_EXCLUDES=(
  "--exclude=/dev-flow/dist"
)

# openrsync（macOS 自带）默认会把非 ASCII 文件名转义成 \#NNN 形式，
# 导致预览明细里的路径无法用于备份匹配，其 --8-bit-output 可关闭该行为。
# GNU rsync 无此选项，故按需探测后再启用。
RSYNC_8BIT_OUTPUT=""
if rsync --help 2>&1 | grep -q -- '--8-bit-output'; then
  RSYNC_8BIT_OUTPUT="--8-bit-output"
fi

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
  echo "用法: $0 [pull|push] [目录名...] [选项...]"
  echo ""
  echo "方向（只能是第一个位置参数，缺省为 pull）:"
  echo "  pull     ~/.codebuddy  ──▶  ai-coding-kit 仓库（默认，与历史行为一致）"
  echo "  push     ai-coding-kit 仓库  ──▶  ~/.codebuddy（含预览/确认/备份护栏）"
  echo ""
  echo "目录名:"
  echo "  不带参数    同步全部 (skills, agents, rules)"
  echo "  skills     仅同步 skills"
  echo "  agents     仅同步 agents"
  echo "  rules      仅同步 rules"
  echo ""
  echo "选项:"
  echo "  --dry-run      只预览将要发生的变更，不写入磁盘"
  echo "  --force        push 时跳过删除项交互确认（仅限非交互环境/CI，请谨慎）"
  echo "  --keep-newer   目标端文件 mtime 更新时跳过该文件（保守模式）"
  echo "  -h, --help     显示此帮助"
  echo ""
  echo "示例:"
  echo "  $0                     # pull 同步全部"
  echo "  $0 skills              # pull 仅同步 skills"
  echo "  $0 push                # push 同步全部（会先预览并确认）"
  echo "  $0 push rules          # push 仅同步 rules"
  echo "  $0 push --dry-run      # 预览 push 变更，不落盘"
}

# 构建 rsync 基础参数，结果写入全局数组 RSYNC_ARGS
# （用全局数组而非命令替换，兼容 macOS 自带的 bash 3.2 —— 无 mapfile）
build_rsync_args() {
  local dir="$1"
  RSYNC_ARGS=(-av --delete "${COMMON_EXCLUDES[@]}")

  # skills 目录需要额外排除运行时数据
  if [ "$dir" = "skills" ]; then
    RSYNC_ARGS+=("${SKILLS_EXCLUDES[@]}")
  fi

  # push 方向额外排除仓库侧独有的分发产物
  if [ "$DIRECTION" = "push" ]; then
    RSYNC_ARGS+=("${PUSH_EXCLUDES[@]}")
  fi

  if [ "$KEEP_NEWER" = true ]; then
    RSYNC_ARGS+=("--update")
  fi
}

# 预览单个目录的变更（不写盘），输出 rsync itemize 明细
preview_dir() {
  local dir="$1"
  local src="$SRC_ROOT/$dir"
  local dst="$DST_ROOT/$dir"

  [ -d "$src" ] && [ -d "$dst" ] || return

  build_rsync_args "$dir"
  # shellcheck disable=SC2086 # RSYNC_8BIT_OUTPUT 需允许为空展开
  rsync "${RSYNC_ARGS[@]}" --dry-run --itemize-changes $RSYNC_8BIT_OUTPUT "$src/" "$dst/" 2>/dev/null
}

sync_dir() {
  local dir="$1"
  local src="$SRC_ROOT/$dir"
  local dst="$DST_ROOT/$dir"

  if [ ! -d "$src" ]; then
    warn "源目录不存在，跳过: $src"
    return
  fi
  if [ ! -d "$dst" ]; then
    warn "目标目录不存在，跳过: $dst"
    return
  fi

  info "同步 $dir ..."

  build_rsync_args "$dir"

  if [ "$DRY_RUN" = true ]; then
    RSYNC_ARGS+=(--dry-run)
  fi

  rsync "${RSYNC_ARGS[@]}" "$src/" "$dst/"

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
  dir_changes=$(git -c core.quotepath=false status --porcelain -- "$dir/" 2>/dev/null)
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

# 方向：仅第一个位置参数生效
if [[ $# -gt 0 && ( "$1" == "push" || "$1" == "pull" ) ]]; then
  DIRECTION="$1"
  shift
fi

# 解析剩余参数（选项 + 目录名）
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)            DRY_RUN=true; shift ;;
    --force)              FORCE=true; shift ;;
    --keep-newer)         KEEP_NEWER=true; shift ;;
    skills|agents|rules)  SYNC_DIRS+=("$1"); shift ;;
    -h|--help)            usage; exit 0 ;;
    *)
      error "无效参数: $1（目录仅支持: ${ALL_DIRS[*]}）"
      echo ""
      usage
      exit 1
      ;;
  esac
done

# 未指定目录 → 同步全部
if [ ${#SYNC_DIRS[@]} -eq 0 ]; then
  SYNC_DIRS=("${ALL_DIRS[@]}")
fi

# 方向 → 源 / 目标
if [ "$DIRECTION" = "push" ]; then
  SRC_ROOT="$REPO_DIR"
  DST_ROOT="$RUNTIME_DIR"
  DIRECTION_LABEL="push  ai-coding-kit/  ──▶  ~/.codebuddy/"
else
  SRC_ROOT="$RUNTIME_DIR"
  DST_ROOT="$REPO_DIR"
  DIRECTION_LABEL="pull  ~/.codebuddy/  ──▶  ai-coding-kit/"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  ${BLUE}🔄 CodeBuddy 配置同步工具${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
info "方向: $DIRECTION_LABEL"
info "源: $SRC_ROOT"
info "目标: $DST_ROOT"
info "同步目录: ${SYNC_DIRS[*]}"
echo ""

# ==================== push 方向护栏 ====================
# 与 pull 不同，push 会覆盖运行时目录，而 ~/.codebuddy 下可能存在
# 非本仓库来源的内容（其他市场安装的 skill、本地手动改动等）。
# 因此 push 必须：预览 → 确认 → 备份 → 落盘。
# 返回值：0 = 允许执行；1 = 中止（已预览/已取消）
run_push_guard() {
  local dir pf
  PREVIEW_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sync-preview.XXXXXX")"
  for dir in "${SYNC_DIRS[@]}"; do
    preview_dir "$dir" > "$PREVIEW_DIR/$dir.txt"
  done

  # 汇总统计（逐目录累加，避免引入自我引用的汇总文件）
  local added=0 modified=0 deleted=0
  for dir in "${SYNC_DIRS[@]}"; do
    pf="$PREVIEW_DIR/$dir.txt"
    [ -f "$pf" ] || continue
    added=$(( added + $(grep -c '^>f+++' "$pf" 2>/dev/null || true) ))
    deleted=$(( deleted + $(grep -c '^\*deleting' "$pf" 2>/dev/null || true) ))
    modified=$(( modified + $(grep -E '^>f' "$pf" 2>/dev/null | grep -vc '^>f+++' || true) ))
  done

  echo -e "  ${BLUE}🔍 变更预览${NC}"
  echo ""
  echo -e "    新增: ${GREEN}${added}${NC} 个文件"
  echo -e "    修改: ${YELLOW}${modified}${NC} 个文件"
  echo -e "    删除: ${RED}${deleted}${NC} 个文件"
  echo ""

  if [ "$deleted" -gt 0 ]; then
    echo -e "  ${RED}⚠️  以下目标端文件将被删除：${NC}"
    cat "$PREVIEW_DIR"/*.txt 2>/dev/null | grep '^\*deleting' | sed 's/^[^ ]*  *//' | head -20 | while IFS= read -r line; do
      echo -e "      ${RED}- ${line}${NC}"
    done
    local rest=$((deleted - 20))
    [ "$rest" -gt 0 ] && echo -e "      ${RED}... 另有 ${rest} 项${NC}"
    echo ""
  fi

  # 纯预览模式：到此为止
  if [ "$DRY_RUN" = true ]; then
    warn "预览模式（--dry-run），未写入任何文件"
    return 1
  fi

  # 无变更：直接结束
  if [ "$added" -eq 0 ] && [ "$modified" -eq 0 ] && [ "$deleted" -eq 0 ]; then
    ok "目标端已与仓库一致，无需同步"
    return 1
  fi

  # 删除项二次确认（非交互环境必须显式 --force）
  if [ "$deleted" -gt 0 ]; then
    if [ ! -t 0 ]; then
      if [ "$FORCE" = true ]; then
        warn "非交互环境 + --force：跳过删除确认，直接执行"
      else
        error "本次同步会删除 ${deleted} 个目标端文件，非交互环境已中止"
        error "确认无误请加 --force，或先手工备份 ~/.codebuddy/"
        return 1
      fi
    else
      local reply=""
      printf "  ${YELLOW}将删除 %s 个目标端文件，确认继续？${NC} (y/N) " "$deleted"
      read -r reply || true
      echo ""
      if [[ ! "$reply" =~ ^[Yy]$ ]]; then
        warn "已取消，未做任何改动"
        return 1
      fi
    fi
  fi

  return 0
}

# 备份目标端将被覆盖/删除的文件到 BACKUP_DIR（保持原相对路径）
#
# 不使用 rsync --backup / --backup-dir 的原因：
#   macOS 自带的 openrsync（protocol 29）虽然接受这两个参数，但实测静默失效
#   —— 既不备份，还会连带导致 --delete 不生效。故改为基于预览明细手工 cp。
backup_targets() {
  local dir="$1"
  local preview_file="$PREVIEW_DIR/$dir.txt"
  [ -f "$preview_file" ] || return 0

  local count=0 rel src_path dst_path
  while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    src_path="$DST_ROOT/$dir/$rel"
    [ -e "$src_path" ] || continue
    dst_path="$BACKUP_DIR/$dir/$rel"
    mkdir -p "$(dirname "$dst_path")"
    cp -R "$src_path" "$dst_path"
    count=$((count + 1))
  done < <(grep -E '^(\*deleting|>f)' "$preview_file" | sed 's/^[^ ]*  *//')

  if [ "$count" -gt 0 ]; then
    info "已备份 $dir: $count 项"
  fi
}

# push 方向：护栏 → 备份 → 落盘
if [ "$DIRECTION" = "push" ]; then
  if ! run_push_guard; then
    rm -rf "$PREVIEW_DIR"
    echo ""
    exit 0
  fi
  BACKUP_DIR="$RUNTIME_DIR/.sync-backup/$(date '+%Y%m%d-%H%M%S')"
  mkdir -p "$BACKUP_DIR"
  info "备份目录: $BACKUP_DIR"
  echo ""
  for dir in "${SYNC_DIRS[@]}"; do
    backup_targets "$dir"
  done
fi

# 执行同步
for dir in "${SYNC_DIRS[@]}"; do
  sync_dir "$dir"
  echo ""
done

# 预览模式：同步已用 --dry-run 跑完，不再进入后续 Git 提交流程
if [ "$DRY_RUN" = true ]; then
  warn "预览模式（--dry-run），未写入任何文件"
  echo ""
  exit 0
fi

# push 方向到此结束（后续 Git 变更分析与交互式提交仅适用于 pull）
if [ "$DIRECTION" = "push" ]; then
  rm -rf "$PREVIEW_DIR"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  ok "push 同步完成"
  if [ -n "$BACKUP_DIR" ]; then
    info "被覆盖/删除的原文件已备份至: $BACKUP_DIR"
    warn "如发现异常，可从备份目录按原路径恢复"
  fi
  echo ""
  exit 0
fi

# 显示 Git 变更
cd "$REPO_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  ${BLUE}📋 Git 变更概览${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

CHANGES=$(git -c core.quotepath=false status --porcelain)
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
git -c core.quotepath=false status --short
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
      files=$(git -c core.quotepath=false status --porcelain -- "$item_path/" 2>/dev/null | awk '{print substr($0,4)}' | sed "s|^$dir/$item/||")
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
      changed_files=$(git -c core.quotepath=false status --porcelain -- "$item_path/" 2>/dev/null | awk '{print substr($0,4)}')
      local desc_parts=()

      while IFS= read -r filepath; do
        [ -z "$filepath" ] && continue
        # 去除可能的引号
        filepath="${filepath#\"}"
        filepath="${filepath%\"}"
        local basename_f
        basename_f=$(basename "$filepath")
        local status_code
        status_code=$(git -c core.quotepath=false status --porcelain -- "$filepath" 2>/dev/null | head -1 | cut -c1-2)

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
read -p "是否提交并推送到远程？(y/n) " -n 1 -r || true
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
  read -p "输入 commit message（回车使用上述建议）: " CUSTOM_MSG || true

  git add -A

  if [ -n "$CUSTOM_MSG" ]; then
    git commit -m "$CUSTOM_MSG"
  elif [ -n "$COMMIT_BODY" ]; then
    git commit -m "$COMMIT_HEADER" -m "$COMMIT_BODY"
  else
    git commit -m "$COMMIT_HEADER"
  fi

  echo ""
  read -p "确认推送到远程？(y/n) " -n 1 -r || true
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
