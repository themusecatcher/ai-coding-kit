# artifacts 历史归档读取区

> 状态：**历史归档存放处**（2026-08-21 起不再接收新产物）。

## 说明

- 本目录曾用于存放 dev-comp 组件的私有开发产物（工作上下文 / metrics / devlog / knowledge）快照，结构为 `{组件名}-{日期}/{working-context|metrics|devlog|knowledge}/`
- **2026-08-21 规范修订**：产物**统一归档在 `~/.codebuddy/` 运行时目录**（原位即归档，不搬移、不产生副本）；阶段 5 收尾**不再弹归档决策**，改为在 Gate 5 报告中告知产物位置。本目录**不再接收新产物**，仅保留为**历史归档的读取兜底**
- 私有产物不随仓库发布：本目录内容已被 skill 自带 `skills/dev-comp/.gitignore` 忽略（仅 `README.md` 保留跟踪）；分发 skill 时须连同该 `.gitignore` 一起复制

## 接续机制

按 `SKILL.md` §产物存储设计原则 第 6 条，阶段 0 接续扫描顺序：`~/.codebuddy/dev-comp/working-context/` 优先 → 本目录（`ARTIFACTS_FALLBACK_DIR`）兜底。命中历史归档时复制回运行时目录恢复活跃状态。
