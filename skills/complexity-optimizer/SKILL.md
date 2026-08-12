---
name: complexity-optimizer
description: 检测TypeScript/JavaScript文件中复杂度超过20的函数，基于ESLint complexity规则。
keywords: ["代码复杂度", "圈复杂度", "ESLint complexity", "TypeScript", "JavaScript", "复杂度检测"]
---

# 复杂度优化助手

## 功能

检测文件中复杂度超过20的函数，基于 ESLint `complexity` 规则。

**特性**：
- 自动临时移除 `eslint-disable complexity` 注释，确保检测到所有函数
- 支持没有 eslint 配置的项目：自动查找有配置的兄弟项目（如 my-project）进行检测

## 使用方式

告诉我要检测的文件路径，我会输出：
- 复杂度超过20的函数列表
- 函数位置（行号）
- 具体复杂度值

## 工作流程

### 第一步：检测复杂度

运行检测脚本，输出超过阈值的函数列表。

### 第二步：询问用户

检测完成后，**必须询问用户**：
> "请问需要对哪个函数进行复杂度优化？请提供函数名或行号。"

### 第三步：设计分步优化方案

用户选择函数后，分析该函数并**设计分步优化方案**。方案需包含：

1. **当前复杂度**：当前值和目标值（≤20）
2. **分步计划**：将优化拆分为多个独立步骤，每步包含：
   - **步骤编号**：如"第一步"、"第二步"
   - **修改范围**：具体行号范围（如"将 128-194 行提取为独立函数"）
   - **改动内容**：具体要做什么（如"提取 `handlePresetAction` 函数处理 preset 相关逻辑"）
   - **预计效果**：该步骤预计减少的复杂度

**方案输出格式示例**：

```
## 优化方案

**当前复杂度**：54（目标 ≤ 20）

### 第一步：将 128-194 行（preset 分支）提取为独立函数

**改动内容**：
- 提取 `handlePresetAction` 函数处理 preset 相关逻辑
- 包含 PRESET_INITIAL/ADD/DELETE/UPDATE 四个 case

**预计效果**：reducer 复杂度减少约 15

---

### 第二步：将 199-250 行（custom option 分支）提取为独立函数

**改动内容**：
- 提取 `handleCustomOptionAction` 函数处理选项相关逻辑

**预计效果**：reducer 复杂度再减少约 10

---

**是否先执行第一步？**
```

### 第四步：逐步执行并确认

**关键原则：每步执行前必须等待用户确认，每步执行后必须验证并询问是否继续。**

执行流程：
1. 输出当前步骤的具体改动内容
2. **等待用户确认**（如"是"、"可以"、"执行"）
3. 执行该步骤的代码修改
4. 运行复杂度检测，验证结果
5. 输出验证结果，询问：
   - 若已达标：告知用户优化完成
   - 若未达标：询问"是否执行下一步？"
6. 等待用户确认后，重复步骤 1-5

**用户可能的回复**：
- 确认：如"是"、"可以"、"好的"、"继续" → 执行当前/下一步
- 拒绝/调整：如"不行"、"换个方案"、"这里需要调整" → 重新讨论
- 指定范围：如"仅对297行以后的逻辑进行修改" → 调整方案范围

### 第五步：单步执行修改

每步修改遵循：
- **优化目标**：将函数复杂度降至 **20 或以下**（达标即可停止，无需执行剩余步骤）
- **最小改动原则**：用最少的代码修改达到目标
- **保持功能不变**：重构不能改变原有行为
- **单步执行**：每次只执行一个步骤，修改不超过100行
- **禁止修改函数入参**：提取函数时，不得在函数内部修改入参对象的属性（避免 `Assignment to property of function parameter` 错误）
- **禁止多余改动**：提取函数时，不得修改原有变量名、注释、代码格式，仅做必要的结构调整

**禁止修改入参的处理方式**：

```ts
// ❌ 错误：直接修改入参对象
const handleAction = (selectedQuestion: InterQuestion) => {
  selectedQuestion.change_flag = ChangeFlagEnum.MODIFY; // ESLint 报错
  return selectedQuestion;
};

// ✅ 正确方式1：在调用处先深拷贝，提取函数内直接修改（原逻辑不变）
const customCopy = deepCopy(state.custom);
const selectedQuestion = customCopy[selectedIndex];
// 此时 selectedQuestion 是 customCopy 的引用，修改它等于修改 customCopy
handleAction(state, action, customCopy, selectedQuestion);

// ✅ 正确方式2：提取函数返回新对象，调用处合并
const handleAction = (question: InterQuestion) => {
  return { ...question, change_flag: ChangeFlagEnum.MODIFY };
};
customCopy[selectedIndex] = handleAction(selectedQuestion);
```

**推荐方式1**：保持原有代码结构，在主函数中完成深拷贝后传入提取函数，提取函数内的修改逻辑不变。

### 第六步：验证并决定是否继续

每步修改完成后：
1. 重新运行复杂度检测
2. 输出验证结果：
   - 当前复杂度值
   - 是否已达标（≤20）
3. **若复杂度未降低或反而升高**：
   - **立即撤回本次改动**（使用 git checkout 或手动还原）
   - 输出"本次优化无效（复杂度从 X 变为 Y），已撤回改动"
   - 分析失败原因，重新思考优化方案
   - 询问用户是否尝试新方案
4. 若已达标：
   - 输出"优化完成，无需执行后续步骤"
   - 进行逻辑一致性检查
5. 若未达标但复杂度有所降低：
   - 输出"是否执行下一步：[下一步内容简述]？"
   - 等待用户确认

### 第七步：最终验证

所有必要步骤完成后，进行最终验证并**向用户输出验证结果**：

1. **复杂度验证**：
   - 目标函数复杂度已降至 20 以下
   - 新提取的函数复杂度也在 20 以下

2. **逻辑一致性检查**：
   - 确认未改动原有业务逻辑（仅做结构调整）
   - **必须向用户说明**：本次优化仅做了哪些结构调整，未改变原有逻辑

**输出格式示例**：

```
## 最终验证

✅ **复杂度验证通过**
- `filterMenuItems` 复杂度：29 → 18
- 新增函数 `isPrivateDisplayedPage` 复杂度：3

✅ **逻辑一致性检查**
本次优化仅做结构调整，未改变原有业务逻辑：
- 提取 `isPrivateDisplayedPage` 函数：将私有化版本白名单判断逻辑提取为独立函数
- 原有判断条件、返回值均保持不变
```

## 拆分方式选择：单独函数 vs 自定义 Hooks

在 React 组件中拆分逻辑时，需根据以下标准选择拆分方式：

| 维度 | 单独函数（组件外部） | 自定义 Hooks |
|------|---------------------|--------------|
| **适用场景** | 纯逻辑处理，不依赖 React 特性 | 需要使用 useState/useEffect/useContext 等 |
| **参数传递** | 需要显式传入所有依赖 | 可直接访问组件 context |
| **复用性** | 可在任何 JS/TS 文件中复用 | 仅能在 React 组件/Hooks 中复用 |
| **测试难度** | 更容易单元测试 | 需要 React 测试环境 |

### 选择单独函数

- 纯数据处理/计算逻辑
- 不需要 React Hooks（useState、useEffect 等）
- 逻辑可能被非 React 代码复用
- 例如：`handleGoBack`、`handleTitleUpdateSuccess`

### 选择自定义 Hooks

- 内部需要使用 useState、useEffect、useCallback 等
- 需要访问 React Context
- 逻辑与组件生命周期相关
- 需要返回状态和方法的组合
- 例如：表单状态管理、数据请求逻辑

### 判断流程

```
待拆分逻辑是否使用 React Hooks？
├── 否 → 提取为单独函数（组件外部）
└── 是 → 是否涉及多个 useState + useEffect 的组合？
    ├── 是 → 提取为自定义 Hook
    └── 否 → 保持在组件内（用 useCallback 包裹）或提取为单独函数
```

## 优化策略参考

| 复杂度来源 | 优化策略 |
|-----------|---------|
| 多层嵌套 if-else | 使用早返回(Early Return)减少嵌套 |
| 大量 switch-case | 提取为映射对象或策略模式 |
| 循环内多分支 | 提取为独立函数 |
| 重复条件判断 | 提取为命名变量或函数 |
| 多个 `\|\|` 判断同一变量 | 使用 `[].includes()` 替代（见下方示例） |
| 大函数 | 按职责拆分为多个小函数 |
| 三元表达式确定类名 | 改用 classnames 对象形式（见下方示例） |

### 三元表达式类名优化示例

三元表达式会增加复杂度，可改用 `classnames` 对象形式：

```tsx
// 优化前（复杂度 +1）
className={cn(
  styles.row,
  listItem.status === 'show' ? 'draggable-item' : styles.fixedItem,
)}

// 优化后（复杂度 +0）
className={cn(styles.row, {
  'draggable-item': listItem.status === 'show',
  [styles.fixedItem]: listItem.status !== 'show',
})}
```

### 多个 || 判断优化示例

多个 `||` 判断同一变量会增加复杂度，可改用 `[].includes()` 形式：

```tsx
// 优化前（复杂度 +4）
const shouldShow = (
  status === StatusCode.A
  || status === StatusCode.B
  || status === StatusCode.C
  || status === StatusCode.D
  || status === StatusCode.E
);

// 优化后（复杂度 +0）
const shouldShow = [
  StatusCode.A,
  StatusCode.B,
  StatusCode.C,
  StatusCode.D,
  StatusCode.E,
].includes(status);
```

## 输出示例

```
文件: my-project/src/views/.../index.tsx
阈值: 20
(已临时移除 eslint-disable complexity 注释)

🔴 复杂度超过 20 的函数:

1. Arrow function (第 1397 行)
   复杂度: 67 (超出 47)

2. Async arrow function (第 715 行)
   复杂度: 25 (超出 5)

---
请问需要对哪个函数进行复杂度优化？请提供函数名或行号。
```
