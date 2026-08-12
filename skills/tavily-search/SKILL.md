---
name: tavily-search
description: 通过 Tavily API 进行 AI 优化的网页搜索，为 AI Agent 返回简洁、相关的搜索结果。
homepage: https://tavily.com
metadata: {"clawdbot":{"emoji":"🔍","requires":{"bins":["node"],"env":["TAVILY_API_KEY"]},"primaryEnv":"TAVILY_API_KEY"}}
---

# Tavily 搜索

基于 Tavily API 的 AI 优化网页搜索工具，专为 AI Agent 设计，返回简洁、相关的搜索结果。

## 搜索

```bash
node {baseDir}/scripts/search.mjs "查询内容"
node {baseDir}/scripts/search.mjs "查询内容" -n 10
node {baseDir}/scripts/search.mjs "查询内容" --deep
node {baseDir}/scripts/search.mjs "查询内容" --topic news
```

## 选项

- `-n <数量>`：返回结果数量（默认：5，最大：20）
- `--deep`：使用高级搜索模式进行更深入的研究（速度较慢，但结果更全面）
- `--topic <主题>`：搜索主题 - `general`（默认，通用搜索）或 `news`（新闻搜索）
- `--days <天数>`：用于新闻主题时，限制搜索最近 n 天的内容

## 从 URL 提取内容

```bash
node {baseDir}/scripts/extract.mjs "https://example.com/article"
```

注意事项：
- 需要 `TAVILY_API_KEY`，可从 https://tavily.com 获取
- Tavily 针对 AI 场景优化，返回简洁、相关的摘要片段
- 使用 `--deep` 参数进行复杂研究类问题的深度搜索
- 使用 `--topic news` 参数搜索时事新闻
