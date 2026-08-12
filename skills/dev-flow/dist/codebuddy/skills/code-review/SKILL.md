---
name: code-review
description: "三级代码审查工作流。L1 基础审查（编码后即触发）→ L2 完整审查（Commit 前）→ L3 多视角深度审查（完整模式归档前）。可独立使用，也被 dev-flow 按需调用。"
---

# 三级代码审查工作流

> 统一的代码审查入口。可独立使用（用户说"帮我审查代码"/"review 一下"），也被 dev-flow 在不同步骤按需调用。

## 全局输出规范（最高优先级）

> 本 Skill 生成的所有审查报告（L1/L2/L3）中，**文件路径、代码位置引用**必须遵循 `~/.codebuddy/rules/AI行为规范.mdc` 的「文件/代码位置引用」规范（反引号包裹相对路径 `` `相对路径` `` + 空格后缀行号 `L行号`，IDE 自动识别为可点击链接）。
>
> **适用范围**：问题定位列、改动文件清单、🔴/🟡/🟢 问题的位置字段、SOLID 审查报告、删除清单、L3 多视角审查的代码位置引用等所有输出。

## 使用方式

### 独立使用

用户说"帮我审查代码"/"review 一下改动"/"检查一下代码质量"时直接触发。
默认执行 **L2 完整审查**（最常用场景），用户可指定级别。

### 被 dev-flow 调用

| dev-flow 步骤 | 审查级别 | 说明 |
|---------------|---------|------|
| 5.5a 编码后置钩子 | L1 | 本轮新增/修改的代码行 |
| 步骤 7 Commit 前 | L2 | 本次所有改动文件 |
| 收尾步骤 3.5 | L2 | 本次所有改动文件 |
| 步骤 8 深度审查 | L3 | 本次所有改动 + 注释 + 多视角 + 复杂度 |

---

## 〇、审查启动流程

独立使用时，按以下步骤启动审查：

1. **收集变更** — 执行 `git diff --staged` 和 `git diff` 查看所有改动。无 diff 时检查最近提交 `git log --oneline -5`
2. **理解范围** — 识别哪些文件变更、关联的功能/修复、文件间关系
3. **阅读上下文** — 不孤立审查改动，阅读完整文件，理解 import、依赖、调用链路
4. **执行审查清单** — 按 CRITICAL → LOW 逐层审查
5. **大 Diff 分治**（diff 超 500 行时启用）：
   - 先执行 `git diff --stat` 输出文件级摘要
   - 按模块/功能区域分批审查，每批聚焦一个逻辑变更
   - 混合关注点时按逻辑功能分组发现，而非按文件顺序
6. **输出报告** — 使用标准报告格式，仅报告符合「报告判断标准」（§四）的问题

---

## 一、分层策略

| 层级 | 时机 | 加载成本 | 审查范围 |
|------|------|---------|---------|
| **L1 基础审查** | 每轮编码后 | 零额外 token | 本轮新增/修改的代码行 |
| **L2 完整审查** | commit 前 | 需 read_rules 加载完整编码规范 | 本次所有改动文件 |
| **L3 多视角深度审查** | 完整模式归档前 | L2 + 多视角审查 + 复杂度检测 + references 深度清单 | 本次所有改动 + 注释补充 |

**关系**：L2 = L1 + L2 额外清单 + 完整编码规范。L3 = L2 + 多视角审查 + 注释补充 + 复杂度检测 + references 深度清单（按需加载）。

---

## 二、L1 审查清单

每轮编码后必须执行，无需加载额外文件。

> **规范来源**：逐条对照「开发规范-红线」的「前端编码底线」章节（alwaysApply，已在上下文中）。
> L1 不重复列出每一条，而是引用红线作为唯一事实来源，红线更新时 L1 自动同步。

### 执行方式

1. **TypeScript / JavaScript**：对照红线「TypeScript / JavaScript」小节，逐条检查本轮新增/修改的代码
2. **React**：对照红线「React」小节，逐条检查本轮新增/修改的代码
3. **CSS / SCSS**：对照红线「CSS / SCSS」小节，逐条检查本轮新增/修改的代码
4. **CSS 变量命名**（涉及 CSS 变量时必须检查）：
   - [ ] CSS 变量使用项目统一命名规范
   - [ ] `var()` 必须提供 fallback 值
5. **浏览器兼容性**（涉及 JS API 或 CSS 属性时必须检查）：
   - [ ] 调用 `use_skill('browser-compat')` 对本轮新增/修改的代码执行兼容性扫描
   - [ ] browser-compat 会自动判定项目基线（读 `browserslist` / `.browser-compat.json`，无则用保守型默认），输出 🔴 CRITICAL / 🟡 WARNING 列表
   - [ ] 将 browser-compat 输出按严重度**回填到 L1 报告**：🔴 立即修复 / 🟡 加入用户决策选项 / 🟢 仅提示
   - [ ] 规则来源：`~/.codebuddy/rules/浏览器兼容性规范.mdc`（单一真相源），修复方案见 browser-compat `references/fix-patterns.md`
6. **异步与竞态安全**（涉及异步操作时必须检查）：
   - [ ] 并发请求是否有竞态保护（AbortController / 版本号比对 / 请求取消）
   - [ ] 异步操作是否有 loading/error/success 三态管理
   - [ ] useEffect 中异步操作是否处理了组件卸载场景（cleanup 取消/忽略结果）
7. **边界条件与错误处理**（涉及数据操作/条件判断时必须检查）：
   - [ ] 空值/undefined/空数组/空字符串边界是否处理（注意 `if (value)` 时 `0` 和 `""` 是有效值的场景）
   - [ ] 数组首尾元素访问前是否检查长度
   - [ ] 除法/取模前是否检查分母为零
   - [ ] 错误处理不吞异常（禁止空 catch / 仅 console.log 后丢弃）
   - [ ] 异步操作的 rejection 是否有 catch 处理
8. **通用检查**（每次必须）：
   - [ ] 无遗留调试代码（console.log/debugger/临时样式）
   - [ ] 无未使用的 import/变量
   - [ ] 风格与同文件已有写法一致
   - [ ] 新增代码质量底线：复制老代码时发现缺陷必须在新代码中修正
9. **条件表达式可读性**（涉及条件逻辑时必须检查）：
   - [ ] 无 ≥2 层嵌套三元表达式（拆分为 if 早返回 / useMemo / 惰性初始化）
   - [ ] JSX props 内无超过单层三元的条件逻辑（提取为变量）
   - [ ] 多个 if 分支逻辑相同时已合并（`if (a || b) return X`）
   - [ ] 分号前无多余空格

---

## 三、L2 额外审查

### 加载策略

以下编码规范通常已作为 alwaysApply 规则在上下文中。**优先检查是否已加载，避免重复加载浪费 Token**。

| 改动涉及 | 需要的规范 | 加载方式 |
|---------|-----------|----------|
| .ts/.tsx/.js/.jsx | TypeScript_官方规范 | 尝试引用规范中具体条目，能引用到则已加载 → 跳过；否则 `read_rules` 补充加载 |
| .scss/.css/.module.scss | CSS_官方规范 | 同上 |
| React 组件 | `references/react.md`（dev-flow skill 内） | 同上 |
| 依赖安装 | 依赖管理与Lock文件规范 | 同上 |
### L2 额外清单（在 L1 基础上增加）

> 以下清单是从完整编码规范中提取的**高频违规项**，审查时优先检查这些条目。
> 完整审查标准以上下文中已加载的编码规范（TypeScript_官方规范、CSS_官方规范等）为准。

#### TypeScript / JavaScript（编码规范）
- [ ] 函数默认参数放在最后
- [ ] 使用 rest 语法代替 arguments
- [ ] 所有 import 放在文件顶部，同路径只有一个 import
- [ ] 每个变量单独声明
- [ ] case 语句中使用大括号创建块级作用域
- [ ] 避免嵌套三元表达式
- [ ] 使用 String() / Number() / parseInt(,10) / !! 进行类型转换
- [ ] 链式调用超两个方法时换行
- [ ] 使用 FIXME/TODO 标记待办

#### CSS / SCSS（编码规范）
- [ ] 类名使用破折号（BEM）
- [ ] 禁止使用 ID 选择器
- [ ] 多选择器各占一行
- [ ] 小于 1 的小数前不加 0
- [ ] 字符串使用单引号
- [ ] 单行只允许一个属性
- [ ] before/after/active/focus 等使用单冒号
- [ ] SCSS @import 使用双引号，.scss 后缀不省略
- [ ] 变量名用破折号
- [ ] 避免 @extend，用 @mixin 代替

#### React（编码规范）
- [ ] 偏向迭代和模块化，避免代码重复
- [ ] 目录名小写+短横线
- [ ] 接口用 interface 而非 type
- [ ] 避免使用枚举，用映射代替

#### 依赖管理
- [ ] 安装前检查 lock 文件版本，禁止盲目升级
- [ ] 禁止修改 lockfileVersion
- [ ] 新增依赖说明用途

#### 后端 / Node.js（适用时）
- [ ] 请求参数（body/params/query）使用 schema 校验，禁止未验证即使用
- [ ] 公共端点配置速率限制（Rate Limiting）
- [ ] 禁止无 LIMIT 的用户侧查询（`SELECT *` 无 LIMIT）
- [ ] 禁止 N+1 查询（循环内逐条查关联数据 → 改用 JOIN/批量查询）
- [ ] 外部 HTTP 调用必须配置超时（timeout）
- [ ] 错误信息禁止泄露内部实现细节（堆栈/路径/SQL）
- [ ] API 配置正确的 CORS 策略

#### i18n 合规（涉及用户可见文本时）
- [ ] 新增的用户可见文本是否使用了翻译函数（`t()` / `i18n.t()` 等）
- [ ] 翻译 key 命名是否符合项目 i18n 规范
- [ ] 是否遗漏语言包文件的同步更新

### 通用 Diff 审查清单
- [ ] 每处改动都与本次需求/问题直接相关
- [ ] 无冗余代码
- [ ] 无超出需求范围的意外修改
- [ ] 无遗留调试痕迹
- [ ] 改动量与需求复杂度匹配
- [ ] **文档同步兜底检查**（时机 ③）：调用 `use_skill('tech-doc')`（路由到 doc-sync 模块）按 §四 逐项检查

---

## 四、L3 多视角深度审查（完整模式步骤 8 专用）

L3 = L2 全部内容 + 以下额外维度：

### 注释补充
- 对本次新增/改动的复杂 JS 逻辑添加精简注释
- 只注释不显而易见的逻辑
- 不要修改本次改动范围之外的注释

### 多视角审查

> 视角定义为 code-review Skill 唯一事实来源，dev-flow Agent 并行调度时引用此处。

| 视角 | 关注点 | 深度清单 |
|------|-------|---------|
| 🔒 安全审计 | 用户输入是否校验、敏感数据是否保护、错误信息是否泄露（详见下方安全审计清单） | 加载 `references/security-deep-checklist.md`（JWT/供应链/竞态条件/密码学等） |
| ⚡ 性能工程 | 是否引入不必要的重渲染、网络请求、大体积依赖 | 加载 `references/code-quality-deep-checklist.md`（N+1/缓存/内存/CPU 密集等） |
| 🔧 可维护性 | 代码是否易读、命名是否清晰、是否过度耦合、异常场景是否有兜底 | — |
| 🏗️ 架构健康度 | SOLID 原则是否违反、代码臭味、移除候选识别（详见 SOLID 清单） | 加载 `references/solid-checklist.md`（SOLID 审查 + 重构启发式 + 移除候选） |

**附加产出**（非独立视角，作为审查附件输出）：
| 产出 | 内容 |
|------|------|
| 📋 建议补充测试的点位清单 | 列出具体函数名 + 边界条件 + 建议的测试场景，供开发者按需补充测试 |

#### 安全审计深度清单（CRITICAL 级）

以下问题**必须**标记——可能造成实际损害：

- **硬编码凭据** — 源码中的 API key、密码、token、连接字符串
- **SQL 注入** — 查询中使用字符串拼接而非参数化查询
- **XSS 漏洞** — 未转义的用户输入渲染到 HTML/JSX
- **路径遍历** — 用户可控的文件路径未做净化
- **CSRF 漏洞** — 状态变更端点未做 CSRF 保护
- **认证绕过** — 受保护路由缺少认证检查
- **日志泄露** — 日志中输出敏感数据（token、密码、PII）

```typescript
// ❌ SQL 注入：字符串拼接查询
const query = `SELECT * FROM users WHERE id = ${userId}`;

// ✅ 参数化查询
const query = `SELECT * FROM users WHERE id = $1`;
const result = await db.query(query, [userId]);
```

```typescript
// ❌ 未净化的用户 HTML 内容（XSS 风险）
// 始终使用 DOMPurify.sanitize() 或等效方案净化

// ✅ 使用文本内容或净化后渲染
<div>{userComment}</div>
```

```typescript
// ❌ N+1 查询
const users = await db.query('SELECT * FROM users');
for (const user of users) {
  user.posts = await db.query('SELECT * FROM posts WHERE user_id = $1', [user.id]);
}

// ✅ 单次 JOIN 查询
const usersWithPosts = await db.query(`
  SELECT u.*, json_agg(p.*) as posts
  FROM users u LEFT JOIN posts p ON p.user_id = u.id
  GROUP BY u.id
`);
```

### React/Next.js 专项检查（适用时）
- Missing dependency arrays
- State updates in render
- Missing keys in lists
- Stale closures
- Client/server boundary

### 复杂度检测
检测改动文件中复杂度超过 20 的函数，提供优化建议（Early Return、策略模式、提取子函数等）。

### 分级处理

| 等级 | 审查维度 | 处理方式 |
|------|---------|---------|
| CRITICAL | 功能正确性、数据安全、XSS/注入 | 直接修复 |
| HIGH | 边界健壮性、空值、并发、异常输入 | 直接修复 |
| MEDIUM | 冗余逻辑、未使用变量、可简化条件 | 符合最小入侵则修复，否则告知用户 |
| LOW | 命名规范、可读性、性能建议 | 列出建议，用户决定 |

### 报告判断标准

以下规则替代主观的"置信度"评估，提供可操作的报告/不报告判断依据：

- ✅ **报告**：能指向具体代码行 + 能给出明确修复方案
- ✅ **报告**：违反了明确的编码规范条目（能引用具体规范）
- ❌ **不报告**：需要运行时数据才能确认的猜测性问题
- ❌ **不报告**：仅基于个人风格偏好的建议（除非违反已加载的编码规范）
- ❌ **不报告**：无法给出具体修复方案的模糊建议

---

## 五、审查报告格式

### 单项发现格式

```
[CRITICAL] 硬编码 API 密钥
文件: src/api/client.ts:42
问题: API key "sk-abc..." 暴露在源码中，将被提交到 git 历史
修复: 迁移到环境变量，并添加到 .gitignore/.env.example

  const apiKey = "sk-abc123";           // ❌
  const apiKey = process.env.API_KEY;   // ✅
```

### Summary 表格

每次审查结尾必须附带：

```
## 审查摘要

| 严重度 | 数量 | 状态 |
|--------|------|------|
| CRITICAL | 0 | ✅ 通过 |
| HIGH | 2 | ⚠️ 警告 |
| MEDIUM | 3 | ℹ️ 信息 |
| LOW | 1 | 📝 备注 |

结论: ⚠️ WARNING — 2 个 HIGH 级问题建议合并前解决。
```

### 审批标准

| 结论 | 条件 | 操作 |
|------|------|------|
| **✅ Approve** | 无 CRITICAL 或 HIGH 问题 | 可直接合并 |
| **⚠️ Warning** | 仅有 HIGH 问题（无 CRITICAL） | 可谨慎合并，建议修复 |
| **🚫 Block** | 存在 CRITICAL 问题 | 必须修复后才能合并 |

---

## 六、References（L3 按需加载）

> 以下文件在 L3 审查时按视角需求加载，L1/L2 不加载以控制 Token 开销。

| 文件 | 用途 | 加载时机 |
|------|------|---------|
| `references/solid-checklist.md` | SOLID 架构审查 + 代码臭味 + 重构启发式 + 移除候选模板 | L3 🏗️ 架构健康度视角 |
| `references/security-deep-checklist.md` | JWT/供应链/竞态条件/密码学/CORS 等深度安全清单 | L3 🔒 安全审计视角 |
| `references/code-quality-deep-checklist.md` | 错误处理反模式/性能/缓存/边界条件深度清单 | L3 ⚡ 性能工程视角 + 通用质量审查 |
