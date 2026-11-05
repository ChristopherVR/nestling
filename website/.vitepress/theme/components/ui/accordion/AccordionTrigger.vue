<script setup lang="ts">
import type { HTMLAttributes } from 'vue'
import { AccordionHeader, AccordionTrigger } from 'reka-ui'
import { ChevronDown } from '@lucide/vue'
import { cn } from '@/lib/utils'

const props = defineProps<{ class?: HTMLAttributes['class'] }>()
</script>

<template>
  <AccordionHeader as="h3" class="flex">
    <AccordionTrigger
      data-slot="accordion-trigger"
      :class="
        cn(
          'group flex flex-1 items-center justify-between gap-4 py-4 text-left text-[16.5px] font-semibold leading-snug text-foreground transition-colors hover:text-primary cursor-pointer',
          props.class,
        )
      "
    >
      <slot />
      <ChevronDown
        aria-hidden="true"
        class="size-5 shrink-0 text-muted-foreground transition-transform duration-200 group-data-[state=open]:rotate-180"
      />
    </AccordionTrigger>
  </AccordionHeader>
</template>
