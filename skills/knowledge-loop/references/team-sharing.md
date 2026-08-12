# 团队共享方案（Phase 2 扩展）

> 本文件定义知识库从个人本地到团队共享的演进路径。
> 当前为规划阶段，实施时加载。

## 演进路径

```
阶段1（当前）：个人本地知识库
  ~/.codebuddy/knowledge/{project-name}/

阶段2（团队共享）：项目仓库内知识库
  {project-root}/.codebuddy/knowledge/    ← 跟随 git 提交，团队共享

阶段3（平台级）：中心化知识服务
  团队知识 API → 跨项目检索 → 智能推荐
```

## 阶段2 设计要点

- 存储层抽象：modes/ 中的读写操作通过存储层间接访问，切换位置只改配置
- 冲突处理：多人同时沉淀时的 merge 策略
- 隐私过滤：个人调试/偏好信息不进入共享库
- 版本控制：knowledge/ 目录纳入 .gitignore 白名单

## 阶段3 设计要点

- MCP Server 暴露知识库为可查询的数据源
- 跨工具访问（Cursor/Claude Code/CodeBuddy）
- 向量化索引支持语义搜索
