import type { Theme } from 'vitepress'
import DefaultTheme from 'vitepress/theme-without-fonts'

import '@fontsource-variable/figtree/index.css'
import './style.css'

import Landing from './components/Landing.vue'
import DownloadOptions from './components/DownloadOptions.vue'
import QuickLinks from './components/QuickLinks.vue'

export default {
  extends: DefaultTheme,
  enhanceApp({ app }) {
    app.component('Landing', Landing)
    app.component('DownloadOptions', DownloadOptions)
    app.component('QuickLinks', QuickLinks)
  },
} satisfies Theme
