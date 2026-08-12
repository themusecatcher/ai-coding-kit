#!/bin/bash
# secret-grep-lint.sh - V6 Security 子检查：硬编码密钥 / XSS 风险点
#
# 兑现「确定性用代码」哲学：把 SKILL.md 提示词中的两条 grep 命令
# 升级为带规则集 + JSON 报告 + 误报豁免的脚本。
#
# 检查项（S1-S6）：
#   S1 openai_api_key       sk-[A-Za-z0-9]{20+}（OpenAI / Anthropic / Stripe 等通用前缀）
#   S2 generic_secret       api_key / apikey / secret / token / password = "..."（赋值式硬编码）
#   S3 aws_access_key       AKIA[0-9A-Z]{16}
#   S4 dangerously_set_html dangerouslySetInnerHTML 使用
#   S5 inner_html           .innerHTML = （非 textContent）
#   S6 document_write       document.write(
#
# 用法：
#   bash secret-grep-lint.sh <file1> [file2 ...]
#   bash secret-grep-lint.sh --staged                  # 扫描已 staged 的源码文件
#   bash secret-grep-lint.sh --json <file...>          # JSON 输出
#   bash secret-grep-lint.sh --raw <file...>           # 仅退出码
#   bash secret-grep-lint.sh --diff-only <file...>     # 仅检查 git diff 新增行
#
# 返回码：0 全部通过 / 1 有违规 / 2 参数错误

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VP_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../lib/common.sh
source "$VP_ROOT/scripts/lib/common.sh"
# shellcheck source=../lib/logger.sh
source "$VP_ROOT/scripts/lib/logger.sh"

MODE="human"
USE_STAGED=0
DIFF_ONLY=0

FILES=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --json)      MODE="json"; shift ;;
    --raw)       MODE="raw";  shift ;;
    --staged)    USE_STAGED=1; shift ;;
    --diff-only) DIFF_ONLY=1;  shift ;;
    --help|-h)   sed -n '2,22p' "$0"; exit 0 ;;
    --*)         log_error "未知参数: $1"; exit 2 ;;
    *)           FILES+=("$1"); shift ;;
  esac
done

# 通过 --staged 自动收集文件
if [ "$USE_STAGED" -eq 1 ]; then
  if ! vp_has_cmd git || ! git rev-parse --git-dir >/dev/null 2>&1; then
    log_error "--staged 需要在 git 仓库内"
    exit 2
  fi
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    case "$f" in
      *.ts|*.tsx|*.js|*.jsx|*.vue|*.mjs|*.cjs) FILES+=("$f") ;;
    esac
  done < <(git diff --staged --name-only --diff-filter=ACM 2>/dev/null)
fi

if [ ${#FILES[@]} -eq 0 ]; then
  log_error "未指定要扫描的文件"
  echo "用法: bash secret-grep-lint.sh [--json|--raw] [--staged] <file...>" >&2
  exit 2
fi

# ========================================
# 规则定义（macOS grep -E 兼容）
# 用 vp_rule_<id>_pattern 形式存储，便于循环
# ========================================
RULES=(
  "S1:openai_api_key:(sk-[A-Za-z0-9]{20,})"
  "S2:generic_secret:(api[_-]?key|apikey|secret|password|token)[[:space:]]*[:=][[:space:]]*[\"'][A-Za-z0-9_\\-]{16,}[\"']"
  "S3:aws_access_key:(AKIA[0-9A-Z]{16})"
  "S4:dangerously_set_html:dangerouslySetInnerHTML"
  "S5:inner_html:\.innerHTML[[:space:]]*="
  "S6:document_write:document\.write[[:space:]]*\\("
)

# 误报豁免：行内含 [VP-IGNORE-SECRET] 注释或所在文件是测试 fixture
is_exempted_line() {
  local line="$1"
  case "$line" in
    *"[VP-IGNORE-SECRET]"*) return 0 ;;
  esac
  return 1
}

is_exempted_file() {
  local f="$1"
  case "$f" in
    */tests/fixtures/*|*/__fixtures__/*|*/__mocks__/*) return 0 ;;
    *.test.*|*.spec.*) return 0 ;;
  esac
  return 1
}

# ========================================
# 扫描单个文件
# 输出：每一行 violation = "rule_id|file|line|matched_text"
# ========================================
scan_file() {
  local file="$1"
  if [ ! -f "$file" ]; then
    log_warn "文件不存在，跳过: $file"
    return 0
  fi

  if is_exempted_file "$file"; then
    log_debug "豁免文件: $file"
    return 0
  fi

  # 决定扫描内容来源：full file 或 git diff 新增行
  local content
  if [ "$DIFF_ONLY" -eq 1 ] && vp_has_cmd git && git rev-parse --git-dir >/dev/null 2>&1; then
    if [ "$USE_STAGED" -eq 1 ]; then
      content="$(git diff --staged -- "$file" 2>/dev/null | grep -E '^\+' | grep -vE '^\+\+\+' | sed 's/^\+//')"
    else
      content="$(git diff -- "$file" 2>/dev/null | grep -E '^\+' | grep -vE '^\+\+\+' | sed 's/^\+//')"
    fi
    [ -z "$content" ] && return 0
  else
    content="$(cat "$file")"
  fi

  # 注意：DIFF_ONLY 模式下行号不准（git diff 不直接给出绝对行号），用 0 表示"diff 新增"
  local lineno_offset=0
  if [ "$DIFF_ONLY" -eq 1 ]; then
    lineno_offset=-1   # 标记为 diff 模式
  fi

  for rule in "${RULES[@]}"; do
    rid="${rule%%:*}"
    rest="${rule#*:}"
    name="${rest%%:*}"
    pattern="${rest#*:}"

    # 用 grep -nE 找出所有匹配
    while IFS= read -r match_line; do
      [ -z "$match_line" ] && continue
      lineno="${match_line%%:*}"
      text="${match_line#*:}"
      if is_exempted_line "$text"; then
        continue
      fi
      [ "$lineno_offset" -eq -1 ] && lineno=0
      printf '%s|%s|%s|%s|%s\n' "$rid" "$name" "$file" "$lineno" "$text"
    done < <(printf '%s\n' "$content" | grep -nE "$pattern" 2>/dev/null || true)
  done
}

# ========================================
# 主扫描
# ========================================
all_violations=""
for f in "${FILES[@]}"; do
  v="$(scan_file "$f")"
  [ -n "$v" ] && all_violations+="$v"$'\n'
done

# 去掉末尾空行
all_violations="${all_violations%$'\n'}"

if [ -z "$all_violations" ]; then
  total=0
else
  total="$(printf '%s\n' "$all_violations" | wc -l | tr -d ' ')"
fi

# ========================================
# 输出
# ========================================
emit_json() {
  # 注意：macOS 默认 bash 3.2 不支持 declare -A，改用字符串拼接
  local hit_S1=true hit_S2=true hit_S3=true hit_S4=true hit_S5=true hit_S6=true
  if [ -n "$all_violations" ]; then
    while IFS='|' read -r rid name file lineno text; do
      [ -z "$rid" ] && continue
      case "$rid" in
        S1) hit_S1=false ;;
        S2) hit_S2=false ;;
        S3) hit_S3=false ;;
        S4) hit_S4=false ;;
        S5) hit_S5=false ;;
        S6) hit_S6=false ;;
      esac
    done <<< "$all_violations"
  fi
  printf '{'
  printf '"security_lint":{'
  printf '"openai_api_key":%s,'         "$hit_S1"
  printf '"generic_secret":%s,'         "$hit_S2"
  printf '"aws_access_key":%s,'         "$hit_S3"
  printf '"dangerously_set_html":%s,'   "$hit_S4"
  printf '"inner_html":%s,'             "$hit_S5"
  printf '"document_write":%s'          "$hit_S6"
  printf '},'
  printf '"violations":['
  local first=1
  if [ -n "$all_violations" ]; then
    while IFS='|' read -r rid name file lineno text; do
      [ -z "$rid" ] && continue
      [ "$first" -eq 1 ] && first=0 || printf ','
      esc="$(vp_json_escape "$text")"
      printf '{"rule":"%s","name":"%s","file":"%s","line":%s,"text":"%s"}' \
        "$rid" "$name" "$file" "$lineno" "$esc"
    done <<< "$all_violations"
  fi
  printf '],'
  printf '"total":%d' "$total"
  printf '}'
  printf '\n'
}

case "$MODE" in
  json) emit_json ;;
  raw)  ;;
  human)
    log_section "Security 检查（硬编码密钥 + XSS 风险点）"
    if [ "$total" -eq 0 ]; then
      log_pass "未发现硬编码密钥或 XSS 风险点（${#FILES[@]} 个文件）"
    else
      log_fail "发现 $total 处可疑代码"
      while IFS='|' read -r rid name file lineno text; do
        [ -z "$rid" ] && continue
        # 截断过长行
        snippet="$text"
        [ "${#snippet}" -gt 120 ] && snippet="${snippet:0:117}..."
        printf '  %-30s %s:%s\n' "$rid $name" "$file" "$lineno" >&2
        printf '    %s\n' "$snippet" >&2
      done <<< "$all_violations"
      log_info "误报豁免：行尾添加 // [VP-IGNORE-SECRET] 注释或文件位于 tests/fixtures/ 下"
    fi
    ;;
esac

[ "$total" -gt 0 ] && exit 1
exit 0
