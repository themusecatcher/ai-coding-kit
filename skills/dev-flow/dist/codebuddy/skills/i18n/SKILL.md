---
name: i18n
description: 国际化翻译资源操作规范。涉及翻译 key 新增/修改/删除、多语言资源文件操作、i18n 配置时加载此 skill。
---

# 国际化翻译资源操作规范

涉及翻译 key 新增/修改/删除、多语言资源文件操作时，必须遵循以下规范。

## 适用场景

- 新增/修改/删除翻译 key
- 操作多语言 JSON 资源文件
- 调试翻译加载问题
- 检查翻译完整性

## 1. 必须先追溯翻译加载路径

- ✅ 找到 `withMetI18n`/`i18n.init` 等初始化代码，确认 `localeFile`/`resources` 指向的实际目录
- ❌ 禁止凭目录名猜测（如看到翻译资源目录就认为是翻译来源）
- ❌ 禁止不验证加载路径就直接添加翻译 key

**追溯方法**：
```bash
# 搜索 i18n 初始化入口
grep -r "withMetI18n\|i18n\.init\|i18next\.init\|localeFile\|resources" src/ --include="*.ts" --include="*.tsx" -l
```

## 2. 新增 key 前必须全局搜索

- ✅ `grep -r "key名" src/ --include="*.json"` 全局搜索，确认 key 是否已存在
- ✅ 同时搜索 `locales/` 目录和 `src/` 目录下的 JSON 文件
- ❌ 禁止只在某个目录搜索就断定是"新增"

**搜索方法**：
```bash
# 全局搜索 key 是否已存在
grep -r "要搜索的key" src/ locales/ --include="*.json"

# 搜索 key 在代码中的使用
grep -r "t('要搜索的key')\|t(\"要搜索的key\")" src/ --include="*.ts" --include="*.tsx"
```

## 3. 子模块改动必须单独检查

- git diff 对子模块只显示 commit hash 变化，必须进入子模块内部 `git diff` 查看具体改动
- ✅ 改动汇总必须覆盖子模块内的改动

```bash
# 检查子模块内部的具体改动
cd path/to/submodule
git diff
git diff --stat
```

## 4. 多语言文件一致性

- ✅ 新增 key 时，必须同时在所有语言文件中添加（至少添加中文和英文）
- ✅ 删除 key 时，必须同时从所有语言文件中删除
- ❌ 禁止只改一个语言文件而遗漏其他语言

## 5. 翻译 key 命名规范

- ✅ 使用有意义的层级命名：`module.feature.description`
- ✅ 保持与项目已有 key 的命名风格一致
- ❌ 禁止使用过于笼统的 key（如 `text1`、`label`）

## 验证清单

- [ ] 已追溯并确认翻译加载路径？
- [ ] 已全局搜索确认 key 不存在/已存在？
- [ ] 所有语言文件都已同步更新？
- [ ] 子模块改动已单独检查？
- [ ] key 命名符合项目已有风格？
