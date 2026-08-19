# 发布流程规范（release-flow）

> 本文件是「验收完成 → 合入 main → 构建发布 → 发布后清理」的**单一权威规范源**。阶段 5 验收收尾完成、用户确认提交后按需加载。
> 背景：dev-comp 此前只有「阶段 1 建 feat 分支」和「阶段 5 提交到 feat 分支」两端规范，**合入 main → 发布链路完全缺失**，导致 AutoComplete 组件验收完成后长期停留在 feat 分支（领先 main 8 个提交），npm 版本（2.4.27）与源码脱节。本文件补齐整条发布链路。
> ⚠️ 发布链路涉及 `git push` / `npm publish` 等不可逆操作，**每一步命令执行前必须用户明确确认**。

---

## 0. 红线（最高优先级）

1. **❌ 严禁 AI 擅自执行 `git push` / `npm publish` / 删除分支**：本链路所有命令由 AI 生成并逐条呈现，**用户明确确认一条执行一条**；`pnpm pub` / `pnpm docs:deploy` 内含 commit+push，同样必须经用户确认
2. **❌ 严禁在 feat 分支上执行发布**：`publish.sh` 不检查当前分支，在 feat 分支上跑会把发布 commit 推到 feat 分支（npm 发布了但 main 没有代码）。发布前必须 `git branch --show-current` 确认在 `main`
3. **✅ 发布前置全部就绪**：Gate 5 验收通过 + 发布前配置项终检全勾销 + changelog/version 已按 `changelog-spec.md` 改好（新增组件 → minor+1 patch 归 0）+ commit 已按 smart-commit 确认提交到 feat 分支

## 1. 合入 main（GitHub PR 方式）

> 与项目 `CONTRIBUTING.md` 一致：通过 GitHub Pull Request 合入，不本地 merge。

1. **推送 feat 分支**：`git push origin feat/{组件名}`（用户确认后执行）
2. **创建 PR**：打开 `https://github.com/themusecatcher/vue-amazing-ui/compare/main...feat/{组件名}`（或 `gh pr create --base main --head feat/{组件名}`，gh 已登录时），PR 标题用 `feat: 新增 {组件名} 组件`，描述附 Gate 5 报告摘要
3. **合入 PR**：等待 CI 通过 → 用户确认后合入（Squash 或 Create a merge commit 均可，项目无强制约定）
4. **本地同步 main**：`git checkout main` → `git pull`

## 2. main 上构建发布

> 前置：已切到 main 且 `git pull` 到最新。发布前最后一道确认。

1. **发布前最终确认清单**（逐项确认后执行）：
   - `git branch --show-current` 输出 `main` ✅
   - `jq -r .version package.json` 与 changelog 顶部版本号一致 ✅
   - 升级幅度与发布内容匹配（`changelog-spec.md` §4）✅
   - npm 登录状态有效（`npm whoami` 非空）
2. **执行发布**：`pnpm pub "feat: 发布 {X.Y.Z} 版本"`（用户明确确认后执行）
   - 脚本链路：`check`（lint+type-check）→ `build` → commit+push 当前待提交更改 → `npm publish` → `pnpm up vue-amazing-ui@版本` → commit `feat: update 版本` + push → `docs:deploy`（构建文档站 + 推 gh-pages + commit+push）
   - ⚠️ 脚本内嵌 git 操作，执行前向用户说明完整链路再等确认
3. **发布验证**：
   - `npm view vue-amazing-ui version` 返回新版本号
   - 文档站更新：`https://themusecatcher.github.io/vue-amazing-ui/` 可见新组件

## 3. 发布后清理

1. **删除 feat 分支（本地 + 远程）**（用户确认后执行）：
   - 本地：`git branch -d feat/{组件名}`
   - 远程：`git push origin --delete feat/{组件名}`
2. **工作上下文收尾**：更新 `~/.codebuddy/dev-comp/working-context/vaui-{组件名}-*.md` 的 status → `released`，补记发布版本号与日期，可归档
3. **知识沉淀补记**：knowledge-loop 沉淀中补记本次发布的版本号与 changelog 位置（若有此环节）

## 4. 自检命令速查

```bash
git branch --show-current                       # 发布前必须输出 main
git --no-pager log --oneline main..feat/{组件名}  # 合入前确认 feat 领先内容
jq -r .version package.json                     # 与 changelog 顶部版本号对照
npm view vue-amazing-ui version                 # 发布后验证 npm 已更新
git branch -a | grep {组件名}                   # 清理后确认分支已删
```

---

## 反模式清单（历史踩坑）

| 反模式 | 正确做法 |
|--------|---------|
| 验收完成即认为任务结束，不推进发布（AutoComplete 停 8 个提交在 feat） | 阶段 5 完成后引导本流程，工作上下文记接续指引 |
| 在 feat 分支上跑 `pnpm pub` | 发布前 `git branch --show-current` 确认在 main |
| AI 未确认即执行 push/publish/删分支 | 逐条命令呈现，用户确认一条执行一条 |
| 发布后残留 feat 分支 | 本地 + 远程双删除，grep 确认无残留 |
| version 只改 package.json 或只改 changelog | 双处同步（`changelog-spec.md` §2），发布前 jq 对照 |
