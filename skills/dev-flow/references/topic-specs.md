# 专题规范

遇到对应场景时加载参考文件：

| 专题 | 参考文件 |
| --- | --- |
| 技术文档（方案/分享/发布） | `tech-doc`（doc-platform-doc 模块） |
| 方案设计 | `use_skill('design-advisor')` → design-guide 模块 |
| React 规范 | `references/react.md` |
| URL 编码 | 见下方「URL 参数编码处理」章节 |
| 组件库 | `references/component-library.md` |
| DOM 动画 | 独立 Skill `dom-animation` |
| 样式分析 | `use_skill('design-advisor')` → style-analysis 模块 |
| 运行时验证 | 独立 Skill `verification-pipeline`（阶段 5 运行时验证） |
| E2E 验证 | 独立 Skill `e2e-testing` |
| 浏览器 MCP 验证 | 独立 Skill `verification-pipeline`（阶段 4 浏览器验证） |
| 浏览器工具路由/性能调试/跨浏览器兼容 | 独立 Skill `browser-toolkit`（agent-browser / Playwright / Chrome DevTools 智能选型） |
| 反模式 | `use_skill('design-advisor')` → anti-patterns 模块 |
| 安全规范 | `code-review` Skill L3 安全审计视角 + 「开发规范-完整」附录 E（底线摘要） |
| 文档同步 | `tech-doc`（doc-sync 模块） |
| 开发日志 | `tech-doc`（devlog 模块） |
| 工作上下文 | `references/working-context.md` |
| 流程反思 | `references/flow-retrospective.md` |
| 代码审查 | 独立 Skill `code-review` |
| 系统化验证 | 独立 Skill `verification-pipeline`（备选：references 手动执行） |
| 环境工具 | `references/env-tools.md` |
| 需求输入 | 内联于 `flow.md` 阶段 0 |
| 编码标准 | 独立 Skill `coding-standards` |
| 国际化 | 独立 skill `i18n` |
| **TS/JS 编码规范** | 「开发规范-完整」第八章 §7 + 按需规则 `TypeScript_官方规范` / `TypeScript_编程开发指南` |
| **CSS/SCSS 编码规范** | 「开发规范-完整」第八章 §9 + 按需规则 `CSS_官方规范` + 项目级 CSS 变量规范 |
| **React 编码规范** | `开发规范-红线.mdc` § React（基础底线）+ `references/react.md`（专项补充，step-5 自动加载） |
| **依赖管理** | 「开发规范-完整」第八章 §10 + 按需规则 `依赖管理与Lock文件规范` |

---

## URL 参数编码处理

> 原 `references/url-encoding.md`，已合并至此。

1. **编码形式全面覆盖**：`\u0026` 字面量和 `%5Cu0026` URL 编码必须同时处理
2. **系统性修改先明确业务场景**：先确认涉及哪些场景（PC/移动端），再逐一排查
3. **主动考虑参数操作连锁影响**：删除/修改参数时考虑是否影响其他编码在一起的参数
4. **CSR 层不要遗漏**：SSR 数据可能被 CSR 轮询/刷新覆盖，必须同时考虑两层
5. **验证覆盖所有场景**：修改后主动列出所有需验证的场景组合
6. **页面刷新后状态保持**：修改 URL 时考虑刷新后关键参数不丢失
