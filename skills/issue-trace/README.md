# issue-trace

> CodeBuddy skill：问题深度根因定位与调用链追溯助手（纯分析场景）

## 它做什么

从用户描述的问题表象出发，沿代码逻辑 / 数据流 / 依赖链反向追溯**真实根因**，输出：

- 根因定论 + 证据链（文件 + 行号 + 来源标签）
- 必要时附跨项目调用链可视化
- 治本 / 治标双修复建议（不自动进入修复，由你决定下一步）

与其他 skill 边界：

| skill | 入口 | 本 skill 区别 |
|-------|------|--------------|
| `dev-flow` | 已决定要修，进入研究→方案→编码 | 本 skill 只分析，不自动进入修复 |
| `bugfix-skill` | 任务平台 bug 修复流程 | 本 skill 不绑定 任务平台 |

## 安装

### 方式 A：从Git 平台 clone（推荐）

```bash
git clone <your-repo-url>
cd codebuddy-skill-issue-trace
bash install.sh
```

### 方式 B：从 ZIP 安装

```bash
unzip issue-trace.zip -d /tmp/
cd /tmp/issue-trace
bash install.sh
```

安装脚本会：

1. 备份你已有的 `~/.codebuddy/skills/issue-trace/`（如有）到 `~/.codebuddy/.backup/<日期>/`
2. 用 `rsync --delete` 复制到 `~/.codebuddy/skills/issue-trace/`（自动排除 `install.sh` / `README.md` 等分发文件）
3. 给 `scripts/*.sh` 加可执行权限
4. 校验 `SKILL.md` 是否落盘

**安装路径写死**：仅支持安装到 `~/.codebuddy/skills/issue-trace/`，CodeBuddy 只识别此路径。

## 使用

重启 CodeBuddy 后，有两种方式触发本 skill：

### 方式 A：命令行调用（推荐，无歧义）

| 命令 | 快捷 | 说明 |
|------|------|------|
| `trace` | `t` | 完整 5 步分析流程 |
| `trace --quick` | `t -q` | 轻量模式：直接给结论，跳过物理门控 |
| `trace --chain` | `t -c` | 链路模式：侧重跨项目调用链追溯 |
| `trace --suspects` | `t -s` | 仅输出嫌疑点列表，暂不深入追溯 |

**示例**：

```
trace 为什么 Avatar 组件在中文环境下显示英文
t -c list-component 的 ShareModal 调用链怎么走的
t -s 详情页偶现白屏
t -q 这个 undefined 从哪来
```

### 方式 B：自然语言触发

向 AI 用自然语言描述问题，命中以下任一关键词即自动触发：

- 「帮我深挖一下 XXX 为什么会这样」
- 「trace 一下这个调用链」
- 「整个链路是什么」
- 「这个值从哪来 / 这个参数为什么是这个值」
- 「排查根因 / 定位根因 / 追溯」

完整触发关键词列表见 `SKILL.md` § 触发规则。

## 卸载

```bash
bash uninstall.sh
```

会先备份当前版本到 `~/.codebuddy/.backup/<日期>/issue-trace.uninstall.<时间>/`，再删除。

## 升级

直接重跑 `install.sh` 即可（脚本幂等，自动备份旧版）：

```bash
git pull
bash install.sh
```

## 打包前自检（维护者用）

如果你 fork 后做了二次开发，提交前请跑一次自检：

```bash
bash preflight.sh
```

会检查：
- 必需文件完整性（`SKILL.md` / `_meta.json` / `install.sh` 等）
- 绝对路径污染（`/Users/<name>` 硬编码）
- 脚本可执行权限
- `_meta.json` JSON 格式合法性

存在 ❌ 错误 → 退出码 1，禁止打包；存在 ⚠️ 警告 → 退出码 0，可分发但建议修复。

## 已知说明

`SKILL.md` 中含示例路径（用于演示「跨项目分析 reflex 三步法」中的 `ls` 命令），使用时请替换为你自己的项目路径，不影响 skill 运行。

## 反馈

issue 提到 <your-repo>/issues

## 版本

当前版本见 `_meta.json` 的 `version` 字段；变更历史见仓库 commit log。
