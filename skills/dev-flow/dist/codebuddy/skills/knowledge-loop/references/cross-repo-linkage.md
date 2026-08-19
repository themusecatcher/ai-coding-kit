# 跨仓库参数链路联动 — 写入范例与规范

> 本文件提供 deposit.md 步骤 5.6「跨仓库参数链路联动」的完整写入范例，供 AI 在执行双向链接写入时参照。
> 核心规范已在 `lifecycle.md` §「跨仓库双向链接维护」中定义，本文件侧重具体写法。

## 范例：client_token 跨仓库参数链路（B → A）

### 场景

B 项目 `project-b` 通过 `buildRequest` 将 `client_token` 作为 query 参数透传给 A 项目 `project-a` 的 `sendRequest`，A 项目在 `service.ts` → `transport.js` 两层中消费该参数。

### 发起方（B 项目）写入范例

**文件**：`~/.codebuddy/knowledge/project-b/api-integration/_overview.md`

```markdown
### client_token 客户端标识透传（跨仓库参数链路）

**全链路视角**（B 项目 → A 项目，N 层传递）：

{ASCII 链路图：B 侧各层 → A 侧各层}

**B 侧（发起方，N 层）**：
| 层 | 文件 | 作用 |
|----|------|------|
| ① ... | ... | ... |

**A 侧（接收方，M 层）**：详见 `~/.codebuddy/knowledge/project-a/infra/_overview.md` §「client_token 参数传递链路」
| 层 | 文件 | 作用 |
|----|------|------|
| ④ ... | ... | ... |

**跨仓库关键共识**：
- {共识 1}
- {共识 2}
- 修改任一侧时必须确认另一侧能正确理解（参见 A 项目 `infra/pitfalls.md` §1）
```

**文件**：`~/.codebuddy/knowledge/project-b/_index.md`

```markdown
## 概念索引
| **跨仓库参数链路：client_token B→A 完整传递** | api-integration ↔ project-a/infra | B 侧 3 层 + A 侧 2 层 |
```

### 消费方（A 项目）写入范例

**文件**：`~/.codebuddy/knowledge/project-a/infra/_overview.md`

在已有 §「client_token 参数传递链路」的「跨仓库联调场景」小节中扩展：

```markdown
### 跨仓库联调场景（⚠️ B → A 完整链路）

{ASCII 完整链路图：从 B 侧 ① 到 A 侧 ⑤}

**B 侧关键文件**（详见 `~/.codebuddy/knowledge/project-b/api-integration/_overview.md` §「client_token 客户端标识透传」）：

| 文件 | 改动 | 作用 |
|------|------|------|
| PermissionService.ts | query参数新增 client_token | 获取客户端标识 |
| utils/common.ts::buildRequest() | 签名扩展：新增第 7 参数 query | 提供透传通道 |

**完整示例**：{1→2→3→4→5 逐步描述}
```

**文件**：`~/.codebuddy/knowledge/project-a/_index.md`

```markdown
## 跨模块知识
| **跨仓库参数链路 B→A** | infra/_overview.md §跨仓库联调场景 ↔ `~/.codebuddy/knowledge/project-b/api-integration/_overview.md` §client_token | 涉及 project-b 调用 project-a 接口 |

## 概念索引
| **跨仓库参数链路：client_token B→A 完整 5 层传递** | infra/_overview.md §跨仓库联调场景 | B 侧 3 层 + A 侧 2 层 |
```

---

## 写入检查清单（AI 执行双向链接后自检）

- [ ] 发起方 `_index.md` 概念索引含跨仓库条目 + 绝对路径
- [ ] 消费方 `_index.md` 跨模块知识 / 概念索引含跨仓库条目 + 绝对路径
- [ ] 发起方主题文件含完整链路图 + 指向消费方的引用链接
- [ ] 消费方主题文件含完整链路图 + 指向发起方的引用链接
- [ ] 两侧引用路径均以 `~/.codebuddy/knowledge/` 开头（绝对路径）
- [ ] 两侧引用的章节锚点 §{章节名} 与实际目标文件章节标题一致
- [ ] 仓库数 >2 时，每一对相邻仓库都有双向链接，形成链式引用

---

## 常见模式

### 模式 1：双向对称链接（最常用）

A 调用 B 且 B 需要感知 A 的参数格式 → 两侧互引，链路图完整。

### 模式 2：单向主链 + 可选回引

A 调用 B 但 B 不关心谁调用它 → A 必须引用 B，B 在 pitfalls 中记录调用方清单（不逐一回引）。

### 模式 3：链式多仓库（>2 个仓库）

A → B → C → D 的参数链路 → 逐对建立：A↔B, B↔C, C↔D。

B 的知识同时引用 A 和 C，形成链式索引：
```
A _index.md → 引用 B
B _index.md → 引用 A + 引用 C
C _index.md → 引用 B + 引用 D
D _index.md → 引用 C
```

从任意一个仓库 grep `client_token` 都能顺着链接追溯到完整链路。
