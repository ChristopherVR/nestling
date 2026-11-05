<script setup lang="ts">
import { withBase } from 'vitepress'

defineProps<{
  src: string
  alt: string
  eager?: boolean
}>()
</script>

<template>
  <figure class="m-0">
    <div
      class="rounded-[34px] border border-frame-edge bg-frame p-[9px] shadow-device"
    >
      <img
        :src="withBase(src)"
        :alt="alt"
        width="600"
        height="1081"
        :loading="eager ? 'eager' : 'lazy'"
        decoding="async"
        class="block h-auto w-full rounded-[26px] dark:brightness-[0.88]"
      />
    </div>
    <figcaption v-if="$slots.default" class="mt-3 text-sm text-muted-foreground">
      <slot />
    </figcaption>
  </figure>
</template>
