# artifacts 临时产物归档区

> 状态：**临时存放**，非长期归档位置。

## 说明

- 本目录存放 dev-comp 组件的私有开发产物（工作上下文 / metrics / devlog / knowledge）快照，结构为 `{组件名}-{日期}/{working-context|metrics|devlog|knowledge}/`
- 产物**默认应留在 `~/.codebuddy/` 运行时目录**（原位即归档）；本目录仅作为用户显式选择的临时归档位置
- **后续将由用户移动到指定位置**，请勿依赖此路径作长期存储
- 私有产物不随仓库发布：本目录内容已被 skill 自带 `skills/dev-comp/.gitignore` 忽略（仅 `README.md` 保留跟踪），归档产物不会进入 git；分发 skill 时须连同该 `.gitignore` 一起复制

## 接续机制

按 SKILL.md 第 6 条，扫描顺序：`~/.codebuddy/dev-comp/working-context/` 优先 → 本目录（`ARTIFACTS_FALLBACK_DIR`）兜底。
