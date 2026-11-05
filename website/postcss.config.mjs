import { postcssIsolateStyles } from 'vitepress'

// Keep VitePress' Markdown document styles (vp-doc.css) away from anything
// inside `.vp-raw`, so the shadcn-vue components look the same in guide pages
// as on the landing page.
export default {
  plugins: [postcssIsolateStyles({ includeFiles: [/vp-doc\.css/] })],
}
