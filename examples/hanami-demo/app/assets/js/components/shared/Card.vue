<template>
  <div
    class="overflow-hidden rounded-lg bg-white shadow dark:bg-gray-800"
    :class="{ 'border border-gray-200 dark:border-gray-700': bordered }"
  >
    <div v-if="$slots.header" class="border-b border-gray-200 bg-gray-50 px-4 py-3 dark:border-gray-700 dark:bg-gray-900">
      <slot name="header" />
    </div>

    <div class="px-4 py-5 sm:p-6">
      <slot />
    </div>

    <div v-if="$slots.footer" class="border-t border-gray-200 bg-gray-50 px-4 py-3 dark:border-gray-700 dark:bg-gray-900">
      <slot name="footer" />
    </div>
  </div>
</template>

<script setup lang="ts">
interface Props {
  bordered?: boolean
}

withDefaults(defineProps<Props>(), {
  bordered: false,
})
</script>
