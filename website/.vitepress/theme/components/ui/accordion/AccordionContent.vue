<script setup lang="ts">
import type { HTMLAttributes } from 'vue'
import { AccordionContent } from 'reka-ui'
import { cn } from '@/lib/utils'

const props = defineProps<{ class?: HTMLAttributes['class'] }>()
</script>

<template>
  <AccordionContent
    data-slot="accordion-content"
    class="accordion-content overflow-hidden text-[15.5px] leading-relaxed text-ink-2"
  >
    <div :class="cn('max-w-[64ch] pb-5 pr-8', props.class)">
      <slot />
    </div>
  </AccordionContent>
</template>
