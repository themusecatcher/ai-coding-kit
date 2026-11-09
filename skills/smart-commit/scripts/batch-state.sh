#!/usr/bin/env bash
# batch-state.sh - 分批提交进度持久化（支撑中断恢复）
#
# 为什么需要它：
#   分批提交是多轮交互，用户可能在中途离开。没有状态文件就必须重新分析全量改动，
#   而且无法确认「上一次提交到第几批、HEAD 有没有漂移」。
#
# 状态文件位置（不写入仓库、不碰 .git 配置）：
#   ${SC_STATE_DIR:-$HOME/.codebuddy/smart-commit/sessions}/<toplevel-hash>.state
#   多 worktree 因 toplevel 不同而各自独立。
#
# 用法：
#   batch-state.sh init <total_batches>
#   batch-state.sh status
#   batch-state.sh next --hash <commit_hash> [--header "<commit header>"]
#   batch-state.sh clear
#
# 退出码：0 = 成功；1 = 无状态/参数错误；2 = 非 git 仓库

set -uo pipefail

STATE_DIR="${SC_STATE_DIR:-$HOME/.codebuddy/smart-commit/sessions}"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "ERROR: 当前目录不是 git 仓库" >&2
  exit 2
fi

TOPLEVEL=$(git rev-parse --show-toplevel)
if command -v shasum >/dev/null 2>&1; then
  REPO_HASH=$(printf '%s' "$TOPLEVEL" | shasum -a 256 | awk '{print $1}')
else
  REPO_HASH=$(printf '%s' "$TOPLEVEL" | cksum | awk '{print $1}')
fi
STATE_FILE="$STATE_DIR/$REPO_HASH.state"

now() { date '+%Y-%m-%d %H:%M:%S'; }

get_field() {
  local file="$1" key="$2"
  awk -F'\t' -v k="$key" '$1==k {print $2; exit}' "$file" 2>/dev/null
}

set_field() {
  local file="$1" key="$2" value="$3" tmp
  tmp="${file}.tmp.$$"
  awk -F'\t' -v OFS='\t' -v k="$key" -v v="$value" '
    $1==k { $2=v; found=1 }
    { print }
    END { if (!found) print k, v }
  ' "$file" > "$tmp" && mv -f "$tmp" "$file"
}

json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

CMD="${1:-}"
shift 2>/dev/null || true

case "$CMD" in
  init)
    TOTAL="${1:-0}"
    case "$TOTAL" in
      ''|*[!0-9]*) echo "ERROR: init 需要一个正整数批次总数" >&2; exit 1 ;;
    esac
    if [ "$TOTAL" -lt 1 ]; then
      echo "ERROR: 批次总数必须 >= 1" >&2
      exit 1
    fi
    mkdir -p "$STATE_DIR" || { echo "ERROR: 无法创建状态目录 $STATE_DIR" >&2; exit 1; }
    {
      printf 'repo\t%s\n' "$TOPLEVEL"
      printf 'branch\t%s\n' "$(git symbolic-ref -q --short HEAD || echo '<detached>')"
      printf 'base_head\t%s\n' "$(git rev-parse HEAD 2>/dev/null || echo '<none>')"
      printf 'total\t%s\n' "$TOTAL"
      printf 'current\t1\n'
      printf 'created_at\t%s\n' "$(now)"
      printf 'updated_at\t%s\n' "$(now)"
    } > "$STATE_FILE"
    echo "OK: 批次状态已创建（共 $TOTAL 批，当前第 1 批）"
    echo "state: $STATE_FILE"
    ;;

  status|resume)
    if [ ! -f "$STATE_FILE" ]; then
      echo "NO_STATE: 当前仓库没有进行中的分批提交" >&2
      exit 1
    fi
    CURRENT=$(get_field "$STATE_FILE" current)
    TOTAL=$(get_field "$STATE_FILE" total)
    BRANCH=$(get_field "$STATE_FILE" branch)
    BASE_HEAD=$(get_field "$STATE_FILE" base_head)
    UPDATED=$(get_field "$STATE_FILE" updated_at)
    REMAINING=$((TOTAL - CURRENT + 1))

    printf '{"repo":"%s","branch":"%s","current":%d,"total":%d,"remaining":%d,"base_head":"%s","updated_at":"%s"}\n' \
      "$(json_escape "$TOPLEVEL")" "$(json_escape "$BRANCH")" "$CURRENT" "$TOTAL" "$REMAINING" \
      "$(json_escape "$BASE_HEAD")" "$(json_escape "$UPDATED")"

    echo ""
    echo "===== batch state ====="
    echo "repo:      $TOPLEVEL"
    echo "branch:    $BRANCH"
    echo "progress:  $CURRENT / $TOTAL   (remaining $REMAINING)"
    echo "base_head: $BASE_HEAD"
    echo "updated:   $UPDATED"
    echo ""
    echo "===== committed batches ====="
    awk -F'\t' '$1=="batch" { printf "  #%s  %s  %s\n", $2, ($3==""?"-":$3), ($4==""?"-":$4) }' "$STATE_FILE"
    ;;

  next)
    if [ ! -f "$STATE_FILE" ]; then
      echo "NO_STATE: 当前仓库没有进行中的分批提交" >&2
      exit 1
    fi
    HASH=""
    HEADER=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --hash) HASH="${2:-}"; shift 2 ;;
        --header) HEADER="${2:-}"; shift 2 ;;
        *) shift ;;
      esac
    done
    HASH=$(printf '%s' "$HASH" | tr '\t\n' '  ')
    HEADER=$(printf '%s' "$HEADER" | tr '\t\n' '  ')

    CURRENT=$(get_field "$STATE_FILE" current)
    TOTAL=$(get_field "$STATE_FILE" total)

    if [ "$CURRENT" -gt "$TOTAL" ]; then
      echo "DONE: 全部 $TOTAL 批已完成，无需继续推进（如需重来请先 init）" >&2
      exit 0
    fi

    if [ -n "$HASH" ]; then
      ACTUAL_HEAD=$(git rev-parse HEAD 2>/dev/null || echo "")
      # 允许传短 hash：先解析为完整 hash 再比对，避免短/长写法差异被误报成「额外提交」
      RESOLVED_HASH=$(git rev-parse --verify --quiet "${HASH}^{commit}" 2>/dev/null || echo "")
      if [ -n "$RESOLVED_HASH" ]; then
        HASH="$RESOLVED_HASH"
      fi
      if [ "$ACTUAL_HEAD" != "$HASH" ]; then
        echo "WARN: 记录的 hash ($HASH) 与当前 HEAD ($ACTUAL_HEAD) 不一致，可能存在额外提交" >&2
      fi
    fi

    printf 'batch\t%s\t%s\t%s\n' "$CURRENT" "${HASH:--}" "${HEADER:--}" >> "$STATE_FILE"
    NEW_CURRENT=$((CURRENT + 1))
    set_field "$STATE_FILE" current "$NEW_CURRENT"
    set_field "$STATE_FILE" updated_at "$(now)"

    if [ "$CURRENT" -ge "$TOTAL" ]; then
      echo "COMPLETED: 第 $CURRENT/$TOTAL 批已记录，全部批次处理完毕"
      echo "提示: 执行 batch-state.sh clear 清理状态文件"
    else
      echo "OK: 第 $CURRENT/$TOTAL 批已记录，下一批为第 $NEW_CURRENT 批"
    fi
    ;;

  clear)
    if [ -f "$STATE_FILE" ]; then
      rm -f "$STATE_FILE"
      echo "OK: 分批状态已清理"
    else
      echo "NO_STATE: 无需清理"
    fi
    ;;

  *)
    cat <<'USAGE' >&2
用法:
  batch-state.sh init <total_batches>
  batch-state.sh status          # resume 为等价别名
  batch-state.sh next --hash <commit_hash> [--header "<commit header>"]
  batch-state.sh clear
USAGE
    exit 1
    ;;
esac

exit 0
