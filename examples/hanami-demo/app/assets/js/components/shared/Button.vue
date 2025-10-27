<template>
  <button
    :type="type"
    :disabled="disabled || loading"
    :class="buttonClasses"
    class="inline-flex items-center justify-center rounded-md font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
    @click="handleClick"
  >
    <LoadingSpinner
      v-if="loading"
      size="sm"
      :color="variant === 'primary' ? 'white' : 'current'"
      class="mr-2"
    />
    <slot />
  </button>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import LoadingSpinner from './LoadingSpinner.vue'

interface Props {
  type?: 'button' | 'submit' | 'reset'
  variant?: 'primary' | 'secondary' | 'danger' | 'ghost'
  size?: 'sm' | 'md' | 'lg'
  disabled?: boolean
  loading?: boolean
  fullWidth?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  type: 'button',
  variant: 'primary',
  size: 'md',
  disabled: false,
  loading: false,
  fullWidth: false,
})

const emit = defineEmits<{
  click: [event: MouseEvent]
}>()

const buttonClasses = computed(() => {
  const base: string[] = []

  // Variant styles
  const variants = {
    primary: 'bg-primary-600 text-white hover:bg-primary-700 focus:ring-primary-500 dark:bg-primary-500 dark:hover:bg-primary-600',
    secondary: 'bg-gray-200 text-gray-900 hover:bg-gray-300 focus:ring-gray-500 dark:bg-gray-700 dark:text-gray-100 dark:hover:bg-gray-600',
    danger: 'bg-danger-600 text-white hover:bg-danger-700 focus:ring-danger-500 dark:bg-danger-500 dark:hover:bg-danger-600',
    ghost: 'bg-transparent text-gray-700 hover:bg-gray-100 focus:ring-gray-500 dark:text-gray-300 dark:hover:bg-gray-800',
  }
  base.push(variants[props.variant])

  // Size styles
  const sizes = {
    sm: 'px-3 py-1.5 text-sm',
    md: 'px-4 py-2 text-base',
    lg: 'px-6 py-3 text-lg',
  }
  base.push(sizes[props.size])

  // Full width
  if (props.fullWidth) {
    base.push('w-full')
  }

  return base.join(' ')
})

function handleClick(event: MouseEvent) {
  if (!props.disabled && !props.loading) {
    emit('click', event)
  }
}
</script>
