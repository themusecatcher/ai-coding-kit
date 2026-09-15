#!/bin/bash
# ============================================================
# validate-component.sh - dev-comp 阶段 5 收尾轻量校验脚本
#
# 定位：dev-comp 唯一的程序化校验入口（轻量定位：不做 .validated
# 物理锁、不接状态机、不做 gate 链、不做 hooks 自动触发）。
# 把 references/checklists.md §发布前配置项终检（A/B/C/E/F 类）+
# 提交红线（S 类：S1 git 身份 / S2 分支核对 / S3 commit hash 回填真实性 /
# S4 能力沉淀三件套 / S5 归档双份）中的确定性 grep 检查收拢为单一可执行体，
# 作为 Gate 5 报告「发布前配置项终检」区块的数据来源。
#
# 规则权威源（双向引用，规则变更必须同步改本脚本）：
#   ← references/checklists.md §发布前配置项终检（ID 一一对应：A/B/C/E/F + S）
#   ← references/linkage-map.md §④⑩⑪⑫⑬⑭⑮
#   ← references/changelog-spec.md §3.2 §3.4 §4（F6）
#   ← references/project-map.md §目录命名约定 / §项目规范权威源索引
#   ← references/flow.md 阶段 5 第 1/4/6 步
#   ← SKILL.md §能力复用索引
#
# 2026-09-15（Comment 事故复盘）变更：
#   ① 修正 B5：原「API 章节四件套齐全」判定过严——项目多数组件无事件/无暴露方法，
#      文档只有 `## APIs` + `## Slots`，会产生**假 FAIL**；改为「APIs 必有 +
#      Events/Methods 按组件实际能力（有 defineEmits/defineExpose 才要求）」。
#   ② 新增 F 节（F1-F8）：组件本体与跨文件规范检查（含 F5 `types/global-components.d.ts`
#      登记差集校验——漏登记不报错、type-check 仍 PASS，属静默失效，必须脚本兜底）。
#
# 用法：
#   validate-component.sh <组件名> [项目根] [--context <工作上下文.md>]
#   环境变量：VAUI_PROJECT_ROOT 替代参数 2；VAUI_ARTIFACTS_DIR 替代归档兜底目录
#
# 输出：每项 [PASS]/[FAIL]/[WARN]/[SKIP] + 证据行 + 汇总
# 退出码：0=无 FAIL（WARN/SKIP 不阻断）；1=存在 FAIL；2=参数错误
#
# 兼容：macOS bash 3.2（不依赖关联数组 / mapfile）
# ============================================================

set -u

NAME="${1:-}"
ROOT="${2:-${VAUI_PROJECT_ROOT:-$HOME/myGithub/vue-amazing-ui}}"
CTX=""
while [ $# -gt 0 ]; do
  case "$1" in
    --context) CTX="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [ -z "$NAME" ]; then
  echo "用法: validate-component.sh <组件名> [项目根] [--context <工作上下文.md>]" >&2
  exit 2
fi

# 归一化组件名：AutoComplete -> autocomplete（归一化示例：小写、去分隔符；实际目录名为 kebab-case，如 auto-complete）。
# 项目目录命名约定不统一（components/ 与 docs/ 为 kebab-case、src/views/ 为 camelCase），
# 禁止用固定形态猜测路径，必须解析真实条目（详见 project-map.md §目录命名约定）。
LCNAME=$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
FALLBACK="${VAUI_ARTIFACTS_DIR:-$HOME/myGithub/ai-coding-kit/skills/dev-comp/artifacts}"

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

# ============================================================
# A · 代码注册链路（对应 checklists.md A1-A5）
# ============================================================
section "A 代码注册链路"

# A1 withInstall + 类型导出
A1_F="$ROOT/components/$COMP_DIR/index.ts"
if [ -n "$COMP_DIR" ] && [ -f "$A1_F" ] && grep -q "withInstall" "$A1_F"; then
  ok "A1 components/$COMP_DIR/index.ts 存在且含 withInstall"
else
  fail "A1 components/ 下未解析到 $NAME 目录或 index.ts 未用 withInstall（目录解析：${COMP_DIR:-未找到}；检查 ${A1_F}）"
fi

# A2 components.ts 两条导出（-i：组件名输入可能小写/驼峰，文件内为 PascalCase）
if grep -qi "default as $NAME" "$ROOT/components/components.ts"; then
  ok "A2 components.ts 组件导出命中（export { default as $NAME }）"
else
  fail "A2 components.ts 缺组件导出：grep 'default as $NAME' components/components.ts"
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
ACTUAL=$(cd "$ROOT" && ls -d components/*/ 2>/dev/null | grep -vE 'components/(style|utils|discrete)/' | wc -l | tr -d ' ')
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
  COMP_VUES=$(ls "$ROOT/components/$COMP_DIR/"*.vue 2>/dev/null)
fi

# F1 defineSlots + `export interface {组件名}Slots`（component-design.md §插槽类型）
if [ -z "$COMP_VUES" ]; then
  skip "F1 组件 .vue 未解析到，跳过 defineSlots 检查"
elif grep -qE "defineSlots" $COMP_VUES 2>/dev/null; then
  if grep -qE "export interface ${NAME}Slots" $COMP_VUES 2>/dev/null; then
    ok "F1 defineSlots + export interface ${NAME}Slots 命中"
  else
    warn "F1 有 defineSlots 但未见 'export interface ${NAME}Slots'（插槽类型命名规范见 component-design.md §插槽类型）"
  fi
else
  fail "F1 组件未声明插槽类型：应 'export interface ${NAME}Slots' + 'defineSlots<${NAME}Slots>()'"
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
  F5_MISSING=$(comm -23 /tmp/dc-map-$$.txt /tmp/dc-decl-$$.txt 2>/dev/null | tr '\n' ' ')
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

# S5 产物归档无双份（运行时目录与 artifacts 兜底目录同时存在 → WARN）
section "S5 归档双份"

RT_HIT=$(ls "$HOME/.codebuddy/dev-comp/working-context/" 2>/dev/null | grep -i "$LCNAME" | head -1)
AF_HIT=$(ls "$FALLBACK"/ 2>/dev/null | grep -i "$LCNAME" | head -1)
if [ -n "$RT_HIT" ] && [ -n "$AF_HIT" ]; then
  warn "S5 工作上下文双份：运行时[$RT_HIT] 与 artifacts[$AF_HIT] 同时存在（归档后应删运行时副本，禁止长期双份）"
elif [ -n "$RT_HIT" ] || [ -n "$AF_HIT" ]; then
  ok "S5 工作上下文单一存放（运行时=${RT_HIT:-无} / 归档=${AF_HIT:-无}）"
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
