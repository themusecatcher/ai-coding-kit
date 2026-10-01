#!/usr/bin/env bash
# dev-comp 工作上下文命名 lint（dev-comp 专属，独立于 dev-flow 体系）
#
# 规则真相（单一权威源）：
#   ← references/capability-reuse.md §工作上下文 · 命名规则（2026-10-01 定型）
# 调用点：
#   ← references/flow.md §阶段 0 第 1 条（新建后必跑，单文件模式）
#   ← references/flow.md §阶段 5 第 8 条（收尾，--all）
#   ← references/flow.md §dc:st / dc:status 子命令（--all 全量体检）
#
# 检查项：
#   L1 文件名格式：^vaui-[a-z0-9]+(-[a-z0-9]+)*-[0-9]{8}\.md$
#   L2 目录纯净性：working-context/ 内不得出现非工作上下文文件（异构文件禁令）
#   L3 组件段 = 项目 components/ 实测目录名（kebab；归一化比对，兼容历史 camelCase/PascalCase）
#   L4 frontmatter `component:` 为 PascalCase（组件导出名口径）
#   L5 归一化重名：同一组件存在多个工作上下文（违反「单文件覆盖式更新」）
#
# 已知边界（2026-10-01 评估为「刻意不加」，命中触发条件再补；勿未经评估直接加）：
#   B1 未做「文件名段 ↔ component 字段」交叉校验：历史 0/14 不一致，出错通道窄（阶段 0 走模板新建而
#      非复制旧文件）；且 73 个目录中有 1 个无同名导出（grid → Row/Col），加它须先定「目录聚合组件的
#      component 取值」规范（超范围）。
#      触发：出现首次不一致 / 开发 Grid 组件 / 创建方式改为复制旧文件 → 增设 L6。
#   B2 未查 working-context/ 内子目录（L2 用 `find -maxdepth 1 -type f`，子目录会被沉默放过）：dev-comp
#      历史 0 次，且三处明文禁止归档（capability-reuse §异构文件禁令 / SKILL 第 3、6 条 / flow 阶段 5）。
#      触发：出现首例子目录 → L2 扩为「文件 + 子目录」同判违规。
#
# 用法：
#   lint-working-context-name.sh                      # 等价 --all（全量体检）
#   lint-working-context-name.sh --all [--suggest]    # 全量体检
#   lint-working-context-name.sh <工作上下文.md>       # 单文件校验（阶段 0 新建后）
# 环境变量：
#   VAUI_WC_DIR        工作上下文目录（默认 ~/.codebuddy/dev-comp/working-context）
#   VAUI_PROJECT_ROOT  组件库项目根（默认 ~/myGithub/vue-amazing-ui）
# 退出码：0 = 无 FAIL；1 = 存在 FAIL；2 = 参数/环境错误
# ⚠️ 必须用 bash 运行；本脚本不使用 bash 4 特性（declare -A），兼容 macOS 自带 bash 3.2
set -o pipefail   # 不用 -u：bash 3.2 下空数组展开在 set -u 时会误报

if [ -z "${BASH_VERSION:-}" ]; then
  echo "[FATAL] 请用 bash 运行本脚本：bash lint-working-context-name.sh ...（当前 shell 非 bash）" >&2
  exit 2
fi

WC_DIR="${VAUI_WC_DIR:-$HOME/.codebuddy/dev-comp/working-context}"
ROOT="${VAUI_PROJECT_ROOT:-$HOME/myGithub/vue-amazing-ui}"
NAME_RE='^vaui-[a-z0-9]+(-[a-z0-9]+)*-[0-9]{8}\.md$'
# 宽松形态：仅用于 L2 判定「是否工作上下文」（大小写不计，命名合规性由 L1 负责）
LOOSE_RE='^vaui-[A-Za-z0-9]+(-[A-Za-z0-9]+)*-[0-9]{8}\.md$'

PASS_N=0; FAIL_N=0; WARN_N=0; SKIP_N=0
QUIET_OK=0

ok()  { PASS_N=$((PASS_N+1)); [ "$QUIET_OK" = 1 ] && return 0; echo "  [PASS] $*"; }
bad() { FAIL_N=$((FAIL_N+1)); echo "  [FAIL] $*"; }
wrn() { WARN_N=$((WARN_N+1)); echo "  [WARN] $*"; }
skp() { SKIP_N=$((SKIP_N+1)); echo "  [SKIP] $*"; }

norm()     { printf '%s' "$1" | tr -d '_-' | tr 'A-Z' 'a-z'; }
to_kebab() { printf '%s' "$1" | sed -E 's/([a-z0-9])([A-Z])/\1-\2/g; s/([A-Z]+)([A-Z][a-z])/\1-\2/g' | tr 'A-Z' 'a-z'; }

USAGE="用法: lint-working-context-name.sh [--all] [--suggest] [<工作上下文.md>]"

usage() { echo "$USAGE"; }

COMP_DIRS=""
[ -d "$ROOT/components" ] && COMP_DIRS="$(find "$ROOT/components" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; 2>/dev/null | sort)"

project_dir_for() {   # $1 = 归一化组件名 → 项目实测目录名（无则空输出）
  [ -n "$COMP_DIRS" ] || return 0
  printf '%s\n' "$COMP_DIRS" | while IFS= read -r d; do
    [ -n "$d" ] || continue
    if [ "$(norm "$d")" = "$1" ]; then printf '%s\n' "$d"; break; fi
  done
}

check_file() {   # $1 = 文件绝对路径
  local f b stem seg sug cv hit mid date_suf
  f="$1"; b="$(basename "$f")"; stem="${b%.md}"
  echo "· ${b}"

  # ---- L1 文件名格式 ----
  if printf '%s' "$b" | grep -qE "$NAME_RE"; then
    seg="$(printf '%s' "$stem" | sed -E 's/^vaui-//; s/-[0-9]{8}$//')"
    ok "L1 格式合规（组件段 '${seg}'）"
  else
    seg=""; sug=""
    if printf '%s' "$stem" | grep -qE '^vaui-'; then
      mid="$(printf '%s' "$stem" | sed -E 's/^vaui-//')"
      date_suf=""
      if printf '%s' "$mid" | grep -qE -- '-[0-9]{8}$'; then
        date_suf="$(printf '%s' "$mid" | grep -oE -- '[0-9]{8}$')"
        mid="$(printf '%s' "$mid" | sed -E 's/-[0-9]{8}$//')"
      fi
      [ -n "$date_suf" ] || date_suf="$(date +%Y%m%d)"
      seg="$(to_kebab "$mid")"
      sug="vaui-${seg}-${date_suf}.md"
      bad "L1 文件名不合规（应 'vaui-{组件目录名}-{YYYYMMDD}.md'；组件目录名取 kebab）→ 建议改名：${sug}"
      [ "$SUGGEST" = 1 ] && echo "        命令：mv ${WC_DIR}/${b} ${WC_DIR}/${sug}"
    else
      bad "L1 文件名不合规且非 vaui- 前缀 → 异构文件，应迁至 dev-comp/notes/（命名 {YYYYMMDD}_{简述}_{类型}.md）"
    fi
  fi

  # ---- L3 与项目 components/ 实测目录比对 ----
  if [ -n "$seg" ] && [ -n "$COMP_DIRS" ]; then
    hit="$(project_dir_for "$(norm "$seg")")"
    if [ -n "$hit" ]; then
      ok "L3 组件段与项目目录一致（components/${hit}/）"
    else
      # WARN 非 FAIL：组件尚未落地（工作上下文先行，如计划中的 TimePicker）或非独立组件目录时属正常
      wrn "L3 组件段 '${seg}' 在 ${ROOT}/components/ 无同源目录 —— 组件未落地/非独立目录可忽略，否则核对命名"
    fi
  elif [ -n "$seg" ]; then
    skp "L3 项目 components/ 不可读（ROOT=${ROOT}），跳过目录比对"
  fi

  # ---- L4 frontmatter component: 口径 ----
  cv="$(grep -m1 '^component:' "$f" 2>/dev/null | sed -E 's/^component:[[:space:]]*//; s/[[:space:]]*$//; s/^"//; s/"$//')"
  if [ -z "$cv" ]; then
    bad "L4 frontmatter 缺 component: 字段（应取组件导出名 PascalCase）"
  elif printf '%s' "$cv" | grep -qE '^[A-Z][A-Za-z0-9]*$'; then
    ok "L4 frontmatter component: '${cv}'（PascalCase 合规）"
  else
    bad "L4 frontmatter component: '${cv}' 非 PascalCase（应取导出名，如 'DatePicker'）"
  fi
}

# ------------------------------------------------------------
# 参数解析
# ------------------------------------------------------------
TARGET=""; ALL=0; SUGGEST=0
for a in "$@"; do
  case "$a" in
    --all) ALL=1 ;;
    --suggest) SUGGEST=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "[FATAL] 未知参数：${a}。${USAGE}" >&2; exit 2 ;;
    *) TARGET="$a" ;;
  esac
done
[ -n "$TARGET" ] || ALL=1

FILES=()
if [ -n "$TARGET" ]; then
  [ -f "$TARGET" ] || { echo "[FATAL] 文件不存在：${TARGET}" >&2; exit 2; }
  FILES=("$TARGET")
else
  [ -d "$WC_DIR" ] || { echo "[FATAL] 工作上下文目录不存在：${WC_DIR}（可用 VAUI_WC_DIR 指定）" >&2; exit 2; }
  while IFS= read -r f; do FILES+=("$f"); done < <(find "$WC_DIR" -maxdepth 1 -type f ! -name '.*' | sort)
  [ "${#FILES[@]}" -gt 0 ] || { echo "[FATAL] 目录内无文件：${WC_DIR}" >&2; exit 2; }
  QUIET_OK=1
fi

echo "[dev-comp lint] 工作上下文命名 | 目录: ${WC_DIR}"
[ "$ALL" = 1 ] && echo "（--all 模式：仅打印 FAIL/WARN，PASS 计数汇总）"

# ------------------------------------------------------------
# 逐文件检查
# ------------------------------------------------------------
if [ "$ALL" = 1 ]; then
  echo
  echo "== 逐文件校验（L1 格式 / L3 目录一致 / L4 component 口径） =="
fi
for f in "${FILES[@]}"; do check_file "$f"; done

# ------------------------------------------------------------
# L2 目录纯净性 + L5 归一化重名（仅 --all）
# ------------------------------------------------------------
if [ "$ALL" = 1 ]; then
  echo
  echo "== L2 目录纯净性（异构文件禁令） =="
  DIRTY="$(find "$WC_DIR" -maxdepth 1 -type f ! -name '.*' -exec basename {} \; 2>/dev/null | grep -vE "$LOOSE_RE" || true)"
  if [ -z "$DIRTY" ]; then
    ok "L2 目录内全部为合规工作上下文"
  else
    while IFS= read -r d; do
      [ -n "$d" ] || continue
      bad "L2 非工作上下文/命名不合规文件：${d}（应迁出或改名）"
    done < <(printf '%s\n' "$DIRTY")
  fi

  echo
  echo "== L5 归一化重名（同一组件仅允许一个文件） =="
  DUPS="$(for f in "${FILES[@]}"; do
      b="$(basename "$f")"
      printf '%s|%s\n' "$(norm "${b%.md}" | sed -E 's/^vaui//; s/[0-9]{8}$//')" "${b}"
    done | sort | awk -F'|' '{n[$1]++; o[$1]=o[$1]" "$2} END{for(k in n) if(n[k]>1) print k" ->"o[k]}')"
  if [ -z "$DUPS" ]; then
    ok "L5 无归一化重名"
  else
    while IFS= read -r d; do
      [ -n "$d" ] || continue
      bad "L5 同一组件多个工作上下文：${d}（规范要求单文件覆盖式更新）"
    done < <(printf '%s\n' "$DUPS")
  fi
fi

# ------------------------------------------------------------
# 汇总
# ------------------------------------------------------------
echo
echo "== 汇总 =="
echo "PASS=${PASS_N}  FAIL=${FAIL_N}  WARN=${WARN_N}  SKIP=${SKIP_N}（文件数 ${#FILES[@]}）"
if [ "$FAIL_N" -gt 0 ]; then
  echo "结果：FAIL —— 形态定义见 references/capability-reuse.md §命名规则；改名属用户决策，脚本不自动改"
  exit 1
fi
echo "结果：PASS"
exit 0
