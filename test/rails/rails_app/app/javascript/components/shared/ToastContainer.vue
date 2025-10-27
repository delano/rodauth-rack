<template>
  <div
    aria-live="assertive"
    class="pointer-events-none fixed inset-0 z-50 flex items-end px-4 py-6 sm:items-start sm:p-6"
  >
    <div class="flex w-full flex-col items-center space-y-4 sm:items-end">
      <Toast
        v-for="toast in toasts"
        :key="toast.id"
        :type="toast.type"
        :message="toast.message"
        :duration="toast.duration"
        @close="removeToast(toast.id)"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import Toast from './Toast.vue'
import type { Toast as ToastType } from '@types/index'

const toasts = ref<ToastType[]>([])

function addToast(toast: Omit<ToastType, 'id'>) {
  const id = Math.random().toString(36).substring(2, 9)
  toasts.value.push({ ...toast, id })
}

function removeToast(id: string) {
  const index = toasts.value.findIndex(t => t.id === id)
  if (index !== -1) {
    toasts.value.splice(index, 1)
  }
}

// Expose methods for external usage
defineExpose({
  addToast,
  removeToast,
})
</script>
