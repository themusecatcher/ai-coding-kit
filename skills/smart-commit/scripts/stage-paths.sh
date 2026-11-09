#!/usr/bin/env bash
# stage-paths.sh - 按批次精确暂存（分批提交专用）
#
# 与 `git add .` 的区别：本脚本强制显式传路径，并在暂存后做严格比对，
# 确保「暂存区里恰好只有本批计划内的文件」。比对失败即中止，不猜测不修复。
#
# 用法：
#   bash stage-paths.sh [--dry-run] <path> [path...]
#
# 退出码：
#   0 = 成功（dry-run 时表示"校验通过，未改动暂存区"）
#   1 = 非 git 仓库 / 无参数
#   2 = 非法参数或非法路径（`.`、以 ./ 开头、-A 等、路径不在改动清单中）
#   3 = 暂存区出现计划外文件（有别的改动被一起暂存了）
#   4 = 传入路径未被暂存（路径不匹配 / 已被忽略）
#   5 = 暂存区已含本批之外的文件（批次边界被污染，需先清理暂存区）

set -uo pipefail

usage() {
  cat <<'USAGE'
用法: stage-paths.sh [--dry-run] <path> [path...]

参数可为文件或目录（目录会展开为该目录下所有改动文件）:
  stage-paths.sh src/components/table src/views/table
  stage-paths.sh src/components            # 目录：整目录改动
  stage-paths.sh --dry-run docs/api.md
USAGE
}

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "ERROR: 当前目录不是 git 仓库" >&2
  exit 1
fi

# 统一在仓库根执行：入参路径一律相对仓库根，
# 避免与 repo-preflight.sh 输出的清单路径基准不一致。
STAGE_CWD="$(pwd)"
cd "$(git rev-parse --show-toplevel)" 2>/dev/null || {
  echo "ERROR: 无法进入仓库根目录" >&2
  exit 1
}
if [ "$STAGE_CWD" != "$(pwd)" ]; then
  echo "INFO: 已切换到仓库根执行 ($(pwd))，路径按仓库根解析" >&2
fi

DRY_RUN=0
PATHS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift ;;
    -*) echo "ERROR: 不支持参数 '$1' —— 分批模式必须显式传路径，禁止 git add . / -A" >&2; exit 2 ;;
    *) PATHS+=("$1"); shift ;;
  esac
done

if [ "${#PATHS[@]}" -eq 0 ]; then
  echo "ERROR: 未提供任何路径" >&2
  usage >&2
  exit 1
fi

for p in "${PATHS[@]}"; do
  case "$p" in
    ""|".")
      echo "ERROR: 禁止使用 '$p' —— 分批模式必须按批次精确指定路径" >&2
      exit 2
      ;;
    "./"*|"../"*|..)
      echo "ERROR: 路径 '$p' 请改用仓库相对路径（去掉 ./ 前缀）" >&2
      exit 2
      ;;
  esac
done

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/sc-stage.XXXXXX") || exit 1
trap 'rm -rf "$TMP_DIR"' EXIT

# ---------- 当前全量改动清单（untracked / deleted / rename 全覆盖） ----------
git -c core.quotePath=false status --porcelain -uall > "$TMP_DIR/porcelain" 2>/dev/null
: > "$TMP_DIR/inventory"
while IFS= read -r line; do
  if [ -z "$line" ]; then continue; fi
  xy="${line:0:2}"
  rest="${line:3}"
  path="$rest"
  case "$xy" in
    R*|*R) path=$(printf '%s' "$rest" | sed 's/^.* -> //') ;;
  esac
  printf '%s\n' "$path" >> "$TMP_DIR/inventory"
done < "$TMP_DIR/porcelain"
sort -u "$TMP_DIR/inventory" -o "$TMP_DIR/inventory"

# ---------- 入参校验 + 展开为具体文件 ----------
# 支持传目录（如 src/components）：展开为该目录下所有改动文件，
# 避免 LLM/用户按目录粒度规划批次时被误判为非法路径。
printf '%s\n' "${PATHS[@]}" | sed '/^$/d' | sort -u > "$TMP_DIR/paths"

: > "$TMP_DIR/illegal"
: > "$TMP_DIR/expected"
while IFS= read -r p; do
  if [ -z "$p" ]; then continue; fi
  matched=$(awk -v p="$p" '$0==p || index($0, p "/")==1' "$TMP_DIR/inventory" | head -1)
  if [ -z "$matched" ]; then
    printf '%s\n' "$p" >> "$TMP_DIR/illegal"
  else
    awk -v p="$p" '$0==p || index($0, p "/")==1' "$TMP_DIR/inventory" >> "$TMP_DIR/expected"
  fi
done < "$TMP_DIR/paths"
sort -u "$TMP_DIR/expected" -o "$TMP_DIR/expected"

if [ -s "$TMP_DIR/illegal" ]; then
  echo "ERROR: 以下路径不在当前改动清单中（拼写错误？已被 .gitignore 忽略？rename 后需传新路径？）" >&2
  sed 's/^/  - /' "$TMP_DIR/illegal" >&2
  echo "提示: 运行 scripts/repo-preflight.sh 查看完整改动清单" >&2
  exit 2
fi

# ---------- 暂存前快照 ----------
git -c core.quotePath=false diff --cached --name-only 2>/dev/null | sed '/^$/d' | sort -u > "$TMP_DIR/before"
BEFORE_COUNT=$(grep -c . "$TMP_DIR/before" 2>/dev/null)
BEFORE_COUNT=${BEFORE_COUNT:-0}

if [ "$BEFORE_COUNT" -gt 0 ]; then
  # 已暂存但不属于本批的文件 = 批次边界污染（上一批残留 / 用户手动 add 的无关文件）。
  # 只 WARN 不够：一旦继续提交，这批 commit 会混入别的东西。
  comm -23 "$TMP_DIR/before" "$TMP_DIR/expected" > "$TMP_DIR/contaminated" 2>/dev/null
  CONTAM_COUNT=$(grep -c . "$TMP_DIR/contaminated" 2>/dev/null)
  CONTAM_COUNT=${CONTAM_COUNT:-0}
  if [ "$CONTAM_COUNT" -gt 0 ]; then
    echo "ERROR: 暂存区已存在不属于本批的文件（批次边界被污染），拒绝继续：" >&2
    sed 's/^/  - /' "$TMP_DIR/contaminated" >&2
    echo "处理建议: git restore --staged <上述路径>   或把它们纳入本批计划后重跑" >&2
    exit 5
  fi
  echo "INFO: 暂存区已有 $BEFORE_COUNT 个文件，均属于本批（继续）" >&2
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "DRY-RUN: 校验通过，未改动暂存区，展开后共 $(grep -c . "$TMP_DIR/expected" 2>/dev/null) 个文件"
  sed 's/^/  - /' "$TMP_DIR/expected"
  exit 0
fi

# ---------- 精确暂存（-A 语义，覆盖新增/修改/删除/重命名） ----------
while IFS= read -r p; do
  if [ -z "$p" ]; then continue; fi
  git add -A -- "$p"
done < "$TMP_DIR/paths"

# ---------- 暂存后严格比对 ----------
git -c core.quotePath=false diff --cached --name-only 2>/dev/null | sed '/^$/d' | sort -u > "$TMP_DIR/after"
AFTER_COUNT=$(grep -c . "$TMP_DIR/after" 2>/dev/null)
AFTER_COUNT=${AFTER_COUNT:-0}

# 计划外：暂存后新增、但不属于本批（expected 为入参展开后的文件集合）
comm -13 "$TMP_DIR/before" "$TMP_DIR/after" 2>/dev/null | grep -vxF -f "$TMP_DIR/expected" > "$TMP_DIR/extra" 2>/dev/null
# 未生效：本批文件没有真正进入暂存区
comm -23 "$TMP_DIR/expected" "$TMP_DIR/after" 2>/dev/null > "$TMP_DIR/missing"

EXTRA_COUNT=$(grep -c . "$TMP_DIR/extra" 2>/dev/null)
EXTRA_COUNT=${EXTRA_COUNT:-0}
MISSING_COUNT=$(grep -c . "$TMP_DIR/missing" 2>/dev/null)
MISSING_COUNT=${MISSING_COUNT:-0}

if [ "$MISSING_COUNT" -gt 0 ]; then
  echo "ERROR: 以下路径暂存后仍未出现在暂存区（可能被 .gitignore 忽略，或路径指向不存在的内容）" >&2
  sed 's/^/  - /' "$TMP_DIR/missing" >&2
  exit 4
fi

if [ "$EXTRA_COUNT" -gt 0 ]; then
  echo "ERROR: 暂存区出现计划外文件（批次边界被破坏），请勿继续提交" >&2
  sed 's/^/  - /' "$TMP_DIR/extra" >&2
  echo "处理建议: git restore --staged <上述路径>   然后重新执行本脚本" >&2
  exit 3
fi

printf '{"dry_run":false,"staged_before":%d,"staged_after":%d,"batch_files":%d,"extra":0,"missing":0}\n' \
  "$BEFORE_COUNT" "$AFTER_COUNT" "$(grep -c . "$TMP_DIR/expected" 2>/dev/null)" >&2

echo "===== staged (batch) ====="
cat "$TMP_DIR/after"
exit 0
