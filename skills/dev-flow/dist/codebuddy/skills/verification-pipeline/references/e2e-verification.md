# Playwright E2E 自动化验证规范

## 背景

AI 在修改涉及运行时行为的代码后（DOM 操作、样式计算、动画定位等），无法自行验证改动是否正确。本规范定义了如何利用项目已有的 Playwright E2E 基础设施，让 AI 在改动后自动编写并运行验证测试。

## 前置条件

使用 E2E 验证需要满足以下条件：

| 条件 | 检查方式 | 不满足时的替代方案 |
|------|---------|-------------------|
| dev server 已启动 | `curl http://127.0.0.1:3000` | 回退到方案 3（自检日志） |
| 登录态已采集 | `.playwright/.auth/state.json` 存在 | `bun run test:e2e:auth` 采集 |
| 有可用的测试 URL | `E2E_URL` 环境变量 | 向用户询问测试页面 URL |
| Playwright 已安装 | `bunx playwright --version` | `bunx playwright install chromium` |

## 何时使用 E2E 验证

### 适合 E2E 验证的场景

- DOM 元素位置/尺寸变化（如 Popper flip、Tooltip 方向）
- 响应式布局（窗口缩放后的行为）
- 交互流程（hover → 弹出 → 点击 → 关闭）
- CSS 动画/过渡效果的最终状态
- 组件可见性/显隐状态

### 不适合 E2E 验证的场景

- 纯逻辑修改（用 console.assert 即可）
- 静态样式调整（颜色、字号）— 需要视觉对比，超出断言能力
- 需要特定数据才能触发的边界场景（除非能 mock）

## 验证测试编写规范

### 1. 文件命名与位置

验证测试是临时的，放在 `tests/e2e/cases/` 对应模块目录下，以 `verify-` 前缀命名：

```
tests/e2e/cases/
├── timelines-panel/
│   ├── verify-translation-bubble-flip.spec.ts  ← 临时验证测试
│   ├── finished-render.spec.ts                 ← 正式测试
│   └── ...
```

### 2. 验证测试模板

```ts
import { expect, test } from '@playwright/test';
import { getTargetUrl } from '../../utils/target-url';

/**
 * 临时验证测试 - 验证 [改动描述]
 * 改动文件：[相关文件列表]
 * 验证通过后删除此文件
 */
test.describe('[模块名]: 改动验证', () => {
  test('[具体验证点]', async ({ page }) => {
    await page.goto(getTargetUrl());
    await page.waitForLoadState('domcontentloaded');
    
    // 等待目标元素出现
    // ... 具体的断言逻辑
  });
});
```

### 3. 常用验证模式

#### 验证 DOM 元素存在且可见
```ts
const element = page.locator('[class*="targetClass"]');
await expect(element).toBeVisible({ timeout: 10_000 });
```

#### 验证元素样式值
```ts
const maxWidth = await page.locator('.translation-bubble').evaluate((el) => {
  return window.getComputedStyle(el).maxWidth;
});
expect(parseInt(maxWidth)).toBeGreaterThan(200);
expect(parseInt(maxWidth)).toBeLessThan(800);
```

#### 验证元素位置（左侧/右侧）
```ts
const bubbleRect = await page.locator('.bubble-content').evaluate((el) => {
  return el.getBoundingClientRect();
});
const triggerRect = await page.locator('.trigger-element').evaluate((el) => {
  return el.getBoundingClientRect();
});
// 验证气泡在触发元素的右侧
expect(bubbleRect.left).toBeGreaterThan(triggerRect.right - 10);
```

#### 验证窗口缩放后的行为
```ts
// 缩小窗口
await page.setViewportSize({ width: 800, height: 600 });
await page.waitForTimeout(500); // 等待 resize 回调

// 验证缩放后的状态
const afterResize = await page.locator('.target').evaluate((el) => {
  return { width: el.offsetWidth, maxWidth: window.getComputedStyle(el).maxWidth };
});
expect(parseInt(afterResize.maxWidth)).toBeLessThan(800);
```

#### 验证 console 输出（配合自检日志）
```ts
const consoleLogs: string[] = [];
page.on('console', (msg) => {
  if (msg.text().includes('[翻译气泡]')) {
    consoleLogs.push(msg.text());
  }
});

await page.goto(getTargetUrl());
await page.waitForTimeout(3000);

// 验证自检日志有输出
expect(consoleLogs.length).toBeGreaterThan(0);
// 验证没有 assert 失败
const assertions = consoleLogs.filter(log => log.includes('Assertion failed'));
expect(assertions).toHaveLength(0);
```

## 运行验证测试

```bash
# 运行单个验证测试
E2E_URL='https://example.com/project-a/page?id=xxx&type=4' \
E2E_STORAGE_STATE='.playwright/.auth/state.json' \
bun run test:e2e -- tests/e2e/cases/feature-panel/verify-feature.spec.ts

# headed 模式（显示浏览器，方便观察）
E2E_URL='...' E2E_STORAGE_STATE='...' bun run test:e2e:headed -- tests/e2e/cases/timelines-panel/verify-xxx.spec.ts
```

## AI 执行 E2E 验证的完整流程

1. **确认前置条件**：检查 dev server、登录态、测试 URL 是否可用
2. **编写验证测试**：基于改动内容，在 `tests/e2e/cases/` 下创建 `verify-*.spec.ts`
3. **运行测试**：执行 `bun run test:e2e` 指定验证文件
4. **分析结果**：
   - 通过 → 改动验证成功，继续步骤 7（清理）
   - 失败 → 分析失败原因，回退到步骤 5 修复
5. **清理**：验证通过后删除 `verify-*.spec.ts` 文件

## 局限性与注意事项

1. **需要测试 URL**：必须有可访问的页面 URL（本地 dev server 或测试环境），AI 需要向用户确认
2. **需要登录态**：大部分页面需要登录，首次使用需要用户手动采集
3. **不能验证视觉效果**：E2E 只能断言 DOM 状态/样式值，不能判断"看起来对不对"
4. **mock 数据限制**：如果验证需要特定数据状态，需要通过 localStorage mock 或网络拦截实现
5. **CI 耗时**：E2E 测试较慢，仅用于关键改动的验证，不要滥用
