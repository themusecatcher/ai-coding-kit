# changelog 编写规范（版本号 + 条目格式）

> 本文件是「更新日志 `docs/guide/changelog.md` + 版本号」的**单一权威规范源**。阶段 4（文档）写 changelog 时按需加载，阶段 5 终检按 §4 校验。
> 背景：新增组件发布时的版本号升级规则此前无任何规范，历史上出现过事故——新增 AutoComplete 组件时只升了 patch（发布为 2.4.28），按规则应为 minor+1（2.5.0）。本文件从根上约束。

---

## 1. 版本号升级规则（核心红线）

> 语义化版本 `major.minor.patch`（如 `2.4.28`）。判定依据 = **本次发布是否包含「新增组件」**。

| 发布内容 | 升级方式 | 示例 |
|:--|:--|:--|
| **新增组件** | **minor +1，patch 归 0** | 2.4.28 → **2.5.0** |
| 非新增组件（优化 / 修复 / 文档 / 依赖） | patch +1 | 2.4.28 → 2.4.29 |

- 历史先例（minor 跳变 patch 归 0）：2.3.0（新增 ConfigProvider）、2.4.0（新增 Highlight）✅；反例：2.4.28（新增 AutoComplete，只升 patch）❌。
- 破坏性变更（移除 API/不兼容改动）→ major +1，但组件库日常发布极少涉及，出现时单独与用户确认。
- **规则优先级**：新增组件 > 其他一切。同一版本既有新增组件又有优化修复 → 按「新增组件」升级（minor+1）。
- 同一版本发布多个新组件 → 仍只 minor+1 一次。

## 2. 双处同步（禁止单边改）

版本号存在 **2 个物理位置**，发布前必须一致：

| 位置 | 内容 | 说明 |
|:--|:--|:--|
| `package.json` | `"version": "X.Y.Z"` | `scripts/publish.sh` 直接读此值发布 npm，**无自动升版逻辑**，必须手动改 |
| `docs/guide/changelog.md` | 新版本条目 `X.Y.Z` | 文档展示的版本号 |

- 判定：`jq -r .version package.json` 与 changelog 顶部第一条 `VersionDateTag` 内的版本号**逐字一致**。
- 发布顺序：改 `package.json` version → 写 changelog 新条目 → 其余发布流程照旧（`pnpm pub`）。

## 3. 条目格式

### 3.1 新版本块结构

新版本块**插在 changelog 文件最顶部**（`# 更新日志` 标题与说明之后、上一个版本块之前）：

```md
## <VersionDateTag date="YYYY-MM-DD">X.Y.Z</VersionDateTag>

- 变更条目 1
- 变更条目 2
```

- `date`：发布当天日期（`YYYY-MM-DD`）。
- 条目按类型分组排序：新增 → 修复 → 优化 → 其他（参照历史条目习惯）。

### 3.2 新增组件条目

```md
- 新增 [中文名 EnglishName](https://themusecatcher.github.io/vue-amazing-ui/guide/components/{目录名}.html) 组件
```

- 链接路径 = 组件目录名的 kebab-case（如 `AutoComplete` → `autocomplete.html`），与 `docs/guide/components/{目录名}.md` 对应。
- 中文名与演示页 `index.ts` 的 `title` 一致；EnglishName 与组件导出名一致。
- 可追加用途描述（参照历史：`用于高亮文本`），非强制。

### 3.3 修复 / 优化条目（参照历史格式）

```md
- 修复 [中文名 EnglishName](链接) 组件 xxx 问题
- 优化并更新 [中文名 EnglishName](链接) 组件，xxx
```

- 必须带组件链接（与新增组件同一链接规则）。
- 纯文档/工程类条目无需链接：如 `组件库及文档代码优化`、`更新组件库部分依赖版本`。

## 4. 阶段 5 终检校验

```bash
# ① package.json 与 changelog 版本号一致
jq -r .version package.json
head -20 docs/guide/changelog.md   # 顶部第一条 VersionDateTag 版本号逐字一致
# ② 升级幅度与发布内容匹配：含新增组件 → minor+1 且 patch 为 0；纯优化修复 → patch+1
```

---

## 反模式清单（历史踩坑）

| 反模式 | 正确做法 |
|--------|---------|
| 新增组件只升 patch（2.4.28 AutoComplete 事故） | 新增组件 → minor+1，patch 归 0 |
| 只改 changelog 不改 package.json（或反之） | 双处同步，发布前 jq 对照校验 |
| 新版本块插入位置错误（追加到文件尾部） | 插在顶部，最新版本在最上方 |
| 组件链接写错目录名（如 `auto-complete.html`） | 用组件目录名 kebab-case，与 docs 文件对应 |
