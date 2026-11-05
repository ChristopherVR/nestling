import { defineConfig } from 'vitepress'
import tailwindcss from '@tailwindcss/vite'
import { fileURLToPath, URL } from 'node:url'
import { site } from './theme/site'

const base = '/nestling/'

export default defineConfig({
  lang: 'en',
  title: 'Nestling',
  titleTemplate: ':title · Nestling',
  description:
    'A calm, shared baby log for feeds, nappies, sleep and growth. Free, no account, and your log stays on your own devices.',
  base,
  cleanUrls: true,
  lastUpdated: false,
  appearance: true,

  head: [
    ['link', { rel: 'icon', type: 'image/png', href: `${base}favicon.png` }],
    ['link', { rel: 'apple-touch-icon', href: `${base}apple-touch-icon.png` }],
    ['meta', { name: 'theme-color', content: '#F8F9FA', media: '(prefers-color-scheme: light)' }],
    ['meta', { name: 'theme-color', content: '#0F1113', media: '(prefers-color-scheme: dark)' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:site_name', content: 'Nestling' }],
    ['meta', { property: 'og:image', content: `${site.url}og-image.png` }],
    ['meta', { name: 'twitter:card', content: 'summary_large_image' }],
  ],

  transformPageData(pageData) {
    const title = pageData.frontmatter.title ?? pageData.title
    pageData.frontmatter.head ??= []
    pageData.frontmatter.head.push([
      'meta',
      { property: 'og:title', content: title ? `${title} · Nestling` : 'Nestling' },
    ])
  },

  vite: {
    plugins: [tailwindcss()],
    resolve: {
      alias: {
        '@': fileURLToPath(new URL('./theme', import.meta.url)),
      },
    },
  },

  themeConfig: {
    logo: { src: '/icon-192.png', alt: '' },
    siteTitle: 'Nestling',

    nav: [
      { text: 'Get started', link: '/get-started', activeMatch: '^/get-started' },
      {
        text: 'Guides',
        activeMatch: '^/guides/',
        items: [
          { text: 'Logging basics', link: '/guides/logging' },
          { text: 'Reminders', link: '/guides/reminders' },
          { text: 'Share with a partner', link: '/guides/sharing' },
          { text: 'Momcozy breast pump', link: '/guides/pump' },
          { text: 'Nanit camera', link: '/guides/camera' },
          { text: 'Backups and updates', link: '/guides/backups' },
        ],
      },
      { text: 'Privacy', link: '/privacy' },
      { text: 'Releases', link: site.releases },
    ],

    sidebar: [
      {
        text: 'Start here',
        items: [{ text: 'Install and set up', link: '/get-started' }],
      },
      {
        text: 'Guides',
        items: [
          { text: 'Logging basics', link: '/guides/logging' },
          { text: 'Reminders', link: '/guides/reminders' },
          { text: 'Share with a partner', link: '/guides/sharing' },
          { text: 'Momcozy breast pump', link: '/guides/pump' },
          { text: 'Nanit camera', link: '/guides/camera' },
          { text: 'Backups and updates', link: '/guides/backups' },
        ],
      },
      {
        text: 'About',
        items: [
          { text: 'Privacy policy', link: '/privacy' },
          { text: 'Disclaimer', link: '/disclaimer' },
          { text: 'Release notes', link: site.releases },
        ],
      },
    ],

    socialLinks: [{ icon: 'github', link: site.repo, ariaLabel: 'Nestling on GitHub' }],

    search: { provider: 'local' },

    outline: { level: [2, 3], label: 'On this page' },

    docFooter: { prev: 'Previous', next: 'Next' },

    editLink: {
      pattern: `${site.repo}/edit/main/website/:path`,
      text: 'Suggest a change to this page',
    },

    externalLinkIcon: true,

    footer: {
      message:
        `Nestling is not a medical device. Read the <a href="${base}privacy">privacy policy</a> and <a href="${base}disclaimer">disclaimer</a>.`,
      copyright: `Made by <a href="https://github.com/ChristopherVR">ChristopherVR</a>.`,
    },
  },
})
