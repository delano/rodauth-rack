<template>
  <div class="space-y-1">
    <label
      v-if="label"
      :for="id"
      class="block text-sm font-medium text-gray-700 dark:text-gray-300"
    >
      {{ label }}
      <span v-if="required" class="text-danger-500">*</span>
    </label>

    <div class="relative">
      <slot :id="id" :errorState="hasError" />
    </div>

    <p
      v-if="hasError"
      class="text-sm text-danger-600 dark:text-danger-400"
      :id="`${id}-error`"
    >
      {{ errors[0] }}
    </p>

    <p
      v-else-if="hint"
      class="text-sm text-gray-500 dark:text-gray-400"
      :id="`${id}-hint`"
    >
      {{ hint }}
    </p>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'

interface Props {
  id: string
  label?: string
  hint?: string
  errors?: string[]
  required?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  errors: () => [],
  required: false,
})

const hasError = computed(() => props.errors.length > 0)
</script>
