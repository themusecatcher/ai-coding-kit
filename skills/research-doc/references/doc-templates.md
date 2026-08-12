# 调研报告模板参考

## 技术方案调研模板

```json
{
  "title": "XXX 技术方案调研",
  "subtitle": "方案对比与选型建议",
  "author": "",
  "date": "2026-03-09",
  "sections": [
    {
      "title": "调研背景",
      "type": "text",
      "content": "描述调研的背景、目标和约束条件。"
    },
    {
      "title": "方案对比",
      "type": "table",
      "content": "",
      "data": {
        "headers": ["维度", "方案 A", "方案 B", "方案 C"],
        "rows": [
          ["功能完整度", "", "", ""],
          ["性能", "", "", ""],
          ["维护成本", "", "", ""],
          ["社区生态", "", "", ""],
          ["学习曲线", "", "", ""],
          ["许可证", "", "", ""]
        ]
      }
    },
    {
      "title": "核心结论",
      "type": "bullet",
      "content": "- 结论 1\n- 结论 2\n- 结论 3"
    },
    {
      "title": "推荐方案",
      "type": "text",
      "content": "推荐 XXX 方案，原因如下：\n\n1. 原因 1\n2. 原因 2\n3. 原因 3"
    },
    {
      "title": "风险与 TODO",
      "type": "bullet",
      "content": "- 风险 1：XXX\n- 风险 2：XXX\n- TODO：XXX"
    }
  ]
}
```

## 竞品分析模板

```json
{
  "title": "XXX 竞品分析",
  "subtitle": "",
  "date": "2026-03-09",
  "sections": [
    {
      "title": "分析目标",
      "type": "text",
      "content": "分析 XXX 领域的主流产品，为 XXX 提供参考。"
    },
    {
      "title": "竞品概览",
      "type": "table",
      "data": {
        "headers": ["产品", "公司", "定位", "用户量", "核心特点"],
        "rows": []
      }
    },
    {
      "title": "功能对比",
      "type": "table",
      "data": {
        "headers": ["功能", "我方", "竞品 A", "竞品 B"],
        "rows": []
      }
    },
    {
      "title": "差异化机会",
      "type": "bullet",
      "content": "- 机会 1\n- 机会 2"
    },
    {
      "title": "行动建议",
      "type": "text",
      "content": ""
    }
  ]
}
```

## 通用调研报告模板

```json
{
  "title": "调研报告标题",
  "subtitle": "副标题（可选）",
  "author": "作者",
  "date": "2026-03-09",
  "sections": [
    {
      "title": "背景与目标",
      "type": "text",
      "content": ""
    },
    {
      "title": "调研方法",
      "type": "bullet",
      "content": "- 方法 1\n- 方法 2"
    },
    {
      "title": "核心发现",
      "type": "text",
      "content": ""
    },
    {
      "title": "数据汇总",
      "type": "table",
      "data": {
        "headers": ["指标", "数值", "说明"],
        "rows": []
      }
    },
    {
      "title": "结论与建议",
      "type": "text",
      "content": ""
    }
  ]
}
```

## section.type 说明

| type | 用途 | 渲染方式 |
|------|------|---------|
| `text` | 普通文本段落 | Markdown → 段落 |
| `table` | 数据表格 | data.headers + data.rows → 表格 |
| `bullet` | 要点列表 | content 中 `- xxx` → 列表项 |
| `chart` | 图表（预留） | 未来扩展 |
