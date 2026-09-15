# changelog 编写规范（版本号 + 条目格式）

> 本文件是「更新日志 `docs/guide/changelog.md` + 版本号」的**单一权威规范源**。阶段 4（文档）写 changelog 时按需加载，阶段 5 终检按 §4 校验。
> 背景：新增组件发布时的版本号升级规则此前无任何规范，历史上出现过事故——新增 AutoComplete 组件时只升了 patch（发布为 2.4.28），按规则应为 minor+1（2.5.0）。本文件从根上约束。
> 2026-09-15（Comment 开发）补充 §3.4：修正链接规则、新增「版本章节唯一性 / future 清单同步 / 分支合并回检」——事故现场为合并后 changelog 出现**两个 `2.6.0` 章节**。

---

## 1. 版本号升级规则（核心红线）

> 语义化版本 `major.minor.patch`（如 `2.4.28`）。判定依据 = **本次发布是否包含「新增组件」**。

| 发布内容 | 升级方式 | 示例 |
|:--|:--|:--|
| **新增组件** | **minor +1，patch 归 0** | 2.4.28 → **2.5.0** |
| 非新增组件（优化 / 修复 / 文档 / 依赖） | patch +1 | 2.4.28 → 2.4.29 |

- 历史先例（minor 跳变 patch 归 0）：2.3.0（新增 ConfigProvider）、2.4.0（新增 Highlight）、2.5.0（新增 AutoComplete）、2.6.0（新增 Comment 计划版本）✅；反例：2.4.28（新增 AutoComplete，只升 patch）❌。
- 破坏性变更（移除 API/不兼容改动）→ major +1，但组件库日常发布极少涉及，出现时单独与用户确认。
- **规则优先级**：新增组件 > 其他一切。同一版本既有新增组件又有优化修复 → 按「新增组件」升级（minor+1）。
- 同一版本发布多个新组件 → 仍只 minor+1 一次。
- **版本号必须取「当前 `package.json` version 的下一个未发布值」**：开工时先 `grep '"version"' package.json` 实测基线，禁止沿用分支创建时记忆中的目标版本号（分支落后主干时极易撞车，见 §3.4）。

## 2. 双处同步（禁止单边改）

版本号存在 **2 个物理位置**，发布前必须一致：

| 位置 | 内容 | 说明 |
|:--|:--|:--|
| `package.json` | `"version": "X.Y.Z"` | `scripts/publish.sh` 直接读此值发布 npm，**无自动升版逻辑**，必须手动改 |
| `docs/guide/changelog.md` | 新版本条目 `X.Y.Z` | 文档展示的版本号 |

- 判定：`package.json` 的 version 与 changelog 顶部第一条 `VersionDateTag` 内的版本号**逐字一致**。
- 发布顺序：改 `package.json` version → 写 changelog 新条目 → 其余发布流程照旧（`pnpm pub`）。
- ⚠️ **与共享分支/主干对齐**：若目标版本号已被主干发布（或主干已推进到更高版本），必须**先同步主干再定版本号**，禁止把分支里的旧版本块直接合并进主干（§3.4）。

## 3. 条目格式

### 3.1 新版本块结构

新版本块**插在 changelog 文件最顶部**（`# 更新日志` 标题与说明之后、上一个版本块之前）：

```md
## <VersionDateTag date="YYYY-MM-DD">X.Y.Z</VersionDateTag>

- 变更条目 1
- 变更条目 2
```

- `date`：发布当天日期（`YYYY-MM-DD`）；开发期预写时取当天，发布时如非同日需更新。
- 条目按类型分组排序：新增 → 修复 → 优化 → 其他（参照历史条目习惯）。
- **开发期（尚未发布）允许预写顶部版本块**，但必须满足 §3.4 的唯一性与版本号规则。

### 3.2 新增组件条目

```md
- 新增 [中文名 EnglishName](/guide/components/{目录名}.html) 组件
```

- **链接形态：站内相对路径 `/guide/components/{目录名}.html`**（2026-09-15 更正）：
  - 实测基线：全文件 335 处站内相对路径 vs 1 处完整 URL（仅 `AI Coding Kit` 等外站链接保留完整 URL）。
  - ❌ 不再使用 `https://themusecatcher.github.io/vue-amazing-ui/...` 完整 URL（早期写法，已废弃）。
- **`{目录名}` = `docs/guide/components/` 下实测文件名（kebab-case）**（2026-09-15 更正）：
  - 正确：`auto-complete.html` / `color-picker.html` / `loading-bar.html`（与目录名一致）。
  - ❌ 错误（旧规则反向）：全小写连写 `autocomplete.html` / `colorpicker.html` —— 2026-08-28 工程重构后目录已统一短横线，旧规则会生成 **404 链接**。
  - 落地前实测：`ls docs/guide/components/ | grep -i {组件名关键词}`。
- 中文名与演示页 `index.ts` 的 `title` 一致；EnglishName 与组件导出名一致。
- 可追加用途描述（参照历史：`用于高亮文本`），非强制。

### 3.3 修复 / 优化条目（参照历史格式）

```md
- 修复 [中文名 EnglishName](/guide/components/{目录名}.html) 组件 xxx 问题
- 优化并更新 [中文名 EnglishName](/guide/components/{目录名}.html) 组件，xxx
```

- 必须带组件链接（与新增组件同一链接规则）；工具函数链接用 `/utils/functions/{kebab}.html`。
- 纯文档/工程类条目无需链接：如 `组件库及文档代码优化`、`更新组件库部分依赖版本`。

### 3.4 版本章节唯一性与存量清理（⭐ 2026-09-15 新增 · 事故复盘）

> 事故：Comment 分支（开发期预写了 `## 2.6.0`（2026-08-20）承载 Comment 条目）合并主干时，主干**已发布**另一个 `## 2.6.0`（2026-08-28，工程重构），合并后 changelog 出现**两个 `2.6.0` 章节**，且分支块错序停留在 `2.5.1` 与 `2.5.0` 之间；同时 `## future` 清单仍列「新增 评论 Comment 组件」。

**规则（四条）**：

1. **章节唯一**：同一版本号只允许出现一个 `## <VersionDateTag>` 章节。预写块与主干已发布块同名 → 必须**改名到下一个未发布版本**并上移到顶部，禁止保留两份。
2. **严格递减**：全文版本号自上而下严格递减，无重复、无错序（`2.9.0 > 2.8.0 > 2.7.4 > ...`）。
3. **合并/rebase 后必须回检**：任何 `git merge` / `rebase` / 同步主干后，changelog 必须重新执行 §4 的 ③④⑤ 三项校验（分支预写块是重复/错序的高发源）。
4. **`## future` 清单同步**：`future` 区块登记「计划新增组件」，某组件落地发布后必须**删除对应待办行**（否则文档自相矛盾：既已发布又仍列为待办）。

## 4. 阶段 5 终检校验

```bash
# ① package.json 与 changelog 版本号一致
grep -oE '"version"[[:space:]]*:[[:space:]]*"[0-9.]+"' package.json
head -20 docs/guide/changelog.md            # 顶部第一条 VersionDateTag 版本号逐字一致
# ② 升级幅度与发布内容匹配：含新增组件 → minor+1 且 patch 为 0；纯优化修复 → patch+1
# ③ 版本章节唯一且严格递减（无重复 / 无错序）
grep -n '^## <VersionDateTag' docs/guide/changelog.md
# ④ 组件条目链接为站内相对路径 + 实测目录名（kebab）
grep -nE '\]\(/guide/components/[^)]+\)' docs/guide/changelog.md | head
# ⑤ future 清单无「已落地组件」残留
grep -n '^## future' -A 15 docs/guide/changelog.md
```

> ①②已下沉 `scripts/validate-component.sh` **B3**；③④⑤下沉为 **F6**（版本章节唯一 + 链接形态 + future 残留），Gate 5 必跑。

---

## 反模式清单（历史踩坑）

| 反模式 | 正确做法 |
|--------|---------|
| 新增组件只升 patch（2.4.28 AutoComplete 事故） | 新增组件 → minor+1，patch 归 0 |
| 只改 changelog 不改 package.json（或反之） | 双处同步，发布前对照校验 |
| 新版本块插入位置错误（追加到文件尾部） | 插在顶部，最新版本在最上方 |
| 组件链接写错目录名（如全小写连写 `auto-complete` → `autocomplete.html`） | 用 `docs/guide/components/` **实测**目录名（kebab）：`auto-complete.html` |
| 组件条目用完整 URL（历史写法） | 站内相对路径 `/guide/components/{目录名}.html` |
| **合并后出现两个同名版本章节**（Comment 2.6.0 事故） | 预写块改名到下一个未发布版本 + 上移顶部；合并/rebase 后回检 §4 ③ |
| **分支沿用旧目标版本号合入主干** | 合并前实测 `package.json` version，取下一个未发布值 |
| **`## future` 清单残留已落地组件** | 组件发布后同步删除该待办行 |
