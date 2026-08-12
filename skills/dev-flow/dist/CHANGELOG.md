# Changelog

本文件记录 dev-flow 分发包的所有版本变更。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

---

## [1.3.0] - 2026-08-11

### Changed

- 🎚️ **安装级别精简为「默认 / `--all-repo`」两档**：默认安装（无参数）= `dev-flow` + 全部 14 依赖（共 15 个 Skill）+ 规则 + Agents；`--all-repo` 为整仓全量（仓库根 `skills/` 下所有 skill，含独立 skill）。规则随安装默认装（已存在不覆盖）
- ⚙️ **`--global` 改为兼容 no-op**：安装本就是全局，`--global` 保留兼容（加不加都装到 `~/.codebuddy/`），不再强制
- 🌐 `remote-install.sh` 同步精简：移除 `--core` / `--full` / `--with-rules` 透传，仅保留 `--all-repo`

### Removed

- 🗑️ **移除 `--core`**：精简到「核心断点」这一档实用价值低（缺强化依赖会降级），默认即全装
- 🗑️ **移除 `--full`**：其内容（全部 14 依赖）已成为默认安装
- 🗑️ **移除 `--with-rules`**：规则改为默认安装，无需单独开关

### Notes

- ⚠️ **破坏性变更**：`--core` / `--full` / `--with-rules` 已删除，传入将报「未知参数」。请改用 `bash install.sh`（默认全装）或 `bash install.sh --all-repo`（整仓全量）
