# 跨项目分析型流程（只读不改）

> 父文件 → `references/cross-project-flow.md`。
> **设计目标**：覆盖「**纯分析型**跨项目」场景——用户只想了解其他项目逻辑（如 import 组件库后追溯实现、上游源码分析），并不一定打算改动 B 项目代码。
> 与「修复型跨项目（A→B→A 三段式）」并列存在。

## 边界判定

- 只读不改 → 走本文件三步法
- 分析后决定要改 B 项目 → 升级为「修复型」（走 [trigger.md](./trigger.md) §「step-2 挂载：跨项目检测钩子」）
- **全量场景适用**：dev-flow / issue-trace（纯分析根因诊断 Skill，见 `skills/issue-trace/SKILL.md`）/ 普通对话咨询 都遵守本三步法

## 触发信号（任一）

1. 当前分析路径走到 `node_modules/@your-org/*` 或非当前 workspace 的文件
2. 用户问句涉及其他项目代码（如"XX 项目里 YY 怎么实现"/"组件库的源码"）
3. 在源码中遇到 import 自外部包且需追溯实现
4. 链式追溯：分析 B 项目时遇到对 C 项目的引用（递归触发）

> 📌 **issue-trace 反向引用**：纯分析场景下用户描述问题现象/想追溯调用链/想定位根因（但未明确要修）时，由 `skills/issue-trace/SKILL.md` 作为入口；其 §「Step 3：反向追溯 / 跨项目追溯硬约束」直接引用本文件三步法，形成双向闭环。

## 执行三步法（强制顺序，禁止跳步）

### Step 1：本地优先探测

```bash
ls ~/workspace/ | grep -i {包名/项目名关键词}

```

- dev-flow 场景可同时回查 [remote-knowledge.md](../remote-knowledge.md) §二 2.2「本地仓库速查表」取精确路径与默认分支
- 命中 → Step 2；未命中 → Step 3

### Step 2：命中本地 → 分支感知 + 读源码

读取源码前**必须先做分支感知**：

```bash
cd ~/workspace/{repo} && git branch --show-current && git status -s | head -5

```

**期望分支判定**：

- dev-flow 场景：从 [remote-knowledge.md](../remote-knowledge.md) §二 2.1「项目 ↔ 目录 ↔ search_domain」表的「默认分支」列取（多为 `master`）
- 非 dev-flow 场景：默认期望 `master` 主干
- 用户明确指定（如「按 release/2.0 看」）：以用户指定为准

**分支处置**：

- ✅ 与期望一致 → 直接 `read_file` / `grep_search` 该路径源码（**禁止**走 知识库平台 MCP 浪费 Token）
- 🔴 不一致 → 主动展示 4 选项模板（不擅自切分支）：

```markdown
🌿 检测到本地分支与分析期望不一致：

- 仓库：`~/workspace/{repo}/`
- 当前分支：`{current_branch}`（{N} 个未提交改动）
- 期望分支：`{expected_branch}`

可选操作：

1. **切到期望分支**（仅当本地无未提交改动时推荐）→ 等待你执行 `git checkout {expected_branch}` 后我继续分析
2. **就用当前分支分析**（差异可接受）→ 立即继续，引用源码时标注 `[local-repo@{current_branch}]`
3. **暂用 知识库平台 MCP / Git 平台 get_blob_content 看主干代码** → 立即继续（dev-flow 内 知识库平台 优先；非 dev-flow 走 get_blob_content）
4. **取消本次跨项目追溯** → 仅基于当前已知信息推进

```

⚠️ **关键约束**：

- 含未提交改动时**禁止主动建议 `git checkout`**（违反"严禁擅自 git 操作"红线）
- 用户选 2 时引用标注必须带分支信息（`[local-repo@{branch}]`），防止误判信息来源

### Step 3：未命中本地 → 主动提醒 clone（不静默 fallback）

````markdown
📦 检测到跨项目分析需求，但本地未发现仓库：

- 涉及项目：{项目名/包名}
- 已查目录：`~/workspace/`
- 建议本地 clone：

```bash
cd ~/workspace && git clone {repo_url}
```

> `repo_url` 取自 [remote-knowledge.md](../remote-knowledge.md) §二 2.2「本地仓库速查表」；表中无此项目时请用户提供 URL（不擅自猜测）

可选操作：

1. **clone 并继续分析**（推荐）→ 等待你 clone 完成后我继续
2. **暂用 知识库平台 MCP 分析**（dev-flow 场景且项目在映射表中）→ 立即继续，但代码可能滞后
3. **暂用Git 平台 `get_blob_content` 分析**（非 dev-flow 场景）→ 立即继续，需要你提供项目路径
4. **跳过此项目分析** → 仅基于当前已知信息推进

````

## 链式追溯（递归触发）

分析 B 项目时遇到对 C 项目的引用（如 B 引用 `@your-org/some-other-pkg`）→ 重新触发三步法（Step 1→2→3），向下递归直到链路终点或用户主动终止。

## 来源标注规范（强制）

引用本地仓库源码时，必须在反引号路径后追加来源标签：

| 来源类型 | 标注格式 | 示例 |
| --- | --- | --- |
| 当前 workspace | （无标签，默认） | `` `src/x.tsx` `` L42 |
| 本地仓库（默认分支） | `[local-repo]` | `` `other-project/src/x.tsx` `` L42 `[local-repo]` |
| 本地仓库（非默认分支） | `[local-repo@{branch}]` | `` `other-project/src/x.tsx` `` L42 `[local-repo@feature/xxx]` |
| 知识库平台 MCP 命中 | `[remote-kb/git]` 等 | （详见 [remote-knowledge.md](../remote-knowledge.md) §五 5.2） |
| Git 平台 API 命中 | `[git-api]` | （略） |

## 反模式（违反即拒收）

- ❌ 检测到非当前 workspace 文件就放弃分析或仅做推测
- ❌ 等用户提醒「可以去本地看一下」才去查
- ❌ 已知本地路径仍优先走 知识库平台 MCP（浪费 Token + 拿到滞后代码）
- ❌ 未做分支感知就直接读本地源码（可能拿到 feature 分支的旧/中间状态代码）
- ❌ 本地有未提交改动时擅自建议 `git checkout`
- ❌ 引用本地仓库源码时不标注来源 + 分支
- ❌ 未命中本地时静默走 知识库平台，不提醒用户 clone

## 与「修复型跨项目」的衔接

本文件是「修复型」流程的**前置阶段**：

- 分析过程中如确认需要修改 B 项目 → 升级为修复型 → 走 [trigger.md](./trigger.md) §「step-2 挂载」
- 分析后仅给出方案不动手 → 留在本文件，给出代码定位 + 方案描述即可结束
