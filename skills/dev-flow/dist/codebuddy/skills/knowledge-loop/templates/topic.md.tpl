---
module: "{module-name}"
topic: "{topic: data-model | api | logic | ui | pitfalls}"

# 置信度（5 级：draft/scanned/pending/verified/stale；废弃用 deprecated 生命周期状态）
confidence: "verified"

# 创建分支追踪（pending 级别必填，其他级别可选；feature 沉淀时由沉淀模式自动写入）
created_branch: ""              # 知识创建时所在的 git 分支
base_branch: "master"           # 目标合入分支（默认取 _index.md 的 base_branch）

# 代码锚点（漂移检测依据；topic 级填具体文件路径，可选 symbols 加权命中）
code_anchors:
  - path: "src/{path/to/file}"  # 文件路径
    symbols: []                  # 可选：关键符号列表，如 ["fooFn", "BarCls"]

# 业务验证信息（与 confidence 正交，独立标记上线/生产验证状态）
release:
  released: false
  released_at: null
  verified_in_production: false

# 稳定性指标（自动维护，详见 references/confidence.md）
stability:
  last_verified: "YYYY-MM-DD"
  drift_count: 0
  days_since_merge: 0
  confidence_score: 85

created: "YYYY-MM-DD"
last_scanned: "YYYY-MM-DD"      # 可选，仅扫描模式写入
---

# {module-name} — {topic 中文名}

> 本文件记录 {module-name} 模块的 {topic} 相关知识。
> 由 knowledge-loop Skill 沉淀模式自动创建/更新。

## 内容

{根据 topic 类型组织内容}

### data-model 主题示例结构
- 核心 TypeScript 接口/类型定义
- State 结构
- Props 定义
- 常量/枚举映射表

### api 主题示例结构
- 接口地址、方法、参数、返回值
- 错误码含义
- 域名/环境配置

### logic 主题示例结构
- 初始化流程/调用链
- 分支逻辑路径
- 函数签名与行为
- 联动规则（Given/When/Then 思维）

### ui 主题示例结构
- 组件树结构
- 渲染条件/显示逻辑
- 公共组件 Props 使用方式

### pitfalls 主题示例结构
- 易错点描述 + 正确做法
- 跨模块隐式依赖
- 已知约束/限制
