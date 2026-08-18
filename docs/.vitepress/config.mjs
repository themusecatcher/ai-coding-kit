import { defineConfig } from 'vitepress'
import { withMermaid } from 'vitepress-plugin-mermaid'

// M2 会生成 sidebar.generated.mjs（skills/rules/agents/dev-flow 侧边栏）。
// M1 阶段该文件可能尚未生成，做容错降级为空对象，保证 docs:dev 可先跑起来。
let generatedSidebar = {}
try {
  const mod = await import('./sidebar.generated.mjs')
  generatedSidebar = mod.sidebar ?? mod.default ?? {}
} catch {
  // sidebar.generated.mjs 尚未生成（M2 前的正常状态），使用空侧边栏
  generatedSidebar = {}
}

const guideSidebar = [
  {
    text: '开始使用',
    items: [
      { text: '这是什么', link: '/guide/what-is-it' },
      { text: '安装与配置', link: '/guide/installation' },
      { text: '5 分钟快速上手', link: '/guide/quick-start' },
    ],
  },
]

// GitHub Pages 部署在子路径 https://<user>.github.io/ai-coding-kit/ 下。
// 通过 DOCS_BASE 环境变量切换：deploy.sh 会注入 '/ai-coding-kit/'，本地开发保持 '/'。
const base = process.env.DOCS_BASE || '/'

export default withMermaid(
  defineConfig({
    title: 'AI Coding Kit',
    description: 'AI 辅助编程方法论门户 —— 以 dev-flow 为核心的 Skills / Rules / Agents 全整合',
    lang: 'zh-CN',
    lastUpdated: true,
    cleanUrls: true,

    base,

    // 开启死链检测（false = 检测）。gen-docs.mjs 的 rewriteLinks 已消除投影内容的死链，
    // 全站构建零死链；如未来引入新外链失效，可在此配置局部白名单。
    ignoreDeadLinks: false,

    head: [
      ['meta', { name: 'theme-color', content: '#3c8772' }],
      // favicon：head 里的 link 不会自动加 base 前缀，故用 base 常量手动拼接，
      // 保证本地（/logo.svg）与子路径部署（/ai-coding-kit/logo.svg）都能命中。
      ['link', { rel: 'icon', type: 'image/svg+xml', href: `${base}logo.svg` }],
    ],

    themeConfig: {
      // 导航栏左上角 logo（配合站点标题）
      logo: '/logo.svg',

      nav: [
        { text: '指南', link: '/guide/what-is-it', activeMatch: '/guide/' },
        { text: '🚩 dev-flow', link: '/dev-flow/', activeMatch: '/dev-flow/' },
        { text: 'Skills', link: '/skills/', activeMatch: '/skills/' },
        { text: 'Rules', link: '/rules/', activeMatch: '/rules/' },
        { text: 'Agents', link: '/agents/', activeMatch: '/agents/' },
      ],

      sidebar: {
        '/guide/': guideSidebar,
        // M2 生成的分组侧边栏（dev-flow / skills / rules / agents）
        ...generatedSidebar,
      },

      // 如需展示仓库入口，填入真实仓库地址后取消注释：
      socialLinks: [{ icon: 'github', link: 'https://github.com/themusecatcher/ai-coding-kit' }],

      outline: {
        // 覆盖 H2~H4，让超大文件（step-router/metrics-rules 等）的右侧页内目录更完整
        level: [2, 4],
        label: '本页目录',
      },

      docFooter: {
        prev: '上一页',
        next: '下一页',
      },

      lastUpdatedText: '最后更新',
      returnToTopLabel: '回到顶部',
      sidebarMenuLabel: '菜单',
      darkModeSwitchLabel: '主题',
      lightModeSwitchTitle: '切换到浅色模式',
      darkModeSwitchTitle: '切换到深色模式',

      footer: {
        message: '基于「单一权威源」哲学构建 —— 文档由源文件投影生成',
        copyright: 'AI Coding Kit',
      },

      // 本地离线搜索（无需外部服务）
      search: {
        provider: 'local',
        options: {
          locales: {
            root: {
              translations: {
                button: {
                  buttonText: '搜索文档',
                  buttonAriaLabel: '搜索文档',
                },
                modal: {
                  noResultsText: '无法找到相关结果',
                  resetButtonTitle: '清除查询条件',
                  footer: {
                    selectText: '选择',
                    navigateText: '切换',
                    closeText: '关闭',
                  },
                },
              },
            },
          },
        },
      },
    },

    // Mermaid 全局配置
    mermaid: {
      // 主题跟随明暗模式由插件处理，此处留默认
    },
    mermaidPlugin: {
      class: 'mermaid-diagram',
    },
  })
)
