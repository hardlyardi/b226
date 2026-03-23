import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
    title: "B226",
    description: "An entity component system for Luau.",
    base: "/b226/",
    
    themeConfig: {
        // https://vitepress.dev/reference/default-theme-config
        logo: "/b2logonotext.png",

        search: {
            provider: 'local'
        },

        nav: [
            {
                text: 'Home',
                items: [
                    { text: '0.2.X', link: '/' },
                ]
            },
        ],

        sidebar: [
            {
                text: 'Learn',
                items: [
                    { text: 'Documentation', link: '/documentation' },
                    { text: 'FAQ', link: '/faq' },
                    { text: 'Quickstart', link: '/quick-start' },
                    { text: 'ECS, Entities & Components', link: '/ecs-entities-and-components' },
                    { text: 'Entity Relationships', link: './relationships' },
                    { text: 'Cleanup Traits', link: './cleanup-traits' },
                    { text: 'Hooks', link: '/hooks' },
                    { text: 'Queries', link: '/queries' },
                    { text: 'Builtin Components', link: '/builtin-components' },
                    { text: 'Bulk Operations', link: '/bulk-operations' },
                ]
            }
        ],

        socialLinks: [
            { icon: 'github', link: 'https://github.com/hardlyardi/b226' }
        ]
    }
})
