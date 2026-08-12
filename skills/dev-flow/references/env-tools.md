# 环境与工具配置

1. **遇到不确定问题使用内部文档**：如网络代理、测试环境配置等内部工具相关问题。禁止猜测或凭记忆回答。
2. **打开文件目录**：直接告知用户文件路径和行号，让用户在编辑器中手动导航。禁止使用 VSCode 命令。
3. **项目创建路径**：一律在工作空间根目录下。

---

## Git Worktrees 参考

> 原 `references/git-worktrees.md`，已合并至此。默认关闭，按需启用。

**适用场景**：多任务并行开发、不同分支同时运行开发服务器、长期功能分支期间临时修复其他分支 bug。

**常用命令**：

```bash

# 基于已有分支创建
git worktree add ../feature-a-worktree feature/feature-a

# 创建新分支并关联
git worktree add -b feature/new ../new-worktree

# 查看所有 worktree
git worktree list

# 删除 worktree
git worktree remove ../feature-a-worktree

```

**注意事项**：

1. 同一分支不能同时存在于多个 worktree
2. 每个 worktree 需独立安装 node_modules
3. IDE 需单独打开每个 worktree
4. 步骤 4.5 检测到 worktree 时，确认当前 worktree 对应分支是否正确
