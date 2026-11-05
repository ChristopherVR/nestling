<script setup lang="ts">
import { Download } from '@lucide/vue'
import { Button } from './ui/button'
import PlayIcon from './PlayIcon.vue'
import { site } from '../site'

const options = [
  {
    key: 'play',
    title: 'Android, from Google Play',
    text: 'The simplest choice. Google Play installs Nestling and keeps it up to date.',
    href: site.play,
    cta: 'Get it on Google Play',
    primary: true,
  },
  {
    key: 'apk',
    title: 'Android, as an APK',
    text: 'Install the file yourself. Nestling offers updates from inside the app.',
    href: site.latestRelease,
    cta: 'Download the APK',
    file: 'BabyLog-<version>.apk',
  },
  {
    key: 'windows',
    title: 'Windows PC',
    text: 'A ZIP you extract and run. Windows 10 or 11, 64-bit.',
    href: site.latestRelease,
    cta: 'Download for Windows',
    file: 'BabyLog-<version>-windows-x64.zip',
  },
]
</script>

<template>
  <ul
    class="vp-raw m-0 grid list-none divide-y divide-border rounded-lg border border-border bg-card p-0 md:grid-cols-3 md:divide-x md:divide-y-0"
    role="list"
  >
    <li v-for="o in options" :key="o.key" class="m-0 flex flex-col gap-2 p-5">
      <h3 class="m-0 text-base font-semibold leading-snug text-foreground">{{ o.title }}</h3>
      <p class="m-0 text-[15px] leading-relaxed text-ink-2">{{ o.text }}</p>
      <p v-if="o.file" class="m-0 text-[13px] leading-relaxed text-muted-foreground">
        File:
        <code class="rounded-sm bg-muted px-1 py-0.5 font-mono text-[12.5px] text-foreground">{{ o.file }}</code>
      </p>
      <Button
        as="a"
        :href="o.href"
        target="_blank"
        rel="noopener"
        :variant="o.primary ? 'default' : 'outline'"
        size="sm"
        class="mt-auto w-full translate-y-1 sm:w-auto sm:self-start"
      >
        <component :is="o.primary ? PlayIcon : Download" aria-hidden="true" />
        {{ o.cta }}
        <span class="sr-only">(opens in a new tab)</span>
      </Button>
    </li>
  </ul>
</template>
