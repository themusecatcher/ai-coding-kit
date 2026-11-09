#!/usr/bin/env bash
# repo-preflight.sh - 仓库体检 + 全量改动清单采集（分批提交前置）
#
# 为什么需要它：
#   `git diff` 看不到 untracked 文件，只靠 diff 会漏掉新建文件，
#   导致分批方案不完整、批次校验失真。本脚本统一用 `git status --porcelain -uall`
#   作为唯一真相源，覆盖 untracked / deleted / renamed 全部状态。
#
# 输出：
#   stderr：单行 JSON（结构化事实，供 LLM 判定）
#   stdout：人读清单（环境 / 体量 / 文件分组 / 敏感与产物标记）
# 退出码：0 = 成功；1 = 不是 git 仓库
#
# 设计哲学：本脚本只产出「确定性事实」，不判断主题归属（那是 LLM 的事）。
# 注意：刻意不使用 set -e —— 采集脚本单点失败不应中断整体体检。

set -uo pipefail

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "ERROR: 当前目录不是 git 仓库" >&2
  exit 1
fi

# 配置路径必须先转绝对路径：下面会 cd 到仓库根，相对路径会失效
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config/action-map.yaml"

# 统一在仓库根执行：否则 `git status --porcelain` 输出的是相对当前子目录的路径，
# 与后续 `git add -A -- <path>` 的基准可能错位，导致批次边界比对失真。
PREFLIGHT_CWD="$(pwd)"
cd "$(git rev-parse --show-toplevel)" 2>/dev/null || {
  echo "ERROR: 无法进入仓库根目录" >&2
  exit 1
}
if [ "$PREFLIGHT_CWD" != "$(pwd)" ]; then
  echo "INFO: 已切换到仓库根执行 ($(pwd))，清单路径均相对仓库根" >&2
fi

# ---------- 读取 batch 配置 ----------
read_scalar() {
  local key="$1" fallback="$2"
  [ -f "$CONFIG_FILE" ] || { printf '%s' "$fallback"; return; }
  local v
  v=$(awk -v key="$key" '
    /^batch:/ { in_batch=1; next }
    in_batch && /^[a-zA-Z]/ { in_batch=0 }
    in_batch && $1 == key":" { print $2; exit }
  ' "$CONFIG_FILE")
  if [ -n "${v:-}" ]; then printf '%s' "$v"; else printf '%s' "$fallback"; fi
}

read_list() {
  local key="$1"
  [ -f "$CONFIG_FILE" ] || return 0
  awk -v target="$key" '
    /^batch:/ { in_batch=1; next }
    in_batch && /^[a-zA-Z]/ { in_batch=0 }
    in_batch && /^  [a-zA-Z_]+:/ {
      k=$1; sub(":", "", k); in_list=(k == target); next
    }
    in_batch && in_list && /^    - / {
      l=$0; sub(/^    - /, "", l); gsub(/"/, "", l); print l
    }
  ' "$CONFIG_FILE"
}

BATCH_ENABLED=$(read_scalar enabled true)
MIN_FILES=$(read_scalar min_files 5)
DIFF_TRIGGER=$(read_scalar diff_lines_trigger 200)
MAX_THEME_RATIO=$(read_scalar max_theme_file_ratio 0.7)
MAX_BATCHES=$(read_scalar max_batches 6)
MIN_THEMES=$(read_scalar min_themes 2)

SENSITIVE_DEFAULT='.env
.env.*
*.pem
*.key
*.p12
*.keystore
id_rsa*
credentials*'
GENERATED_DEFAULT='dist/*
es/*
lib/*
*.lock'

SENSITIVE_LIST=$(read_list sensitive_patterns)
if [ -z "${SENSITIVE_LIST:-}" ]; then SENSITIVE_LIST="$SENSITIVE_DEFAULT"; fi
GENERATED_LIST=$(read_list generated_patterns)
if [ -z "${GENERATED_LIST:-}" ]; then GENERATED_LIST="$GENERATED_DEFAULT"; fi

json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

# ---------- 环境体检 ----------
TOPLEVEL=$(git rev-parse --show-toplevel)
BRANCH=$(git symbolic-ref -q --short HEAD || true)
DETACHED="false"
if [ -z "$BRANCH" ]; then DETACHED="true"; fi

OP="none"
if [ -f "$(git rev-parse --git-path MERGE_HEAD 2>/dev/null)" ]; then OP="merge"; fi
if [ -d "$(git rev-parse --git-path rebase-merge 2>/dev/null)" ]; then OP="rebase"; fi
if [ -d "$(git rev-parse --git-path rebase-apply 2>/dev/null)" ]; then OP="rebase"; fi
if [ -f "$(git rev-parse --git-path CHERRY_PICK_HEAD 2>/dev/null)" ]; then OP="cherry-pick"; fi
if [ -f "$(git rev-parse --git-path REVERT_HEAD 2>/dev/null)" ]; then OP="revert"; fi

# ---------- 全量改动清单（唯一真相源） ----------
TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/sc-preflight.XXXXXX") || exit 1
trap 'rm -rf "$TMP_DIR"' EXIT

ALL_PATHS="$TMP_DIR/all"
STAGED_PATHS="$TMP_DIR/staged"
UNSTAGED_PATHS="$TMP_DIR/unstaged"
UNTRACKED_PATHS="$TMP_DIR/untracked"
DELETED_PATHS="$TMP_DIR/deleted"
RENAMED_PATHS="$TMP_DIR/renamed"
: > "$ALL_PATHS"; : > "$STAGED_PATHS"; : > "$UNSTAGED_PATHS"
: > "$UNTRACKED_PATHS"; : > "$DELETED_PATHS"; : > "$RENAMED_PATHS"

git -c core.quotePath=false status --porcelain -uall > "$TMP_DIR/porcelain" 2>/dev/null

while IFS= read -r line; do
  if [ -z "$line" ]; then continue; fi
  xy="${line:0:2}"
  rest="${line:3}"
  path="$rest"
  case "$xy" in
    R*|*R)
      # rename 显示为 "old -> new"，暂存按新路径 add（git add -A 会带上旧路径的删除）
      path=$(printf '%s' "$rest" | sed 's/^.* -> //')
      printf '%s\n' "$path" >> "$RENAMED_PATHS"
      ;;
  esac
  case "$xy" in
    D*|*D) printf '%s\n' "$path" >> "$DELETED_PATHS" ;;
  esac
  if [ "$xy" = "??" ]; then
    printf '%s\n' "$path" >> "$UNTRACKED_PATHS"
  else
    xchar="${xy:0:1}"
    ychar="${xy:1:1}"
    if [ "$xchar" != " " ] && [ "$xchar" != "?" ]; then
      printf '%s\n' "$path" >> "$STAGED_PATHS"
    fi
    if [ "$ychar" != " " ] && [ "$ychar" != "?" ]; then
      printf '%s\n' "$path" >> "$UNSTAGED_PATHS"
    fi
  fi
  printf '%s\n' "$path" >> "$ALL_PATHS"
done < "$TMP_DIR/porcelain"

for f in "$ALL_PATHS" "$STAGED_PATHS" "$UNSTAGED_PATHS" "$UNTRACKED_PATHS" "$DELETED_PATHS" "$RENAMED_PATHS"; do
  sort -u "$f" -o "$f" 2>/dev/null
done

count_lines() {
  local n
  n=$(grep -c . "$1" 2>/dev/null)
  printf '%s' "${n:-0}"
}

CHANGED_FILES=$(count_lines "$ALL_PATHS")
STAGED_COUNT=$(count_lines "$STAGED_PATHS")
UNSTAGED_COUNT=$(count_lines "$UNSTAGED_PATHS")
UNTRACKED_COUNT=$(count_lines "$UNTRACKED_PATHS")
DELETED_COUNT=$(count_lines "$DELETED_PATHS")
RENAMED_COUNT=$(count_lines "$RENAMED_PATHS")

# 同一文件同时存在已暂存与未暂存改动 → 无法安全分批
comm -12 "$STAGED_PATHS" "$UNSTAGED_PATHS" > "$TMP_DIR/mixed" 2>/dev/null
MIXED_COUNT=$(count_lines "$TMP_DIR/mixed")

# ---------- 体量统计（估算：同一文件的 staged+unstaged 会各计一次） ----------
ADDED=0
DELETED_LINES=0
BINARY=0
collect_numstat() {
  local out a d
  out=$(git -c core.quotePath=false diff --numstat "$@" 2>/dev/null || true)
  if [ -z "$out" ]; then return 0; fi
  for a in $(printf '%s\n' "$out" | awk '$1=="-"{print "B"} $1!="-"{print $1}'); do
    if [ "$a" = "B" ]; then
      BINARY=$((BINARY + 1))
    else
      ADDED=$((ADDED + a))
    fi
  done
  for d in $(printf '%s\n' "$out" | awk '$2=="-"{next} {print $2}'); do
    DELETED_LINES=$((DELETED_LINES + d))
  done
}
collect_numstat --cached
collect_numstat

# untracked 文件行数（文本文件才计入）
UNTRACKED_LINES=0
while IFS= read -r f; do
  if [ -z "$f" ]; then continue; fi
  if [ ! -f "$f" ]; then continue; fi
  if [ ! -s "$f" ]; then
    continue
  fi
  if grep -Iq . "$f" 2>/dev/null; then
    n=$(wc -l < "$f" 2>/dev/null | tr -d ' ')
    UNTRACKED_LINES=$((UNTRACKED_LINES + ${n:-0}))
  else
    BINARY=$((BINARY + 1))
  fi
done < "$UNTRACKED_PATHS"

TOTAL_LINES=$((ADDED + DELETED_LINES + UNTRACKED_LINES))

# ---------- 顶层目录聚合 ----------
awk -F/ '{ if (NF > 1) print $1; else print "." }' "$ALL_PATHS" 2>/dev/null | sort | uniq -c | sort -rn > "$TMP_DIR/dirs"

# ---------- 敏感文件 / 生成产物标记 ----------
match_patterns() {
  local path="$1" list="$2" base pat
  base=$(basename "$path")
  while IFS= read -r pat; do
    if [ -z "$pat" ]; then continue; fi
    # shellcheck disable=SC2254
    case "$path" in $pat) return 0 ;; esac
    # shellcheck disable=SC2254
    case "$base" in $pat) return 0 ;; esac
  done <<EOF
$list
EOF
  return 1
}

: > "$TMP_DIR/sensitive"
: > "$TMP_DIR/generated"
while IFS= read -r f; do
  if [ -z "$f" ]; then continue; fi
  if match_patterns "$f" "$SENSITIVE_LIST"; then printf '%s\n' "$f" >> "$TMP_DIR/sensitive"; fi
  if match_patterns "$f" "$GENERATED_LIST"; then printf '%s\n' "$f" >> "$TMP_DIR/generated"; fi
done < "$ALL_PATHS"

# ---------- 分批阻塞项 ----------
BLOCKED="none"
if [ "$OP" != "none" ]; then
  BLOCKED="$OP"
elif [ "$MIXED_COUNT" -gt 0 ]; then
  BLOCKED="mixed-stage"
fi

VOLUME_TRIGGER="false"
if [ "$CHANGED_FILES" -ge "$MIN_FILES" ] || [ "$TOTAL_LINES" -gt "$DIFF_TRIGGER" ]; then
  VOLUME_TRIGGER="true"
fi

# batch.enabled=false 时强制单批（配置级总开关）
if [ "$BATCH_ENABLED" = "false" ]; then
  VOLUME_TRIGGER="false"
fi

# ---------- stderr：结构化事实 ----------
printf '{"repo":true,"toplevel":"%s","branch":"%s","detached":%s,"op":"%s","blocked":"%s","batch_enabled":"%s","volume_trigger":%s,"changed_files":%d,"staged":%d,"unstaged":%d,"untracked":%d,"deleted":%d,"renamed":%d,"mixed_files":%d,"added_lines":%d,"deleted_lines":%d,"untracked_lines":%d,"total_lines":%d,"binary":%d,"min_files":%s,"diff_lines_trigger":%s,"max_theme_file_ratio":%s,"max_batches":%s,"min_themes":%s}\n' \
  "$(json_escape "$TOPLEVEL")" "$(json_escape "$BRANCH")" "$DETACHED" "$OP" "$BLOCKED" "$BATCH_ENABLED" "$VOLUME_TRIGGER" \
  "$CHANGED_FILES" "$STAGED_COUNT" "$UNSTAGED_COUNT" "$UNTRACKED_COUNT" "$DELETED_COUNT" "$RENAMED_COUNT" "$MIXED_COUNT" \
  "$ADDED" "$DELETED_LINES" "$UNTRACKED_LINES" "$TOTAL_LINES" "$BINARY" \
  "$MIN_FILES" "$DIFF_TRIGGER" "$MAX_THEME_RATIO" "$MAX_BATCHES" "$MIN_THEMES" >&2

# ---------- stdout：人读清单 ----------
echo "===== repo ====="
echo "toplevel: $TOPLEVEL"
echo "branch:   ${BRANCH:-<detached HEAD>}"
echo "op:       $OP"
if [ "$BLOCKED" != "none" ]; then
  echo "blocked:  $BLOCKED  !! 禁止分批提交，先处理该状态"
fi
echo ""
echo "===== volume ====="
echo "changed_files:   $CHANGED_FILES  (staged=$STAGED_COUNT unstaged=$UNSTAGED_COUNT untracked=$UNTRACKED_COUNT deleted=$DELETED_COUNT renamed=$RENAMED_COUNT)"
echo "lines:           +$ADDED -$DELETED_LINES (untracked +$UNTRACKED_LINES) = $TOTAL_LINES"
echo "batch_enabled:   $BATCH_ENABLED"
if [ "$VOLUME_TRIGGER" = "true" ]; then
  echo "volume_trigger:  true   (min_files=$MIN_FILES, diff_lines_trigger=$DIFF_TRIGGER)"
else
  echo "volume_trigger:  false  (min_files=$MIN_FILES, diff_lines_trigger=$DIFF_TRIGGER)"
fi
if [ "$MIXED_COUNT" -gt 0 ]; then
  echo "mixed_files:     $MIXED_COUNT  !! 同一文件同时有已暂存与未暂存改动"
fi
echo ""
echo "===== changed files ====="
cat "$ALL_PATHS"
echo ""
echo "===== top dirs ====="
cat "$TMP_DIR/dirs"
if [ -s "$TMP_DIR/sensitive" ]; then
  echo ""
  echo "===== sensitive (建议排除出所有批次) ====="
  cat "$TMP_DIR/sensitive"
fi
if [ -s "$TMP_DIR/generated" ]; then
  echo ""
  echo "===== generated artifacts (排查/提示) ====="
  cat "$TMP_DIR/generated"
fi
if [ -s "$RENAMED_PATHS" ]; then
  echo ""
  echo "===== renamed (add 新路径即可) ====="
  cat "$RENAMED_PATHS"
fi
if [ "$BLOCKED" = "mixed-stage" ]; then
  echo ""
  echo "===== mixed-stage files ====="
  cat "$TMP_DIR/mixed"
  echo "建议先统一暂存区: git add -A  或  git restore --staged ."
fi
exit 0
