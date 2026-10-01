import{_ as n,o as a,c as p,a2 as e}from"./chunks/framework.BUwdTBzS.js";const k=JSON.parse('{"title":"文档同步入口（dev:sync）","description":"","frontmatter":{"title":"文档同步入口（`dev:sync`）"},"headers":[],"relativePath":"dev-flow/references/in-flow-sync.md","filePath":"dev-flow/references/in-flow-sync.md","lastUpdated":null}'),l={name:"dev-flow/references/in-flow-sync.md"};function i(t,s,c,o,d,r){return a(),p("div",null,[...s[0]||(s[0]=[e(`<blockquote><p>📄 本页由源文件 <code>skills/dev-flow/references/in-flow-sync.md</code> 自动投影生成（单一权威源）。请勿直接编辑本页。</p></blockquote><h1 id="文档同步入口-dev-sync" tabindex="-1">文档同步入口（<code>dev:sync</code>） <a class="header-anchor" href="#文档同步入口-dev-sync" aria-label="Permalink to &quot;文档同步入口（\`dev:sync\`）&quot;">​</a></h1><blockquote><p>本文件定义 <code>dev:sync</code> / <code>dev:s2</code> 命令的全量文档同步流程，支持<strong>流程内模式</strong>（<code>.flow</code> 存在）和<strong>独立模式</strong>（工作上下文匹配）。 复用 <code>closeout-flow.md §H.0~H.3+</code> 的现有环节（caller=in-flow-sync），零新增同步逻辑。</p></blockquote><h2 id="零、设计哲学-必读" tabindex="-1">零、设计哲学（必读） <a class="header-anchor" href="#零、设计哲学-必读" aria-label="Permalink to &quot;零、设计哲学（必读）&quot;">​</a></h2><blockquote><p>⚠️ <strong>dev:sync 是补救机制，不是 5.5b 的替代品</strong>。详细规则见 <code>~/.codebuddy/rules/AI行为规范.mdc</code> §「主动文档同步弹框提醒」。 简单记：<strong>5.5b 是日常必做</strong>（freshness-lint 物理硬阻断），<strong>dev:sync 是累计静默 ≥3 次后的兜底</strong>。禁止以&quot;dev:sync 会兜底&quot;为由跳过 5.5b。</p></blockquote><h2 id="一、触发条件" tabindex="-1">一、触发条件 <a class="header-anchor" href="#一、触发条件" aria-label="Permalink to &quot;一、触发条件&quot;">​</a></h2><h3 id="_1-1-用户主动召唤" tabindex="-1">1.1 用户主动召唤 <a class="header-anchor" href="#_1-1-用户主动召唤" aria-label="Permalink to &quot;1.1 用户主动召唤&quot;">​</a></h3><table tabindex="0"><thead><tr><th>输入</th><th>行为</th></tr></thead><tbody><tr><td><code>dev:sync</code> / <code>dev:s2</code></td><td>标准触发</td></tr><tr><td>&quot;同步文档&quot; / &quot;全量同步&quot; / &quot;检查文档&quot; / &quot;更新文档&quot;</td><td>关键词触发</td></tr></tbody></table><blockquote><p>高级修饰符 <code>--docs={list}</code> 暂不在 MVP 范围，详见附录·未来增强。</p></blockquote><h3 id="_1-2-ai-主动弹框-必须使用-ask-followup-question" tabindex="-1">1.2 AI 主动弹框（必须使用 <code>ask_followup_question</code>） <a class="header-anchor" href="#_1-2-ai-主动弹框-必须使用-ask-followup-question" aria-label="Permalink to &quot;1.2 AI 主动弹框（必须使用 \`ask_followup_question\`）&quot;">​</a></h3><blockquote><p>🔴 <strong>强制规则</strong>：以下 2 个场景必须主动弹框提醒用户，不得静默推进。</p></blockquote><table tabindex="0"><thead><tr><th>触发场景</th><th>触发条件</th><th>默认推荐项</th></tr></thead><tbody><tr><td><strong>场景 A：5.5 静默累计 ≥3 次</strong></td><td>step-5 内部多轮修复 + 迭代修复 5.5 静默执行<strong>累计</strong> ≥3 次（统一计数器，post-step.sh 物理层兜底维护）</td><td>✅ 立即同步</td></tr><tr><td><strong>场景 B：完整模式跨步骤真空期 追加改动</strong></td><td><code>caller=full-7</code> 完成后到步骤 10 之间，步骤 8/9/10 入口 git diff 快照对比发现新增改动</td><td>✅ 立即同步</td></tr></tbody></table><blockquote><p>ℹ️ 原 v1「每轮迭代修复完成必弹」已删除——迭代修复每轮结束本身会走完整步骤 7（含 H 全套），属于伪盲区。 ℹ️ 步骤 10 入口仍触发——这是事前同步的最后机会，10.3.5 H.3+ 是事后兜底而非替代。</p></blockquote><p><strong>统一静默计数器规则（物理层兜底）</strong>：</p><ul><li>计数器位置：<code>.flow</code> 文件 <code>silent_55_count</code> 字段（无则视为 0）</li><li>自增执行者：<strong><code>scripts/hooks/post-step.sh</code></strong>——AI 层为辅，物理层为主</li><li>自增判定：post-step.sh 收到 <code>STEP_ID=5.5</code> 时，若 <code>validate-output.sh</code> 未生成 <code>.step-5_5.validated.json</code> （说明走的是 iteration-fix §四 / step-5-execute §2.5 静默路径），则 silent_55_count += 1</li><li>重置时机：① 用户接受 dev:sync 提醒并完成同步 → 归零；② 流程进入步骤 7 H 环节 → 归零；③ 用户点&quot;❌ 永久跳过本流程&quot; → 不归零但不再弹</li></ul><p><strong>弹框模板</strong>（参照 <code>step-router.md</code> §「交互式决策强制规则」）：</p><div class="language-text vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">text</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>【dev:sync 提醒】检测到 {触发场景描述}，建议同步以下文档：</span></span>
<span class="line"><span></span></span>
<span class="line"><span>📄 技术方案文档 — 兜底对账（{docid} 存在）</span></span>
<span class="line"><span>📝 工作上下文 — 一致性校验</span></span>
<span class="line"><span>📋 devlog — 增量追加 Sync-{N} 段</span></span>
<span class="line"><span>📊 plan.md — 增量追加（CR 非空即触发检查）</span></span>
<span class="line"><span>📂 artifacts — 路径完整性校验（遍历所有非 null 路径确认文件存在）</span></span>
<span class="line"><span>🧠 knowledge — 漂移检测</span></span>
<span class="line"><span></span></span>
<span class="line"><span>是否立即同步？</span></span></code></pre></div><table tabindex="0"><thead><tr><th>选项</th><th>说明</th></tr></thead><tbody><tr><td>✅ 立即同步全部文档</td><td>执行 <code>dev:sync</code> 完整流程</td></tr><tr><td>✏️ 选择性同步</td><td>用户逐条勾选要同步的文档</td></tr><tr><td>⏭️ 跳过本次，由步骤 7/10 兜底</td><td>标记已提醒，计数器不归零（下次到 3 仍弹）</td></tr><tr><td>❌ 永久跳过本流程</td><td>工作上下文 YAML 头部写入 <code>sync_reminder_disabled: true</code>（仅对当前工作上下文 YAML 生效；迭代修复 N+1 / 批次切换 batch_next 仍属同需求继续生效；新需求自动重置）</td></tr></tbody></table><h2 id="二、工具门禁声明" tabindex="-1">二、工具门禁声明 <a class="header-anchor" href="#二、工具门禁声明" aria-label="Permalink to &quot;二、工具门禁声明&quot;">​</a></h2><blockquote><p><code>caller=in-flow-sync</code> 期间<strong>复用 <code>gates.yaml tool_gates.phases.step_5_plus</code></strong> 的全工具集，无需新增 phase 配置。 实证依据：<code>gates.yaml</code> L559~L563 <code>step_5_plus: allowed=[read_only, write_code, execute, interact, mcp_read, mcp_write], blocked=[]</code>， 恰好覆盖 dev:sync 所需的 git/read/write/MCP 全部能力。</p></blockquote><h2 id="三、执行流程" tabindex="-1">三、执行流程 <a class="header-anchor" href="#三、执行流程" aria-label="Permalink to &quot;三、执行流程&quot;">​</a></h2><h3 id="_4-1-标准执行-用户输入-dev-sync" tabindex="-1">4.1 标准执行（用户输入 <code>dev:sync</code>） <a class="header-anchor" href="#_4-1-标准执行-用户输入-dev-sync" aria-label="Permalink to &quot;4.1 标准执行（用户输入 \`dev:sync\`）&quot;">​</a></h3><div class="language-text vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">text</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span></span></span>
<span class="line"><span>1. 读取 .flow 文件 → 取 current_step 暂存到 sync_from_step 字段</span></span>
<span class="line"><span>├─ .flow 存在 → 继续（流程内模式）</span></span>
<span class="line"><span>└─ .flow 不存在 → 扫描 working-context 匹配（项目路径+分支名）</span></span>
<span class="line"><span>     ├─ 匹配到 → 继续（独立模式，跳过暂存/恢复 .flow 操作）</span></span>
<span class="line"><span>     └─ 未匹配到 → 终止：&quot;未找到关联工作上下文，请先创建&quot;</span></span>
<span class="line"><span></span></span>
<span class="line"><span>2. 检查 工作上下文 YAML 头部 sync_reminder_disabled:</span></span>
<span class="line"><span>- true → 仅在用户主动输入 dev:sync 时执行；AI 主动场景 A/B 静默跳过</span></span>
<span class="line"><span>- false/缺省 → 正常执行</span></span>
<span class="line"><span></span></span>
<span class="line"><span>3. 写 .flow 暂存状态（仅 .flow 存在时执行）：</span></span>
<span class="line"><span>- status: paused_for_sync</span></span>
<span class="line"><span>- sync_from_step: {原步骤号}</span></span>
<span class="line"><span>- sync_started_at: {ISO 8601}</span></span>
<span class="line"><span>- sync_base_sha: $(git rev-parse HEAD)   ← 用于后续增量去重</span></span>
<span class="line"><span></span></span>
<span class="line"><span>### 4.0 文档就绪检查</span></span>
<span class="line"><span></span></span>
<span class="line"><span>就绪检查（仅依赖文件存在性，不依赖流程状态）：</span></span>
<span class="line"><span></span></span>
<span class="line"><span>| 文档 | 检查方式 | 不存在时的处理 |</span></span>
<span class="line"><span>|------|---------|--------------|</span></span>
<span class="line"><span>| 工作上下文 | Phase 0 已保证存在 | （不会到这里） |</span></span>
<span class="line"><span>| 文档平台 | \`docid\` 或 \`file_path\` 非空 + 文档可读取 | ⏸️ 跳过，原因：&quot;未关联 技术方案文档&quot; |</span></span>
<span class="line"><span>| devlog | \`artifacts.devlog\` 路径文件存在 | ⏸️ 跳过，原因：&quot;尚未生成（预期步骤 7 创建）&quot; |</span></span>
<span class="line"><span>| plan.md | \`artifacts.plan\` 路径文件存在 | ⏸️ 跳过，原因：&quot;尚未生成（预期步骤 4 创建）&quot; |</span></span>
<span class="line"><span>| report.yaml | \`artifacts.dir\` + \`report.yaml\` 存在 | ⏸️ 跳过，原因：&quot;度量采集尚未执行（预期步骤 7/9）&quot; |</span></span>
<span class="line"><span></span></span>
<span class="line"><span>**规则**：</span></span>
<span class="line"><span>- 未就绪文档标记 \`⏸️ 未就绪\` + 原因，不报错，不中断</span></span>
<span class="line"><span>- 已就绪文档正常进入 Phase 2 同步管道</span></span>
<span class="line"><span>- 就绪检查结果汇总到 Phase 4 报告</span></span>
<span class="line"><span></span></span>
<span class="line"><span>4. 加载 closeout-flow.md，以 caller=in-flow-sync 身份执行：</span></span>
<span class="line"><span></span></span>
<span class="line"><span>&gt; 🔴 **强制规则 #S1**：步骤 4 的第一个 tool call 必须是 \`read_file(&quot;references/closeout-flow.md&quot;)\`。</span></span>
<span class="line"><span>&gt; AI 必须加载该文件后才能执行 H.3 knowledge 漂移检测和 I 度量采集，</span></span>
<span class="line"><span>&gt; 禁止凭记忆手动拼装步骤。违反此规则视为 dev:sync 未完成。</span></span>
<span class="line"><span></span></span>
<span class="line"><span>✅ H.0 CR 同步与登记</span></span>
<span class="line"><span>（复用 drift-handling §步骤 3.5 的 CR 创建逻辑：扫描 git diff，</span></span>
<span class="line"><span>对未登记的改动自动创建 CR-N，状态 in_progress；</span></span>
<span class="line"><span>对已存在 in_progress 的 CR 检测命中即标记 done + 填 resolution）</span></span>
<span class="line"><span>✅ H.2 devlog 增量追加（按 sync 触发场景写入&quot;#### Sync-{N}：{触发场景} - {时间}&quot;小节）</span></span>
<span class="line"><span>✅ H.3 knowledge 漂移检测（grep 反查 + 命中模块变更历史追加）</span></span>
<span class="line"><span></span></span>
<span class="line"><span>&gt; 🔴 **强制规则 #S2**：H.3 执行前必须先 \`grep -rl &quot;&lt;核心符号&gt;&quot; ~/.codebuddy/knowledge/\` 反查命中条目，</span></span>
<span class="line"><span>&gt; 然后逐条读取、逐条比对、逐条增量更新。禁止跳过 grep 反查直接凭记忆追加。</span></span>
<span class="line"><span></span></span>
<span class="line"><span>✅ H.3+ 文档平台 兜底对账（docid 非空时执行三方对账）</span></span>
<span class="line"><span>✅ plan.md 增量追加（CR 非空即触发检查，与 文档平台 对账逻辑一致；CR 不影响计划内容时输出 unchanged）</span></span>
<span class="line"><span>✅ artifacts 路径完整性校验（遍历 artifacts 中所有非 null 路径，确认文件存在；</span></span>
<span class="line"><span>失效路径标注 ⚠️ 并提示手动修复或自动更新）  ← 本环节是预防&quot;猜目录名找不到文件&quot;的物理防线</span></span>
<span class="line"><span>✅ 工作上下文一致性校验（validate-working-context.sh）</span></span>
<span class="line"><span></span></span>
<span class="line"><span>❌ 跳过 H.1 commit（仍由步骤 7 生成）</span></span>
<span class="line"><span>❌ 跳过 G L2/L3 审查（重审太重）</span></span>
<span class="line"><span>❌ 跳过 J 经验快检</span></span>
<span class="line"><span>❌ 跳过 K dev-logs 完整性自检</span></span>
<span class="line"><span>理由：dev-logs 完整性必须等 commit 完成后才有意义，</span></span>
<span class="line"><span>dev:sync 不生成 commit（commit 由步骤 7 H.1 生成），故 K 环节无运行前提</span></span>
<span class="line"><span></span></span>
<span class="line"><span>🔄 步骤 4a：I 度量采集（按流程状态分情况处理）</span></span>
<span class="line"><span></span></span>
<span class="line"><span>| 条件 | 行为 | 理由 |</span></span>
<span class="line"><span>|------|:---:|------|</span></span>
<span class="line"><span>| \`.flow\` 存在 + \`current_step\` 非 \`done/completed\` | ❌ 跳过 | 后续步骤 7/9 会执行完整度量采集 |</span></span>
<span class="line"><span>| \`.flow\` 不存在 + 工作上下文 \`status: completed/done/testing/delivered\` | ✅ 必须执行 | 流程已结束，不会再触发步骤 7/9，度量数据需由本轮 sync 更新 |</span></span>
<span class="line"><span>| \`.flow\` 不存在 + \`report.yaml\` 存在 + 代码有增量变更 | ✅ 增量刷新 | report.yaml 已存在但数据过时（如 complete_date / corrections / changes 字段），仅刷新变更字段，不重建全量 |</span></span>
<span class="line"><span>| \`.flow\` 存在但其他条件不明确 | ❌ 跳出决策，不得擅自决定，提示用户确认 |</span></span>
<span class="line"><span>| \`report.yaml\` 不存在 | ⏸️ 跳过 | 度量从未生成，通常因流程未走到步骤 7，标记待关注 |</span></span>
<span class="line"><span></span></span>
<span class="line"><span>**增量刷新执行清单**（仅刷新变更字段，不重建全量）：</span></span>
<span class="line"><span>1. 读取现有 \`report.yaml\`</span></span>
<span class="line"><span>2. 更新 \`complete_date\` 为当前日期</span></span>
<span class="line"><span>3. 用 \`git diff master --stat\` 刷新 \`changes\` 字段（files_changed / insertions / deletions）</span></span>
<span class="line"><span>4. 更新 \`iterations.total\` 和 \`corrections\`（从工作上下文 CR 列表统计）</span></span>
<span class="line"><span>5. 更新 \`knowledge.pitfalls_recorded\`（\`grep -c &quot;^## &quot; knowledge条目.md\`）</span></span>
<span class="line"><span>6. 写入 \`report.yaml\`（保持文件尾部空行）</span></span>
<span class="line"><span></span></span>
<span class="line"><span>&gt; 📌 \`report.yaml\` 的完整 schema 与标准化采集流程（步骤 7-I 详细清单）→ \`closeout-flow.md\` §环节 I</span></span>
<span class="line"><span></span></span>
<span class="line"><span>5. 弹出最终用户决策（强制 ask_followup_question）：</span></span>
<span class="line"><span>| 选项 | 说明 |</span></span>
<span class="line"><span>| --- | --- |</span></span>
<span class="line"><span>| ✅ 全部应用变更 | AI 通过 MCP 直接更新 文档平台 + 写入所有文档 |</span></span>
<span class="line"><span>| ✏️ 逐项确认 | 用户逐条决定哪些变更应用 |</span></span>
<span class="line"><span>| ⏭️ 仅生成报告 | AI 输出对账报告，用户手动同步 |</span></span>
<span class="line"><span>| 🔁 取消同步 | 不应用任何变更，恢复原步骤 |</span></span>
<span class="line"><span></span></span>
<span class="line"><span>### Phase 3：🔐 物理写入校验</span></span>
<span class="line"><span></span></span>
<span class="line"><span>&gt; 复用 \`scripts/lints/doc-sync-lint.sh\`（micro-fix-doc-sync-lint.sh 重构版）。</span></span>
<span class="line"><span>&gt; 物理事实校验，不依赖 AI 的完成声明。</span></span>
<span class="line"><span></span></span>
<span class="line"><span>执行：\`bash ~/.codebuddy/skills/dev-flow/scripts/lints/doc-sync-lint.sh &lt;flow-name&gt; --mode sync\`</span></span>
<span class="line"><span></span></span>
<span class="line"><span>**校验项**（7 项，缺一即 🔴 阻断）：</span></span>
<span class="line"><span></span></span>
<span class="line"><span>| # | 校验项 | 检查方式 | 覆盖环节 |</span></span>
<span class="line"><span>|:---:|---|------|:---:|</span></span>
<span class="line"><span>| 1 | devlog.md 写入 | 文件存在 + mtime 为今天 | H.2 |</span></span>
<span class="line"><span>| 2 | plan.md CR 同步 | done 的 CR ID 是否出现在 plan.md 中 | plan.md |</span></span>
<span class="line"><span>| 3 | CR 登记完整性 | in_progress CR 数 ≤ plan.md 中 CR 行数 | H.0 |</span></span>
<span class="line"><span>| 4 | knowledge 漂移 | 相关 knowledge 文件 mtime 为今天 | H.3 |</span></span>
<span class="line"><span>| 5 | 文档平台 同步 | 工作上下文 \`last_synced_at\` 为今天 | H.3+ |</span></span>
<span class="line"><span>| 6 | artifacts 路径 | 所有非 null 路径（plan/devlog/report.yaml）存在 | artifacts |</span></span>
<span class="line"><span>| 7 | 度量采集 | report.yaml \`complete_date\` 为今天（仅流程已完成时） | I |</span></span>
<span class="line"><span></span></span>
<span class="line"><span>失败 → 🔴 阻断，回退到 Phase 2 补执行遗漏项。</span></span>
<span class="line"><span></span></span>
<span class="line"><span>### Phase 4：输出同步报告</span></span>
<span class="line"><span></span></span>
<span class="line"><span>&gt; 每次 dev:sync 执行完毕后必须输出此报告，禁止省略。</span></span>
<span class="line"><span></span></span>
<span class="line"><span>\`\`\`markdown</span></span>
<span class="line"><span>## 📋 文档同步报告</span></span>
<span class="line"><span></span></span>
<span class="line"><span>&gt; 执行时间：{ISO 8601} | 模式：{流程内 / 独立} | 来源：{from-drift / standalone / ai-reminder}</span></span>
<span class="line"><span></span></span>
<span class="line"><span>### 同步结果</span></span>
<span class="line"><span></span></span>
<span class="line"><span>| 文档 | 状态 | 说明 |</span></span>
<span class="line"><span>|------|:---:|------|</span></span>
<span class="line"><span>| 📄 工作上下文 | {✅/⏸️} | {具体变更摘要，或跳过原因} |</span></span>
<span class="line"><span>| 🌐 技术方案文档 | {✅/⏸️} | {章节变更摘要，或跳过原因} |</span></span>
<span class="line"><span>| 📝 devlog | {✅/⏸️} | {追加段落摘要，或跳过原因} |</span></span>
<span class="line"><span>| 📊 plan.md | {✅/⏸️} | {增量变更，或跳过原因} |</span></span>
<span class="line"><span>| 📈 report.yaml | {✅/⏸️} | {计数器变更，或跳过原因} |</span></span>
<span class="line"><span>| 🧠 knowledge | {✅/⏸️} | {漂移检测结果，或跳过原因} |</span></span>
<span class="line"><span>| 📂 artifacts | {✅/⚠️} | {路径校验结果} |</span></span>
<span class="line"><span></span></span>
<span class="line"><span>### 🔐 门控校验</span></span>
<span class="line"><span></span></span>
<span class="line"><span>| 检查项 | 结果 |</span></span>
<span class="line"><span>|--------|:---:|</span></span>
<span class="line"><span>| devlog.md 已写入 | {✅/🔴} |</span></span>
<span class="line"><span>| plan.md CR 已同步 | {✅/🔴} |</span></span>
<span class="line"><span>| CR 已登记 | {✅/🔴} |</span></span>
<span class="line"><span></span></span>
<span class="line"><span>### 未就绪文档（如有）</span></span>
<span class="line"><span></span></span>
<span class="line"><span>| 文档 | 跳过原因 |</span></span>
<span class="line"><span>|------|---------|</span></span>
<span class="line"><span>| {文档} | {原因} |</span></span>
<span class="line"><span>\`\`\`</span></span>
<span class="line"><span></span></span>
<span class="line"><span>6. 恢复 .flow（仅 .flow 存在时执行）：</span></span>
<span class="line"><span>- current_step: {原步骤号}（从 sync_from_step 还原）</span></span>
<span class="line"><span>- status: active</span></span>
<span class="line"><span>- 写 last_sync_diff_sha: $(git rev-parse HEAD)   ← 供下次增量对比 / 场景 B 检测</span></span>
<span class="line"><span>- silent_55_count: 0                              ← 重置计数器</span></span>
<span class="line"><span>- 删除 sync_from_step、sync_started_at、sync_base_sha 字段</span></span>
<span class="line"><span></span></span>
<span class="line"><span>7. 更新 sync_history（仅 .flow 存在时写入；独立模式下仅输出到报告）：</span></span>
<span class="line"><span>- sync_history 追加条目（3 字段精简）：</span></span>
<span class="line"><span>- at: {ISO 8601}</span></span>
<span class="line"><span>from_step: {原步骤号}</span></span>
<span class="line"><span>choice: {apply_all | partial | report_only | cancelled}</span></span>
<span class="line"><span>注：sync_history 写入工作上下文 YAML 头部（与 iteration_history / change_requests 同级），</span></span>
<span class="line"><span>不写 .flow（.flow 只承载&quot;当下一轮&quot;临时态）。</span></span>
<span class="line"><span></span></span>
<span class="line"><span>8. 输出回归提示：</span></span>
<span class="line"><span>&quot;✅ 文档同步完成，已回到步骤 {原步骤号}，继续原任务&quot;</span></span></code></pre></div><h2 id="四、结构化完成标记-必须输出" tabindex="-1">四、结构化完成标记（必须输出） <a class="header-anchor" href="#四、结构化完成标记-必须输出" aria-label="Permalink to &quot;四、结构化完成标记（必须输出）&quot;">​</a></h2><div class="language-json vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">json</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">{</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">&quot;command&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">: </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;dev:sync&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">,</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">&quot;caller&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">: </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;in-flow-sync&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">,</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">&quot;status&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">: </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;completed&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">,</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">&quot;outputs&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">: {</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">&quot;sync_trigger&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">: </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;user_active | ai_reminder_silent_55 | ai_reminder_full_void&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">,</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">&quot;sync_from_step&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">: </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;5.5&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">,</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">&quot;sync_resumed_to_step&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">: </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;5.5&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">,</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">&quot;docs_synced&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">: {</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">&quot;cr_registered&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">: </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">2</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">,</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">&quot;devlog_appended&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">: </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;sync_N_section&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">,</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">&quot;knowledge_drift_checked&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">: </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;no_hits | appended_history&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">,</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">&quot;doc_platform_sync_result&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">: </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;synced | skipped_no_changes | skipped_user_opt_out | skipped_no_docid&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">,</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">&quot;plan_md_updated&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">: </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;true | unchanged（CR 不影响计划内容）&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">,</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">&quot;artifacts_paths_validated&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">: </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">true</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">,</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">&quot;working_context_validated&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">: </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">true</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">},</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">&quot;user_choice&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">: </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;apply_all | partial_apply | report_only | cancelled&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">,</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">&quot;silent_55_count_reset&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">: </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">true</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">,</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">&quot;last_sync_diff_sha&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">: </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;{git rev-parse HEAD 后}&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">,</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">&quot;duration_seconds&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">: </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">45</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">},</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">&quot;next_step&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">: </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;{原步骤号}（恢复后）&quot;</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">}</span></span></code></pre></div><p><strong>完成标记校验规则</strong>：</p><ul><li><code>sync_from_step</code> 必须有值（证明确实是流程内召唤）</li><li><code>sync_resumed_to_step</code> 必须等于 <code>sync_from_step</code>（证明恢复成功）</li><li><code>docs_synced</code> 至少包含 1 个非空字段</li><li><code>user_choice</code> 不能为空</li><li><code>last_sync_diff_sha</code> 必须等于完成时刻的 <code>git rev-parse HEAD</code></li><li><code>artifacts_paths_validated</code> 必须为 <code>true</code>（确认所有非 null 路径均已 <code>[ -f ]</code> / <code>[ -d ]</code> 核验）</li></ul><h2 id="五、与活跃流程恢复的关系" tabindex="-1">五、与活跃流程恢复的关系 <a class="header-anchor" href="#五、与活跃流程恢复的关系" aria-label="Permalink to &quot;五、与活跃流程恢复的关系&quot;">​</a></h2><p>跨会话恢复时若发现 <code>.flow.status == paused_for_sync</code>：</p><div class="language-text vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">text</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>新对话首响：</span></span>
<span class="line"><span>&quot;⚠️ 检测到上次会话在步骤 {sync_from_step} 召唤了 dev:sync 但未完成。</span></span>
<span class="line"><span></span></span>
<span class="line"><span>- 已同步：{docs_synced 摘要}</span></span>
<span class="line"><span>- 是否继续同步剩余文档？&quot;</span></span>
<span class="line"><span></span></span>
<span class="line"><span>| 选项 | 说明 |</span></span>
<span class="line"><span>| --- | --- |</span></span>
<span class="line"><span>| ▶️ 继续未完成的同步 | 加载未完成的子环节继续 |</span></span>
<span class="line"><span>| 🔁 重新开始 dev:sync | 重置 sync 状态从头开始 |</span></span>
<span class="line"><span>| ⏭️ 取消同步，回原步骤 | 恢复 current_step={sync_from_step} 继续原任务 |</span></span></code></pre></div><h2 id="六、边界情况" tabindex="-1">六、边界情况 <a class="header-anchor" href="#六、边界情况" aria-label="Permalink to &quot;六、边界情况&quot;">​</a></h2><table tabindex="0"><thead><tr><th>场景</th><th>处理</th></tr></thead><tbody><tr><td><code>.flow</code> 不存在</td><td>扫描 working-context 匹配项目路径+分支名；匹配到则进入独立模式，未匹配到则终止</td></tr><tr><td>git diff（相对 sync_base_sha）为空</td><td>输出&quot;无代码改动，文档已最新，跳过同步&quot;</td></tr><tr><td>工作上下文缺失</td><td>中止，提示用户先恢复工作上下文</td></tr><tr><td>文档平台 docid 为空</td><td>文档平台 子环节跳过，其他文档照常同步</td></tr><tr><td>同步中用户撤销</td><td>完整回滚到 <code>sync_from_step</code> 状态，不留半成品</td></tr><tr><td>同一会话连续 dev:sync</td><td>第 2 次以 <code>last_sync_diff_sha</code> 为起点仅同步增量</td></tr><tr><td><code>sync_reminder_disabled: true</code></td><td>用户主动 <code>dev:sync</code> 仍执行；AI 场景 A/B 静默跳过</td></tr><tr><td>迭代修复 N+1 / 批次切换 batch_next</td><td>仍属同需求，<code>sync_reminder_disabled</code> 持续生效</td></tr></tbody></table><h2 id="七、相关文档" tabindex="-1">七、相关文档 <a class="header-anchor" href="#七、相关文档" aria-label="Permalink to &quot;七、相关文档&quot;">​</a></h2><ul><li>收尾子流程定义 → <code>references/closeout-flow.md</code></li><li>文档同步规则 → <code>references/doc-sync-rules.md</code></li><li>需求漂移处理 + CR 自动登记 → <code>references/drift-handling.md</code> §三 + §3.5</li><li>工具门禁权威源 → <code>config/gates.yaml</code> §<code>tool_gates.phases.step_5_plus</code></li><li>工作上下文 freshness 物理守护 → <code>scripts/lints/working-context-freshness-lint.sh</code></li><li>silent_55_count 物理层维护 → <code>scripts/hooks/post-step.sh</code></li><li>AI 主动弹框规则 + dev:sync ≠ 5.5b 替代品 → <code>~/.codebuddy/rules/AI行为规范.mdc</code> §「主动文档同步弹框提醒」</li></ul>`,34)])])}const u=n(l,[["render",i]]);export{k as __pageData,u as default};
