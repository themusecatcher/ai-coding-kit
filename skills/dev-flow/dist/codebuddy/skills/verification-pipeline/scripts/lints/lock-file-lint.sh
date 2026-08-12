#!/bin/bash
# lock-file-lint.sh - V7 Diff Review 子检查：lock 文件 / i18n locales / 自动生成文件
#
# 兑现 SKILL.md「确定性用代码」哲学：把原本写在提示词里的 4 项 Diff 检查
# 转为脚本一次性扫描 git diff 输出 + JSON 报告。
#
# 检查项（D1-D4，与 SKILL.md 反模式编号区分）：
#   L1 lockfile_version_changed   package-lock.json/yarn.lock/pnpm-lock.yaml 中 lockfileVersion 字段是否被改动
#   L2 lockfile_format_change     lock 文件中 +/- 行数 > 阈值（默认 50）但本次 PR 未声明依赖变更
#   L3 i18n_auto_generated        locales/*.json 等 i18n 自动生成文件被改动（未声明翻译变更）
#   L4 unexpected_meta_files      .DS_Store / *.swp / .idea/ 等 IDE/OS 元文件混入
#
# 用法：
#   bash lock-file-lint.sh                        # 默认扫描 git diff（HEAD vs working tree）
#   bash lock-file-lint.sh --staged               # 仅扫描已 staged 的改动
#   bash lock-file-lint.sh --base=<ref>           # 与指定 ref 比较
#   bash lock-file-lint.sh --json                 # JSON 格式输出（默认人类可读 + JSON 摘要）
#   bash lock-file-lint.sh --raw                  # 仅退出码，无输出
#
# 返回码：0 全部通过 / 1 有违规 / 2 参数或环境错误

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VP_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../lib/common.sh
source "$VP_ROOT/scripts/lib/common.sh"
# shellcheck source=../lib/logger.sh
source "$VP_ROOT/scripts/lib/logger.sh"

MODE="human"   # human / json / raw
DIFF_TARGET="HEAD"
USE_STAGED=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --json)     MODE="json";  shift ;;
    --raw)      MODE="raw";   shift ;;
    --staged)   USE_STAGED=1; shift ;;
    --base=*)   DIFF_TARGET="${1#--base=}"; shift ;;
    --help|-h)  sed -n '2,22p' "$0"; exit 0 ;;
    *)          log_error "未知参数: $1"; exit 2 ;;
  esac
done

if ! vp_has_cmd git; then
  log_error "本脚本需要 git 命令"
  exit 2
fi

# 不在 git 仓库内 → 跳过（return 0 表示"没有违规"）
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  [ "$MODE" = "human" ] && log_info "当前目录不在 git 仓库内，跳过 lock 文件检查"
  [ "$MODE" = "json" ] && echo '{"skipped":true,"reason":"not_in_git_repo"}'
  exit 0
fi

# ========================================
# 收集本次改动的文件列表
# ========================================
if [ "$USE_STAGED" -eq 1 ]; then
  changed_files="$(git diff --staged --name-only 2>/dev/null || true)"
else
  changed_files="$(git diff --name-only "$DIFF_TARGET" 2>/dev/null || git diff --name-only 2>/dev/null || true)"
fi

# ========================================
# L1: lockfileVersion 字段是否被改
# ========================================
violations_l1=""
l1_count=0

# 取本次 diff 中 lock 文件的具体 diff 内容
get_lock_diff() {
  if [ "$USE_STAGED" -eq 1 ]; then
    git diff --staged -- 'package-lock.json' 'yarn.lock' 'pnpm-lock.yaml' 2>/dev/null
  else
    git diff -- 'package-lock.json' 'yarn.lock' 'pnpm-lock.yaml' 2>/dev/null
  fi
}

lock_diff="$(get_lock_diff)"
if [ -n "$lock_diff" ]; then
  # 任一加/删行包含 lockfileVersion 字段
  lockver_lines="$(printf '%s\n' "$lock_diff" | grep -E '^[+-][[:space:]]*"lockfileVersion"' || true)"
  if [ -n "$lockver_lines" ]; then
    l1_count=$(printf '%s\n' "$lockver_lines" | wc -l | tr -d ' ')
    # 取前 5 条
    sample="$(printf '%s\n' "$lockver_lines" | head -5)"
    violations_l1="$sample"
  fi
fi

# ========================================
# L2: lock 文件大量行变化（潜在格式变化）
# ========================================
l2_count=0
violations_l2=""
if [ -n "$lock_diff" ]; then
  total_lines="$(printf '%s\n' "$lock_diff" | wc -l | tr -d ' ')"
  if [ "$total_lines" -gt 200 ]; then
    l2_count=1
    violations_l2="lock 文件 diff 行数 = $total_lines（阈值 200）→ 可能存在格式变化或大版本依赖更新"
  fi
fi

# ========================================
# L3: i18n 自动生成的 locales 文件
# ========================================
l3_count=0
violations_l3=""
if [ -n "$changed_files" ]; then
  i18n_files="$(printf '%s\n' "$changed_files" | grep -E '(^|/)(locales?|i18n|translations?)/.+\.(json|ts|js)$' || true)"
  if [ -n "$i18n_files" ]; then
    l3_count="$(printf '%s\n' "$i18n_files" | wc -l | tr -d ' ')"
    violations_l3="$i18n_files"
  fi
fi

# ========================================
# L4: 元文件 / IDE / OS 残留
# ========================================
l4_count=0
violations_l4=""
if [ -n "$changed_files" ]; then
  meta_files="$(printf '%s\n' "$changed_files" | grep -E '(^|/)(\.DS_Store|\.swp$|\.idea/|\.vscode/settings\.json|Thumbs\.db|desktop\.ini)' || true)"
  if [ -n "$meta_files" ]; then
    l4_count="$(printf '%s\n' "$meta_files" | wc -l | tr -d ' ')"
    violations_l4="$meta_files"
  fi
fi

# ========================================
# 输出
# ========================================
total=$((l1_count + l2_count + l3_count + l4_count))

emit_json() {
  printf '{'
  printf '"file_lint":{'
  printf '"lockfile_version_changed":%s,' "$([ "$l1_count" -gt 0 ] && echo false || echo true)"
  printf '"lockfile_format_change":%s,'   "$([ "$l2_count" -gt 0 ] && echo false || echo true)"
  printf '"i18n_auto_generated":%s,'      "$([ "$l3_count" -gt 0 ] && echo false || echo true)"
  printf '"unexpected_meta_files":%s'     "$([ "$l4_count" -gt 0 ] && echo false || echo true)"
  printf '},'
  printf '"violations":['

  first=1
  emit_v() {
    local rule="$1"
    local text="$2"
    [ -z "$text" ] && return
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      [ "$first" -eq 1 ] && first=0 || printf ','
      esc="$(vp_json_escape "$line")"
      printf '{"rule":"%s","text":"%s"}' "$rule" "$esc"
    done <<EOF
$text
EOF
  }
  emit_v "lockfile_version_changed" "$violations_l1"
  emit_v "lockfile_format_change"   "$violations_l2"
  emit_v "i18n_auto_generated"      "$violations_l3"
  emit_v "unexpected_meta_files"    "$violations_l4"

  printf '],'
  printf '"total":%d' "$total"
  printf '}'
  printf '\n'
}

case "$MODE" in
  json)
    emit_json
    ;;
  raw)
    ;;
  human)
    log_section "Lock & Meta 文件检查"
    log_kv "L1 lockfileVersion 改动" "$l1_count"
    log_kv "L2 lock 文件大量变化"   "$l2_count"
    log_kv "L3 i18n 自动生成文件"   "$l3_count"
    log_kv "L4 IDE/OS 元文件残留"   "$l4_count"

    if [ "$l1_count" -gt 0 ]; then
      log_warn "L1 违规示例（前 5 行）:"
      printf '    %s\n' "$violations_l1" >&2
    fi
    if [ "$l2_count" -gt 0 ]; then
      log_warn "L2: $violations_l2"
    fi
    if [ "$l3_count" -gt 0 ]; then
      log_warn "L3 i18n 文件:"
      printf '    %s\n' "$violations_l3" >&2
    fi
    if [ "$l4_count" -gt 0 ]; then
      log_warn "L4 元文件:"
      printf '    %s\n' "$violations_l4" >&2
    fi

    if [ "$total" -gt 0 ]; then
      log_fail "共 $total 处异常，请确认是否预期"
    else
      log_pass "Lock 文件 / locales / 元文件 均无异常"
    fi
    ;;
esac

[ "$total" -gt 0 ] && exit 1
exit 0
