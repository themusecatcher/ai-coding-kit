---
module: "{module-name}"
topic: "design-intent"

# 默认 confidence: scanned；被多源仲裁升级后可能变为 auto-verified / auto-stale
confidence: "scanned"

base_branch: "master"

# 代码锚点（仲裁层用于判断意图与代码是否对齐；可逐条目维护）
code_anchors:
  - path: "src/{module-path}/"

# release 不参与设计意图体系
release:
  released: false
  released_at: null
  verified_in_production: false

# 稳定性与衰减指标
stability:
  last_verified: "YYYY-MM-DD"
  drift_count: 0
  confidence_score: 40            # scanned 基线；auto-verified 升至 80

# auto_upgrade 字段在被自动升级后由仲裁流程写入（见 references/confidence.md）
# auto_upgrade:
#   upgraded_at: "YYYY-MM-DD"
#   upgraded_by: "step-1-arbitration"
#   code_anchor: "src/x.ts::foo"
#   source_ref: "远程知识库/wiki/..."
#   ttl_days: 90

created: "YYYY-MM-DD"
last_scanned: "YYYY-MM-DD"
---

# {module-name} · 设计意图反哺

> 本文件由 P3 类远程知识（远程知识库/wiki / git_doc_platform / doc_platform / web_search）反哺产生，记录**设计意图、架构背景、未来规划**类知识。
> 与代码事实并列，**不互相覆盖**。完整规则详见 `modes/deposit.md` § design-intent.md 写入规则。
> 默认硬上限 200 行；超限时自动归档至 `_archive/design-intent-{YYYYMMDD}.md`。

## {主题示例：心跳机制设计背景}

<!-- source: 远程知识库/wiki/{path} | doc_platform:{id} | mr#{number} -->
<!-- ingested_at: YYYY-MM-DD -->
<!-- arbitration: P3 · scanned · 未与代码交叉验证 -->

{原始表述摘要，控制在 200 字以内}

**设计意图**：{提炼后的意图陈述}
**与代码事实的关系**：{选一：已在 X.tsx 中实现 / 部分实现于 Y / 仅为规划未实施}

---

<!-- 后续条目按相同格式追加；总行数接近 200 时进入归档压缩流程 -->
