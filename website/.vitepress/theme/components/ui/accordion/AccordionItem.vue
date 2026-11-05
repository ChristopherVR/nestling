<script setup lang="ts">
import type { HTMLAttributes } from 'vue'
import { AccordionItem } from 'reka-ui'
import { cn } from '@/lib/utils'

const props = defineProps<{
  value: string
  disabled?: boolean
  class?: HTMLAttributes['class']
}>()
</script>

<template>
  <AccordionItem
    data-slot="accordion-item"
    :value="props.value"
    :disabled="props.disabled"
    :class="cn('border-b border-border last:border-b-0', props.class)"
  >
    <slot />
  </AccordionItem>
</template>
