#!/bin/bash
# post-step.sh - 步骤完成后统一钩子调度
# 在步骤 N 完成标记 JSON 输出后调用，自动执行 validate-output.sh + 相关 lints
#
# 用法:
#   bash post-step.sh <step-id> <json-file> <flow-name>
#
# 行为:
#   1. 调用 validate-output.sh 做 Schema + 业务校验（含物理检查点写入）
#   2. 步骤 4：附加调用 doc-platform-lint.sh
#   3. 后续可扩展：步骤 1/3/7 的报告做 path-lint
#
# 返回码: 与 validate-output.sh 一致
#   0 通过；1 JSON 错误；2 Schema 失败；3 工具缺失

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_FLOW_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$DEV_FLOW_ROOT/scripts/lib/common.sh"
source "$DEV_FLOW_ROOT/scripts/lib/logger.sh"
source "$DEV_FLOW_ROOT/scripts/lib/audit.sh"

STEP_ID="${1:-}"
JSON_FILE="${2:-}"
FLOW_NAME="${3:-}"

if [ -z "$STEP_ID" ] || [ -z "$JSON_FILE" ]; then
  log_error "用法: $0 <step-id> <json-file> [flow-name]"
  exit 2
fi

# ========================================
# 0. 步骤 5.5 静默路径计数器维护（物理层兜底，必须在 validate 之前）
# ========================================
# 设计意图：iteration-fix §四 / step-5-execute §2.5 静默路径下，
# AI 不输出完成标记 JSON。post-step.sh 收到 STEP_ID=5.5 但 JSON_FILE 不存在/为空时，
# 判定为静默路径，物理层兜底自增 .flow.silent_55_count。
# 达到 3 → AI 在下一次响应前读 .flow 检测到 ≥3 时必弹 dev:sync 提醒（场景 A）。
# 注意：此逻辑必须在 validate-output.sh 之前执行，因为静默路径下 JSON_FILE 不存在，
# validate-output.sh 会 exit 1 阻断后续所有逻辑。
case "$STEP_ID" in
  5.5|5_5)
    if [ ! -f "$JSON_FILE" ] || [ ! -s "$JSON_FILE" ]; then
      if [ -n "$FLOW_NAME" ]; then
        FLOW_FILE_S55="$(df_active_flows_dir)/${FLOW_NAME}.flow"
        if [ -f "$FLOW_FILE_S55" ]; then
          current=$(df_get_flow_field "$FLOW_FILE_S55" "silent_55_count" 2>/dev/null || echo "")
          current="${current:-0}"
          next=$((current + 1))

          if grep -q "^silent_55_count:" "$FLOW_FILE_S55"; then
            sed -i.bak "s/^silent_55_count:.*/silent_55_count: $next/" "$FLOW_FILE_S55" && rm -f "${FLOW_FILE_S55}.bak"
          else
            echo "silent_55_count: $next" >> "$FLOW_FILE_S55"
          fi

          log_info "📝 silent_55_count: $current → $next（静默 5.5 路径，JSON 不存在）"
          df_audit "hook.post_step.silent_55_inc" "silent count incremented" step="$STEP_ID" flow="$FLOW_NAME" count="$next"

          if [ "$next" -ge 3 ]; then
            log_warn "⚠️  silent_55_count=$next ≥ 3，AI 下一次响应前必须弹 dev:sync 提醒（场景 A）"
            df_audit "hook.post_step.silent_55_threshold" "silent count reached threshold" flow="$FLOW_NAME" count="$next"
          fi
        fi
      fi
      # 静默路径无 JSON，计数器已处理，后续 validate 必定失败，直接退出
      exit 0
    fi
    ;;
esac

log_section "🔒 PostStepComplete Hook (step-$STEP_ID)"
df_audit "hook.post_step.start" "post-step started" step="$STEP_ID" flow="${FLOW_NAME:-}"

# ========================================
# 0.5. 全局熔断器检查（步骤级别，防止 token 失控）
# ========================================
# 设计意图：
#   同一步骤反复调用 post-step（AI 反复输出不合法完成标记 → validate 失败 → 重试）
#   累计 3 次仍未通过时熔断，防止无限消耗 token。
#   每次 validate-output.sh 通过后自动重置该步骤计数（见 §1 末尾）。
if [ -n "$FLOW_NAME" ]; then
  CB_SCRIPT="$DEV_FLOW_ROOT/scripts/harness/circuit-breaker.sh"
  if [ -f "$CB_SCRIPT" ] && [ -x "$CB_SCRIPT" ]; then
    # 递增失败计数并检查是否熔断
    # 注意：此处 --inc 会在 post-step 首次运行时将计数设为 1
    # 每次 validate 失败后 AI 会修正 JSON 重新调用 post-step，计数会继续递增
    # 只有当 validate 通过后，下方的 reset 才会清零
    bash "$CB_SCRIPT" --inc "$FLOW_NAME" "$STEP_ID" || {
      # 熔断触发，拒绝继续
      log_section "🔴 熔断已触发，请用户介入"
      echo ""
      echo "  post-step.sh 在同一步骤上反复调用，已达到熔断阈值。"
      echo "  可能原因：AI 输出的完成标记 JSON 反复不合法。"
      echo "  建议：回退到上一步骤重新执行，或手动检查 JSON 输出。"
      echo ""
      echo "  解除熔断：bash $CB_SCRIPT --reset $FLOW_NAME $STEP_ID"
      df_audit "hook.post_step.circuit_breaker_tripped" "circuit breaker tripped" step="$STEP_ID" flow="$FLOW_NAME"
      exit 1
    }
  fi
fi

# ========================================
# 1. validate-output.sh（Schema + 物理检查点）
# ========================================
log_step "1. Schema 校验 + 物理检查点写入"
local_rc=0
bash "$DEV_FLOW_ROOT/scripts/validate-output.sh" "$STEP_ID" "$JSON_FILE" "$FLOW_NAME" || local_rc=$?

if [ $local_rc -ne 0 ]; then
  log_fail "❌ validate-output.sh 失败 (rc=$local_rc)"
  df_audit "hook.post_step.fail" "validate-output failed" step="$STEP_ID" rc="$local_rc"
  exit $local_rc
fi

# ========================================
# 1.5. 产物归档（validate 通过后自动执行）
# ========================================
if [ -n "$FLOW_NAME" ]; then
  # dry-run 模式产物隔离
  DRY_RUN_MODE=false
  if [ -n "${DF_DRY_RUN:-}" ] && [ "$DF_DRY_RUN" = "true" ]; then
    DRY_RUN_MODE=true
  fi
  # 也检查 .flow 文件中的 dry_run 字段
  if [ "$DRY_RUN_MODE" = "false" ]; then
    FLOW_DIR_CHECK="$(df_active_flows_dir)"
    FLOW_FILE_CHECK=$(find "$FLOW_DIR_CHECK" -name "*.flow" 2>/dev/null | head -1)
    if [ -n "$FLOW_FILE_CHECK" ] && [ -f "$FLOW_FILE_CHECK" ]; then
      dry_run_val=$(df_get_flow_field "$FLOW_FILE_CHECK" "dry_run" 2>/dev/null || echo "")
      if [ "$dry_run_val" = "true" ]; then
        DRY_RUN_MODE=true
      fi
    fi
  fi

  if [ "$DRY_RUN_MODE" = "true" ]; then
    ARTIFACT_DIR="$HOME/.codebuddy/dev-flow-artifacts/${FLOW_NAME}--dry-run"
  else
    ARTIFACT_DIR="$HOME/.codebuddy/dev-flow-artifacts/$FLOW_NAME"
  fi

  mkdir -p "$ARTIFACT_DIR"
  STEP_SLUG=$(echo "$STEP_ID" | tr '.' '_')
  cp "$JSON_FILE" "$ARTIFACT_DIR/step-${STEP_SLUG}.json"

  if [ "$DRY_RUN_MODE" = "true" ]; then
    log_pass "📦 [DRY-RUN] 产物归档: dev-flow-artifacts/${FLOW_NAME}--dry-run/step-${STEP_SLUG}.json"
  else
    log_pass "📦 产物归档: dev-flow-artifacts/$FLOW_NAME/step-${STEP_SLUG}.json"
  fi
  df_audit "hook.post_step.archive" "artifact archived" step="$STEP_ID" flow="$FLOW_NAME" dry_run="$DRY_RUN_MODE"
fi

# ========================================
# 1.6. 交互式步骤推进选项校验（interactive_progression_shown 门控）
# ========================================
# 设计动机：
#   2026-07-01 新增：AI 反复出现「只输出文本选项表格但未调用 ask_followup_question」
#   的问题。规范层（step-router.md / gate-validator.md）已完备，但 post-step hook
#   未机械校验。本检查在 JSON 完成标记中强制该字段，弥补执行层缺口。
# 规范源：step-router.md §「步骤流转交互规则」+ gate-validator.md §「交互式选项一致性门控」
# 豁免清单（精简模式）：0.5->1, 4.5->5, 5->5.5, 5.5->6
#   - 标准模式：所有步骤流转必须 interactive_progression_shown=true
#   - 精简模式：豁免流转可省略该字段，非豁免流转仍必须为 true
if [ -n "$FLOW_NAME" ]; then
  echo ""
  log_step "1.6. 交互式步骤推进选项校验（interactive_progression_shown）"

  # 读取当前模式
  FLOW_DIR_IPS="$(df_active_flows_dir)"
  FLOW_FILE_IPS=$(find "$FLOW_DIR_IPS" -name "*.flow" 2>/dev/null | head -1)
  FLOW_MODE_IPS="standard"
  if [ -n "$FLOW_FILE_IPS" ] && [ -f "$FLOW_FILE_IPS" ]; then
    FLOW_MODE_IPS=$(df_get_flow_mode "$FLOW_FILE_IPS")
  fi

  # 消除步骤变体后缀（7-standard → 7, 7-full → 7 等），构造纯净的流转标识
  base_step=$(echo "$STEP_ID" | sed 's/-.*//')
  next_step_raw=$(jq -r '.next_step // ""' "$JSON_FILE" 2>/dev/null || echo "")
  base_next=$(echo "$next_step_raw" | sed 's/-.*//')

  # 豁免流转清单（与 step-router.md §「步骤流转交互规则」完全对齐）
  IPS_EXEMPTED="0.5->1 4.5->5 5->5.5 5.5->6"
  transition="${base_step}->${base_next}"

  # 判定是否豁免
  is_ips_exempted=false
  if [ "$FLOW_MODE_IPS" = "streamlined" ]; then
    for ex in $IPS_EXEMPTED; do
      if [ "$ex" = "$transition" ]; then
        is_ips_exempted=true
        break
      fi
    done
  fi

  # 仅对非豁免流转 + 有实际下一步（非空）的步骤做校验
  if [ "$is_ips_exempted" = "false" ] && [ -n "$next_step_raw" ]; then
    ips_value=$(jq -r '.interactive_progression_shown // "missing"' "$JSON_FILE" 2>/dev/null || echo "missing")
    if [ "$ips_value" != "true" ]; then
      log_fail "🔴 interactive_progression_shown 字段缺失或不为 true [当前: $ips_value]"
      echo "   流转: step-${STEP_ID} → ${next_step_raw}（mode=${FLOW_MODE_IPS}）"
      echo "   规范要求：每个步骤完成后必须通过 ask_followup_question 弹出推进选项"
      echo "   修复：在当前步骤完成前调用 ask_followup_question 弹出 A/B/C 选项，"
      echo "        并在完成标记 JSON 中设置 interactive_progression_shown: true"
      echo "   参考：step-router.md §「步骤流转交互规则」+ gate-validator.md §「交互式选项一致性门控」"
      df_audit "hook.post_step.fail" "interactive_progression_shown missing" step="$STEP_ID" flow="$FLOW_NAME" transition="$transition" mode="$FLOW_MODE_IPS"
      exit 1
    fi
    log_pass "✅ interactive_progression_shown=true (流转: ${transition})"
    df_audit "hook.post_step.ips_pass" "interactive_progression_shown verified" step="$STEP_ID" flow="$FLOW_NAME" transition="$transition" mode="$FLOW_MODE_IPS"
  elif [ "$is_ips_exempted" = "true" ]; then
    log_info "⏭️  豁免校验（精简模式 ${transition}）"
  else
    # next_step 为空（如 requirement-intake 无关步骤）
    log_info "⏭️  跳过校验（next_step 为空）"
  fi
fi

# ========================================
# 1.7. .flow 与 .md 的 current_step 一致性检查（2026-07-08 新增）
# ========================================
# 设计动机：file-export 事故中 .flow=6, .md=6 同步漂移，无任何机制察觉。
#   步骤路由器动作 2 要求同时更新两者，若遗漏则两个文件一起滞后。
#   本检查对比两者 current_step，不一致时发出软告警（不阻断）。
#   不阻断理由：迭代修复中短暂不一致是正常的（.md 已写但 .flow 即将刷新）。
if [ -n "$FLOW_NAME" ]; then
  FLOW_DIR_CS1="$(df_active_flows_dir)"
  FLOW_FILE_CS1="$FLOW_DIR_CS1/${FLOW_NAME}.flow"
  WC_FILE_CS1="$HOME/.codebuddy/working-context/${FLOW_NAME}.md"
  if [ -f "$FLOW_FILE_CS1" ] && [ -f "$WC_FILE_CS1" ]; then
    flow_cs=$(grep "^current_step:" "$FLOW_FILE_CS1" 2>/dev/null | head -1 | sed 's/current_step:\s*//' | tr -d '"' | xargs)
    md_cs=$(grep "^current_step:" "$WC_FILE_CS1" 2>/dev/null | head -1 | sed 's/current_step:\s*//' | tr -d '"' | xargs)
    if [ -n "$flow_cs" ] && [ -n "$md_cs" ] && [ "$flow_cs" != "$md_cs" ]; then
      log_warn "⚠️  .flow.current_step ($flow_cs) ≠ .md.current_step ($md_cs)"
      echo "   可能原因：步骤路由器动作 2 未同步更新两者"
      echo "   建议：以工作上下文 ## 进度 区块为准，同步 .flow"
      df_audit "hook.post_step.warn" "current_step_mismatch" step="$STEP_ID" flow="$FLOW_NAME" flow_step="$flow_cs" md_step="$md_cs"
    fi
  fi
fi

# ========================================
# 2. 步骤 4：附加 doc-platform-lint
# ========================================
if [ "$STEP_ID" = "4" ]; then
  echo ""
  log_step "2. 文档平台 决策门控"
  if ! bash "$DEV_FLOW_ROOT/scripts/lints/doc-platform-lint.sh" --raw "$JSON_FILE"; then
    log_fail "❌ doc-platform-lint 失败"
    df_audit "hook.post_step.fail" "doc-platform-lint failed" step="$STEP_ID"
    exit 2
  fi
fi

# ========================================
# 3. 步骤 5.5 / 步骤 7（全变体）：工作上下文新鲜度检查
# ========================================
# 触发范围（与 config/gates.yaml §lints.working-context-freshness-lint.triggers 对齐）：
#   - step-5.5：standard/full/batch 三模式编码后置钩子
#   - step-7：standard/full/batch 三变体；micro-fix 按 skip_conditions 显式排除
# 历史 bug（2026-06-02 修复）：原条件 `[ "$STEP_ID" = "7" ]` 与实际调用 `7-standard`/`7-full`/`7-batch` 永不匹配，
#   导致所有 step-7 调用静默跳过 freshness 检查（约 70% 影响被 step-5.5 兜底缓解）。
#   修复：改用 case 模式精确覆盖 4 个变体（不含 micro-fix）。
# 灰度开关：导出 DF_FRESHNESS_SOFT=true 可暂时降级为软告警（rc=1 时不阻断，仅 warn），用于修复后观察期。
freshness_should_check=false
case "$STEP_ID" in
  5.5|5_5|7-standard|7_standard|7-full|7_full|7-batch|7_batch)
    freshness_should_check=true
    ;;
esac

if [ "$freshness_should_check" = "true" ]; then
  if [ -n "$FLOW_NAME" ]; then
    echo ""
    log_step "3. 工作上下文新鲜度检查"
    wc_rc=0
    bash "$DEV_FLOW_ROOT/scripts/lints/working-context-freshness-lint.sh" "$FLOW_NAME" || wc_rc=$?
    if [ $wc_rc -eq 1 ]; then
      if [ "${DF_FRESHNESS_SOFT:-false}" = "true" ]; then
        log_warn "⚠️  工作上下文未更新（软告警模式 DF_FRESHNESS_SOFT=true，不阻断）"
        df_audit "hook.post_step.warn" "working-context-freshness-lint soft-warn" step="$STEP_ID" flow="$FLOW_NAME"
      else
        log_fail "🔴 工作上下文未更新（步骤 5.5b 要求）"
        echo "   临时降级：导出 DF_FRESHNESS_SOFT=true 切换为软告警（用于修复后观察期）" >&2
        df_audit "hook.post_step.fail" "working-context-freshness-lint failed" step="$STEP_ID" flow="$FLOW_NAME"
        exit 1
      fi
    elif [ $wc_rc -eq 2 ]; then
      log_warn "⚠️  工作上下文新鲜度检查跳过（无基准时间戳）"
      # 不阻断，仅警告
    fi
  fi
fi

# ========================================
# 3.5. 步骤 7（standard）：文档平台 兜底对账漂移预检（H.3+）
# ========================================
# 设计原则：
#   - 仅 7-standard 触发：full 推迟到 step10、batch 跳过、micro-fix 不绑定 doc_platform
#   - docid 为空 → 直接 pass（不破坏没绑定 doc_platform 的简单需求）
#   - docid 非空 → 必须从 step-7-standard.json 产物读到 doc_platform_sync_result，否则提示走 closeout-flow.md §H.3+
#   - skipped_user_opt_out 是用户显式跳过，hook 必须放行
#   - skipped_no_changes + last_synced_at < latest_commit → 漂移矛盾，必须拦截
#   - 时间戳取不到时降级为仅校验字段存在性，不做严格阈值
# 规范源：references/closeout-flow.md §H.3+ + references/gate-validator.md §「文档平台 归档同步门控」
if [ "$STEP_ID" = "7-standard" ] || [ "$STEP_ID" = "7_standard" ]; then
  if [ -n "$FLOW_NAME" ]; then
    echo ""
    log_step "3.5. 文档平台 兜底对账漂移预检（H.3+）"

    # 定位工作上下文文件（active 优先，archive 兜底）
    WC_FILE_doc_platform="$HOME/.codebuddy/working-context/${FLOW_NAME}.md"
    if [ ! -f "$WC_FILE_doc_platform" ]; then
      WC_FILE_doc_platform=$(find "$HOME/.codebuddy/working-context/archive" -name "${FLOW_NAME}.md" 2>/dev/null | head -1 || true)
    fi

    if [ -z "$WC_FILE_doc_platform" ] || [ ! -f "$WC_FILE_doc_platform" ]; then
      log_warn "⚠️  doc_platform 漂移预检跳过：找不到工作上下文文件 ${FLOW_NAME}.md"
    else
      # 解析 doc_platform_tech_proposal.docid（YAML 格式：缩进 2 空格 + docid: "xxx"）
      doc_platform_DOCID=$(awk '
        /^doc_platform_tech_proposal:/ { in_block=1; next }
        in_block && /^[^[:space:]]/ { in_block=0 }
        in_block && /^[[:space:]]+docid:/ {
          val=$0
          sub(/^[[:space:]]+docid:[[:space:]]*/, "", val)
          gsub(/^"|"$/, "", val)
          gsub(/^'\''|'\''$/, "", val)
          print val
          exit
        }
      ' "$WC_FILE_doc_platform" || true)

      if [ -z "$doc_platform_DOCID" ]; then
        log_pass "✅ doc_platform_tech_proposal.docid 为空，跳过兜底对账（无绑定文档）"
      else
        # 直接从入参 JSON 读 doc_platform_sync_result（schema 已通过校验，内容可信）
        # 注意：hook §1.5 归档时使用 step-{STEP_SLUG}.json 命名（STEP_SLUG=7-standard），
        #      故不能写死 step-7.json，直接用 $JSON_FILE 最稳健
        doc_platform_RESULT=""
        doc_platform_LAST_SYNCED=""
        if [ -f "$JSON_FILE" ]; then
          doc_platform_RESULT=$(jq -r '.outputs.doc_platform_sync_result // ""' "$JSON_FILE" 2>/dev/null || echo "")
          doc_platform_LAST_SYNCED=$(jq -r '.outputs.last_synced_at // ""' "$JSON_FILE" 2>/dev/null || echo "")
        fi

        if [ -z "$doc_platform_RESULT" ]; then
          log_fail "🔴 doc_platform_sync_result 字段缺失"
          echo "   工作上下文 docid=$doc_platform_DOCID 已绑定 文档平台 文档"
          echo "   按 references/closeout-flow.md §H.3+ 规范，标准模式必须执行兜底对账"
          echo "   修复：加载 references/closeout-flow.md 完成 H.3+ 后重新输出 step-7-standard.json"
          df_audit "hook.post_step.fail" "doc_platform_sync_result missing" step="$STEP_ID" flow="$FLOW_NAME" docid="$doc_platform_DOCID"
          exit 1
        fi

        # skipped_no_docid 在 docid 非空时不合法
        if [ "$doc_platform_RESULT" = "skipped_no_docid" ]; then
          log_fail "🔴 doc_platform_sync_result=skipped_no_docid 与 docid=$doc_platform_DOCID 矛盾"
          echo "   docid 非空时不允许 skipped_no_docid，请走 H.3+ 兜底对账"
          df_audit "hook.post_step.fail" "doc_platform_sync_result inconsistent" step="$STEP_ID" flow="$FLOW_NAME" docid="$doc_platform_DOCID" result="$doc_platform_RESULT"
          exit 1
        fi

        # 漂移检测：skipped_no_changes 但 last_synced_at < 最新 commit 时间
        if [ "$doc_platform_RESULT" = "skipped_no_changes" ]; then
          # 取功能分支最新 commit 时间（ISO 8601 字符串可直接字典序比较）
          LATEST_COMMIT_AT=""
          if [ -d ".git" ] || git rev-parse --git-dir > /dev/null 2>&1; then
            LATEST_COMMIT_AT=$(git log -1 --format="%aI" 2>/dev/null || echo "")
          fi

          if [ -n "$doc_platform_LAST_SYNCED" ] && [ -n "$LATEST_COMMIT_AT" ]; then
            # ISO 8601 形如 2026-06-02T17:59:00+08:00 可直接字符串比较
            if [ "$doc_platform_LAST_SYNCED" \< "$LATEST_COMMIT_AT" ]; then
              log_fail "🔴 doc_platform 漂移检测失败"
              echo "   last_synced_at=$doc_platform_LAST_SYNCED < latest_commit=$LATEST_COMMIT_AT"
              echo "   但 doc_platform_sync_result=skipped_no_changes（声称无变化）矛盾"
              echo "   修复：核实是否漏掉了 H.3+ 兜底对账（可能有 commit 未同步到 文档平台）"
              df_audit "hook.post_step.fail" "doc_platform drift detected" step="$STEP_ID" flow="$FLOW_NAME" docid="$doc_platform_DOCID" last_synced="$doc_platform_LAST_SYNCED" latest_commit="$LATEST_COMMIT_AT"
              exit 1
            fi
          fi
        fi

        log_pass "✅ 文档平台 漂移预检通过 (docid=$doc_platform_DOCID, result=$doc_platform_RESULT)"
        df_audit "hook.post_step.doc_platform_check_pass" "doc_platform drift check passed" step="$STEP_ID" flow="$FLOW_NAME" docid="$doc_platform_DOCID" result="$doc_platform_RESULT"

        # doc-platform-lint.sh 触发说明（保留扩展点）：
        #   - tech-doc/scripts/lints/doc-platform-lint.sh 接受 markdown 文件路径，非 docid
        #   - 调用前需先将文档内容本地存盘
        #   - 这是文档质量 lint，与本 hook（漂移检测）职责正交，故不在此处实际触发
        #   - 真正的 doc-platform-doc-lint 由 H.3+ 兜底对账子流程或 step-10 同步流程负责拉起
        #   - 字段 doc_platform_lint_passed 由该子流程填写到产物 JSON，schema 已强制必填
      fi
    fi
  fi
fi

# ========================================
# 5. 步骤间质量门禁（Layer 3）
# ========================================
if [ -n "$FLOW_NAME" ]; then
  # 查询下一步（通过 gates.yaml 中的步骤序列）
  GATES_YAML="$DEV_FLOW_ROOT/config/gates.yaml"
  NEXT_STEP=""

  if [ -f "$GATES_YAML" ]; then
    # 从 .flow 文件获取当前模式
    FLOW_DIR="$(df_active_flows_dir)"
    FLOW_FILE=$(find "$FLOW_DIR" -name "*.flow" 2>/dev/null | head -1)
    FLOW_MODE="standard"
    if [ -n "$FLOW_FILE" ] && [ -f "$FLOW_FILE" ]; then
      FLOW_MODE=$(df_get_flow_mode "$FLOW_FILE")
    fi

    # 获取步骤序列
    STEP_SEQ=$(df_get_yaml_value "$GATES_YAML" "state_machine.step_sequences.$FLOW_MODE" 2>/dev/null || echo "")
    if [ -n "$STEP_SEQ" ]; then
      # 在序列中找当前步骤的下一步
      found_current=false
      for s in $STEP_SEQ; do
        if [ "$found_current" = "true" ]; then
          NEXT_STEP="$s"
          break
        fi
        if [ "$s" = "$STEP_ID" ]; then
          found_current=true
        fi
      done
    fi
  fi

  if [ -n "$NEXT_STEP" ]; then
    echo ""
    log_step "5. 质量门禁 (step-$STEP_ID → step-$NEXT_STEP)"
    gate_rc=0
    bash "$DEV_FLOW_ROOT/scripts/harness/harness-engine.sh" \
      "$FLOW_NAME" "$STEP_ID" "$NEXT_STEP" "${MODIFIED_FILES:-}" || gate_rc=$?

    case $gate_rc in
      0) ;; # 通过，继续
      1) log_fail "❌ P0 门禁失败，禁止推进到 step-$NEXT_STEP"
         df_audit "hook.post_step.harness_fail" "gate P0 failed" step="$STEP_ID" next="$NEXT_STEP"
         exit 1 ;;
      2) log_warn "⚠️  P1 门禁警告（不阻塞推进到 step-$NEXT_STEP）"
         df_audit "hook.post_step.harness_warn" "gate P1 warning" step="$STEP_ID" next="$NEXT_STEP" ;;
    esac
  fi
fi

# ========================================
# 3.6. 步骤 7-standard：YAML 报告物理存在性检查（环节 I 兜底）
# ========================================
# 设计动机：
#   2026-06-09 事故——6 个已完成需求的 YAML 缺失（12/18=67% 覆盖率），根因是环节 I
#   （度量采集）未执行或执行失败但无人察觉。validate-output.sh 只校验 JSON 中的
#   metrics_report_generated 字段（声明），不校验物理文件存在。
#   本检查在 7-standard 完成时校验 .metrics/reports/{FLOW_NAME}.yaml 物理存在。
# 规范源：references/closeout-flow.md §I「环节 I：度量采集」（要求写入 YAML 并立即校验）
if [ "$STEP_ID" = "7-standard" ] || [ "$STEP_ID" = "7_standard" ]; then
  if [ -n "$FLOW_NAME" ]; then
    echo ""
    log_step "3.6. YAML 报告物理存在性检查（环节 I 兜底）"
    YAML_PATH="$HOME/.codebuddy/.metrics/reports/${FLOW_NAME}.yaml"
    if [ -f "$YAML_PATH" ]; then
      log_pass "✅ YAML 报告存在: .metrics/reports/${FLOW_NAME}.yaml"
      df_audit "hook.post_step.yaml_exists" "yaml report found" step="$STEP_ID" flow="$FLOW_NAME"
    else
      log_fail "🔴 YAML 报告缺失: .metrics/reports/${FLOW_NAME}.yaml"
      echo "   环节 I（度量采集）要求写入此文件但未实际落盘"
      echo "   可能原因：环节 I 未执行、写入失败、或文件名不匹配"
      echo "   修复：重新执行环节 I 或手动补建 YAML"
      echo "   参考：references/closeout-flow.md §I + references/metrics-rules.md"
      df_audit "hook.post_step.fail" "yaml report missing" step="$STEP_ID" flow="$FLOW_NAME"
      exit 1
    fi
  fi
fi

# ========================================
# 3.6b. 步骤 7-standard：用户纠正标记格式校验（🔧 [纠正] 门控）
# ========================================
# 设计动机：
#   2026-07-28 复盘发现——13 个 user_corrections>0 的需求中 9 个工作上下文无规范
#   🔧 标记、1 个标记格式不匹配（🔧 误置于时间戳前），gen-flow-report.py 无法
#   提取纠正详情（提取正则要求时间戳前置 [HH:mm] 🔧）。规范
#   （metrics-rules.md §L796-803）早已存在，但书写侧无门控兜底导致系统性遗漏。
#   本检查在 7-standard 完成时校验标记存在性与格式（WARN 级，不阻断）。
# 规范源：references/metrics-rules.md §「用户纠正记录」
# 正则对齐：scripts/gen-flow-report.py L62 extract_corrections（单一真相）
if [ "$STEP_ID" = "7-standard" ] || [ "$STEP_ID" = "7_standard" ]; then
  if [ -n "$FLOW_NAME" ]; then
    echo ""
    log_step "3.6b. 用户纠正标记格式校验（🔧 [纠正] 门控）"
    UC_YAML_PATH="$HOME/.codebuddy/.metrics/reports/${FLOW_NAME}.yaml"
    UC_WC_FILE="$HOME/.codebuddy/working-context/${FLOW_NAME}.md"
    UC_COUNT=$(grep '^user_corrections:' "$UC_YAML_PATH" 2>/dev/null | head -1 | grep -oE '[0-9]+' | head -1 || true)
    UC_COUNT=${UC_COUNT:-0}
    if [ "$UC_COUNT" -gt 0 ] && [ -f "$UC_WC_FILE" ]; then
      # 与 gen-flow-report.py L62 同一正则：列表项 + 时间戳前置 + 🔧（[纠正] 后缀可选）
      MARK_COUNT=$(grep -cE '^[[:space:]]*[-*][[:space:]]*\[([0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]]+)?[0-9]{1,2}:[0-9]{2}\][[:space:]]*🔧' "$UC_WC_FILE" 2>/dev/null || true)
      MARK_COUNT=${MARK_COUNT:-0}
      if [ "$MARK_COUNT" -eq 0 ]; then
        log_warn "⚠️  user_corrections=$UC_COUNT 但工作上下文无规范 🔧 标记（纠正详情将无法进入复盘报告）"
        echo "   规范格式: - [HH:mm] 🔧 [纠正] {描述}（时间戳必须前置）"
        echo "   文件: working-context/${FLOW_NAME}.md"
        echo "   参考: references/metrics-rules.md §「用户纠正记录」"
        df_audit "hook.post_step.warn" "correction marks missing" step="$STEP_ID" flow="$FLOW_NAME" corrections="$UC_COUNT"
      elif [ "$MARK_COUNT" -lt "$UC_COUNT" ]; then
        log_warn "⚠️  🔧 标记数 $MARK_COUNT < user_corrections=$UC_COUNT（部分纠正未按规范记录）"
        echo "   规范格式: - [HH:mm] 🔧 [纠正] {描述}（时间戳必须前置）"
        df_audit "hook.post_step.warn" "correction marks partial" step="$STEP_ID" flow="$FLOW_NAME" corrections="$UC_COUNT" marks="$MARK_COUNT"
      else
        log_pass "✅ 🔧 纠正标记 $MARK_COUNT 条（>= user_corrections=$UC_COUNT）"
        df_audit "hook.post_step.correction_marks" "correction marks ok" step="$STEP_ID" flow="$FLOW_NAME" corrections="$UC_COUNT" marks="$MARK_COUNT"
      fi
    else
      log_info "⏭️  跳过（user_corrections=$UC_COUNT 或工作上下文不存在）"
    fi
  fi
fi

# ========================================
# 3.7. 步骤 7-standard：devlog 状态一致性检查
# ========================================
# 设计动机：
#   2026-06-09 审计发现 15/18 个 devlog 的状态标记与 working-context 不一致：
#   7 个显示 "🟡 开发中"、6 个无状态行，但 working-context 全部为 completed。
#   这说明步骤 7 H.2 环节在生成/更新 devlog 后可能漏写状态行。
#   本检查在 7-standard 完成时校验 devlog 状态标记。
# 规范源：references/devlog-rules.md §「状态标记规范」
if [ "$STEP_ID" = "7-standard" ] || [ "$STEP_ID" = "7_standard" ]; then
  if [ -n "$FLOW_NAME" ]; then
    echo ""
    log_step "3.7. devlog 状态一致性检查"
    # 解析 devlog_dirname：优先从 JSON 读取，其次按日期前缀匹配
    DEVLOG_DIRNAME=""
    if [ -f "$JSON_FILE" ]; then
      DEVLOG_DIRNAME=$(jq -r '.outputs.devlog_dir // ""' "$JSON_FILE" 2>/dev/null || echo "")
    fi
    # 兜底：从 FLOW_NAME 提取日期前缀在 dev-logs/ 中查找
    if [ -z "$DEVLOG_DIRNAME" ]; then
      DATE_PREFIX=$(echo "$FLOW_NAME" | grep -oE '^[0-9]{8}' || echo "")
      if [ -n "$DATE_PREFIX" ]; then
        DEVLOG_DIRNAME=$(find "$HOME/.codebuddy/dev-logs" -maxdepth 1 -type d \
          -name "${DATE_PREFIX}_*" 2>/dev/null | head -1 | xargs basename 2>/dev/null || echo "")
      fi
    fi

    if [ -n "$DEVLOG_DIRNAME" ]; then
      DEVLOG_FILE="$HOME/.codebuddy/dev-logs/$DEVLOG_DIRNAME/devlog.md"
      if [ -f "$DEVLOG_FILE" ]; then
        STATUS_LINE=$(grep '^\> \*\*状态\*\*' "$DEVLOG_FILE" 2>/dev/null | head -1 || echo "")
        if echo "$STATUS_LINE" | grep -q '✅ 已完成'; then
          log_pass "✅ devlog 状态正确: ✅ 已完成"
        elif [ -z "$STATUS_LINE" ]; then
          log_warn "⚠️  devlog 缺少状态行（建议在头部添加 '> **状态**：✅ 已完成'）"
          echo "   文件: dev-logs/$DEVLOG_DIRNAME/devlog.md"
          df_audit "hook.post_step.warn" "devlog status line missing" step="$STEP_ID" flow="$FLOW_NAME" devlog_dir="$DEVLOG_DIRNAME"
        else
          log_warn "⚠️  devlog 状态不是 '✅ 已完成'，当前: $(echo "$STATUS_LINE" | sed 's/> \*\*状态\*\*：//')"
          echo "   文件: dev-logs/$DEVLOG_DIRNAME/devlog.md"
          echo "   建议更新为 '✅ 已完成'"
          df_audit "hook.post_step.warn" "devlog status not completed" step="$STEP_ID" flow="$FLOW_NAME" devlog_dir="$DEVLOG_DIRNAME"
        fi
      else
        log_warn "⚠️  devlog 文件不存在: dev-logs/$DEVLOG_DIRNAME/devlog.md（跳过状态检查）"
      fi
    else
      log_warn "⚠️  无法解析 devlog 目录名（跳过状态检查）"
    fi
  fi
fi

# ========================================
# 3.8. 步骤 7-standard：devlog-integrity-lint 完整性扫描（步骤 7 §K 对齐）
# ========================================
# 设计动机：
#   devlog-integrity-lint.sh 是步骤 7 §K 强制执行的完整性自检，应在 post-step hook
#   中作为物理兜底再执行一次（与 JSON 中的 devlog_integrity_check 字段互补）。
#   防止步骤 7 完成标记声称通过了自检但实际未执行的情况。
# 规范源：steps/step-7-commit.md §K + references/gate-validator.md §「dev-logs 完整性」
if [ "$STEP_ID" = "7-standard" ] || [ "$STEP_ID" = "7_standard" ]; then
  echo ""
  log_step "3.8. devlog-integrity-lint 完整性兜底扫描（步骤 7 §K 对齐）"
  dli_rc=0
  bash "$DEV_FLOW_ROOT/scripts/lints/devlog-integrity-lint.sh" --strict --quiet || dli_rc=$?
  if [ $dli_rc -ne 0 ]; then
    log_fail "🔴 devlog-integrity-lint 发现错误（--strict 模式）"
    echo "   详见上方输出，修复后重新运行步骤 7"
    df_audit "hook.post_step.fail" "devlog-integrity-lint failed" step="$STEP_ID" flow="$FLOW_NAME"
    exit 1
  else
    log_pass "✅ devlog-integrity-lint 通过"
  fi
fi

# ========================================
# 3.9. Token/模型统计（步骤 7-standard 完成时，P2 轻量版）
# ========================================
# 设计意图：
#   IDE 不暴露原始 token API，通过 heuristic 估算每个步骤的 token 消耗，
#   并记录主模型和子 agent 模型信息，为可视化 Dashboard 提供成本数据。
#   估算精度：粗粒度（步骤级），但足以用于趋势分析和模式对比。
# 规范源：P2 Token/模型统计（2026-07-08 loop-engineering 分析产物）
if [ "$STEP_ID" = "7-standard" ] || [ "$STEP_ID" = "7_standard" ]; then
  if [ -n "$FLOW_NAME" ]; then
    echo ""
    log_step "3.9. Token/模型消耗估算（P2 轻量版）"
    
    TE_SCRIPT="$DEV_FLOW_ROOT/scripts/harness/token-estimate.sh"
    if [ -f "$TE_SCRIPT" ] && [ -x "$TE_SCRIPT" ]; then
      # 估算全流程 token
      TE_RESULT=$(bash "$TE_SCRIPT" "$FLOW_NAME" 2>&1) || true
      
      if [ -n "$TE_RESULT" ] && echo "$TE_RESULT" | grep -q "total_est_tokens"; then
        total=$(echo "$TE_RESULT" | sed 's/.*"total_est_tokens":\([0-9]*\).*/\1/')
        model=$(echo "$TE_RESULT" | sed 's/.*"model":"\([^"]*\)".*/\1/')
        
        if [ -n "$total" ] && [ "$total" -gt 0 ] 2>/dev/null; then
          # 写入 .flow 文件供 dashboard 消费
          FLOW_FILE_TE="$(df_active_flows_dir)/${FLOW_NAME}.flow"
          if [ -f "$FLOW_FILE_TE" ]; then
            # 追加 token/model 统计（幂等：若已有则替换）
            if grep -q "^est_tokens:" "$FLOW_FILE_TE"; then
              sed -i.bak "s/^est_tokens:.*/est_tokens: $total/" "$FLOW_FILE_TE" && rm -f "${FLOW_FILE_TE}.bak"
            else
              echo "est_tokens: $total" >> "$FLOW_FILE_TE"
            fi
            if grep -q "^primary_model:" "$FLOW_FILE_TE"; then
              sed -i.bak "s/^primary_model:.*/primary_model: $model/" "$FLOW_FILE_TE" && rm -f "${FLOW_FILE_TE}.bak"
            else
              echo "primary_model: $model" >> "$FLOW_FILE_TE"
            fi
          fi
          log_pass "✅ 全流程估算: ~${total} tokens（模型: ${model}）"
          df_audit "hook.post_step.token_estimate" "token estimate recorded" \
            step="$STEP_ID" flow="$FLOW_NAME" est_tokens="$total" model="$model"
        else
          log_warn "⚠️  token 估算结果无效，跳过"
        fi
      else
        log_warn "⚠️  token 估算脚本返回异常，跳过"
      fi
    else
      log_info "⏭️  跳过 token 估算（脚本不可用）"
    fi
  fi
fi

# ========================================
# 3.10. 步骤 5/5.5/7：可选链检查（?.) 门控
# ========================================
# 设计动机：
#   AI 在手动审查可选链时会做主观豁免（"回调参数安全"、"守卫后安全"），
#   导致裸 . 属性访问漏过。此脚本使用确定性 grep 规则，不依赖 AI 判断。
#   触发步骤：5（编码后）、5.5（L1 审查后）、7（commit 前）。
# 规范源：开发规范-红线.mdc §7（所有链式属性访问必须使用 ?.）
optional_chain_should_check=false
case "$STEP_ID" in
  5|5.5|5_5|7-standard|7_standard|7-full|7_full|7-batch|7_batch)
    optional_chain_should_check=true
    ;;
esac

if $optional_chain_should_check; then
  echo ""
  log_step "3.10. 可选链检查（?. 门控）"

  OC_SCRIPT="$DEV_FLOW_ROOT/scripts/lints/optional-chain-lint.sh"
  if [ -f "$OC_SCRIPT" ] && [ -x "$OC_SCRIPT" ]; then
    oc_rc=0
    set +e; bash "$OC_SCRIPT"; oc_rc=$?; set -e

    if [ "$oc_rc" -ne 0 ]; then
      log_fail "❌ 可选链检查未通过（发现缺少 ?. 的属性访问）"
      df_audit "hook.post_step.fail" "optional-chain-lint failed" step="$STEP_ID"
      exit 1
    else
      log_pass "✅ 可选链检查通过"
      df_audit "hook.post_step.ok" "optional-chain-lint passed" step="$STEP_ID"
    fi
  else
    log_warn "⚠️  optional-chain-lint.sh 不可用，跳过可选链检查"
  fi
fi

# ========================================
# 3.11. 步骤 7-micro-fix：文档同步物理事实校验
# ========================================
# 设计动机：
#   2026-07-14 事故——micro-fix 模式下 AI 在 smart-commit「跳过提交」后直接终止，
#   不执行 H.2 devlog + H.3 knowledge + plan.md CR 同步，导致后续 dev:sync 时才发现
#   全部文档滞后。本检查在 validate-output.sh 之前校验物理文件状态，不依赖 AI 承诺。
# 规范源：references/micro-fix-light.md §四/§五 + steps/step-7-commit.md
if [ "$STEP_ID" = "7-micro-fix" ] || [ "$STEP_ID" = "7_micro_fix" ]; then
  echo ""
  log_step "3.11. micro-fix 文档同步物理事实校验"
  MF_SYNC_LINT="$DEV_FLOW_ROOT/scripts/lints/micro-fix-doc-sync-lint.sh"
  if [ -f "$MF_SYNC_LINT" ] && [ -x "$MF_SYNC_LINT" ]; then
    mf_rc=0
    set +e; bash "$MF_SYNC_LINT" "$FLOW_NAME"; mf_rc=$?; set -e
    if [ "$mf_rc" -ne 0 ]; then
      log_fail "🔴 文档同步未完成（devlog / plan.md 遗漏）"
      echo "   可能原因：AI 在 smart-commit 跳过提交后未继续执行 H.2/H.3"
      echo "   修复：执行 H.2 devlog 追加 + plan.md CR 同步后重新提交"
      df_audit "hook.post_step.fail" "micro-fix doc sync missing" step="$STEP_ID" flow="$FLOW_NAME"
      exit 1
    fi
    log_pass "✅ micro-fix 文档同步完成"
    df_audit "hook.post_step.ok" "micro-fix doc sync passed" step="$STEP_ID"
  else
    log_warn "⚠️  micro-fix-doc-sync-lint.sh 不可用，跳过"
  fi
fi

# ========================================
# 6. 步骤 7 / 10：工作上下文位置完整性检查（流程结束兜底）
# ========================================
# 设计动机：
#   2026-06-02 事故根因——有人/Agent 在流程已 completed 后手动 mv .md 到 archive/ 子目录，
#   导致 dashboard 显示 ARCHIVED 角标。所有现有 lint 假设 .md 在顶层（-f 静默跳过反而隐藏问题）。
#   本检查在流程结束节点强制校验 .md 位置 + 状态一致性 + .active-flows 残留。
# 单一权威源：scripts/lints/working-context-location-lint.sh
#
# 🔴 2026-06-09 修复：原条件 `[ "$STEP_ID" = "7" ]` 不覆盖 7-standard/7-full/7-batch 等变体，
#   与 §3 已修复的同类型 bug 一致。扩展为 case 模式匹配。
location_should_check=false
case "$STEP_ID" in
  7|7-standard|7_standard|7-full|7_full|7-batch|7_batch|10)
    location_should_check=true
    ;;
esac
if [ "$location_should_check" = "true" ]; then
  if [ -n "$FLOW_NAME" ]; then
    echo ""
    log_step "6. 工作上下文位置完整性检查（流程结束兜底）"
    loc_rc=0
    bash "$DEV_FLOW_ROOT/scripts/lints/working-context-location-lint.sh" "$FLOW_NAME" || loc_rc=$?
    case $loc_rc in
      0) ;;  # 通过
      1) log_fail "🔴 工作上下文位置完整性失败"
         df_audit "hook.post_step.fail" "working-context-location-lint failed" step="$STEP_ID" flow="$FLOW_NAME"
         exit 1 ;;
      2) log_warn "⚠️  工作上下文位置完整性有警告（不阻断）"
         df_audit "hook.post_step.warn" "working-context-location-lint warned" step="$STEP_ID" flow="$FLOW_NAME" ;;
    esac
  fi
fi

# ========================================
# 7. 流程结束自动清理（.flow + .validated* + .done）
# ========================================
# 设计动机：
#   2026-07-08 补充：原设计中步骤 7/10 完成后的 .flow + .validated* 清理
#   是 AI 手动操作步骤（step-router.md §「步骤完成」§动作 2），无自动化 enforcement。
#   导致已完成流程的 .flow 和 .validated* 文件长期残留（如 20260429 的 .flow
#   status=completed 未删除，20260514/20260529 的孤儿 .validated* 无人清理）。
#   本节在所有校验通过后自动执行清理，消除人工遗漏。
# 规范源：steps/step-router.md §「步骤完成」§动作 2（最终步骤删除 .flow）
#         + steps/step-router.md §「物理检查点规范」（流程结束时清理 .validated*）
# 安全机制：
#   - 仅 STEP_ID ∈ {7-standard, 7-batch, 7-micro-fix, 10} 时触发
#     （7-full 的 next_step=8 不触发，保留至步骤 10）
#   - 仅 JSON 中 next_step="done" 时触发（双重确认流程确实结束）
#   - 位于所有前置校验（Schema/新鲜度/doc_platform/YAML/devlog/位置完整性）通过之后
#   - rm -f 天然幂等，文件不存在时静默成功
case "$STEP_ID" in
  7-standard|7_standard|7-batch|7_batch|7-micro-fix|7_micro_fix|10)
    if [ -n "$FLOW_NAME" ] && [ -f "$JSON_FILE" ]; then
      FINAL_DEST=$(jq -r '.next_step // ""' "$JSON_FILE" 2>/dev/null || echo "")
      if [ "$FINAL_DEST" = "done" ]; then
        echo ""
        log_step "7. 流程结束自动清理（next_step=done）"
        CLEANED_COUNT=0
        AFLOWS_DIR="$(df_active_flows_dir)"

        # 清理 .flow 锁文件
        FLOW_FILE_CLEANUP="$AFLOWS_DIR/${FLOW_NAME}.flow"
        if [ -f "$FLOW_FILE_CLEANUP" ]; then
          rm -f "$FLOW_FILE_CLEANUP"
          log_pass "🗑️  已删除 .flow: ${FLOW_NAME}.flow"
          CLEANED_COUNT=$((CLEANED_COUNT + 1))
        fi

        # 清理所有 .validated* 检查点
        for f in "$AFLOWS_DIR/${FLOW_NAME}".step-*.validated*; do
          [ -f "$f" ] || continue
          rm -f "$f"
          CLEANED_COUNT=$((CLEANED_COUNT + 1))
        done

        # 清理旧 .done 兼容文件（v1 遗留）
        for f in "$AFLOWS_DIR/${FLOW_NAME}".step-*.done; do
          [ -f "$f" ] || continue
          rm -f "$f"
          CLEANED_COUNT=$((CLEANED_COUNT + 1))
        done

        # 清理熔断器状态目录（流程结束，计数已无意义）
        BREAKER_DIR="$AFLOWS_DIR/${FLOW_NAME}.breaker"
        if [ -d "$BREAKER_DIR" ]; then
          rm -rf "$BREAKER_DIR"
          log_info "🗑️  已清理熔断器状态: ${FLOW_NAME}.breaker/"
          CLEANED_COUNT=$((CLEANED_COUNT + 1))
        fi

        log_pass "🗑️  共清理 ${CLEANED_COUNT} 个文件（.flow + .validated* + .done + .breaker）"
        df_audit "hook.post_step.cleanup" "flow end auto-cleanup" \
          step="$STEP_ID" flow="$FLOW_NAME" files_cleaned="$CLEANED_COUNT"
      fi
    fi
    ;;
esac

# ========================================
# 8. 熔断器重置（所有检查通过，证明 AI 成功完成本步骤）
# ========================================
# 设计动机：仅在所有检查（Schema/doc_platform/freshness/YAML/devlog/location）全部通过后
# 才重置全局熔断计数器。若任一中间检查失败，计数器保留，下次 post-step 继续累加。
if [ -n "$FLOW_NAME" ]; then
  CB_RESET="$DEV_FLOW_ROOT/scripts/harness/circuit-breaker.sh"
  if [ -f "$CB_RESET" ] && [ -x "$CB_RESET" ]; then
    bash "$CB_RESET" --reset "$FLOW_NAME" "$STEP_ID" >/dev/null 2>&1 || true
  fi
fi

echo ""
log_pass "✅ post-step hook 全部通过"
df_audit "hook.post_step.pass" "post-step passed" step="$STEP_ID"
exit 0
