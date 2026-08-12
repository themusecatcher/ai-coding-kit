# 复杂度优化助手

检测 TypeScript/JavaScript 文件中复杂度超过 20 的函数，并提供分步优化方案。

## 安装

本 skill 是本仓库（ai-coding-kit）统一管理的**独立 skill**，不属于 dev-flow 的依赖，需单独安装到 `~/.codebuddy/skills/`。

**方式一（推荐）：随 dev-flow 安装器一并全量安装**

```bash
cd skills/dev-flow/dist
bash install.sh --all-repo   # 整仓全量：含本 skill 在内的所有 skill
```

**方式二：单独安装本 skill**

```bash
# 复制（在仓库根目录执行）
cp -r skills/complexity-optimizer ~/.codebuddy/skills/

# 或软链（源码更新自动生效，需用绝对路径）
ln -s "$(pwd)/skills/complexity-optimizer" ~/.codebuddy/skills/complexity-optimizer
```

> CodeBuddy 只识别 `~/.codebuddy/skills/` 下的 skill，安装后重启 IDE 生效。

## 使用方式

### 1. 检测复杂度

```
检测文件复杂度：src/views/xxx/index.tsx
```

或直接说：

```
分析这个文件的复杂度
```

### 2. 选择要优化的函数

检测完成后会列出超标函数，选择要优化的函数：

```
优化 filterMenuItems 函数
```

或指定行号：

```
优化第 140 行的函数
```

### 3. 确认并执行优化方案

助手会设计分步优化方案，确认后逐步执行：

```
执行
```

## 示例对话

```
用户：检测 my-project/src/routers/index.tsx 的复杂度

助手：检测到以下超标函数：
      1. filterMenuItems (第 140 行) - 复杂度 29
      2. GenerateMenuItem (第 360 行) - 复杂度 27
      请问需要优化哪个函数？

用户：filterMenuItems

助手：[输出优化方案]
      是否执行第一步？

用户：执行

助手：[执行优化并验证]
```

## 注意事项

- 每步修改不超过 100 行
- 优化后会自动验证复杂度是否降低
- 若优化无效会自动撤回改动
