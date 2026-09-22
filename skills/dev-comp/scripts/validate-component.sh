#!/bin/bash
# ============================================================
# validate-component.sh - dev-comp 阶段 5 收尾轻量校验脚本
#
# 定位：dev-comp 唯一的程序化校验入口（轻量定位：不做 .validated
# 物理锁、不接状态机、不做 gate 链、不做 hooks 自动触发）。
# 把 references/checklists.md §发布前配置项终检（A/B/C/E/F/G 类）+
# 提交红线（S 类：S1 git 身份 / S2 分支核对 / S3 commit hash 回填真实性 /
# S4 能力沉淀三件套 / S5 归档双份）中的确定性 grep 检查收拢为单一可执行体，
# 作为 Gate 5 报告「发布前配置项终检」区块的数据来源。
#
# 规则权威源（双向引用，规则变更必须同步改本脚本）：
#   ← references/checklists.md §发布前配置项终检（ID 一一对应：A/B/C/E/F/G + S）
#   ← references/linkage-map.md §④⑩⑪⑫⑬⑭⑮
#   ← references/changelog-spec.md §3.2 §3.4 §4（F6）
#   ← references/project-map.md §目录命名约定 / §项目规范权威源索引
#   ← references/refine-spec.md §1 §3.3 §5（C5 品牌残留 / G2 Props 顺序 / G4 用例对齐）
#   ← references/flow.md 阶段 5 第 1/4/5/6 步
#   ← SKILL.md §能力复用索引
#
# 2026-09-22（多次实践复盘 · 交付前精修）变更：
#   ① 新增 C5：品牌信息残留扫描（两段口径 = 本分支净改动新增行[基点→当前工作区] +
#      未跟踪新增文件全文，覆盖「分批开发 + 分批提交」场景；存量不追溯；
#      例外 @ant-design/icons-vue 等既有 @ant-design/* 基础包）。
#   ② 新增 G 节（G1-G6）：交付前精修与三方一致性。确定性下沉 G2（源码 Props 顺序
#      ↔ docs API 表顺序）、G4（views ↔ docs 用例数量/顺序/标题）；G1/G3/G5/G6
#      为语义判断 → SKIP 提示人工按 refine-spec.md 勾销。
#   ③ 新增 --base <ref> 参数（C5 分支基点，支持工作上下文 base_ref 字段）。
#
# 2026-09-15（Comment 事故复盘）变更：
#   ① 修正 B5：原「API 章节四件套齐全」判定过严——项目多数组件无事件/无暴露方法，
#      文档只有 `## APIs` + `## Slots`，会产生**假 FAIL**；改为「APIs 必有 +
#      Events/Methods 按组件实际能力（有 defineEmits/defineExpose 才要求）」。
#   ② 新增 F 节（F1-F8）：组件本体与跨文件规范检查（含 F5 `types/global-components.d.ts`
#      登记差集校验——漏登记不报错、type-check 仍 PASS，属静默失效，必须脚本兜底）。
#
# 用法：
#   validate-component.sh <组件名> [项目根] [--context <工作上下文.md>] [--base <git ref>]
#   环境变量：VAUI_PROJECT_ROOT 替代参数 2；VAUI_ARTIFACTS_DIR 替代归档兜底目录
#   --base：C5 分支基点（分批提交时用于回溯已提交改动）；缺省按
#           工作上下文 base_ref → merge-base(origin/main|origin/master|main|master, HEAD) 自动解析
#
# 输出：每项 [PASS]/[FAIL]/[WARN]/[SKIP] + 证据行 + 汇总
# 退出码：0=无 FAIL（WARN/SKIP 不阻断）；1=存在 FAIL；2=参数错误
#
# ⚠️ 维护红线（2026-09-22 自查事故）：shell 变量后紧跟**非 ASCII 字符**（如中文括号）
#    必须写成 `${VAR_名}`——bash 在 UTF-8 locale 下会把中文标点并入变量名，配合 set -u
#    直接以「unbound variable」中断脚本（事故现场：G2 的 MISS 提示导致 G3-G6/S 段被整段跳过）。
#    自检：rg '\$[A-Za-z_][A-Za-z0-9_]*[^\x00-\x7F]' scripts/validate-component.sh 应为 0 命中
#
# 兼容：macOS bash 3.2（不依赖关联数组 / mapfile）
# ============================================================

set -u

# ⚠️ 必须用 bash 运行：脚本依赖 bash 的单词分割（`for f in $VAR`）与 $BASH_VERSION 等语义；
#    误在 zsh 下执行（zsh 默认不做单词分割）会导致扫描集合为单元素、**检查静默失效**。
if [ -z "${BASH_VERSION:-}" ]; then
  echo "[FATAL] 请用 bash 运行本脚本：bash validate-component.sh <组件名> <项目根> …（当前 shell 非 bash 会静默失效）" >&2
  exit 2
fi

# 临时文件统一清理（异常退出 / Ctrl-C 也不留残留；文件名均以 $$ 作用域隔离）
trap 'rm -f /tmp/dc-ghost-$$.txt /tmp/dc-map-$$.txt /tmp/dc-decl-$$.txt \
  /tmp/dc-brand-$$.txt /tmp/dc-brand-seen-$$.txt \
  /tmp/dc-vt-$$.txt /tmp/dc-dt-$$.txt /tmp/dc-dtu-$$.txt' EXIT

NAME="${1:-}"
ROOT="${2:-${VAUI_PROJECT_ROOT:-$HOME/myGithub/vue-amazing-ui}}"
CTX=""
BASE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --context) CTX="$2"; shift 2 ;;
    --base) BASE="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [ -z "$NAME" ]; then
  echo "用法: validate-component.sh <组件名> [项目根] [--context <工作上下文.md>] [--base <git ref>]" >&2
  exit 2
fi

# 归一化组件名：AutoComplete -> autocomplete（归一化示例：小写、去分隔符；实际目录名为 kebab-case，如 auto-complete）。
# 项目目录命名约定不统一（components/ 与 docs/ 为 kebab-case、src/views/ 为 camelCase），
# 禁止用固定形态猜测路径，必须解析真实条目（详见 project-map.md §目录命名约定）。
LCNAME=$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
FALLBACK="${VAUI_ARTIFACTS_DIR:-$HOME/myGithub/ai-coding-kit/skills/dev-comp/artifacts}"

# ------------------------------------------------------------
# 「非公开组件」定义（B4/E1 与 F5 共用）
# components/ 下并非每个目录都是「面向用户的基础 UI 组件」：
#   - style / utils   ：样式入口与工具函数，非组件
#   - discrete        ：createDiscreteApi 工具函数，非组件
#   - popup           ：内部浮层宿主（Tooltip 等的「参照容器 + 面板」承载层），
#                       无对外文档、不在 components.ts 导出，但需存在于 resolver.componentsMap
#                       供 componentDependencies 依赖解析（如 Tooltip: [..., 'Popup']）
# 二者口径差异：目录名（小写 kebab）/ 组件导出名（大驼峰），故分别维护。
# ⚠️ 新增此类内部目录/组件时必须同步本定义，否则 B4/E1、F5 会产生假 FAIL。
# ------------------------------------------------------------
NON_COMPONENT_DIRS="style|utils|discrete|popup"
NON_PUBLIC_COMPS="Popup"

# resolve_entry <目录>：按归一化名（去 .md 后缀）在该目录下匹配真实条目名，
# 命中输出条目名（可能带 .md 后缀），未命中输出空。
resolve_entry() {
  local dir="$1" p b n
  [ -d "$dir" ] || return 0
  for p in "$dir"/*; do
    [ -e "$p" ] || continue
    b=$(basename "$p")
    n=$(echo "$b" | sed 's/\.md$//' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
    if [ "$n" = "$LCNAME" ]; then echo "$b"; return 0; fi
  done
  return 0
}

COMP_DIR=$(resolve_entry "$ROOT/components")
VIEW_DIR=$(resolve_entry "$ROOT/src/views")
DOC_ENTRY=$(resolve_entry "$ROOT/docs/guide/components")
DOC_FILE="$ROOT/docs/guide/components/$DOC_ENTRY"

PASS=0; FAIL=0; WARN=0; SKIP=0
ok()   { PASS=$((PASS+1)); echo "  [PASS] $1"; }
fail() { FAIL=$((FAIL+1)); echo "  [FAIL] $1"; }
warn() { WARN=$((WARN+1)); echo "  [WARN] $1"; }
skip() { SKIP=$((SKIP+1)); echo "  [SKIP] $1"; }
section() { echo; echo "== $1 =="; }

echo "[dev-comp validate] 组件: $NAME | 项目: $ROOT"
[ -d "$ROOT" ] || { echo "[FATAL] 项目根不存在: ${ROOT}（参数 2 或 VAUI_PROJECT_ROOT 指定）" >&2; exit 2; }

# 脚本自检：变量后紧跟非 ASCII 字符（bash 会把中文标点并入变量名，set -u 下中断整个脚本）
SELF_BUG=$(grep -nE '\$[A-Za-z_][A-Za-z0-9_]*[^ -~]' "$0" 2>/dev/null | head -3)
[ -n "$SELF_BUG" ] && echo "  [WARN] 脚本自身存在「变量后紧跟非 ASCII 字符」隐患（会中断执行）：$SELF_BUG" >&2

# ============================================================
# A · 代码注册链路（对应 checklists.md A1-A5）
# ============================================================
section "A 代码注册链路"

# A1 withInstall + 类型导出
# ⚠️ 复合组件（2026-09-22 自查修正）：聚合层 index.ts 只做 `import/export 子组件`，
#    withInstall 位于**子组件层** index.ts（如 dropdown/dropdown/index.ts）——原判定会假 FAIL。
A1_F="$ROOT/components/$COMP_DIR/index.ts"
A1_SUB=""
if [ -n "$COMP_DIR" ]; then
  A1_SUB=$(grep -rl "withInstall" "$ROOT/components/$COMP_DIR" --include='index.ts' 2>/dev/null \
    | grep -v "^${A1_F}$" | sed "s|^${ROOT}/||" | tr '\n' ' ')
fi
if [ -n "$COMP_DIR" ] && [ -f "$A1_F" ] && grep -q "withInstall" "$A1_F"; then
  ok "A1 components/$COMP_DIR/index.ts 存在且含 withInstall（单组件）"
elif [ -n "$A1_SUB" ]; then
  ok "A1 复合组件：聚合 index.ts 委托子组件，withInstall 位于子组件层（${A1_SUB}）"
else
  fail "A1 components/ 下未解析到 $NAME 目录或 index.ts 未用 withInstall（目录解析：${COMP_DIR:-未找到}；检查 ${A1_F}）"
fi

# A2 components.ts 两条导出（-i：组件名输入可能小写/驼峰，文件内为 PascalCase）
# ⚠️ 复合组件（2026-09-22 自查修正）：导出形态为 `export { Dropdown, DropdownButton }`，
#    不含 `default as`——故同时接受「default as」与「花括号具名导出含该名」两种写法；
#    用 `[ {]` / `[,}[:space:]]` 做词边界，避免 DropdownProps / DropdownKey 误命中。
A2_OK=0
grep -qiE "default as $NAME([^A-Za-z0-9_]|$)" "$ROOT/components/components.ts" 2>/dev/null && A2_OK=1
grep -qiE "^[[:space:]]*export[[:space:]]+[{][^}]*[ {]$NAME([,}[:space:]]|$)" "$ROOT/components/components.ts" 2>/dev/null && A2_OK=1
if [ "$A2_OK" = "1" ]; then
  ok "A2 components.ts 组件导出命中（default as ${NAME} 或具名导出含 ${NAME}）"
else
  fail "A2 components.ts 缺组件导出：grep -E 'default as $NAME|export \\{[^}]*$NAME' components/components.ts"
fi
if grep -qi "${NAME}Props" "$ROOT/components/components.ts"; then
  ok "A2 components.ts 类型导出命中（export type { ${NAME}Props }）"
else
  fail "A2 components.ts 缺类型导出：grep '${NAME}Props' components/components.ts"
fi

# A3 resolver componentsMap 映射 + 字母序
RESOLVER="$ROOT/components/utils/resolver.ts"
A3_OK=0
if grep -qiE "^[[:space:]]+$NAME:[[:space:]]*'" "$RESOLVER" 2>/dev/null; then
  ok "A3 resolver componentsMap 映射命中（$NAME: '...'）"
  A3_OK=1
else
  fail "A3 resolver componentsMap 缺映射：grep '$NAME:' components/utils/resolver.ts"
fi
if [ "$A3_OK" = "1" ]; then
KEYS=$(sed -n '/componentsMap[[:space:]]*=/,/^}/p' "$RESOLVER" 2>/dev/null \
  | grep -E '^[[:space:]]+[A-Za-z][A-Za-z0-9]*:' \
  | sed -E 's/^[[:space:]]+([A-Za-z0-9]+):.*/\1/')
# 字母序做局部检查（前一 key < 当前 key）；项目存在 Row/Col 等按目录分组的
# 特殊条目，全段有序判定会误报，故只查插入位置（乱序为风格问题 → WARN）
PREV=$(echo "$KEYS" | grep -iB1 "^$NAME$" | head -1)
if [ -n "$PREV" ] && [ "$PREV" != "$NAME" ]; then
  # 比较统一转小写，避免 locale 排序对大小写敏感性的差异
  if printf '%s\n%s\n' "$(echo "$PREV" | tr '[:upper:]' '[:lower:]')" "$(echo "$NAME" | tr '[:upper:]' '[:lower:]')" | sort -C 2>/dev/null; then
    ok "A3 字母序 OK（${PREV} < ${NAME}，局部有序）"
  else
    warn "A3 插入位置可能未按字母序（前一 key=${PREV} 当前=${NAME}），请人工核对（linkage-map.md §④ 要求按字母序插入）"
  fi
else
  ok "A3 字母序 OK（${NAME} 为段首条目）"
fi
else
  skip "A3 字母序检查跳过（映射缺失，先修复映射）"
fi

# A4 resolver componentDependencies 与源码 import 对上
if [ -n "$COMP_DIR" ]; then
  # 单双引号两种 import 写法都要覆盖
  DEPS=$(grep -rhoE "from ['\"]components/[^'\"]+['\"]" "$ROOT/components/$COMP_DIR/" 2>/dev/null \
    | grep -vE "^from ['\"]components/utils(/|['\"])" \
    | sed -E "s|from ['\"]components/([^'\"]+)['\"].*|\1|" | sort -u)
else
  DEPS=""
fi
DEP_ENTRY=$(grep -iE "^[[:space:]]+$NAME:[[:space:]]*\[" "$RESOLVER" 2>/dev/null)
if [ -z "$COMP_DIR" ]; then
  skip "A4 组件目录未解析到，跳过依赖核对"
elif [ -z "$DEPS" ]; then
  if [ -n "$DEP_ENTRY" ]; then
    warn "A4 源码无 components/ import，但 resolver 有 ${NAME} 依赖条目（可能冗余：${DEP_ENTRY}）"
  else
    ok "A4 源码无组件间依赖，resolver 无条目（一致）"
  fi
else
  MISSING=""
  for d in $DEPS; do
    # 大小写不敏感：源码 import 路径小写（components/scrollbar），resolver 条目 PascalCase（['Scrollbar']）
    echo "$DEP_ENTRY" | grep -qi "$d" || MISSING="$MISSING $d"
  done
  if [ -n "$DEP_ENTRY" ] && [ -z "$MISSING" ]; then
    ok "A4 componentDependencies 与源码 import 逐一对上（${DEPS}）"
  else
    fail "A4 componentDependencies 缺失依赖:${MISSING:-（条目本身缺失 $NAME: [...]）} 源码 import: $DEPS"
  fi
fi

# A5 自动注册无手改
A5_DIFF=$(git -C "$ROOT" diff HEAD -- components/index.ts src/router/index.ts 2>/dev/null | grep -E '^[+-]' | head -3)
if [ -z "$A5_DIFF" ]; then
  ok "A5 自动注册文件无手改（components/index.ts / router 无 diff）"
else
  fail "A5 自动注册文件有手改痕迹，应依赖 glob 自动扫描：$A5_DIFF"
fi

# ============================================================
# B · 文档联动链路（对应 checklists.md B1-B7）
# ============================================================
section "B 文档联动链路"

if [ -f "$DOC_FILE" ]; then
  ok "B1 组件文档存在：docs/guide/components/${DOC_ENTRY:-未解析}"
else
  fail "B1 组件文档缺失：${DOC_FILE}（目录解析：${DOC_ENTRY:-未找到}）"
fi

if grep -qiE "$NAME|$LCNAME" "$ROOT/docs/.vitepress/config.ts" 2>/dev/null; then
  ok "B2 vitepress 侧边栏入口命中（config.ts）"
else
  fail "B2 vitepress 侧边栏缺入口：grep '$NAME' docs/.vitepress/config.ts"
fi

CHANGELOG="$ROOT/docs/guide/changelog.md"
if grep -qi "$NAME" "$CHANGELOG" 2>/dev/null; then
  ok "B3 changelog 变更记录命中"
else
  fail "B3 changelog 缺变更记录：grep '$NAME' docs/guide/changelog.md"
fi
VER_PKG=$(grep -oE '"version"[[:space:]]*:[[:space:]]*"[0-9.]+"' "$ROOT/package.json" 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
VER_LOG=$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+' "$CHANGELOG" 2>/dev/null | head -1)
if [ -n "$VER_PKG" ] && [ "$VER_PKG" = "$VER_LOG" ]; then
  ok "B3 版本号一致：package.json=$VER_PKG = changelog 顶部=$VER_LOG"
else
  fail "B3 版本号不一致：package.json=${VER_PKG:-?} vs changelog 顶部=${VER_LOG:-?}（新增组件应 minor+1 patch 归 0，见 changelog-spec.md）"
fi

# B4 组件总数 4 处 +1 且一致（兼 E1）
# 排除 NON_COMPONENT_DIRS（工具目录 + 内部宿主，见文件头定义），只统计面向用户的基础 UI 组件
ACTUAL=$(cd "$ROOT" && ls -d components/*/ 2>/dev/null | grep -vE "components/(${NON_COMPONENT_DIRS})/" | wc -l | tr -d ' ')
NUMS=""
for f in README.md README.zh-CN.md docs/index.md docs/guide/features.md; do
  n=$(grep -oE '(共包含|includes)[[:space:]]+`?[0-9]+`?' "$ROOT/$f" 2>/dev/null | grep -oE '[0-9]+' | head -1)
  NUMS="$NUMS $n"
done
UNIQ=$(echo "$NUMS" | tr ' ' '\n' | grep -v '^$' | sort -u)
if [ "$(echo "$UNIQ" | wc -l | tr -d ' ')" = "1" ] && [ "$UNIQ" = "$ACTUAL" ]; then
  ok "B4/E1 组件总数 4 处一致且 = 实际组件数 $ACTUAL"
else
  fail "B4/E1 组件总数不一致：4 处数字=[${NUMS}] 实际组件数=${ACTUAL}（详见 linkage-map.md §⑩⑪⑫）"
fi

# B5 API 章节标题（2026-09-15 修正：原「四件套齐全」过严，会产生假 FAIL）
# 判定规则：`## APIs` 必有；`## Events` / `## Methods` 按组件实际能力
# （组件 SFC 有 defineEmits / defineExpose 才要求）；`## Expose` 永远禁止。
# 依据：项目多数组件无事件/无暴露方法，文档只有 `## APIs` + `## Slots`（如 divider/statistic/comment）。
B5_HAS_EMIT=0; B5_HAS_EXPOSE=0
if [ -n "$COMP_DIR" ]; then
  grep -qE "defineEmits" "$ROOT/components/$COMP_DIR/"*.vue 2>/dev/null && B5_HAS_EMIT=1
  grep -qE "defineExpose" "$ROOT/components/$COMP_DIR/"*.vue 2>/dev/null && B5_HAS_EXPOSE=1
fi
B5_MISSING=""
if [ -f "$DOC_FILE" ]; then
  grep -qE '^## APIs$' "$DOC_FILE" 2>/dev/null || B5_MISSING="$B5_MISSING APIs"
  if [ "$B5_HAS_EMIT" = "1" ]; then
    grep -qE '^## Events$' "$DOC_FILE" 2>/dev/null || B5_MISSING="$B5_MISSING Events"
  fi
  if [ "$B5_HAS_EXPOSE" = "1" ]; then
    grep -qE '^## Methods$' "$DOC_FILE" 2>/dev/null || B5_MISSING="$B5_MISSING Methods"
  fi
  B5_EXPOSE=$(grep -cE '^## Expose' "$DOC_FILE" 2>/dev/null | tr -d ' ')
else
  B5_MISSING=" APIs（文档缺失）"; B5_EXPOSE=0
fi
if [ -z "$B5_MISSING" ] && [ "${B5_EXPOSE:-0}" = "0" ]; then
  ok "B5 API 章节齐全（APIs 必有；Events/Methods 按能力：emit=${B5_HAS_EMIT} expose=${B5_HAS_EXPOSE}），无 ## Expose"
else
  fail "B5 API 章节缺失:${B5_MISSING:-无}（组件能力 emit=${B5_HAS_EMIT} expose=${B5_HAS_EXPOSE}）；## Expose 出现 ${B5_EXPOSE:-0} 次"
fi

# B6 `## APIs` 下 `### {组件名}` 子标题（实测：项目单组件文档均有）
if [ ! -f "$DOC_FILE" ]; then
  skip "B6 文档缺失，跳过 ### 子标题检查"
elif grep -qE "^###[[:space:]]+$NAME[[:space:]]*$" "$DOC_FILE" 2>/dev/null; then
  ok "B6 API 表 ### $NAME 子标题命中"
else
  warn "B6 未找到 '### $NAME' 子标题（项目单组件文档惯例为 \`## APIs\` 下分节，详见 checklists.md B6）"
fi

# B7 API 表类型列无 `string | slot` / `Array | slot` 残留（2.7.1 类型强化决策）
if [ ! -f "$DOC_FILE" ]; then
  skip "B7 文档缺失，跳过类型列写法检查"
else
  B7_HIT=$(grep -nE '\|[[:space:]]*(string|Array)[[:space:]]*(&#124;|\|)[[:space:]]*slot' "$DOC_FILE" 2>/dev/null | head -3)
  if [ -z "$B7_HIT" ]; then
    ok "B7 API 表类型列无 'string | slot' / 'Array | slot' 残留"
  else
    fail "B7 类型列残留 slot 写法（应写真实 TS 类型，插槽由 ## Slots 表表达）：$B7_HIT"
  fi
fi

# ============================================================
# C · 残留清理（对应 checklists.md C1-C4）
# ============================================================
section "C 残留清理"

# C1 components.d.ts 幽灵声明
CDTS="$ROOT/components.d.ts"
if [ ! -f "$CDTS" ]; then
  skip "C1 components.d.ts 不存在（项目未用 unplugin，跳过）"
else
  GHOST=""
  grep -E "typeof import\('ant-design-vue/es'\)" "$CDTS" 2>/dev/null \
    | sed -E 's/^[[:space:]]*([A-Za-z0-9]+):.*/\1/' \
    | while read -r entry; do
        tag=$(echo "$entry" | sed -E 's/^A//' | sed -E 's/([a-z0-9])([A-Z])/\1-\2/g' | tr '[:upper:]' '[:lower:]')
        used=0
        grep -rqiE "<a-$tag([ >/]|$)" "$ROOT/src" "$ROOT/components" "$ROOT/docs" 2>/dev/null && used=1
        grep -rqw "$entry" "$ROOT/src" "$ROOT/components" "$ROOT/docs" 2>/dev/null && used=1
        [ "$used" = "0" ] && echo "$entry"
      done > /tmp/dc-ghost-$$.txt
  GHOST=$(cat /tmp/dc-ghost-$$.txt | tr '\n' ' '); rm -f /tmp/dc-ghost-$$.txt
  if [ -z "$GHOST" ]; then
    ok "C1 components.d.ts 无幽灵声明（antdv 条目均有源码引用）"
  else
    fail "C1 components.d.ts 幽灵声明（源码 0 引用，须删除并随本次 commit 提交）:$GHOST"
  fi
fi

# C2 App.vue 孤儿变量（半确定性：数据流分析，脚本只提示不判定）
skip "C2 App.vue 孤儿变量为数据流分析，请人工 grep 定义 vs 引用（仅本次动了全局 ConfigProvider/主题时检查，详见 linkage-map.md §⑬）"

# C3 演示页对照清除
if [ -n "$VIEW_DIR" ]; then
  DEMO="$ROOT/src/views/$VIEW_DIR/Index.vue"
fi
if [ -n "$VIEW_DIR" ] && [ -f "$DEMO" ]; then
  C3_HIT=$(grep -nE "from 'ant-design-vue'|<a-" "$DEMO" 2>/dev/null | head -3)
  if [ -z "$C3_HIT" ]; then
    ok "C3 演示页对照已清除（无 ant-design-vue import / <a- 真身标签）"
  else
    fail "C3 演示页仍残留 antdv 对照内容：$C3_HIT"
  fi
else
  skip "C3 演示页不存在（src/views/ 解析：${VIEW_DIR:-未找到}）"
fi

# C4 调试代码清理
if [ -n "$COMP_DIR" ]; then
  C4_HIT=$(grep -rnE "console\.(log|debug)" "$ROOT/components/$COMP_DIR/" 2>/dev/null | head -3)
else
  C4_HIT=""
fi
if [ -n "$COMP_DIR" ] && [ -z "$C4_HIT" ]; then
  ok "C4 组件目录无 console.log/debug"
elif [ -n "$COMP_DIR" ]; then
  fail "C4 组件目录残留调试代码：$C4_HIT"
else
  skip "C4 组件目录未解析到，跳过调试代码检查"
fi

# ------------------------------------------------------------
# C5 品牌信息残留（2026-09-22 新增 · 权威源 refine-spec.md §1）
# 两段口径（覆盖「分批开发 + 分批提交」——只在收尾看工作区会漏掉已提交批次）：
#   ① 本分支净改动新增行：git diff <base> -U0 的 + 行（base = 分支基点，
#      与【当前工作区】比对 → 一次覆盖「已提交批次 + 未提交改动」；
#      ⚠️ 不用 base...HEAD 再单独扫工作区：那样会把「提交后又在工作区删掉」的行误判为残留）
#   ② 未跟踪新增文件：全文
#   范围：components/ src/ docs/（组件文档 + 周边文档 changelog/features/index）types/ tests/
#         + 根级 README/CHANGELOG
#   豁免：基础设施（package.json / lock / components.d.ts / vite.config.ts / tsconfig / eslintrc）
#         + 生成物（node_modules / dist / lib / es / coverage / .temp）
#   例外：@ant-design/icons-vue 等既有 @ant-design/* 基础包（用户 2026-09-22 确认豁免）
#   base 解析：--base 参数 > 工作上下文 base_ref > merge-base(origin/main|master|main|master, HEAD)
#              （解析失败 → 退化为「工作区 vs HEAD」并 WARN：分批提交场景会漏）
# ------------------------------------------------------------
if [ -z "$BASE" ] && [ -n "$CTX" ] && [ -f "$CTX" ]; then
  BASE=$(sed -n 's/^base_ref: *"\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' "$CTX" | head -1 | sed 's/[[:space:]]*$//')
fi
if [ -z "$BASE" ]; then
  for cand in origin/main origin/master main master; do
    if git -C "$ROOT" rev-parse --verify --quiet "$cand" >/dev/null 2>&1; then
      BASE=$(git -C "$ROOT" merge-base "$cand" HEAD 2>/dev/null)
      [ -n "$BASE" ] && break
    fi
  done
fi

# ⚠️ `antd` 必须单列：实测「// 对齐 antd 口径」这类只写 antd（不带 v）的注释是存量高频形态，
#    仅写 antdv 会漏检（`ant-[a-z]+` 也匹配不到 antd——它没有连字符）
BRAND_PAT='antd|antdv|ant-design-vue|ant design|ant-[a-z]+|naive|</?a-[a-z][a-z-]*[[:space:]>]'
BRAND_EXCL='(^|/)(package\.json|pnpm-lock\.yaml|components\.d\.ts|vite\.config\.ts|tsconfig[^/]*\.json)$|\.eslintrc|pnpm-workspace\.yaml$|(^|/)(node_modules|dist|lib|coverage|\.temp)/|^es/'
BRAND_SCOPE='^(components|src|docs|types|tests)/|^README|^CHANGELOG'
BRAND_ALLOW='@ant-design/(icons-vue|colors)'
BRAND_HITS=/tmp/dc-brand-$$.txt
BRAND_SEEN=/tmp/dc-brand-seen-$$.txt
: > "$BRAND_HITS"; : > "$BRAND_SEEN"

brand_scan_full() {   # ② 新增文件：全文扫描
  local rel="$1" abs="$ROOT/$1"
  [ -f "$abs" ] || return 0
  echo "$rel" | grep -qE "$BRAND_EXCL" && return 0
  echo "$rel" >> "$BRAND_SEEN"
  grep -nE "$BRAND_PAT" "$abs" 2>/dev/null | grep -viE "$BRAND_ALLOW" \
    | sed "s|^|${rel}|" >> "$BRAND_HITS"
}

brand_scan_diff() {   # ① 已跟踪文件：按 diff 范围取新增行（$2=基点 ref / HEAD，$3=标签）
  local rel="$1" rng="$2" label="$3"
  [ -n "$rng" ] || return 0
  echo "$rel" | grep -qE "$BRAND_EXCL" && return 0
  echo "$rel" >> "$BRAND_SEEN"
  git -C "$ROOT" diff "$rng" -U0 -- "$rel" 2>/dev/null \
    | grep -E '^\+' | grep -vE '^\+\+\+' | sed 's/^+//' \
    | grep -viE "$BRAND_ALLOW" | grep -iE "$BRAND_PAT" \
    | sed "s|^|${rel}（${label}）:|" >> "$BRAND_HITS"
}

# ① 本分支净改动（基点 → 当前工作区）；base 缺失时退化为「工作区 vs HEAD」
if [ -n "$BASE" ]; then
  git -C "$ROOT" diff --name-only "$BASE" 2>/dev/null | grep -E "$BRAND_SCOPE" \
    | while read -r rel; do brand_scan_diff "$rel" "$BASE" "本分支新增行"; done
else
  git -C "$ROOT" diff --name-only HEAD 2>/dev/null | grep -E "$BRAND_SCOPE" \
    | while read -r rel; do brand_scan_diff "$rel" HEAD "工作区新增行"; done
fi
# ② 未跟踪新增文件
git -C "$ROOT" ls-files --others --exclude-standard 2>/dev/null | grep -E "$BRAND_SCOPE" \
  | while read -r rel; do brand_scan_full "$rel"; done

C5_TOTAL=$(sort -u "$BRAND_HITS" 2>/dev/null | grep -c .)
C5_HITS=$(sort -u "$BRAND_HITS" 2>/dev/null | head -8 | tr '\n' ' ')
C5_FILES=$(sort -u "$BRAND_SEEN" 2>/dev/null | grep -c .)
rm -f "$BRAND_HITS" "$BRAND_SEEN"
if [ "${C5_FILES:-0}" = "0" ]; then
  skip "C5 未扫描到改动文件（本分支净改动为空 + 无未跟踪文件）——请确认 base 解析与 git 状态（口径见 refine-spec.md §1.3）"
elif [ -n "$C5_HITS" ]; then
  fail "C5 品牌信息残留共 ${C5_TOTAL} 处（品牌对比/差异说明类内容须【直接删除】；其余去品牌化或删除；例外仅 @ant-design/* 基础包；详见 refine-spec.md §1）：$C5_HITS"
elif [ -z "$BASE" ]; then
  warn "C5 品牌信息 0 残留（扫描 ${C5_FILES} 个文件）⚠️ 但未解析到分支基点 base：本次仅比对「工作区 vs HEAD」，本分支【已提交】批次未纳入（分批提交会漏）——请显式 --base <ref> 或在工作上下文登记 base_ref"
else
  # 附查「已提交批次」（base...HEAD）：若仍残留但工作区已清除 → 必须随本次 commit 提交，否则复活
  C5_HEAD_HITS=$(git -C "$ROOT" diff --name-only "$BASE"...HEAD 2>/dev/null | grep -E "$BRAND_SCOPE" \
    | while read -r rel; do
        echo "$rel" | grep -qE "$BRAND_EXCL" && continue
        git -C "$ROOT" diff "$BASE"...HEAD -U0 -- "$rel" 2>/dev/null \
          | grep -E '^\+' | grep -vE '^\+\+\+' | sed 's/^+//' \
          | grep -viE "$BRAND_ALLOW" | grep -iE "$BRAND_PAT"
      done | grep -c .)
  if [ "${C5_HEAD_HITS:-0}" != "0" ]; then
    ok "C5 品牌信息 0 残留（净改动口径，扫描 ${C5_FILES} 个文件：base=${BASE} → 当前工作区 + 新增文件全文）"
    warn "C5 附注：本分支【已提交】批次中仍有 ${C5_HEAD_HITS} 处品牌残留，工作区已清除但**尚未提交**——请确保这些删除随本次 commit 一起提交（与 components.d.ts 幽灵声明同理，不提交会「复活」）"
  else
    ok "C5 品牌信息 0 残留（扫描 ${C5_FILES} 个文件：本分支净改动新增行[base=${BASE}] + 新增文件全文）"
  fi
fi

# ============================================================
# E · 一致性（E1 已并入 B4；E2 半确定性提示人工）
# ============================================================
section "E 一致性"

skip "E2 演示页↔docs 描述同源为文本语义对比（半确定性），请按 demo-description.md §5 人工 grep 双向核对"

# ============================================================
# F · 组件本体与跨文件规范（对应 checklists.md F1-F8，2026-09-15 新增）
# 事故背景：Comment 漏登记 types/global-components.d.ts（静默失效、type-check 仍 PASS），
# 并暴露 defineSlots 缺失 / 根类名 m- 前缀 / 注释 string | slot / 演示页序号注释与
# 组件库 import 等无检查项覆盖的问题 → 全部下沉为确定性检查。
# ============================================================
section "F 组件本体与跨文件规范"

COMP_VUES=""
if [ -n "$COMP_DIR" ]; then
  # 含一层子目录：复合组件（如 dropdown/dropdown/Dropdown.vue + dropdown/dropdown-button/DropdownButton.vue）
  COMP_VUES=$(find "$ROOT/components/$COMP_DIR" -maxdepth 2 -name '*.vue' 2>/dev/null | sort)
fi

# F1 defineSlots + `export interface {组件名}Slots`（component-design.md §插槽类型）
# 复合组件：逐个 .vue 校验（每个子组件各自声明 *Slots 类型）
if [ -z "$COMP_VUES" ]; then
  skip "F1 组件 .vue 未解析到，跳过 defineSlots 检查"
else
  F1_NO_SLOTDECL=""; F1_NO_IFACE=""; F1_CNT=0
  for f1f in $COMP_VUES; do
    F1_CNT=$((F1_CNT+1))
    grep -qE "defineSlots" "$f1f" 2>/dev/null || F1_NO_SLOTDECL="$F1_NO_SLOTDECL $(basename "$f1f")"
    grep -qE "export interface [A-Za-z]+Slots" "$f1f" 2>/dev/null || F1_NO_IFACE="$F1_NO_IFACE $(basename "$f1f")"
  done
  if [ -n "$F1_NO_SLOTDECL" ]; then
    fail "F1 组件未声明插槽类型（应 'export interface {组件名}Slots' + 'defineSlots<{组件名}Slots>()'）：$F1_NO_SLOTDECL"
  elif [ -n "$F1_NO_IFACE" ]; then
    warn "F1 有 defineSlots 但未见 'export interface {组件名}Slots'：${F1_NO_IFACE}（命名规范见 component-design.md §插槽类型）"
  else
    ok "F1 defineSlots + export interface *Slots 命中（${F1_CNT} 个组件文件）"
  fi
fi

# F2 根类名 = {组件名}-wrap；禁止 m-/vui- 自拟前缀
if [ -z "$COMP_VUES" ]; then
  skip "F2 组件 .vue 未解析到，跳过根类名检查"
else
  F2_BAD=$(grep -nE 'class="(m|vui)-[a-z0-9-]+"' $COMP_VUES 2>/dev/null | head -3)
  if [ -z "$F2_BAD" ]; then
    ok "F2 无 m-/vui- 自拟类名前缀（根类名应为 {组件名}-wrap）"
  else
    fail "F2 使用了自拟类名前缀（应为 {组件名}-wrap / {组件名}-xxx）：$F2_BAD"
  fi
fi

# F3 Props/Slots 注释无 `string | slot` / `Array | slot` 残留
if [ -z "$COMP_VUES" ]; then
  skip "F3 组件 .vue 未解析到，跳过注释残留检查"
else
  F3_HIT=$(grep -nE "//.*(string|Array)[[:space:]]*\|[[:space:]]*slot" $COMP_VUES 2>/dev/null | head -3)
  if [ -z "$F3_HIT" ]; then
    ok "F3 Props/Slots 注释无 'string | slot' 残留"
  else
    fail "F3 注释残留 'string | slot'（插槽形态由 {组件名}Slots 类型 + 文档 Slots 表表达）：$F3_HIT"
  fi
fi

# F4 useSlotsExist 数组内插槽名均有实际消费点（半确定性：只列候选，须人工确认）
if [ -z "$COMP_VUES" ]; then
  skip "F4 组件 .vue 未解析到，跳过插槽探测检查"
else
  F4_ARR=$(grep -hoE "useSlotsExist\(\[[^]]*\]" $COMP_VUES 2>/dev/null | head -1)
  if [ -z "$F4_ARR" ]; then
    ok "F4 未使用 useSlotsExist 数组形式（或无需插槽探测）"
  else
    F4_NAMES=$(echo "$F4_ARR" | grep -oE "'[a-zA-Z]+'" | tr -d "'" | tr '\n' ' ')
    F4_UNUSED=""
    for s in $F4_NAMES; do
      cnt=$(grep -ohE "slotsExist\.$s" $COMP_VUES 2>/dev/null | wc -l | tr -d ' ')
      [ "${cnt:-0}" = "0" ] && F4_UNUSED="$F4_UNUSED $s"
    done
    if [ -z "$F4_UNUSED" ]; then
      ok "F4 useSlotsExist 各插槽名均有消费点（${F4_NAMES}）"
    else
      warn "F4 useSlotsExist 可能含冗余探测项:${F4_UNUSED}（须人工确认，禁止多传未使用的插槽名）"
    fi
  fi
fi

# F5 types/global-components.d.ts 登记（差集：componentsMap keys − 已声明）
# ⚠️ 漏登记不报错、type-check 仍 PASS（静默失效），只能靠本项兜底
GDTS="$ROOT/types/global-components.d.ts"
if [ ! -f "$GDTS" ]; then
  skip "F5 types/global-components.d.ts 不存在（项目未使用该机制，跳过登记校验）"
else
  sed -n '/componentsMap[[:space:]]*=/,/^}/p' "$RESOLVER" 2>/dev/null \
    | grep -oE '^[[:space:]]+[A-Za-z][A-Za-z0-9]*:' \
    | sed -E 's/^[[:space:]]+([A-Za-z0-9]+):.*/\1/' | sort -u > /tmp/dc-map-$$.txt
  grep -oE '^[[:space:]]+[A-Za-z][A-Za-z0-9]*: typeof' "$GDTS" 2>/dev/null \
    | sed -E 's/^[[:space:]]+([A-Za-z0-9]+):.*/\1/' | sort -u > /tmp/dc-decl-$$.txt
  # 过滤 NON_PUBLIC_COMPS：内部宿主/依赖组件（如需在 componentsMap 中供依赖解析，但不对外公开、不登记全局声明）
  F5_MISSING=$(comm -23 /tmp/dc-map-$$.txt /tmp/dc-decl-$$.txt 2>/dev/null | grep -vxE "${NON_PUBLIC_COMPS}" | tr '\n' ' ')
  rm -f /tmp/dc-map-$$.txt /tmp/dc-decl-$$.txt
  if [ -z "$F5_MISSING" ]; then
    ok "F5 types/global-components.d.ts 覆盖 componentsMap 全量（$NAME 已登记）"
  else
    fail "F5 types/global-components.d.ts 缺登记:${F5_MISSING}（漏登记不报错、type-check 仍 PASS，必须手工补，见 linkage-map.md §⑮）"
  fi
fi

# F6 changelog 三查：版本章节唯一 + 组件链接站内相对路径 + future 无本组件残留
if [ ! -f "$CHANGELOG" ]; then
  skip "F6 changelog 不存在，跳过三查"
else
  F6_DUP=$(grep -oE '^## <VersionDateTag[^>]*>[0-9.]+' "$CHANGELOG" 2>/dev/null \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+$' | sort | uniq -d | tr '\n' ' ')
  F6_BADLINK=$(grep -nE '\]\(https?://themusecatcher\.github\.io/vue-amazing-ui/guide/components/' "$CHANGELOG" 2>/dev/null | head -3)
  F6_FUTURE=$(sed -n '/^## future/,$p' "$CHANGELOG" 2>/dev/null | grep -i "$NAME" | head -3)
  if [ -z "$F6_DUP" ] && [ -z "$F6_BADLINK" ] && [ -z "$F6_FUTURE" ]; then
    ok "F6 changelog 三查通过（版本章节唯一 / 组件链接站内相对路径 / future 无本组件残留）"
  else
    fail "F6 changelog 未过：重复版本号=[${F6_DUP:-无}] 完整URL链接=[${F6_BADLINK:-无}] future残留=[${F6_FUTURE:-无}]（详见 changelog-spec.md §3.2 §3.4）"
  fi
fi

# F7 演示页与文档：注释 / <h2> 标题无数字序号
F7_HIT=""
if [ -n "$VIEW_DIR" ] && [ -f "$DEMO" ]; then
  F7_HIT=$(grep -nE '^// [0-9]\.|<h2[^>]*>[[:space:]]*[0-9]+\.' "$DEMO" 2>/dev/null | head -3)
fi
if [ -z "$F7_HIT" ] && [ -f "$DOC_FILE" ]; then
  F7_HIT=$(grep -nE '^// [0-9]\.' "$DOC_FILE" 2>/dev/null | head -3)
fi
if [ -z "$F7_HIT" ]; then
  ok "F7 演示页/文档无数字序号注释与标题"
else
  fail "F7 存在数字序号注释/标题（应为纯语义注释，如 '// 基本评论'；分区顺序由排列体现）：$F7_HIT"
fi

# F8 演示页无本项目组件 import（全局注册，直接写 <Xxx> 标签）
if [ -n "$VIEW_DIR" ] && [ -f "$DEMO" ]; then
  F8_HIT=$(grep -nE "^import .*from 'vue-amazing-ui'" "$DEMO" 2>/dev/null | grep -v "import type" | head -3)
  if [ -z "$F8_HIT" ]; then
    ok "F8 演示页无本项目组件 import（组件已全局注册）"
  else
    fail "F8 演示页 import 了本项目组件（无需引入，直接写 <Xxx> 标签；仅 import type 允许）：$F8_HIT"
  fi
else
  skip "F8 演示页不存在，跳过组件 import 检查"
fi

# ============================================================
# G · 交付前精修与三方一致性（对应 checklists.md G1-G6，2026-09-22 新增）
# 权威源：references/refine-spec.md
#   §2 注释精修 / §3 Props 排序 / §4 演示用例排序与布局 / §5 三方一致性对照
# 确定性下沉：G2（源码 Props 顺序 ↔ docs API 表顺序，支持复合组件按子组件比对）、
#             G4（views ↔ docs 用例数量/顺序/标题）
# 语义判断（SKIP 提示人工勾销）：G1 注释精修 / G3 用例排序与布局 / G5 三方矩阵 / G6 记录与复验
# ============================================================
section "G 交付前精修与三方一致性"

# ---- 用例标题提取（G4 用；演示页 <h2> ↔ docs 二级标题）----
VT=/tmp/dc-vt-$$.txt; DT=/tmp/dc-dt-$$.txt; DTU=/tmp/dc-dtu-$$.txt
: > "$VT"; : > "$DT"; : > "$DTU"
if [ -n "$VIEW_DIR" ] && [ -f "$DEMO" ]; then
  grep -oE '<h2[^>]*>[^<]+</h2>' "$DEMO" 2>/dev/null \
    | sed -E 's/<[^>]+>//g' | sed -E 's/^[[:space:]]+//;s/[[:space:]]+$//' | grep -v '^$' > "$VT"
fi
# DT = docs 全部二级标题（用于子序列比对，避免白名单误伤真实用例标题）
# DTU = 剔除固定章节后（用于数量比对；固定章节实测频次见 refine-spec.md §5.1 旁注）
if [ -f "$DOC_FILE" ]; then
  grep -E '^## ' "$DOC_FILE" 2>/dev/null | sed -E 's/^##[[:space:]]+//' \
    | sed -E 's/[[:space:]]+$//' | grep -v '^$' > "$DT"
  grep -vxE '何时使用|基本使用|APIs|Slots|Events|Methods|自定义样式' "$DT" > "$DTU"
  # 白名单章节若本身也是演示页的用例标题（自定义样式等），补回 DTU，避免数量误判
  for w in 何时使用 基本使用 APIs Slots Events Methods 自定义样式; do
    if grep -qxF -- "$w" "$VT" 2>/dev/null && grep -qxF -- "$w" "$DT" 2>/dev/null; then
      echo "$w" >> "$DTU"
    fi
  done
fi

# G1 注释精修（语义判断 → 人工）
skip "G1 组件源码注释精修为语义判断（半确定性），请按 refine-spec.md §2 人工精修：三层结构 / 删复述与过期注释 / 删品牌来源标注"

# G2 源码 Props 顺序 ↔ docs `## APIs` → `### {组件名}` 表行顺序（refine-spec.md §3.3）
# 支持复合组件：按 .vue 文件（含一层子目录）逐一与 docs 中同名 `### {子组件名}` 表比对
src_props_of() {   # $1 = .vue → 字段序（逐行）
  sed -n '/interface[[:space:]]*Props[[:space:]]*{/,/^}/p' "$1" 2>/dev/null \
    | grep -E '^[[:space:]]+[A-Za-z_][A-Za-z0-9_]*\??[[:space:]]*:' \
    | sed -E 's/^[[:space:]]+([A-Za-z0-9_]+).*/\1/' | awk '!seen[$0]++'
}
doc_props_of() {   # $1 = docs 中 ### 标题名 → 表首列（逐行，限定在 `## APIs` 之后）
  # ⚠️ 项目 docs 的 API 表为「无边框」写法（行首无 `|`，如 `color | 说明 | string`），
  #    故按「行内含 |」取行；表头与分隔行由末尾的标识符 grep 过滤掉。
  #    限定 `## APIs` 之后：同名 `### Xxx` 在 Slots / Methods 区会重复出现，只取 API 表那份。
  awk -v name="$1" '
      /^## APIs/ { inapi = 1 }
      inapi && $0 ~ "^###[[:space:]]+" name "[[:space:]]*$" { f = 1; next }
      f && /^#{2,4}[[:space:]]/ { exit }
      f && /\|/ { print }
    ' "$DOC_FILE" 2>/dev/null \
    | sed -E 's/^[[:space:]]*\|//' | cut -d'|' -f1 \
    | sed -E 's/<[^>]*>//g' | sed -E 's/[[:space:]`]//g' \
    | sed -E 's/^v-model:(.*)/\1/' | grep -E '^[A-Za-z][A-Za-z0-9]*$'
}
g2_compare() {     # $1 = 源码字段序（空格分隔）$2 = docs 表列（换行）；结果写 G2R_*
  G2R_ORDER=1; G2R_MATCHED=0; G2R_TOTAL=0; G2R_MISS=""
  local last=0 ln p
  for p in $1; do
    G2R_TOTAL=$((G2R_TOTAL+1))
    ln=$(printf '%s\n' "$2" | grep -nx "$p" | head -1 | cut -d: -f1)
    if [ -z "$ln" ]; then
      G2R_MISS="$G2R_MISS $p"
    else
      G2R_MATCHED=$((G2R_MATCHED+1))
      [ "$ln" -lt "$last" ] && G2R_ORDER=0
      last=$ln
    fi
  done
}

if [ -z "$COMP_DIR" ] || [ -z "$COMP_VUES" ]; then
  skip "G2 组件 .vue 未解析到（目录解析：${COMP_DIR:-未找到}），请人工核对 Props 顺序（refine-spec.md §3）"
elif [ ! -f "$DOC_FILE" ]; then
  warn "G2 组件文档缺失，跳过 Props 顺序校验"
else
  G2_CNT=$(printf '%s\n' "$COMP_VUES" | grep -c .)
  G2_FAIL=""; G2_UNCERTAIN=""; G2_MISSALL=""; G2_OKN=0; G2_CHECKED=0
  for vf in $COMP_VUES; do
    # 单文件组件用 `### {组件名}`；复合组件用 `### {子组件名}`（= .vue 文件名）
    if [ "${G2_CNT:-0}" = "1" ]; then G2_SEC="$NAME"; else G2_SEC=$(basename "$vf" .vue); fi
    sp=$(src_props_of "$vf" | tr '\n' ' ')
    [ -n "$(printf '%s' "$sp" | tr -d ' ')" ] || continue
    dp=$(doc_props_of "$G2_SEC")
    G2_CHECKED=$((G2_CHECKED+1))
    if [ -z "$(printf '%s' "$dp" | tr -d ' ')" ]; then
      G2_UNCERTAIN="$G2_UNCERTAIN ${G2_SEC}(docs 无 ### ${G2_SEC} API 表)"
      continue
    fi
    g2_compare "$sp" "$dp"
    if [ "$G2R_MATCHED" = "0" ]; then
      G2_UNCERTAIN="$G2_UNCERTAIN ${G2_SEC}(无同名 prop，命名差异须人工核对)"
    elif [ "$((G2R_MATCHED * 100 / G2R_TOTAL))" -lt 60 ]; then
      G2_UNCERTAIN="$G2_UNCERTAIN ${G2_SEC}(匹配率 ${G2R_MATCHED}/${G2R_TOTAL}，解析存疑)"
    elif [ "$G2R_ORDER" != "1" ]; then
      G2_FAIL="$G2_FAIL ${G2_SEC}(docs 表序=$(printf '%s\n' "$dp" | head -8 | tr '\n' '/'))"
    else
      G2_OKN=$((G2_OKN+1))
    fi
    # MISS 只作补充提示：docs 未列出的 prop 多为 v-model 命名差异（`v-model:value`），
    # 不影响「顺序是否一致」的结论，故不降级 ok → warn
    [ -n "$G2R_MISS" ] && G2_MISSALL="$G2_MISSALL ${G2_SEC}→${G2R_MISS}"
  done
  if [ "$G2_CHECKED" = "0" ]; then
    skip "G2 组件 .vue 内未解析到 interface Props（extends/跨行等写法），请人工核对 Props 顺序（refine-spec.md §3.3）"
  elif [ -n "$G2_FAIL" ]; then
    fail "G2 源码 Props 顺序与 docs API 表顺序不一致（须逐项同序）：$G2_FAIL"
  else
    [ "${G2_OKN:-0}" != "0" ] && ok "G2 源码 Props 顺序 ↔ docs API 表顺序一致（${G2_OKN}/${G2_CHECKED} 个组件比对通过）"
    [ -n "$G2_UNCERTAIN" ] && warn "G2 无法判定项（解析局限），须人工核对 Props 顺序：$G2_UNCERTAIN"
    [ -n "$G2_MISSALL" ] && warn "G2 源码有而 docs API 表未列出的 Props：${G2_MISSALL}（确认是 v-model 命名差异还是文档漏列）"
    true
  fi
fi

# G3 演示用例排序与布局（语义判断 → 人工）
skip "G3 演示用例排序与布局为语义判断（半确定性），请按 refine-spec.md §4 人工精修：官网保序 / 新增插回原序 / 同类型布局一致"

# G4 views ↔ docs 用例对齐（数量 / 顺序 / 标题逐字；演示页为权威源）
G4_V_N=$(grep -c . "$VT" 2>/dev/null | tr -d ' '); G4_D_N=$(grep -c . "$DTU" 2>/dev/null | tr -d ' ')
G4_MISS=""; G4_LAST=0; G4_ORDER=1
while IFS= read -r gt; do
  [ -n "$gt" ] || continue
  gln=$(grep -nxF -- "$gt" "$DT" 2>/dev/null | head -1 | cut -d: -f1)
  if [ -z "$gln" ]; then
    G4_MISS="$G4_MISS [$gt]"
  else
    [ "$gln" -lt "$G4_LAST" ] && G4_ORDER=0
    G4_LAST=$gln
  fi
done < "$VT"
rm -f "$VT" "$DT" "$DTU"
if [ "${G4_V_N:-0}" = "0" ]; then
  skip "G4 演示页未解析到用例标题（<h2>），跳过 docs ↔ views 用例对齐校验"
elif [ -n "$G4_MISS" ]; then
  fail "G4 docs 缺演示页用例:${G4_MISS}（docs 用例须与演示页一一对应，演示页为权威源；refine-spec.md §5.1）"
elif [ "$G4_ORDER" != "1" ]; then
  fail "G4 docs 用例顺序与演示页不一致（演示页为权威源，须同序；refine-spec.md §5.1）"
elif [ "$G4_V_N" != "$G4_D_N" ]; then
  warn "G4 用例数不一致：演示页 ${G4_V_N} 个 vs docs 用例类标题 ${G4_D_N} 个（docs 多出项须确认为固定章节「何时使用/APIs/Slots/Methods/Events/自定义样式」，或补齐演示页漏掉的分区）"
else
  ok "G4 docs ↔ 演示页用例对齐（${G4_V_N} 个用例，数量与顺序一致）"
fi

# G5 / G6 三方一致性矩阵 + 精修记录与复验（人工）
skip "G5 三方一致性对照矩阵（源码 ↔ docs ↔ views 全维度）须人工逐格勾销，见 refine-spec.md §5.1"
skip "G6 精修记录（工作上下文「交付前精修记录」区）+ 精修后复验（lint/type-check/test/浏览器）须人工确认，见 refine-spec.md §6"

# ============================================================
# S · 提交红线（对应 flow.md 阶段 5 第 4 步 + checklists.md §验收：
# S1 git 身份 / S2 分支核对 / S3 commit hash 回填真实性 /
# S4 能力沉淀三件套 / S5 归档双份）
# ============================================================
section "S 提交红线"

if [ -z "$CTX" ] || [ ! -f "$CTX" ]; then
  skip "S1-S3 需工作上下文（--context {wc 文件}），未提供则跳过 git 身份 / 分支 / hash 校验"
else
  # S1 git 身份实测 vs git_identity
  IDENT=$(sed -n 's/^git_identity: "\(.*\)"/\1/p' "$CTX")
  NAME_ACT=$(git -C "$ROOT" config user.name)
  EMAIL_ACT=$(git -C "$ROOT" config user.email)
  if [ -z "$IDENT" ]; then
    skip "S1 工作上下文无 git_identity 字段（旧模板），跳过身份校验——提交前人工确认 ${NAME_ACT} / ${EMAIL_ACT} 为预期身份"
  else
    NAME_EXP=$(echo "$IDENT" | sed -E 's#[[:space:]]*/.*$##' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    EMAIL_EXP=$(echo "$IDENT" | sed -E 's#^.*/[[:space:]]*##')
    if [ "$NAME_ACT" = "$NAME_EXP" ] && [ "$EMAIL_ACT" = "$EMAIL_EXP" ]; then
      ok "S1 git 身份与 git_identity 一致（${NAME_ACT} / ${EMAIL_ACT}）"
    else
      fail "S1 git 身份不符：实测 [${NAME_ACT} / ${EMAIL_ACT}] vs 预期 [${NAME_EXP} / ${EMAIL_EXP}]（历史事故：误用公司身份提交）"
    fi
  fi

  # S2 当前分支 vs 工作上下文 branch（Gate 5「提交前检查」对应项；分支不符时 S3 hash 对比必然失真，先拦截）
  CTX_BRANCH=$(sed -n 's/^branch: *"\(.*\)"/\1/p' "$CTX")
  CUR_BRANCH=$(git -C "$ROOT" branch --show-current 2>/dev/null)
  if [ -n "$CTX_BRANCH" ] && [ "$CTX_BRANCH" = "$CUR_BRANCH" ]; then
    ok "S2 当前分支与工作上下文一致（${CUR_BRANCH}）"
  elif [ -n "$CTX_BRANCH" ]; then
    fail "S2 当前分支 ${CUR_BRANCH} ≠ 工作上下文 branch ${CTX_BRANCH}（提交前须切换到正确分支，且下列 S3 hash 对比在该状态下失真）"
  else
    skip "S2 工作上下文无 branch 字段，跳过分支核对"
  fi

  # S3 commit hash 回填真实性（frontmatter 有 commit 时才校验；字段可能为 "hash" 或 "hash message"，取首个 token）
  CTX_COMMIT=$(sed -n 's/^commit: "\([^ "]*\).*/\1/p' "$CTX")
  HEAD_HASH=$(git -C "$ROOT" log -1 --format='%h')
  if [ -n "$CTX_COMMIT" ]; then
    if git -C "$ROOT" cat-file -e "${CTX_COMMIT}^{commit}" 2>/dev/null; then
      if [ "$CTX_COMMIT" = "$HEAD_HASH" ]; then
        ok "S3 工作上下文 commit=$CTX_COMMIT 与 HEAD 实测一致"
      else
        warn "S3 工作上下文 commit=$CTX_COMMIT 在仓库存在但 HEAD=$HEAD_HASH 已推进（若 commit 为本次开发提交且 HEAD 含后续提交属正常；若预期 HEAD=commit 请先核对 S2 分支）"
      fi
    else
      fail "S3 工作上下文 commit=$CTX_COMMIT 在仓库中不存在（凭记忆记录的假 hash，禁止回填）"
    fi
  else
    skip "S3 工作上下文 commit 为空（尚未提交），跳过"
  fi
fi

# S4 能力沉淀三件套（两级扫描：运行时目录优先 → FALLBACK 归档兜底；
# 顺序上脚本常跑于沉淀前，缺失 → WARN 提示提交前补齐）
section "S4 能力沉淀三件套"

# devlog 两种可能结构：① tech-doc 规范 {YYYYMMDD}_{类型}_{简述}/devlog.md
# ② dev-comp 早期记载 <项目>/<分支>/devlog.md；按组件归一化名过滤路径。
# 简述纯中文不含组件名时无法自动关联 → 保守报 WARN（人工确认），不误 PASS
DEVLOG_HIT=$(find "$HOME/.codebuddy/dev-logs" -maxdepth 3 -iname "devlog.md" 2>/dev/null \
  | grep -i "$LCNAME" | head -1)
if [ -n "$DEVLOG_HIT" ]; then
  ok "S4 devlog 已存在（${DEVLOG_HIT}）"
else
  AF_DEVLOG=$(find "$FALLBACK" -maxdepth 2 -type d -iname "devlog" 2>/dev/null | grep -i "$LCNAME" | head -1)
  if [ -n "$AF_DEVLOG" ]; then
    warn "S4 devlog 仅存归档副本（${AF_DEVLOG}）——接续时经用户同意复制回运行时目录；已收尾归档则属正常"
  else
    warn "S4 devlog 缺失或简述未含组件名：提交前须 use_skill('tech-doc') 生成（历史事故：三次跳过）"
  fi
fi

METRIC_HIT=$(ls "$HOME/.codebuddy/dev-comp/metrics/" 2>/dev/null | grep -i "$LCNAME" | head -1)
if [ -n "$METRIC_HIT" ]; then
  M_F="$HOME/.codebuddy/dev-comp/metrics/$METRIC_HIT"
  if grep -q "^component:" "$M_F" 2>/dev/null; then
    ok "S4 metrics 已存在且含 component 字段（${M_F}）"
  else
    warn "S4 metrics 文件存在但缺 component 字段：${M_F}"
  fi
else
  AF_METRIC=$(ls "$FALLBACK"/ 2>/dev/null | grep -i "$LCNAME" | head -1)
  if [ -n "$AF_METRIC" ] && [ -d "$FALLBACK/$AF_METRIC/metrics" ] && ls "$FALLBACK/$AF_METRIC/metrics/" 2>/dev/null | grep -qi .; then
    warn "S4 metrics 仅存归档副本（$FALLBACK/$AF_METRIC/metrics/）——接续时经用户同意复制回运行时目录；已收尾归档则属正常"
  else
    warn "S4 metrics 缺失：提交前按 templates/metrics-lite.tpl.yaml 写入 ~/.codebuddy/dev-comp/metrics/"
  fi
fi

KNOW_HIT=$(find "$HOME/.codebuddy/knowledge/vue-amazing-ui" -maxdepth 3 -iname "*$LCNAME*" 2>/dev/null | head -1)
if [ -n "$KNOW_HIT" ]; then
  ok "S4 knowledge 已沉淀（${KNOW_HIT}）"
else
  AF_KNOW=$(ls "$FALLBACK"/ 2>/dev/null | grep -i "$LCNAME" | head -1)
  if [ -n "$AF_KNOW" ] && [ -d "$FALLBACK/$AF_KNOW/knowledge" ] && ls "$FALLBACK/$AF_KNOW/knowledge/" 2>/dev/null | grep -qi .; then
    warn "S4 knowledge 仅存归档副本（$FALLBACK/$AF_KNOW/knowledge/）——接续时经用户同意复制回运行时目录；已收尾归档则属正常"
  else
    warn "S4 knowledge 缺失：提交前须 use_skill('knowledge-loop') 沉淀"
  fi
fi

# S5 产物存放位置（2026-08-21 规范：产物统一留在运行时目录；artifacts 仅作历史归档读取兜底）
section "S5 产物存放位置"

RT_HIT=$(ls "$HOME/.codebuddy/dev-comp/working-context/" 2>/dev/null | grep -i "$LCNAME" | head -1)
AF_HIT=$(ls "$FALLBACK"/ 2>/dev/null | grep -i "$LCNAME" | head -1)
if [ -n "$RT_HIT" ] && [ -n "$AF_HIT" ]; then
  warn "S5 工作上下文双份：运行时[$RT_HIT] 与 artifacts[$AF_HIT] 同时存在（产物应统一留在运行时目录；artifacts 若为历史归档请按需清理）"
elif [ -n "$RT_HIT" ]; then
  ok "S5 产物位置正常（运行时=${RT_HIT}，无新增归档副本）"
elif [ -n "$AF_HIT" ]; then
  warn "S5 产物仅存历史归档（artifacts/${AF_HIT}）——按 2026-08-21 规范产物应留在运行时目录；如需继续开发请复制回运行时目录"
else
  skip "S5 运行时与归档两级均未检索到工作上下文（组件名拼写差异或未建上下文；--context 提供的文件不在两级目录内）"
fi

# ============================================================
# 汇总
# ============================================================
echo
echo "==== 汇总: PASS=$PASS FAIL=$FAIL WARN=$WARN SKIP=$SKIP ===="
if [ "$FAIL" -gt 0 ]; then
  echo "结果: 存在 FAIL，须修复后重跑；WARN 项须在提交前逐一确认"
  exit 1
else
  echo "结果: 无 FAIL（WARN 为提示项，须在提交前逐一确认；SKIP 为半确定性/条件性项，须人工核对）"
  exit 0
fi
