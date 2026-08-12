#!/bin/bash
# run-verify.sh - verification-pipeline 主调度引擎
#
# 职责：
# 1. 读取 config/stages.yaml 决定执行哪些阶段（preset 或 --stages 自定义）
# 2. 按 group 串/并行执行（group 1 全通过后才执行 group 2）
# 3. 阶段失败时调用 circuit-breaker.sh 累计失败次数；达到阈值停止
# 4. 输出符合 references/report.schema.json 的 JSON 报告
# 5. dev-flow step-6 V1~V3/V6/V7 可直接调用本脚本获取结构化结果
#
# 用法：
#   bash run-verify.sh                                # 默认 preset=core
#   bash run-verify.sh --preset=full                  # 完整 7 阶段
#   bash run-verify.sh --stages=build,typecheck,lint  # 自定义阶段
#   bash run-verify.sh --json                         # 仅 JSON 输出（CI 友好）
#   bash run-verify.sh --no-parallel                  # 全部串行（调试用）
#   bash run-verify.sh --reset-breaker                # 执行前清空所有熔断计数
#
# 返回码：
#   0 全部通过
#   1 有阶段失败但未触发熔断
#   2 触发了 3 次失败熔断，需用户介入
#   3 配置/环境错误

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/common.sh
source "$VP_ROOT/scripts/lib/common.sh"
# shellcheck source=lib/logger.sh
source "$VP_ROOT/scripts/lib/logger.sh"

CIRCUIT_BREAKER="$VP_ROOT/scripts/state/circuit-breaker.sh"
STAGES_YAML="$VP_CONFIG/stages.yaml"

# ========================================
# 参数解析
# ========================================
PRESET="core"
CUSTOM_STAGES=""
OUTPUT_MODE="human"     # human / json
PARALLEL=1
RESET_BREAKER=0
REPORT_PATH=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --preset=*)        PRESET="${1#--preset=}"; shift ;;
    --stages=*)        CUSTOM_STAGES="${1#--stages=}"; PRESET="custom"; shift ;;
    --json)            OUTPUT_MODE="json"; shift ;;
    --no-parallel)     PARALLEL=0; shift ;;
    --reset-breaker)   RESET_BREAKER=1; shift ;;
    --report=*)        REPORT_PATH="${1#--report=}"; shift ;;
    --help|-h)         sed -n '2,24p' "$0"; exit 0 ;;
    *)
      log_error "未知参数: $1"
      exit 3
      ;;
  esac
done

[ ! -f "$STAGES_YAML" ] && { log_error "配置不存在: $STAGES_YAML"; exit 3; }

# ========================================
# 决定执行哪些阶段
# ========================================
resolve_stages() {
  if [ -n "$CUSTOM_STAGES" ]; then
    echo "$CUSTOM_STAGES" | tr ',' '\n' | tr -d ' '
    return
  fi
  case "$PRESET" in
    core)    echo -e "build\ntypecheck\nlint\ndiff_review" ;;
    full)    echo -e "build\ntypecheck\nlint\nsecurity\ndiff_review\nbrowser\ntest" ;;
    minimal) echo -e "build\ntypecheck" ;;
    *)
      log_error "未知 preset: $PRESET"
      exit 3
      ;;
  esac
}

SELECTED="$(resolve_stages)"
[ -z "$SELECTED" ] && { log_error "未选择任何阶段"; exit 3; }

# ========================================
# 阶段元数据（写死 fallback；优先从 stages.yaml 读取）
# ========================================
# 注意：macOS 默认 bash 3.2 不支持 declare -A 关联数组，
# 改用 case 函数实现「stage_id → 属性」查找。
stage_name() {
  case "$1" in
    build)       echo "V1 Build" ;;
    typecheck)   echo "V2 TypeCheck" ;;
    lint)        echo "V3 Lint" ;;
    security)    echo "V6 Security" ;;
    diff_review) echo "V7 Diff Review" ;;
    browser)     echo "V4 Browser" ;;
    test)        echo "V5 Test" ;;
    *)           echo "" ;;
  esac
}

stage_group() {
  case "$1" in
    build|typecheck|lint) echo 1 ;;
    security|diff_review|browser|test) echo 2 ;;
    *) echo 0 ;;
  esac
}

stage_required() {
  case "$1" in
    build|typecheck|lint|diff_review) echo 1 ;;
    *) echo 0 ;;
  esac
}

stage_on_demand() {
  case "$1" in
    browser|test) echo 1 ;;
    *) echo 0 ;;
  esac
}

# 简易状态存储：用临时目录 + 文件名做 key（替代 declare -A）
VP_RUN_STATE_DIR="$(mktemp -d -t vp-run-state.XXXXXX)"
trap 'rm -rf "$VP_RUN_STATE_DIR" 2>/dev/null || true' EXIT

rs_set() {  # rs_set <bucket> <stage> <value>
  local f="$VP_RUN_STATE_DIR/${1}__${2}"
  printf '%s' "$3" > "$f"
}
rs_get() {  # rs_get <bucket> <stage>
  local f="$VP_RUN_STATE_DIR/${1}__${2}"
  [ -f "$f" ] && cat "$f" || echo ""
}

# ========================================
# 收集本次改动文件（供 lint/security 阶段使用）
# ========================================
collect_changed_files() {
  if vp_has_cmd git && git rev-parse --git-dir >/dev/null 2>&1; then
    git diff --name-only HEAD 2>/dev/null | grep -E '\.(ts|tsx|js|jsx|vue|mjs|cjs)$' || true
  fi
}

CHANGED_FILES_RAW="$(collect_changed_files)"

# ========================================
# 单阶段执行
# 输入：stage_id
# 输出：通过 rs_set status/duration/exit/fail/output 写入临时状态文件
# ========================================

run_one_stage() {
  local sid="$1"
  local name
  name="$(stage_name "$sid")"
  [ -z "$name" ] && name="$sid"
  local on_demand
  on_demand="$(stage_on_demand "$sid")"

  log_section "$name ($sid)"

  # on_demand 阶段：默认不执行（dev-flow 显式触发时再调用）
  if [ "$on_demand" = "1" ]; then
    rs_set status "$sid" "not_triggered"
    rs_set duration "$sid" 0
    rs_set exit "$sid" 0
    rs_set fail "$sid" "$("$CIRCUIT_BREAKER" --get "$sid" 2>/dev/null || echo 0)"
    rs_set output "$sid" "(on_demand stage; not triggered by run-verify; see references/handbook)"
    log_info "按需阶段，未触发；详见 references/ 下对应手册"
    return 0
  fi

  # 已熔断的阶段直接标记（circuit-breaker.sh --check 返回 1 表示已熔断）
  if ! "$CIRCUIT_BREAKER" --check "$sid" >/dev/null 2>&1; then
    rs_set status "$sid" "circuit_broken"
    rs_set duration "$sid" 0
    rs_set exit "$sid" 1
    local fc
    fc="$("$CIRCUIT_BREAKER" --get "$sid")"
    rs_set fail "$sid" "$fc"
    rs_set output "$sid" "circuit broken; user decision required"
    log_fail "已熔断，跳过执行（计数 $fc）"
    return 1
  fi

  local start_ms end_ms duration
  start_ms="$(vp_now_ms)"

  local exit_code=0
  local out_file
  out_file="$(mktemp -t vp-stage-${sid}.XXXXXX)"

  case "$sid" in
    build)
      ( npm run build ) >"$out_file" 2>&1
      exit_code=$?
      ;;
    typecheck)
      if vp_has_cmd npx; then
        ( npx --no-install tsc --noEmit 2>/dev/null || npx tsc --noEmit ) >"$out_file" 2>&1
        exit_code=$?
      else
        echo "npx not found, skip typecheck" >"$out_file"
        exit_code=0
      fi
      ;;
    lint)
      if [ -z "$CHANGED_FILES_RAW" ]; then
        echo "(no changed files; lint skipped)" >"$out_file"
        exit_code=0
      else
        # 用空格分隔传给 eslint
        # shellcheck disable=SC2086
        ( npx --no-install eslint --no-error-on-unmatched-pattern $CHANGED_FILES_RAW ) >"$out_file" 2>&1
        exit_code=$?
      fi
      ;;
    security)
      if [ -z "$CHANGED_FILES_RAW" ]; then
        echo "(no changed files; security check skipped)" >"$out_file"
        exit_code=0
      else
        # shellcheck disable=SC2086
        ( bash "$VP_ROOT/scripts/lints/secret-grep-lint.sh" $CHANGED_FILES_RAW ) >"$out_file" 2>&1
        exit_code=$?
      fi
      ;;
    diff_review)
      ( bash "$VP_ROOT/scripts/lints/lock-file-lint.sh" ) >"$out_file" 2>&1
      exit_code=$?
      ;;
    *)
      echo "未实现的阶段: $sid" >"$out_file"
      exit_code=1
      ;;
  esac

  end_ms="$(vp_now_ms)"
  duration=$((end_ms - start_ms))
  rs_set duration "$sid" "$duration"
  rs_set exit "$sid" "$exit_code"

  # 截取尾部 30 行作为输出摘要
  rs_set output "$sid" "$(tail -30 "$out_file" 2>/dev/null || echo '')"
  rm -f "$out_file"

  if [ "$exit_code" -eq 0 ]; then
    # 通过 → 重置该阶段熔断计数
    "$CIRCUIT_BREAKER" --reset "$sid" >/dev/null 2>&1 || true
    rs_set status "$sid" "passed"
    rs_set fail "$sid" 0
    log_pass "$name 通过 ($(vp_fmt_duration_ms $duration))"
    return 0
  else
    # 失败 → 累加熔断计数
    "$CIRCUIT_BREAKER" --inc "$sid" >/dev/null 2>&1 || true
    local new_count
    new_count="$("$CIRCUIT_BREAKER" --get "$sid")"
    rs_set fail "$sid" "$new_count"

    if [ "$new_count" -ge 3 ]; then
      rs_set status "$sid" "circuit_broken"
      log_fail "$name 失败 ($(vp_fmt_duration_ms $duration))，已熔断（$new_count 次）"
    else
      rs_set status "$sid" "failed"
      log_fail "$name 失败 ($(vp_fmt_duration_ms $duration))，累计失败 $new_count 次"
    fi
    log_info "stdout/stderr 末 30 行已记录到 JSON 报告"
    return 1
  fi
}

# ========================================
# 串行 vs 并行执行
# 由于 bash 并发管理复杂，本版采用「同 group 顺序执行 + group 之间严格串行」
# 真正并行需要 wait + 临时文件，留作 v2.1 优化
# ========================================
group1=()
group2=()
for sid in $SELECTED; do
  if [ -z "$(stage_name "$sid")" ]; then
    log_warn "未知阶段，跳过: $sid"
    continue
  fi
  if [ "$(stage_group "$sid")" = "1" ]; then
    group1+=("$sid")
  else
    group2+=("$sid")
  fi
done

if [ "$RESET_BREAKER" = "1" ]; then
  "$CIRCUIT_BREAKER" --clear-all >/dev/null 2>&1 || true
fi

started_at="$(vp_now_iso)"
overall_start_ms="$(vp_now_ms)"

CIRCUIT_BROKEN=0
GROUP1_BLOCKED=0

# Group 1
for sid in ${group1[@]+"${group1[@]}"}; do
  if ! run_one_stage "$sid"; then
    if [ "$(stage_required "$sid")" = "1" ]; then
      GROUP1_BLOCKED=1
    fi
    if [ "$(rs_get status "$sid")" = "circuit_broken" ]; then
      CIRCUIT_BROKEN=1
    fi
  fi
done

# Group 2（仅当 group1 必需阶段全通过时执行；否则全标记 skipped）
if [ "$GROUP1_BLOCKED" = "1" ]; then
  for sid in ${group2[@]+"${group2[@]}"}; do
    rs_set status "$sid" "skipped"
    rs_set duration "$sid" 0
    rs_set exit "$sid" 0
    rs_set fail "$sid" "$("$CIRCUIT_BREAKER" --get "$sid" 2>/dev/null || echo 0)"
    rs_set output "$sid" "(skipped: group 1 has blocking failures)"
    log_warn "$(stage_name "$sid") 跳过（group 1 有阻塞失败）"
  done
else
  for sid in ${group2[@]+"${group2[@]}"}; do
    if ! run_one_stage "$sid"; then
      if [ "$(rs_get status "$sid")" = "circuit_broken" ]; then
        CIRCUIT_BROKEN=1
      fi
    fi
  done
fi

overall_end_ms="$(vp_now_ms)"
finished_at="$(vp_now_iso)"
total_duration=$((overall_end_ms - overall_start_ms))

# ========================================
# 汇总
# ========================================
passed=0; failed=0; skipped=0; blocked=0
for sid in ${group1[@]+"${group1[@]}"} ${group2[@]+"${group2[@]}"}; do
  st="$(rs_get status "$sid")"
  [ -z "$st" ] && st="skipped"
  case "$st" in
    passed)         passed=$((passed + 1)) ;;
    failed|circuit_broken)
      failed=$((failed + 1))
      [ "$(stage_required "$sid")" = "1" ] && blocked=$((blocked + 1))
      ;;
    skipped|not_triggered)
      skipped=$((skipped + 1))
      ;;
  esac
done
if [ "$blocked" -gt 0 ]; then
  OVERALL="BLOCKED"
elif [ "$failed" -gt 0 ]; then
  OVERALL="WARNING"
else
  OVERALL="READY"
fi

NEEDS_USER=0
if [ "$CIRCUIT_BROKEN" = "1" ] || [ "$OVERALL" = "BLOCKED" ]; then
  NEEDS_USER=1
fi

# ========================================
# 输出 JSON 报告
# ========================================
emit_report() {
  printf '{'
  printf '"schema_version":"1.0",'
  printf '"started_at":"%s",' "$started_at"
  printf '"finished_at":"%s",' "$finished_at"
  printf '"duration_ms":%d,' "$total_duration"
  printf '"preset":"%s",' "$PRESET"

  printf '"selected_stages":['
  first=1
  for sid in ${group1[@]+"${group1[@]}"} ${group2[@]+"${group2[@]}"}; do
    [ "$first" -eq 1 ] && first=0 || printf ','
    printf '"%s"' "$sid"
  done
  printf '],'

  printf '"stages":['
  first=1
  for sid in ${group1[@]+"${group1[@]}"} ${group2[@]+"${group2[@]}"}; do
    [ "$first" -eq 1 ] && first=0 || printf ','
    local st
    st="$(rs_get status "$sid")"
    [ -z "$st" ] && st="skipped"
    local dur
    dur="$(rs_get duration "$sid")"
    [ -z "$dur" ] && dur=0
    local ec
    ec="$(rs_get exit "$sid")"
    [ -z "$ec" ] && ec=0
    local fc
    fc="$(rs_get fail "$sid")"
    [ -z "$fc" ] && fc=0
    local req
    req="$(stage_required "$sid")"
    local grp
    grp="$(stage_group "$sid")"
    printf '{'
    printf '"id":"%s",' "$sid"
    printf '"name":"%s",' "$(stage_name "$sid")"
    printf '"status":"%s",' "$st"
    printf '"required":%s,' "$([ "$req" = "1" ] && echo true || echo false)"
    printf '"group":%d,' "$grp"
    printf '"duration_ms":%d,' "$dur"
    printf '"exit_code":%d,' "$ec"
    printf '"failure_count":%d,' "$fc"
    tail_esc="$(vp_json_escape "$(rs_get output "$sid")")"
    printf '"stdout_tail":"%s"' "$tail_esc"
    printf '}'
  done
  printf '],'

  printf '"summary":{'
  printf '"overall":"%s",' "$OVERALL"
  printf '"passed_count":%d,' "$passed"
  printf '"failed_count":%d,' "$failed"
  printf '"skipped_count":%d,' "$skipped"
  printf '"circuit_breaker_triggered":%s,' "$([ "$CIRCUIT_BROKEN" = "1" ] && echo true || echo false)"
  printf '"needs_user_decision":%s' "$([ "$NEEDS_USER" = "1" ] && echo true || echo false)"
  printf '},'

  printf '"context":{'
  printf '"cwd":"%s"' "$(pwd | sed 's/"/\\"/g')"
  if vp_has_cmd git && git rev-parse --git-dir >/dev/null 2>&1; then
    branch="$(git symbolic-ref --short HEAD 2>/dev/null || echo '')"
    head="$(git rev-parse HEAD 2>/dev/null || echo '')"
    printf ',"git_branch":"%s","git_head":"%s"' "$branch" "$head"
  fi
  printf '}'

  printf '}'
  printf '\n'
}

# 默认报告路径
if [ -z "$REPORT_PATH" ]; then
  REPORT_PATH="$VP_STATE_DIR/last-report.json"
  mkdir -p "$VP_STATE_DIR" 2>/dev/null || true
fi

emit_report > "$REPORT_PATH"

if [ "$OUTPUT_MODE" = "json" ]; then
  cat "$REPORT_PATH"
else
  log_section "验证报告汇总"
  log_kv "整体结论" "$OVERALL"
  log_kv "通过" "$passed"
  log_kv "失败" "$failed"
  log_kv "跳过" "$skipped"
  log_kv "熔断" "$([ "$CIRCUIT_BROKEN" = "1" ] && echo "是" || echo "否")"
  log_kv "需用户决策" "$([ "$NEEDS_USER" = "1" ] && echo "是" || echo "否")"
  log_kv "报告路径" "$REPORT_PATH"
fi

# ========================================
# 返回码
# ========================================
if [ "$CIRCUIT_BROKEN" = "1" ]; then
  exit 2
fi
if [ "$OVERALL" = "BLOCKED" ] || [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
