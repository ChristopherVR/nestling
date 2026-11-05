<script setup lang="ts">
import { withBase } from 'vitepress'
import { ChevronRight } from '@lucide/vue'

const links = [
  {
    href: '/get-started',
    title: 'Install Nestling',
    text: 'Android from Google Play or as an APK, or Windows as a ZIP. About a minute.',
  },
  {
    href: '/guides/sharing',
    title: 'Set up with your partner',
    text: 'Scan one QR code and both phones keep the same log from then on.',
  },
  {
    href: '/guides/camera',
    title: 'Connect a Nanit camera',
    text: 'Video, sound and room temperature on your home Wi‑Fi, without a Nanit account.',
  },
]
</script>

<template>
  <ul class="vp-raw m-0 list-none border-t border-border p-0" role="list">
    <li v-for="link in links" :key="link.href" class="m-0 border-b border-border">
      <a
        :href="withBase(link.href)"
        class="group -mx-3 flex items-center gap-4 rounded-md px-3 py-4 text-foreground no-underline transition-colors hover:bg-muted sm:py-5"
      >
        <span class="flex min-w-0 flex-1 flex-col gap-0.5 sm:flex-row sm:items-baseline sm:gap-6">
          <span class="text-[17px] font-semibold leading-snug text-primary sm:w-60 sm:shrink-0">
            {{ link.title }}
          </span>
          <span class="text-[15px] leading-normal text-ink-2">{{ link.text }}</span>
        </span>
        <ChevronRight
          class="size-5 shrink-0 text-muted-foreground transition-transform duration-150 group-hover:translate-x-0.5"
          aria-hidden="true"
        />
      </a>
    </li>
  </ul>
</template>
