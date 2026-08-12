---
module: payment
topic: api-spec
confidence: foobar
created: 2026-05-15
---

# payment api-spec（非法 confidence）

> knowledge-loop fixtures - 反例：confidence=foobar 不在 state-machine.yaml 映射表中。
> 用途：覆盖 check-state.sh 的失败路径——state.sh 应退出码 1（未知 confidence），lint 应将此文件计入失败计数。
