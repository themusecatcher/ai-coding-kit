# dist 同步提醒

> 在对话中修改 dev-flow 依赖 Skill 或规则文件后，提醒用户同步到 `dist/` 目录。

---

## 触发条件

本规则**全局生效**（不依赖 dev-flow 加载）。当 AI 在对话中执行了以下操作时触发：

- 通过 `write_to_file` / `replace_in_file` / 终端命令修改了 `~/.codebuddy/skills/<name>/` 下的任意依赖 Skill 文件
- 修改了 `~/.codebuddy/rules/AI行为规范.mdc` 或 `~/.codebuddy/rules/开发规范-红线.mdc`
- 修改了 `~/.codebuddy/agents/` 下的任意 Agent 文件

## 依赖清单（权威源：`package.sh` 脚本变量）

根据 `skills/dev-flow/dist/package.sh`，需同步的组件：

### 核心依赖（7 个）

`requirement-intake`, `knowledge-loop`, `design-advisor`, `code-review`, `tech-doc`, `verification-pipeline`, `smart-commit`

### 强化依赖（4 个）

`coding-standards`, `frontend-patterns`, `self-improving-agent`, `browser-compat`

### 可选依赖（3 个）

`i18n`, `dom-animation`, `browser-toolkit`

### 规则文件（2 个）

`AI行为规范.mdc`, `开发规范-红线.mdc`

### Agent 文件（10 个）

`1号.md`, `2 号.md`, `3 号.md`, `4 号.md`, `5 号.md`, `6 号.md`, `7 号.md`, `8 号.md`, `9 号.md`, `step-gate.md`

## 行为

修改以上任意文件后，在当轮回复末尾追加提醒：

> 💡 检测到 dev-flow 依赖组件变更（{组件名}），是否执行 `bash package.sh` 同步到 `skills/dev-flow/dist/`？

- 仅提醒，不自动执行
- 同一轮对话中多次修改同一组件时，仅提醒一次
- 用户要求同步后，执行 `cd ~/.codebuddy/skills/dev-flow/dist && bash package.sh`
